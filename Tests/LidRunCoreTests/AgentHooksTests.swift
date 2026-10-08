import Foundation
import Testing
@testable import LidRunCore

@Test func agentSignalsFromHookEvents() {
    #expect(AgentSignal.from(event: "Notification", type: "permission_prompt", error: nil) == .needsYou)
    #expect(AgentSignal.from(event: "Notification", type: "idle_prompt", error: nil) == .finished)
    #expect(AgentSignal.from(event: "Notification", type: "quota_auto_resume_fired", error: nil) == .resumed)
    #expect(AgentSignal.from(event: "Notification", type: "quota_auto_resume_disabled", error: nil) == .gaveUp)
    #expect(AgentSignal.from(event: "StopFailure", type: nil, error: "rate_limit") == .limitHit)
    #expect(AgentSignal.from(event: "StopFailure", type: nil, error: "overloaded") == .ignore)
    #expect(AgentSignal.from(event: "Stop", type: nil, error: nil) == .turnEnded)
    #expect(AgentSignal.from(event: "Notification", type: "auth_success", error: nil) == .ignore)
}

@Test func claudeHooksInstallKeepsOtherHooksAndRemovesCleanly() {
    let other: [String: Any] = ["matcher": "*", "hooks": [["type": "command", "command": "bash other.sh"]]]
    let original: [String: Any] = ["model": "opus", "hooks": ["SessionStart": [other], "Stop": [other]]]
    let apprun = "/Applications/LidRun Personal.app/Contents/MacOS/apprun"

    let installed = ClaudeHooks.installing(into: original, apprun: apprun)
    #expect(ClaudeHooks.isInstalled(installed))
    #expect(installed["model"] as? String == "opus")
    #expect((installed["hooks"] as? [String: Any])?["Stop"] as? [Any] != nil)
    #expect(((installed["hooks"] as? [String: Any])?["Stop"] as? [Any])?.count == 2)
    // Installing twice must not duplicate.
    #expect((((ClaudeHooks.installing(into: installed, apprun: apprun))["hooks"] as? [String: Any])?["Stop"] as? [Any])?.count == 2)

    let removed = ClaudeHooks.removing(from: installed)
    #expect(!ClaudeHooks.isInstalled(removed))
    let hooks = removed["hooks"] as? [String: Any]
    #expect((hooks?["Stop"] as? [Any])?.count == 1)
    #expect(hooks?["SessionStart"] != nil)
    #expect(hooks?["Notification"] == nil)
    #expect(ClaudeHooks.removing(from: ["model": "x"])["hooks"] == nil)
}
