import Foundation
import Testing
@testable import LidRunCore

final class FakeAssertion: SleepAssertion, @unchecked Sendable {
    private(set) var isHeld = false
    func acquire(reason: String) throws { isHeld = true }
    func release() { isHeld = false }
}

@Test func manualSessionLogsStartAndStop() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let log = EventLog(url: temp.appendingPathComponent("events.jsonl"))
    let assertion = FakeAssertion()
    let controller = SessionController(assertion: assertion, log: log)

    try controller.startManual(now: Date(timeIntervalSince1970: 1))
    #expect(assertion.isHeld)
    #expect(controller.state.isActive)
    #expect(controller.state.whyAwake == "Manual keep-awake")

    controller.stop(reason: .manual, now: Date(timeIntervalSince1970: 2))
    #expect(!assertion.isHeld)
    #expect(!controller.state.isActive)

    let events = try log.recent()
    #expect(events.map(\.type) == [.started, .stopped])
    #expect(events.map(\.reason) == ["Manual keep-awake", "manual"])
}

@Test func startingNewSessionDoesNotLogPhantomStop() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let log = EventLog(url: temp.appendingPathComponent("events.jsonl"))
    let controller = SessionController(assertion: FakeAssertion(), log: log)

    try controller.startTimed(seconds: 30 * 60)

    let events = try log.recent()
    #expect(events.count == 1)
    #expect(events.first?.type == .started)
}

@Test func switchingSessionsNeverReportsInactive() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let log = EventLog(url: temp.appendingPathComponent("events.jsonl"))
    let assertion = FakeAssertion()
    let controller = SessionController(assertion: assertion, log: log)
    var reported: [Bool] = []
    controller.onChange = { reported.append($0.isActive) }

    try controller.startManual()
    try controller.startTimed(seconds: 60)

    #expect(reported == [true, true])
    #expect(assertion.isHeld)
    #expect(try log.recent().map(\.reason) == ["Manual keep-awake", "replaced by new session", "Timer keep-awake"])
}
