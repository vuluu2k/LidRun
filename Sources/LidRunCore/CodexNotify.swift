import Foundation

/// Codex runs one `notify` program per finished turn, passing a JSON payload as its last argument.
/// LidRun wraps any existing program instead of replacing it: `notify = ["<apprun>", "codex-notify", <old program and args>...]`.
public enum CodexNotify {
    public static let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/config.toml")
    static let marker = "\"codex-notify\""

    /// The top-level `notify = [...]` line (before the first table), if any.
    private static func notifyLine(_ lines: [Substring]) -> Int? {
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { return nil }
            if trimmed.hasPrefix("notify"), trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces).hasPrefix("=") { return index }
        }
        return nil
    }

    private static func quote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    public static func isInstalled(_ toml: String) -> Bool {
        let lines = toml.split(separator: "\n", omittingEmptySubsequences: false)
        return notifyLine(lines).map { lines[$0].contains(marker) } ?? false
    }

    /// nil when `notify` is not a one-line array (left alone rather than risk breaking the file).
    public static func installing(into toml: String, apprun: String) -> String? {
        var lines = toml.split(separator: "\n", omittingEmptySubsequences: false)
        let prefix = "notify = [\(quote(apprun)), \(marker)"
        guard let index = notifyLine(lines) else {
            return "\(prefix)]\n" + toml
        }
        if lines[index].contains(marker) { return toml }
        let line = lines[index]
        guard let open = line.firstIndex(of: "["), let close = line.lastIndex(of: "]"), open < close else { return nil }
        let existing = line[line.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
        lines[index] = Substring(existing.isEmpty ? "\(prefix)]" : "\(prefix), \(existing)]")
        return lines.joined(separator: "\n")
    }

    /// Restores the wrapped program, or drops the line when LidRun was the only one.
    public static func removing(from toml: String) -> String {
        var lines = toml.split(separator: "\n", omittingEmptySubsequences: false)
        guard let index = notifyLine(lines), let range = lines[index].range(of: marker) else { return toml }
        let rest = lines[index][range.upperBound...].drop { $0 == "," || $0 == " " }
        if rest.hasPrefix("]") { lines.remove(at: index) } else { lines[index] = Substring("notify = [" + rest) }
        return lines.joined(separator: "\n")
    }

    /// The pieces of the payload LidRun shows: project folder and Codex's last message.
    public static func summary(fromPayload json: String) -> (type: String?, body: String) {
        let object = (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
        let message = (object["last-assistant-message"] as? String).map { String($0.prefix(200)) } ?? "Turn finished"
        let folder = (object["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
        return (object["type"] as? String, folder.map { "\($0): \(message)" } ?? message)
    }
}
