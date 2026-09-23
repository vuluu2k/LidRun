import Foundation
import Testing
@testable import LidRunCore

private struct SafeGuardrails: GuardrailReading {
    func snapshot() -> GuardrailSnapshot {
        GuardrailSnapshot(isCharging: true, batteryPercent: 100, thermalPressure: .nominal)
    }
}

@Test func commandRunnerReleasesAssertionAndReturnsExitCode() throws {
    let assertion = FakeAssertion()
    let logURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("events.jsonl")
    let log = EventLog(url: logURL)
    let runner = CommandRunner(assertion: assertion, log: log, guardrails: SafeGuardrails())

    let result = try runner.run(executable: "/usr/bin/true", arguments: [])

    #expect(result.exitCode == 0)
    #expect(!assertion.isHeld)
    #expect(try log.recent().map(\.type) == [.started, .stopped])
}
