import Foundation

public enum WebhookPlatform: String, Sendable {
    case discord = "Discord"
    case slack = "Slack"
    case teams = "Microsoft Teams"
    case generic = "Generic JSON"

    public static func detect(url: URL) -> WebhookPlatform {
        let host = url.host?.lowercased() ?? ""
        if (host == "discord.com" || host.hasSuffix(".discord.com") || host == "discordapp.com"),
           url.path.contains("/api/webhooks/") { return .discord }
        if host == "hooks.slack.com" { return .slack }
        if host.hasSuffix("webhook.office.com") || host.hasSuffix("logic.azure.com") { return .teams }
        return .generic
    }

    public func body(event: String, reason: String, time: Date = Date()) throws -> Data {
        let timestamp = ISO8601DateFormatter().string(from: time)
        let title = "LidRun · \(event.replacingOccurrences(of: "_", with: " ").capitalized)"
        let payload: [String: Any]

        switch self {
        case .discord:
            payload = [
                "username": "LidRun",
                "embeds": [[
                    "title": title,
                    "description": reason,
                    "color": event == "stopped" ? 15_807_914 : 5_765_719,
                    "timestamp": timestamp,
                ]],
            ]
        case .slack:
            payload = ["text": "*\(title)*\n\(reason)\n`\(timestamp)`"]
        case .teams:
            payload = [
                "type": "message",
                "attachments": [[
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": [
                        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                        "type": "AdaptiveCard",
                        "version": "1.4",
                        "body": [
                            ["type": "TextBlock", "weight": "Bolder", "text": title],
                            ["type": "TextBlock", "wrap": true, "text": reason],
                            ["type": "TextBlock", "isSubtle": true, "text": timestamp],
                        ],
                    ],
                ]],
            ]
        case .generic:
            payload = ["event": event, "reason": reason, "time": timestamp]
        }

        return try JSONSerialization.data(withJSONObject: payload)
    }
}
