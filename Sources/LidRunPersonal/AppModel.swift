import AppKit
import Foundation
import LidRunCore
import ServiceManagement
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var session = SessionState(isActive: false, whyAwake: "Inactive", nextRelease: "None")
    @Published private(set) var snapshot: GuardrailSnapshot?
    @Published private(set) var workloads: [DevWorkload] = []
    @Published private(set) var recentEvents: [RunEvent] = []
    @Published private(set) var systemMetrics = SystemMetrics(cpuPercent: 0, displayIsAsleep: false)
    @Published var autoModeEnabled = false
    @Published var chargingOnly = false
    @Published var thermalSafety = true
    @Published var closedLidEnabled = false
    @Published var alertsEnabled = false
    @Published var lowBatteryPercent: Int? = 5
    @Published var watchdogMinutes: Int? = 480
    @Published var webhookURL = ""
    @Published var webhookToken = ""
    @Published var customProcessRules = ""
    @Published var launchAtLogin = false
    @Published var language: AppLanguage = .english
    @Published var errorMessage: String?
    @Published private(set) var notificationStatus = "Not requested"
    @Published private(set) var webhookStatus = "Not configured"
    @Published private(set) var hotKeysReady = false
    @Published private var now = Date()

    private let controller = SessionController()
    private let closedLidAssertion = SystemPowerAssertion(kind: .systemSleep)
    private let guardrailReader = SystemGuardrailReader()
    private let processList = SystemProcessList()
    private let metricsReader = SystemMetricsReader()
    private let eventLog = EventLog()
    private var monitor: Timer?
    private var ticker: Timer?
    private var metricsMonitor: Timer?
    private var watchdog: Timer?
    private var heatAlertSent = false

    init() {
        loadSettings()
        refreshNotificationStatus()
        controller.onChange = { [weak self] state in
            Task { @MainActor in self?.sessionChanged(state) }
        }
        refresh()
        monitor = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        updateSystemMetrics()
        metricsMonitor = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateSystemMetrics() }
        }
    }

    var batteryText: String { snapshot?.batteryPercent.map { "\($0)%" } ?? "--" }
    var thermalText: String {
        guard let pressure = snapshot?.thermalPressure else { return "--" }
        let key: String
        switch pressure {
        case .nominal: key = "thermalOK"
        case .fair: key = "thermalWarm"
        case .serious: key = "thermalHot"
        case .critical: key = "thermalCritical"
        }
        return L10n.text(key, language)
    }
    var uniqueWorkloadCount: Int { Set(workloads.map(\.label)).count }
    var cpuText: String { "\(systemMetrics.cpuPercent)%" }
    var temperatureText: String { systemMetrics.temperatureCelsius.map { "\($0)°C" } ?? thermalText }
    var temperatureSeverity: TemperatureSeverity { .classify(systemMetrics.temperatureCelsius) }
    var fanText: String { systemMetrics.fanRPM.map { "\($0)" } ?? "N/A" }
    var displayText: String { systemMetrics.displayIsAsleep ? "Off" : "On" }
    var activeDurationText: String {
        guard let startedAt = session.startedAt else { return L10n.text("notRunning", language) }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
    var isCharging: Bool { snapshot?.isCharging == true }
    func webhookPlatform(for value: String) -> String {
        guard let url = URL(string: value), !value.isEmpty else { return "Not configured" }
        return WebhookPlatform.detect(url: url).rawValue
    }
    var workloadText: String {
        Array(Set(workloads.map(\.label))).sorted().joined(separator: ", ").nilIfEmpty ?? L10n.text("noTasks", language)
    }
    var weeklyEvents: [RunEvent] {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return recentEvents.filter { $0.time >= cutoff }
    }
    var protectedSessions: Int { weeklyEvents.filter { $0.type == .started }.count }
    var safetyStops: Int {
        let reasons = Set([StopReason.lowBattery.rawValue, StopReason.thermalPressure.rawValue, StopReason.chargerDisconnected.rawValue])
        return weeklyEvents.filter { $0.type == .stopped && reasons.contains($0.reason) }.count
    }
    var protectedTimeText: String {
        var start: Date?
        var seconds: TimeInterval = 0
        for event in weeklyEvents {
            if event.type == .started { start = event.time }
            if event.type == .stopped, let began = start { seconds += event.time.timeIntervalSince(began); start = nil }
        }
        if let start { seconds += Date().timeIntervalSince(start) }
        return String(format: "%.1fh", seconds / 3600)
    }
    var weeklyReport: String {
        """
        # LidRun Weekly Report
        - Protected time: \(protectedTimeText)
        - Sessions: \(protectedSessions)
        - Safety stops: \(safetyStops)
        - Active workloads: \(workloadText)
        """
    }

    func toggleKeepAwake() {
        if session.isActive {
            stop()
        } else {
            chargingOnly = false
            saveSettings()
            start { try controller.startManual() }
        }
    }

    func startTimer(minutes: Int) { start { try controller.startTimed(seconds: TimeInterval(minutes * 60)) } }

    func stop() {
        watchdog?.invalidate()
        closedLidAssertion.release()
        closedLidEnabled = false
        controller.stop()
    }

    func setAutoMode(_ enabled: Bool) { autoModeEnabled = enabled; saveSettings(); refresh() }
    func setChargingOnly(_ enabled: Bool) { chargingOnly = enabled; saveSettings(); evaluateSafety() }
    func setThermalSafety(_ enabled: Bool) { thermalSafety = enabled; saveSettings(); evaluateSafety() }
    func setLowBattery(_ percent: Int?) { lowBatteryPercent = percent; saveSettings(); evaluateSafety() }

    func setClosedLid(_ enabled: Bool) {
        do {
            if enabled {
                if !session.isActive { try controller.startManual() }
                try closedLidAssertion.acquire(reason: "Closed-Lid Mode")
            } else {
                closedLidAssertion.release()
            }
            closedLidEnabled = enabled
        } catch {
            closedLidEnabled = false
            errorMessage = String(describing: error)
        }
    }

    func setAlerts(_ enabled: Bool) {
        if !enabled {
            alertsEnabled = false
            notificationStatus = "Disabled"
            saveSettings()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                self?.alertsEnabled = granted
                self?.notificationStatus = granted ? "Authorized" : "Denied"
                self?.saveSettings()
                if error != nil { self?.errorMessage = "Notifications are unavailable for this app identity. Reinstall the latest build or enable LidRun in System Settings → Notifications." }
            }
        }
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func sendTestNotification() {
        guard alertsEnabled else { setAlerts(true); return }
        let content = UNMutableNotificationContent()
        content.title = "LidRun test"
        content.body = "Notifications are working."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func setHotKeysReady(_ ready: Bool) { hotKeysReady = ready }

    func setWatchdog(minutes: Int?) {
        watchdogMinutes = minutes
        saveSettings()
        scheduleWatchdog()
    }

    func saveWebhook(_ value: String) {
        webhookURL = value.trimmingCharacters(in: .whitespacesAndNewlines)
        webhookStatus = webhookURL.isEmpty ? "Not configured" : "Saved"
        saveSettings()
    }

    func sendTestWebhook() {
        saveWebhook(webhookURL)
        guard !webhookURL.isEmpty else { return }
        publish(title: "LidRun test", body: "Webhook test", event: "test", reportWebhookStatus: true)
    }

    func setLanguage(_ value: AppLanguage) { language = value; saveSettings() }
    func saveCustomRules(_ value: String) { customProcessRules = value; saveSettings(); refresh() }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled
        } catch {
            launchAtLogin = false
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        snapshot = guardrailReader.snapshot()
        let custom = customProcessRules.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        workloads = WorkloadDetector.detect(in: processList.processes(), customNeedles: custom)
        recentEvents = (try? eventLog.recent(limit: 100)) ?? []
        evaluateAutoMode()
        evaluateSafety()
    }

    func shutdown() {
        monitor?.invalidate()
        ticker?.invalidate()
        metricsMonitor?.invalidate()
        watchdog?.invalidate()
        closedLidAssertion.release()
        controller.stop(reason: .appQuit)
    }

    private func updateSystemMetrics() {
        let reader = metricsReader
        Task.detached {
            let metrics = reader.snapshot()
            await MainActor.run { [weak self] in
                self?.systemMetrics = metrics
                self?.evaluateHardwareTemperature()
            }
        }
    }

    private func evaluateHardwareTemperature() {
        guard thermalSafety, let temperature = systemMetrics.hotspotTemperatureCelsius else { return }
        if temperature >= 100, session.isActive {
            controller.stop(reason: .thermalPressure)
        } else if temperature >= 90, !heatAlertSent {
            heatAlertSent = true
            publish(title: "LidRun thermal warning", body: "CPU hotspot is \(temperature)°C", event: "thermal_warning")
        } else if temperature < 85 {
            heatAlertSent = false
        }
    }

    private var policy: GuardrailPolicy {
        GuardrailPolicy(chargingOnly: chargingOnly, lowBatteryPercent: lowBatteryPercent, stopOnThermalPressure: thermalSafety)
    }

    private func sessionChanged(_ state: SessionState) {
        session = state
        if state.isActive {
            scheduleWatchdog()
            publish(title: "LidRun started", body: state.whyAwake, event: "started")
        } else {
            watchdog?.invalidate()
            closedLidAssertion.release()
            closedLidEnabled = false
            let reason = (try? eventLog.recent(limit: 1).last?.reason) ?? "stopped"
            publish(title: "LidRun stopped", body: reason, event: "stopped")
        }
        recentEvents = (try? eventLog.recent(limit: 100)) ?? []
    }

    private func evaluateAutoMode() {
        guard autoModeEnabled else { return }
        let autoSession = session.whyAwake.hasPrefix("Auto Mode:")
        if session.isActive, autoSession, workloads.isEmpty {
            controller.stop(reason: .workloadFinished)
        } else if !session.isActive, !workloads.isEmpty {
            let labels = Array(Set(workloads.map(\.label))).sorted()
            start { try controller.startAuto(workloads: labels) }
        }
    }

    private func evaluateSafety() {
        guard session.isActive, let snapshot else { return }
        if case .stop(let reason) = SafetyGovernor.evaluate(snapshot, policy: policy) {
            controller.stop(reason: reason)
        }
    }

    private func scheduleWatchdog() {
        watchdog?.invalidate()
        guard session.isActive, let minutes = watchdogMinutes else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.controller.stop(reason: .timerExpired) }
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                switch status {
                case .authorized, .provisional: self?.notificationStatus = "Authorized"
                case .denied: self?.notificationStatus = "Denied"
                default: self?.notificationStatus = "Not requested"
                }
            }
        }
    }

    private func publish(title: String, body: String, event: String, reportWebhookStatus: Bool = false) {
        if alertsEnabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
        guard let url = URL(string: webhookURL), !webhookURL.isEmpty else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !webhookToken.isEmpty { request.setValue("Bearer \(webhookToken)", forHTTPHeaderField: "Authorization") }
        let platform = WebhookPlatform.detect(url: url)
        request.httpBody = try? platform.body(event: event, reason: body)
        sendWebhook(request, reportStatus: reportWebhookStatus)
    }

    private func sendWebhook(_ request: URLRequest, reportStatus: Bool) {
        if reportStatus { webhookStatus = "Sending…" }
        Task {
            for attempt in 0..<3 {
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                        if reportStatus { webhookStatus = "Delivered (HTTP \(http.statusCode))" }
                        return
                    }
                } catch { }
                if attempt < 2 { try? await Task.sleep(for: .seconds(1 << attempt)) }
            }
            if reportStatus { webhookStatus = "Failed after 3 attempts" }
        }
    }

    private func start(_ action: () throws -> Void) {
        do { try action(); evaluateSafety() } catch { errorMessage = String(describing: error) }
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        autoModeEnabled = defaults.bool(forKey: "autoMode")
        chargingOnly = defaults.bool(forKey: "chargingOnly")
        thermalSafety = defaults.object(forKey: "thermalSafety") as? Bool ?? true
        alertsEnabled = defaults.bool(forKey: "alerts")
        webhookURL = defaults.string(forKey: "webhookURL") ?? ""
        webhookToken = defaults.string(forKey: "webhookToken") ?? ""
        customProcessRules = defaults.string(forKey: "customProcessRules") ?? ""
        launchAtLogin = SMAppService.mainApp.status == .enabled
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "en") ?? .english
        watchdogMinutes = defaults.object(forKey: "watchdogMinutes") as? Int ?? 480
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoModeEnabled, forKey: "autoMode")
        defaults.set(chargingOnly, forKey: "chargingOnly")
        defaults.set(thermalSafety, forKey: "thermalSafety")
        defaults.set(alertsEnabled, forKey: "alerts")
        defaults.set(webhookURL, forKey: "webhookURL")
        defaults.set(webhookToken, forKey: "webhookToken")
        defaults.set(customProcessRules, forKey: "customProcessRules")
        defaults.set(language.rawValue, forKey: "language")
        defaults.set(watchdogMinutes, forKey: "watchdogMinutes")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
