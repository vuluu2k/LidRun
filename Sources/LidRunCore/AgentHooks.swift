import Foundation

/// What a Claude Code hook event means for LidRun.
public enum AgentSignal: Equatable, Sendable {
    case needsYou      // permission prompt or question
    case finished      // done and idle, waiting for the next prompt
    case limitHit      // turn failed on a usage/rate limit; Claude Code auto-resumes at the reset
    case resumed       // auto-resume fired after the limit reset
    case gaveUp        // auto-resume was cancelled
    case turnEnded
    case ignore

    public static func from(event: String?, type: String?, error: String?) -> AgentSignal {
        switch (event, type) {
        case ("Notification", "permission_prompt"?), ("Notification", "elicitation_dialog"?),
             ("Notification", "elicitation_url_dialog"?), ("Notification", "agent_needs_input"?):
            return .needsYou
        case ("Notification", "idle_prompt"?), ("Notification", "agent_completed"?): return .finished
        case ("Notification", "quota_auto_resume_fired"?), ("Notification", "quota_auto_resume_stale"?): return .resumed
        case ("Notification", "quota_auto_resume_disabled"?): return .gaveUp
        case ("StopFailure", _): return error == "rate_limit" ? .limitHit : .ignore
        case ("Stop", _): return .turnEnded
        default: return .ignore
        }
    }
}

/// Adds or removes LidRun's command hooks in Claude Code's settings.json, leaving every other key and hook alone.
public enum ClaudeHooks {
    public static let events = ["Notification", "Stop", "StopFailure", "PermissionRequest"]
    public static let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")

    public static func command(apprun: String) -> String { "'\(apprun)' hook" }

    private static func isOurs(_ group: Any) -> Bool {
        ((group as? [String: Any])?["hooks"] as? [[String: Any]])?.contains { ($0["command"] as? String)?.hasSuffix("/apprun' hook") == true } == true
    }

    public static func isInstalled(_ settings: [String: Any]) -> Bool {
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        return events.allSatisfy { (hooks[$0] as? [Any])?.contains(where: isOurs) == true }
    }

    public static func removing(from settings: [String: Any]) -> [String: Any] {
        var settings = settings
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            let kept = (hooks[event] as? [Any] ?? []).filter { !isOurs($0) }
            hooks[event] = kept.isEmpty ? nil : kept
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        return settings
    }

    public static func installing(into settings: [String: Any], apprun: String) -> [String: Any] {
        var settings = removing(from: settings)
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            // PermissionRequest may wait for an answer from the phone (RemoteApproval.wait), up to Claude Code's 600 s cap.
            let timeout = event == "PermissionRequest" ? 600 : 10
            let group: [String: Any] = ["hooks": [["type": "command", "command": command(apprun: apprun), "timeout": timeout]]]
            hooks[event] = (hooks[event] as? [Any] ?? []) + [group]
        }
        settings["hooks"] = hooks
        return settings
    }

    /// nil when the file is missing; throws when it exists but is not a JSON object, so it is never overwritten.
    public static func read(_ url: URL = settingsURL) throws -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        return object
    }

    public static func write(_ settings: [String: Any], to url: URL = settingsURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
    }
}
