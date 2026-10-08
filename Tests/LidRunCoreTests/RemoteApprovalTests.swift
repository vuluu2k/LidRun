import Foundation
import Testing
@testable import LidRunCore

@Test func remoteApprovalButtonsAndAnswers() throws {
    let request = try #require(RemoteApproval.askRequest(topic: "lidrun-abc", title: "t", message: "m", nonce: "N1"))
    #expect(request.url?.absoluteString == "https://ntfy.sh/lidrun-abc")
    let actions = try #require(request.value(forHTTPHeaderField: "Actions"))
    #expect(actions.contains("https://ntfy.sh/lidrun-abc-reply, method=POST, body=N1 allow"))
    #expect(actions.contains("body=N1 deny"))
    #expect(RemoteApproval.replyURL(topic: "https://ntfy.example.com/x")?.absoluteString == "https://ntfy.example.com/x-reply")

    let poll = """
    {"event":"message","message":"OLD allow"}
    {"event":"message","message":"N1 deny"}
    """
    #expect(RemoteApproval.decision(inPoll: poll, nonce: "N1") == false)
    #expect(RemoteApproval.decision(inPoll: poll, nonce: "N2") == nil)
    #expect(RemoteApproval.decision(inPoll: #"{"message":"N2 allow"}"#, nonce: "N2") == true)

    #expect(RemoteApproval.hookOutput(allow: true) == #"{"hookSpecificOutput":{"decision":{"behavior":"allow"},"hookEventName":"PermissionRequest"}}"#)
    #expect(RemoteApproval.describe(tool: "Bash", input: ["command": "npm test"]) == "Bash: npm test")
    #expect(RemoteApproval.describe(tool: "ExitPlanMode", input: ["plan": "1. do it"]) == "Plan: 1. do it")
    #expect(RemoteApproval.secondsSinceInput >= 0)
}
