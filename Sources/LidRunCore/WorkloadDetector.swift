import Foundation

public struct RunningProcess: Equatable, Sendable {
    public let name: String
    public let command: String
    /// `ps` %CPU, a decaying average over roughly the last minute.
    public let cpu: Double

    public init(name: String, command: String, cpu: Double = 0) {
        self.name = name
        self.command = command
        self.cpu = cpu
    }
}

public struct DevWorkload: Equatable, Sendable {
    public let label: String
    public let process: RunningProcess

    public init(label: String, process: RunningProcess) {
        self.label = label
        self.process = process
    }
}

public enum WorkloadDetector {
    // Exact executable names (case-sensitive) plus command fragments. Substring matching on names caught
    // unrelated processes: macOS's CursorUIViewService, the Claude desktop app, anything under a "claude" path.
    // Idle daemons (Docker Desktop, `ollama serve`) are not workloads; active CLI runs and loaded models are.
    private static let matchers: [(label: String, names: Set<String>, commands: [String])] = [
        ("Claude Code", ["claude"], ["@anthropic-ai/claude-code", "claude-code/cli.js"]),
        ("Codex", ["codex"], ["@openai/codex"]),
        ("Cursor", ["Cursor"], []),
        ("Docker", ["docker", "docker-compose"], []),
        ("Ollama", [], ["ollama run"]),
    ]

    /// Opt-in: these runtimes also back many long-lived background tools, so they would keep some Macs awake forever.
    private static let extendedMatchers: [(label: String, names: Set<String>, commands: [String])] = [
        ("Python", ["python", "python3", "Python"], []),
        ("Node", ["node", "bun", "deno"], []),
        ("SSH", ["ssh", "scp", "sftp", "rsync", "mosh-client"], []),
        ("Xcode build", ["xcodebuild", "swift-build", "swift-frontend"], []),
    ]

    public static func detect(in processes: [RunningProcess], customNeedles: [String] = [], extended: Bool = false) -> [DevWorkload] {
        let matchers = extended ? matchers + extendedMatchers : matchers
        return processes.compactMap { process in
            let command = process.command.lowercased()
            if let match = matchers.first(where: { matcher in
                matcher.names.contains(process.name) || matcher.commands.contains { command.contains($0) }
            }) {
                return DevWorkload(label: match.label, process: process)
            }
            let haystack = "\(process.name) \(process.command)".lowercased()
            guard let custom = customNeedles.first(where: { !$0.isEmpty && haystack.contains($0.lowercased()) }) else { return nil }
            return DevWorkload(label: custom, process: process)
        }
    }
}

public protocol ProcessListing: Sendable {
    func processes() -> [RunningProcess]
}

public struct SystemProcessList: ProcessListing {
    public init() {}

    public func processes() -> [RunningProcess] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pcpu=,comm=,command="]
        process.environment = ["LC_ALL": "C"]  // "0,1" in comma-decimal locales would drop every line
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            let parts = text.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 2 else { return nil }
            let cpu = Double(parts[0].replacingOccurrences(of: ",", with: ".")) ?? 0
            let name = URL(fileURLWithPath: parts[1]).lastPathComponent
            return RunningProcess(name: name, command: parts.count > 2 ? parts[2] : parts[1], cpu: cpu)
        }
    }
}

public struct WatchCandidate: Identifiable, Equatable, Sendable {
    public let id: Int32
    public let name: String
    public let cpu: Double

    public init(id: Int32, name: String, cpu: Double) {
        self.id = id
        self.name = name
        self.cpu = cpu
    }
}

public extension SystemProcessList {
    /// The current user's processes, busiest first — what someone would want to "keep awake until it ends".
    func userProcesses(limit: Int = 60) -> [WatchCandidate] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-U", String(getuid()), "-o", "pid=,pcpu=,comm="]
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let me = getpid()
        return (String(data: data, encoding: .utf8) ?? "").split(separator: "\n").compactMap { line -> WatchCandidate? in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = Int32(parts[0]), pid != me, let cpu = Double(parts[1]) else { return nil }
            return WatchCandidate(id: pid, name: URL(fileURLWithPath: String(parts[2])).lastPathComponent, cpu: cpu)
        }
        .sorted { $0.cpu > $1.cpu }
        .prefix(limit).map { $0 }
    }
}

/// Detects uploads/downloads by sampling interface byte counters between calls.
public final class NetworkActivity: @unchecked Sendable {
    private var last: (bytes: UInt64, time: Date)?

    public init() {}

    /// Bytes per second since the previous call (nil on the first call).
    public func rate(now: Date = Date()) -> Double? {
        let bytes = Self.totalBytes()
        defer { last = (bytes, now) }
        guard let last, now > last.time, bytes >= last.bytes else { return nil }
        return Double(bytes - last.bytes) / now.timeIntervalSince(last.time)
    }

    static func totalBytes() -> UInt64 {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return 0 }
        defer { freeifaddrs(head) }
        var total: UInt64 = 0
        var cursor = head
        while let entry = cursor?.pointee {
            defer { cursor = entry.ifa_next }
            guard entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = entry.ifa_data,
                  !String(cString: entry.ifa_name).hasPrefix("lo") else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            total += UInt64(stats.ifi_ibytes) + UInt64(stats.ifi_obytes)
        }
        return total
    }
}
