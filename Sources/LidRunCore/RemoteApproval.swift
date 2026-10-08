import CoreGraphics
import Foundation

/// Answers a Claude Code permission prompt (or plan approval) from the phone, with no server:
/// the ntfy push carries Allow/Deny buttons that post `<nonce> allow|deny` to `<topic>-reply`,
/// and the waiting hook polls that topic. Only the per-request random nonce is accepted.
public enum RemoteApproval {
    /// Seconds without keyboard/mouse input before you count as away (display still on).
    public static let awayAfterIdle: TimeInterval = 120

    public static var secondsSinceInput: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    public static var userIsAway: Bool {
        SystemSleep.isLidClosed || CGDisplayIsAsleep(CGMainDisplayID()) != 0 || secondsSinceInput > awayAfterIdle
    }

    public static func replyURL(topic: String) -> URL? {
        Ntfy.request(topic: topic, title: "", message: "")?.url.flatMap { URL(string: $0.absoluteString + "-reply") }
    }

    public static func askRequest(topic: String, title: String, message: String, nonce: String) -> URLRequest? {
        guard var request = Ntfy.request(topic: topic, title: title, message: message), let reply = replyURL(topic: topic) else { return nil }
        let button = { (label: String, answer: String) in "http, \(label), \(reply.absoluteString), method=POST, body=\(nonce) \(answer), clear=true" }
        request.setValue(button("Allow", "allow") + "; " + button("Deny", "deny"), forHTTPHeaderField: "Actions")
        request.setValue("high", forHTTPHeaderField: "Priority")
        return request
    }

    /// Scans an ntfy `/json?poll=1` response for this request's answer.
    public static func decision(inPoll body: String, nonce: String) -> Bool? {
        for line in body.split(separator: "\n") {
            guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  let message = object["message"] as? String else { continue }
            if message == "\(nonce) allow" { return true }
            if message == "\(nonce) deny" { return false }
        }
        return nil
    }

    public static func hookOutput(allow: Bool) -> String {
        let decision: [String: Any] = allow ? ["behavior": "allow"] : ["behavior": "deny", "message": "Denied from the phone (LidRun)."]
        let object: [String: Any] = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        return String(data: (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data(), encoding: .utf8) ?? ""
    }

    /// One readable line for the push: the command, file or plan being approved.
    public static func describe(tool: String, input: [String: Any]) -> String {
        let detail = ["command", "plan", "file_path", "url", "pattern"].lazy.compactMap { input[$0] as? String }.first ?? ""
        let name = tool == "ExitPlanMode" ? "Plan" : tool
        return detail.isEmpty ? name : "\(name): \(detail.prefix(400))"
    }

    /// Polls for the answer every 3 s. Returns nil (let the terminal ask) on timeout, or as soon as you are back at the Mac.
    public static func wait(topic: String, nonce: String, since: Date, timeout: TimeInterval, present: () -> Bool = { secondsSinceInput < 5 }) -> Bool? {
        guard let reply = replyURL(topic: topic),
              let url = URL(string: reply.absoluteString + "/json?poll=1&since=\(Int(since.timeIntervalSince1970))") else { return nil }
        let deadline = since.addingTimeInterval(timeout)
        while Date() < deadline {
            if present() { return nil }
            // ponytail: blocking fetch with the system timeout; fine for a 3 s poll in a short-lived hook process.
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if let answer = decision(inPoll: body, nonce: nonce) { return answer }
            Thread.sleep(forTimeInterval: 3)
        }
        return nil
    }
}
