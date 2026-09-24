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
