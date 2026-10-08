import Foundation
import Testing
@testable import LidRunCore

@Test func codexNotifyWrapsExistingProgramAndRestoresIt() throws {
    let original = """
    model = "gpt"
    notify = ["/Apps/Sky Client", "turn-ended"]

    [features]
    notify = "not top level"
    """
    let apprun = "/Applications/LidRun Personal.app/Contents/MacOS/apprun"
    let installed = try #require(CodexNotify.installing(into: original, apprun: apprun))
    #expect(installed.contains(#"notify = ["/Applications/LidRun Personal.app/Contents/MacOS/apprun", "codex-notify", "/Apps/Sky Client", "turn-ended"]"#))
    #expect(CodexNotify.isInstalled(installed))
    #expect(CodexNotify.installing(into: installed, apprun: apprun) == installed)
    #expect(CodexNotify.removing(from: installed) == original)

    let bare = "model = \"gpt\"\n"
    let added = try #require(CodexNotify.installing(into: bare, apprun: apprun))
    #expect(CodexNotify.isInstalled(added))
    #expect(CodexNotify.removing(from: added) == bare)
    #expect(CodexNotify.installing(into: "notify = [\n  \"x\",\n]\n", apprun: apprun) == nil)
}

@Test func codexPayloadSummary() {
    let summary = CodexNotify.summary(fromPayload: #"{"type":"agent-turn-complete","cwd":"/x/shop","last-assistant-message":"Done"}"#)
    #expect(summary.type == "agent-turn-complete")
    #expect(summary.body == "shop: Done")
}
