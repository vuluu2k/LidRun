import Foundation

/// A plain text file of shell commands, one per line, run top to bottom by `apprun queue run`.
/// Editing the file by hand is fine; lines added while the queue runs are picked up.
public struct JobQueue: Sendable {
    public let url: URL

    public init(url: URL = EventLog.defaultURL().deletingLastPathComponent().appendingPathComponent("queue.txt")) {
        self.url = url
    }

    public func list() -> [String] {
        ((try? String(contentsOf: url, encoding: .utf8)) ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    public func add(_ command: [String]) throws {
        try save(list() + [command.map(Self.shellQuote).joined(separator: " ")])
    }

    /// Removes and returns the first job.
    // ponytail: read-modify-write without a file lock; an `add` landing in the same instant can be lost. Add flock if people script concurrent adds.
    public func pop() throws -> String? {
        var jobs = list()
        guard !jobs.isEmpty else { return nil }
        let first = jobs.removeFirst()
        try save(jobs)
        return first
    }

    public func clear() throws { try save([]) }

    // MARK: Runner state, shared with the menu bar app through small files next to the queue

    private var directory: URL { url.deletingLastPathComponent() }
    private var pausedFlag: URL { directory.appendingPathComponent("queue.paused") }
    private var runningFile: URL { directory.appendingPathComponent("queue.running") }
    public var logDirectory: URL { directory.appendingPathComponent("logs", isDirectory: true) }

    /// A paused queue finishes its current job, then waits before starting the next one.
    public var isPaused: Bool { FileManager.default.fileExists(atPath: pausedFlag.path) }

    public func setPaused(_ paused: Bool) {
        if paused {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: pausedFlag.path, contents: nil)
        } else {
            try? FileManager.default.removeItem(at: pausedFlag)
        }
    }

    /// Records the job a runner (`pid`) is on; nil clears it.
    public func setRunning(_ job: String?, pid: Int32 = getpid()) {
        guard let job else { try? FileManager.default.removeItem(at: runningFile); return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? "\(pid)\n\(job)".write(to: runningFile, atomically: true, encoding: .utf8)
    }

    /// The job being run right now, ignoring a marker left by a runner that was killed.
    public func running() -> String? {
        guard let text = try? String(contentsOf: runningFile, encoding: .utf8) else { return nil }
        let parts = text.split(separator: "\n", maxSplits: 1).map(String.init)
        guard parts.count == 2, let pid = Int32(parts[0]), kill(pid, 0) == 0 else { return nil }
        return parts[1]
    }

    /// A fresh log file for one job; keeps the newest `keep` logs.
    public func newLog(for job: String, now: Date = Date(), keep: Int = 50) -> URL {
        let manager = FileManager.default
        try? manager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        let old = ((try? manager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        old.dropFirst(max(0, keep - 1)).forEach { try? manager.removeItem(at: $0) }
        // UTC so names sort in time order across DST/travel; the pid keeps same-second jobs apart.
        let stamp = ISO8601DateFormatter.string(from: now, timeZone: .gmt, formatOptions: [.withFullDate, .withTime])
        let slug = String(job.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(40))
        return logDirectory.appendingPathComponent("\(stamp)-\(getpid())-\(slug).log")
    }

    /// The last `lines` non-empty lines of a log, capped for a phone push.
    public static func tail(of log: URL, lines: Int = 5, maxLength: Int = 600) -> String {
        guard let data = try? Data(contentsOf: log) else { return "" }
        let text = String(decoding: data, as: UTF8.self)
        let last = text.split(separator: "\n").suffix(lines).joined(separator: "\n")
        return last.count > maxLength ? "…" + last.suffix(maxLength) : last
    }

    private func save(_ jobs: [String]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (jobs.map { $0 + "\n" }.joined()).write(to: url, atomically: true, encoding: .utf8)
    }

    /// Single-quotes an argument for `/bin/sh -c` unless it is plainly safe.
    public static func shellQuote(_ arg: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./=:@%+,"))
        if !arg.isEmpty, arg.unicodeScalars.allSatisfy(safe.contains) { return arg }
        return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Turns a Claude Code / Codex hook's stdin JSON into a short push line.
public enum HookMessage {
    public static func body(from json: Data, fallback: String) -> String {
        let object = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] ?? [:]
        let message = (object["message"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        guard let cwd = object["cwd"] as? String, !cwd.isEmpty else { return message }
        return "\(URL(fileURLWithPath: cwd).lastPathComponent): \(message)"
    }
}
