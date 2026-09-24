import Foundation
import Testing
@testable import LidRunCore

private func freshDefaults() -> UserDefaults {
    let name = "lidrun-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func settingsRoundTripIncludingOffValues() {
    let defaults = freshDefaults()
    var settings = AppSettings()
    settings.chargingOnly = true
    settings.lowBatteryPercent = nil
    settings.watchdogMinutes = nil
    settings.webhookToken = "secret"
    settings.extendedDetection = true
    settings.save(to: defaults)

    #expect(AppSettings(defaults: defaults) == settings)
}

@Test func missingSettingsUseSafeDefaults() {
    let settings = AppSettings(defaults: freshDefaults())
    #expect(settings.thermalSafety)
    #expect(settings.lowBatteryPercent == 5)
    #expect(settings.watchdogMinutes == 480)
}

@Test func autoModeStartsOnlyWhenAllowed() {
    func decide(active: Bool = false, auto: Bool = false, workloads: [String] = ["Docker"], paused: Bool = false, blocked: Bool = false) -> AutoModeAction {
        AutoMode.decide(enabled: true, sessionActive: active, isAutoSession: auto, workloads: workloads, paused: paused, blocked: blocked)
    }
    #expect(decide(workloads: ["Node", "Docker", "Node"]) == .start(["Docker", "Node"]))
    #expect(decide(blocked: true) == .none)          // guardrail: no start/stop loop
    #expect(decide(paused: true) == .none)           // user stopped it: stay stopped
    #expect(decide(active: true) == .none)           // never replaces a manual session
    #expect(decide(active: true, auto: true, workloads: []) == .stop)
    #expect(decide(active: true, auto: false, workloads: []) == .none)
    #expect(AutoMode.decide(enabled: false, sessionActive: false, isAutoSession: false, workloads: ["Docker"], paused: false, blocked: false) == .none)
}

@Test func scheduleHandlesDaytimeAndOvernightWindows() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    func at(_ hour: Int, day: Int = 1) -> Date { calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: 30))! }
    func end(_ hour: Int, day: Int = 1) -> Date { calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour))! }

    #expect(Schedule.activeUntil(now: at(3), startHour: 1, endHour: 7, calendar: calendar) == end(7))
    #expect(Schedule.activeUntil(now: at(8), startHour: 1, endHour: 7, calendar: calendar) == nil)
    #expect(Schedule.activeUntil(now: at(23), startHour: 23, endHour: 7, calendar: calendar) == end(7, day: 2))
    #expect(Schedule.activeUntil(now: at(2), startHour: 23, endHour: 7, calendar: calendar) == end(7))
    #expect(Schedule.activeUntil(now: at(12), startHour: 23, endHour: 7, calendar: calendar) == nil)
    #expect(Schedule.activeUntil(now: at(5), startHour: 5, endHour: 5, calendar: calendar) == nil)
}

@Test func ntfyAcceptsTopicOrURL() {
    #expect(Ntfy.request(topic: " my-topic ", title: "t", message: "m")?.url?.absoluteString == "https://ntfy.sh/my-topic")
    #expect(Ntfy.request(topic: "https://ntfy.example.com/x", title: "t", message: "m")?.url?.absoluteString == "https://ntfy.example.com/x")
    #expect(Ntfy.request(topic: "", title: "t", message: "m") == nil)
}

@Test func pushFiltersRespectTogglesAndWindow() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let night = Date(timeIntervalSince1970: 2 * 3600)   // 02:00 UTC
    let day = Date(timeIntervalSince1970: 10 * 3600)    // 10:00 UTC
    var settings = AppSettings()
    #expect(settings.allowsPush(event: "agent_idle", now: night, calendar: calendar))

    settings.idleAgentAlerts = false
    #expect(!settings.allowsPush(event: "agent_idle", now: day, calendar: calendar))

    settings.pushWindowEnabled = true   // 07:00–23:00
    #expect(settings.allowsPush(event: "command_finished", now: day, calendar: calendar))
    #expect(!settings.allowsPush(event: "command_finished", now: night, calendar: calendar))
    #expect(settings.allowsPush(event: "battery_warning", now: night, calendar: calendar))   // safety ignores the window
    settings.batteryAlerts = false
    #expect(!settings.allowsPush(event: "battery_warning", now: night, calendar: calendar))
}
