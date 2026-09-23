import Foundation

public struct RunningProcess: Equatable, Sendable {
    public let name: String
    public let command: String

    public init(name: String, command: String) {
        self.name = name
        self.command = command
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
        ("Cursor", ["Cursor"], []),
        ("Docker", ["docker", "docker-compose"], []),
        ("Ollama", [], ["ollama run"]),
    ]

    public static func detect(in processes: [RunningProcess], customNeedles: [String] = []) -> [DevWorkload] {
        processes.compactMap { process in
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
        process.arguments = ["-axo", "comm=,command="]
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.split(separator: "\n").compactMap { line in
            let text = String(line).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
            let name = URL(fileURLWithPath: parts[0]).lastPathComponent
            return RunningProcess(name: name, command: parts.dropFirst().first ?? text)
        }
    }
}
