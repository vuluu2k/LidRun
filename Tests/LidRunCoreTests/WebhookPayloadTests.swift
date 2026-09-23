import Foundation
import Testing
@testable import LidRunCore

@Test func detectsSupportedWebhookPlatforms() throws {
    #expect(WebhookPlatform.detect(url: try #require(URL(string: "https://discord.com/api/webhooks/1/token"))) == .discord)
    #expect(WebhookPlatform.detect(url: try #require(URL(string: "https://hooks.slack.com/services/a/b/c"))) == .slack)
    #expect(WebhookPlatform.detect(url: try #require(URL(string: "https://example.webhook.office.com/x"))) == .teams)
    #expect(WebhookPlatform.detect(url: try #require(URL(string: "https://example.com/hook"))) == .generic)
}

@Test func discordPayloadContainsEmbed() throws {
    let data = try WebhookPlatform.discord.body(event: "started", reason: "Docker build")
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["username"] as? String == "LidRun")
    #expect((object["embeds"] as? [[String: Any]])?.first?["description"] as? String == "Docker build")
}

@Test func genericPayloadKeepsMachineReadableFields() throws {
    let data = try WebhookPlatform.generic.body(event: "stopped", reason: "low battery")
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["event"] as? String == "stopped")
    #expect(object["reason"] as? String == "low battery")
}
