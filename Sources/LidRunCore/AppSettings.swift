import Foundation

/// User settings shared by the menu bar app and `apprun` (same UserDefaults domain).
public struct AppSettings: Equatable, Sendable {
    public static let domain = "io.opensource.lidrun"

    public var autoMode = false
    public var extendedDetection = false
    public var chargingOnly = false
    public var thermalSafety = true
    public var alerts = false
    public var lowBatteryPercent: Int? = 5
    public var watchdogMinutes: Int? = 480
    public var webhookURL = ""
    public var webhookToken = ""
    public var customProcessRules = ""
    public var language = "en"
    public var closedLidChecklistAccepted = false
    /// ntfy.sh topic (or full https URL of a self-hosted topic) for phone push notifications.
    public var ntfyTopic = ""
    public var scheduleEnabled = false
    public var scheduleStartHour = 1
    public var scheduleEndHour = 7
    public var sleepWhenWatchEnds = false

    public init() {}

    /// Optional numbers are stored as 0 for "Off": a nil write would delete the key and bring the default back.
    public init(defaults: UserDefaults) {
        let fallback = AppSettings()
        autoMode = defaults.bool(forKey: "autoMode")
        extendedDetection = defaults.bool(forKey: "extendedDetection")
        chargingOnly = defaults.bool(forKey: "chargingOnly")
        thermalSafety = defaults.object(forKey: "thermalSafety") as? Bool ?? fallback.thermalSafety
        alerts = defaults.bool(forKey: "alerts")
        lowBatteryPercent = Self.optional(defaults.object(forKey: "lowBatteryPercent") as? Int ?? fallback.lowBatteryPercent ?? 0)
        watchdogMinutes = Self.optional(defaults.object(forKey: "watchdogMinutes") as? Int ?? fallback.watchdogMinutes ?? 0)
        webhookURL = defaults.string(forKey: "webhookURL") ?? ""
        webhookToken = defaults.string(forKey: "webhookToken") ?? ""
        customProcessRules = defaults.string(forKey: "customProcessRules") ?? ""
        language = defaults.string(forKey: "language") ?? fallback.language
        closedLidChecklistAccepted = defaults.bool(forKey: "closedLidChecklistAccepted")
        ntfyTopic = defaults.string(forKey: "ntfyTopic") ?? ""
        scheduleEnabled = defaults.bool(forKey: "scheduleEnabled")
        scheduleStartHour = defaults.object(forKey: "scheduleStartHour") as? Int ?? fallback.scheduleStartHour
        scheduleEndHour = defaults.object(forKey: "scheduleEndHour") as? Int ?? fallback.scheduleEndHour
        sleepWhenWatchEnds = defaults.bool(forKey: "sleepWhenWatchEnds")
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(autoMode, forKey: "autoMode")
        defaults.set(extendedDetection, forKey: "extendedDetection")
        defaults.set(chargingOnly, forKey: "chargingOnly")
        defaults.set(thermalSafety, forKey: "thermalSafety")
        defaults.set(alerts, forKey: "alerts")
        defaults.set(lowBatteryPercent ?? 0, forKey: "lowBatteryPercent")
        defaults.set(watchdogMinutes ?? 0, forKey: "watchdogMinutes")
        defaults.set(webhookURL, forKey: "webhookURL")
        defaults.set(webhookToken, forKey: "webhookToken")
        defaults.set(customProcessRules, forKey: "customProcessRules")
        defaults.set(language, forKey: "language")
        defaults.set(closedLidChecklistAccepted, forKey: "closedLidChecklistAccepted")
        defaults.set(ntfyTopic, forKey: "ntfyTopic")
        defaults.set(scheduleEnabled, forKey: "scheduleEnabled")
        defaults.set(scheduleStartHour, forKey: "scheduleStartHour")
        defaults.set(scheduleEndHour, forKey: "scheduleEndHour")
        defaults.set(sleepWhenWatchEnds, forKey: "sleepWhenWatchEnds")
    }

    public var guardrailPolicy: GuardrailPolicy {
        GuardrailPolicy(chargingOnly: chargingOnly, lowBatteryPercent: lowBatteryPercent, stopOnThermalPressure: thermalSafety)
    }

    private static func optional(_ value: Int) -> Int? { value == 0 ? nil : value }
}

public enum AutoModeAction: Equatable, Sendable {
    case none
    case start([String])
    case stop
}

public enum AutoMode {
    /// `paused`: the user stopped an Auto session and the same workloads are still running.
    /// `blocked`: a guardrail would stop a new session immediately — starting it caused a start/stop loop.
    public static func decide(
        enabled: Bool, sessionActive: Bool, isAutoSession: Bool,
        workloads: [String], paused: Bool, blocked: Bool
    ) -> AutoModeAction {
        guard enabled else { return .none }
        if isAutoSession, workloads.isEmpty { return .stop }
        if !sessionActive, !workloads.isEmpty, !paused, !blocked { return .start(Array(Set(workloads)).sorted()) }
        return .none
    }
}

/// Daily keep-awake window in local hours, e.g. 1→7 or overnight 23→7.
public enum Schedule {
    /// The end of the window containing `now`, or nil when `now` is outside it. start == end means off.
    public static func activeUntil(now: Date, startHour: Int, endHour: Int, calendar: Calendar = .current) -> Date? {
        guard startHour != endHour else { return nil }
        let hour = calendar.component(.hour, from: now)
        let inside = startHour < endHour ? (startHour..<endHour).contains(hour) : (hour >= startHour || hour < endHour)
        guard inside else { return nil }
        let today = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: now)!
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }
}

/// Phone push via ntfy.sh (free, no account): the user subscribes to the same topic in the ntfy app.
public enum Ntfy {
    public static func request(topic: String, title: String, message: String) -> URLRequest? {
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://ntfy.sh/\(trimmed)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        // Headers are ASCII-only; ntfy decodes RFC 2047 so Vietnamese titles survive.
        request.setValue("=?UTF-8?B?\(Data(title.utf8).base64EncodedString())?=", forHTTPHeaderField: "Title")
        request.setValue("laptop", forHTTPHeaderField: "Tags")
        request.httpBody = Data(message.utf8)
        return request
    }
}
