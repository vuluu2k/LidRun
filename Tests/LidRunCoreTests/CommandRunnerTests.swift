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

@Test func commandRunnerCopiesOutputToLog() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let queue = JobQueue(url: dir.appendingPathComponent("queue.txt"))
    let log = queue.newLog(for: "echo test")
    let runner = CommandRunner(assertion: FakeAssertion(), log: EventLog(url: dir.appendingPathComponent("events.jsonl")), guardrails: SafeGuardrails())

    let result = try runner.run(executable: "/bin/sh", arguments: ["-c", "echo one; echo two >&2; exit 3"], outputLog: log)

    #expect(result.exitCode == 3)
    #expect(JobQueue.tail(of: log) == "one\ntwo")
}
