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
    @Published private(set) var extendedDetection = false
    @Published private(set) var closedLidHelperInstalled = SystemSleep.closedLidHelperInstalled
    @Published private(set) var commandLineToolInstalled = false
    @Published var language: AppLanguage = .english
    @Published var errorMessage: String?
    @Published private(set) var notificationStatus = "Not requested"
    @Published private(set) var webhookStatus = "Not configured"
    @Published private(set) var hotKeysReady = false
    @Published private(set) var availableUpdate: String?
    @Published private(set) var isUpdating = false
    @Published private var now = Date()

    private let controller = SessionController()
    private let closedLidAssertion = SystemPowerAssertion(kind: .systemSleep)
    private let guardrailReader = SystemGuardrailReader()
    private let processList = SystemProcessList()
    private let metricsReader = SystemMetricsReader()
    private let eventLog = EventLog()
    private let network = NetworkActivity()
    /// True while this app has turned off system sleep via `pmset disablesleep`.
    private var sleepDisabled = false
    private var monitor: Timer?
    private var ticker: Timer?
    private var metricsMonitor: Timer?
    private var watchdog: Timer?
    private var updateChecker: Timer?
    private static let site = "https://vuluu2k.github.io/LidRun/"
    /// Set when the user stops an Auto session; Auto Mode waits until the workloads end before re-arming.
    private var autoPaused = false
    private var closedLidChecklistAccepted = false
    private var heatWarned = false
    private var panelVisible = false
    private var crashGuard: Process?
    private var isQuitting = false
    private var bundledAppRun: String { Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/apprun").path }

    init() {
        // Recover from a crash that left `disablesleep 1` behind.
        SystemSleep.setSleepDisabled(false)
        loadSettings()
        refreshLaunchAtLogin()
        commandLineToolInstalled = SystemSleep.commandLineToolInstalled(bundled: bundledAppRun)
        refreshNotificationStatus()
        controller.onChange = { [weak self] state in
            Task { @MainActor in self?.sessionChanged(state) }
        }
        refresh()
        monitor = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        checkForUpdate()
        updateChecker = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdate() }
        }
    }

    /// The 1 s metric and clock timers only feed the panel; run them while it is open (idle CPU was 1–2%).
    func setPanelVisible(_ visible: Bool) {
        panelVisible = visible
        if visible { refresh() }
        metricsMonitor?.invalidate()
        ticker?.invalidate()
        guard visible else { metricsMonitor = nil; ticker = nil; return }
        now = Date()
        updateSystemMetrics()
        metricsMonitor = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateSystemMetrics() }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    var batteryText: String { snapshot?.batteryPercent.map { "\($0)%" } ?? "--" }
    var batteryIcon: String {
        if isCharging { return "battery.100percent.bolt" }
        switch snapshot?.batteryPercent ?? 100 {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
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
    var activeDurationText: String {
        guard let startedAt = session.startedAt else { return L10n.text("notRunning", language) }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
    var isCharging: Bool { snapshot?.isCharging == true }

    var whyAwakeText: String {
        let why = session.whyAwake
        if why.hasPrefix("Auto Mode: ") { return L10n.text("autoMode", language) + ": " + why.dropFirst("Auto Mode: ".count) }
        return L10n.text(why, language)
    }

    /// "until 15:30 · 1h 12m left" for timers, the watchdog cap for open-ended sessions.
    var nextReleaseText: String {
        guard session.isActive else { return L10n.text("None", language) }
        if let releaseAt = session.releaseAt {
            let left = max(0, Int(releaseAt.timeIntervalSince(now)) / 60)
            let clock = releaseAt.formatted(date: .omitted, time: .shortened)
            return "\(L10n.text("until", language)) \(clock) · \(left >= 60 ? "\(left / 60)h \(left % 60)m" : "\(left)m")"
        }
        return watchdogMinutes.map { "\(L10n.text("max", language)) \($0 / 60)h" } ?? L10n.text("Manual stop", language)
    }

    struct PastSession: Identifiable {
        let id: Date
        let reason: String
        let duration: TimeInterval
        let stopReason: String?
    }

    /// Started/stopped pairs from the log, newest first.
    var recentSessions: [PastSession] {
        var result: [PastSession] = []
        var open: RunEvent?
        for event in weeklyEvents {
            if event.type == .started {
                open = event
            } else if event.type == .stopped, let began = open {
                result.append(PastSession(id: began.time, reason: began.reason, duration: event.time.timeIntervalSince(began.time), stopReason: event.reason))
                open = nil
            }
        }
        if let open { result.append(PastSession(id: open.time, reason: open.reason, duration: Date().timeIntervalSince(open.time), stopReason: nil)) }
        return Array(result.suffix(8).reversed())
    }
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
        let reasons = Set([StopReason.lowBattery.rawValue, StopReason.thermalPressure.rawValue, StopReason.chargerDisconnected.rawValue, StopReason.watchdog.rawValue])
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
            start { try controller.startManual() }
        }
    }

    func startTimer(minutes: Int) { start { try controller.startTimed(seconds: TimeInterval(minutes * 60)) } }

    func stop() {
        if isAutoSession { autoPaused = true }
        watchdog?.invalidate()
        releaseClosedLid()
        controller.stop()
    }

    func setAutoMode(_ enabled: Bool) {
        autoModeEnabled = enabled
        autoPaused = false
        saveSettings()
        if !enabled, isAutoSession { controller.stop(reason: .manual) }
        refresh()
    }
    func setChargingOnly(_ enabled: Bool) { chargingOnly = enabled; saveSettings(); evaluateSafety() }
    func setThermalSafety(_ enabled: Bool) { thermalSafety = enabled; saveSettings(); evaluateSafety() }
    func setLowBattery(_ percent: Int?) { lowBatteryPercent = percent; saveSettings(); evaluateSafety() }

    func setClosedLid(_ enabled: Bool) {
        guard enabled else { releaseClosedLid(); return }
        guard confirmClosedLidChecklist() else { return }
        snapshot = guardrailReader.snapshot()
        // Without the helper only PreventSystemSleep is available: honoured on AC power, not on a closed lid on battery.
        guard closedLidHelperInstalled || isCharging else {
            errorMessage = L10n.text("closedLidNeedsCharger", language)
            return
        }
        if !session.isActive { start { try controller.startManual() } }
        guard controller.state.isActive else { return }
        do {
            try closedLidAssertion.acquire(reason: "Closed-Lid Mode")
            if closedLidHelperInstalled {
                guard SystemSleep.setSleepDisabled(true) else {
                    closedLidAssertion.release()
                    errorMessage = L10n.text("closedLidHelperFailed", language)
                    return
                }
                sleepDisabled = true
                crashGuard = SystemSleep.startCrashGuard()
            }
            closedLidEnabled = true
            try? eventLog.append(RunEvent(type: .armed, reason: sleepDisabled ? "Closed-Lid Mode (sleep disabled)" : "Closed-Lid Mode (AC only)"))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Safety checklist before closing the lid (spec PRO-01); "Don't show again" remembers the answer.
    private func confirmClosedLidChecklist() -> Bool {
        if closedLidChecklistAccepted { return true }
        let alert = NSAlert()
        alert.messageText = L10n.text("checklistTitle", language)
        alert.informativeText = L10n.text("checklistBody", language)
        alert.addButton(withTitle: L10n.text("checklistConfirm", language))
        alert.addButton(withTitle: L10n.text("cancel", language))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = L10n.text("dontShowAgain", language)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        if alert.suppressionButton?.state == .on { closedLidChecklistAccepted = true; saveSettings() }
        return true
    }

    func installCommandLineTool() {
        let bundled = bundledAppRun
        Task { [weak self] in
            let installed = await Task.detached {
                _ = SystemSleep.installCommandLineTool(bundled: bundled)
                return SystemSleep.commandLineToolInstalled(bundled: bundled)
            }.value
            self?.commandLineToolInstalled = installed
        }
    }

    func setExtendedDetection(_ enabled: Bool) { extendedDetection = enabled; saveSettings(); refresh() }

    func installClosedLidHelper() { changeClosedLidHelper { SystemSleep.installClosedLidHelper() } }
    func removeClosedLidHelper() {
        releaseClosedLid()
        changeClosedLidHelper { SystemSleep.removeClosedLidHelper() }
    }

    private func changeClosedLidHelper(_ action: @escaping @Sendable () -> Bool) {
        Task { [weak self] in
            // The admin prompt blocks until the user answers, so keep it off the main thread.
            let installed = await Task.detached { _ = action(); return SystemSleep.closedLidHelperInstalled }.value
            self?.closedLidHelperInstalled = installed
        }
    }

    /// Restores normal sleep. Must run before any `sleepNow`, or `disablesleep` would ignore it.
    private func releaseClosedLid() {
        closedLidAssertion.release()
        if sleepDisabled { SystemSleep.setSleepDisabled(false); sleepDisabled = false }
        crashGuard?.terminate()
        crashGuard = nil
        if closedLidEnabled { try? eventLog.append(RunEvent(type: .disarmed, reason: "Closed-Lid Mode")) }
        closedLidEnabled = false
    }

    func setAlerts(_ enabled: Bool) {
        if !enabled {
            alertsEnabled = false
            notificationStatus = "Disabled"
            saveSettings()
            return
        }
        Task { [weak self] in
            let granted: Bool
            do { granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) } catch {
                granted = false
                self?.errorMessage = "Notifications are unavailable for this app identity. Reinstall the latest build or enable LidRun in System Settings → Notifications."
            }
            self?.alertsEnabled = granted
            self?.notificationStatus = granted ? "Authorized" : "Denied"
            self?.saveSettings()
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
        webhookStatus = L10n.text(webhookURL.isEmpty ? "Not configured" : "Saved", language)
        saveSettings()
    }

    func sendTestWebhook() {
        saveWebhook(webhookURL)
        guard !webhookURL.isEmpty else { return }
        publish(title: "LidRun test", body: "Webhook test", event: "test", reportWebhookStatus: true)
    }

    func setWebhookToken(_ value: String) { webhookToken = value; saveSettings() }
    func setLanguage(_ value: AppLanguage) { language = value; saveSettings() }
    func saveCustomRules(_ value: String) { customProcessRules = value; saveSettings(); refresh() }

    /// The login item is recorded against a bundle path; after the rename to "LidRun Personal.app" (or a move)
    /// re-register so it doesn't point at the old, deleted app.
    private func refreshLaunchAtLogin() {
        let path = Bundle.main.bundlePath
        defer { UserDefaults.standard.set(path, forKey: "registeredBundlePath") }
        guard launchAtLogin, UserDefaults.standard.string(forKey: "registeredBundlePath") != path else { return }
        try? SMAppService.mainApp.unregister()
        try? SMAppService.mainApp.register()
    }

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
        // Scanning processes and re-reading the log are the expensive parts; skip them when nobody needs them.
        if autoModeEnabled || panelVisible {
            let custom = customProcessRules.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            workloads = WorkloadDetector.detect(in: processList.processes(), customNeedles: custom, extended: extendedDetection)
            if extendedDetection, let rate = network.rate(), rate > 1_000_000 {  // ~1 MB/s; idle background traffic sits around 200 KB/s
                workloads.append(DevWorkload(label: "Network transfer", process: RunningProcess(name: "network", command: "\(Int(rate / 1000)) KB/s")))
            }
        }
        if panelVisible { recentEvents = (try? eventLog.recent(limit: Self.reportEventLimit)) ?? [] }
        evaluateAutoMode()
        evaluateSafety()
    }

    /// Stops everything and waits (max 3 s) for the "stopped" webhook; the async onChange path never ran before exit.
    func shutdown() async {
        monitor?.invalidate()
        ticker?.invalidate()
        metricsMonitor?.invalidate()
        watchdog?.invalidate()
        isQuitting = true
        let wasActive = controller.state.isActive
        releaseClosedLid()
        controller.stop(reason: .appQuit)
        guard wasActive, let delivery = publish(title: "LidRun stopped", body: StopReason.appQuit.rawValue, event: "stopped") else { return }
        let timeout = Task { try? await Task.sleep(for: .seconds(3)); delivery.cancel() }
        await delivery.value
        timeout.cancel()
    }

    private func updateSystemMetrics() {
        let reader = metricsReader
        Task.detached {
            let metrics = reader.snapshot()
            await MainActor.run { [weak self] in
                self?.systemMetrics = metrics
            }
        }
    }

    private var policy: GuardrailPolicy { settings.guardrailPolicy }

    private func sessionChanged(_ state: SessionState) {
        session = state
        if isQuitting { return }
        if state.isActive {
            scheduleWatchdog()
            publish(title: "LidRun started", body: state.whyAwake, event: "started")
        } else {
            watchdog?.invalidate()
            releaseClosedLid()
            let reason = (try? eventLog.recent(limit: 1).last?.reason) ?? "stopped"
            publish(title: "LidRun stopped", body: reason, event: "stopped")
        }
        if panelVisible { recentEvents = (try? eventLog.recent(limit: Self.reportEventLimit)) ?? [] }
    }

    private static let reportEventLimit = 2000
    private var isAutoSession: Bool { session.isActive && session.whyAwake.hasPrefix("Auto Mode:") }

    private var guardrailBlock: StopReason? {
        guard let snapshot, case .stop(let reason) = SafetyGovernor.evaluate(snapshot, policy: policy) else { return nil }
        return reason
    }

    private func evaluateAutoMode() {
        if workloads.isEmpty { autoPaused = false }
        let action = AutoMode.decide(
            enabled: autoModeEnabled, sessionActive: session.isActive, isAutoSession: isAutoSession,
            workloads: workloads.map(\.label), paused: autoPaused, blocked: guardrailBlock != nil
        )
        switch action {
        case .stop: controller.stop(reason: .workloadFinished)
        case .start(let labels): start { try controller.startAuto(workloads: labels) }
        case .none: break
        }
    }

    private func evaluateSafety() {
        guard session.isActive, let snapshot else { return }
        if case .stop(let reason) = SafetyGovernor.evaluate(snapshot, policy: policy) {
            let lidMode = closedLidEnabled
            releaseClosedLid()
            controller.stop(reason: reason)
            // Releasing is not enough when the lid is shut or the battery is nearly empty: sleep now, as lidrun.com does.
            if reason == .lowBattery || (lidMode && SystemSleep.isLidClosed) { SystemSleep.sleepNow() }
            return
        }
        // A shut lid traps heat: warn at "fair", before the serious/critical stop.
        if closedLidEnabled, snapshot.thermalPressure == .fair {
            if !heatWarned {
                heatWarned = true
                publish(title: L10n.text("heatWarningTitle", language), body: L10n.text("heatWarningBody", language), event: "thermal_warning")
            }
        } else if snapshot.thermalPressure == .nominal {
            heatWarned = false
        }
    }

    private func scheduleWatchdog() {
        watchdog?.invalidate()
        // Timed sessions already end on their own; the watchdog only caps open-ended ones.
        guard session.isActive, session.nextRelease == "Manual stop", let minutes = watchdogMinutes else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.controller.stop(reason: .watchdog) }
        }
    }

    func checkForUpdate() {
        // Dev builds from .build are replaced by rebuilding, not by the release DMG.
        guard !Bundle.main.bundlePath.contains("/.build/"),
              let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        Task { [weak self] in
            guard let latest = await Self.latestVersion() else { return }
            self?.availableUpdate = latest.compare(current, options: .numeric) == .orderedDescending ? latest : nil
        }
    }

    /// Runs the website install script against this bundle; it replaces and relaunches the app.
    func installUpdate() {
        isUpdating = true
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "curl -fsSL \(Self.site)install.sh | LIDRUN_APP=\"$0\" bash", Bundle.main.bundlePath]
        process.terminationHandler = { [weak self] process in
            let failed = process.terminationStatus != 0
            Task { @MainActor in
                self?.isUpdating = false
                if failed { self?.errorMessage = "Update failed. Download the latest version from \(Self.site)" }
            }
        }
        do { try process.run() } catch {
            isUpdating = false
            errorMessage = error.localizedDescription
        }
    }

    private nonisolated static func latestVersion() async -> String? {
        guard let (data, _) = try? await URLSession.shared.data(from: URL(string: site + "download.json")!),
              let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return release["version"] as? String
    }

    private nonisolated static func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func refreshNotificationStatus() {
        Task { [weak self] in
            switch await Self.notificationAuthorizationStatus() {
            case .authorized, .provisional: self?.notificationStatus = "Authorized"
            case .denied: self?.notificationStatus = "Denied"
            default: self?.notificationStatus = "Not requested"
            }
        }
    }

    @discardableResult
    private func publish(title: String, body: String, event: String, reportWebhookStatus: Bool = false) -> Task<Void, Never>? {
        if alertsEnabled {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
        guard let url = URL(string: webhookURL), !webhookURL.isEmpty else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !webhookToken.isEmpty { request.setValue("Bearer \(webhookToken)", forHTTPHeaderField: "Authorization") }
        let platform = WebhookPlatform.detect(url: url)
        request.httpBody = try? platform.body(event: event, reason: body)
        return sendWebhook(request, reportStatus: reportWebhookStatus)
    }

    private func sendWebhook(_ request: URLRequest, reportStatus: Bool) -> Task<Void, Never> {
        if reportStatus { webhookStatus = L10n.text("webhookSending", language) }
        return Task {
            for attempt in 0..<3 {
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                        if reportStatus { webhookStatus = "\(L10n.text("webhookDelivered", language)) (HTTP \(http.statusCode))" }
                        return
                    }
                } catch { }
                if attempt < 2, !Task.isCancelled { try? await Task.sleep(for: .seconds(1 << attempt)) }
            }
            if reportStatus { webhookStatus = L10n.text("webhookFailed", language) }
        }
    }

    private func start(_ action: () throws -> Void) {
        snapshot = guardrailReader.snapshot()
        if let reason = guardrailBlock {
            errorMessage = "\(L10n.text("blockedByGuardrail", language)): \(reason.rawValue)"
            return
        }
        do { try action() } catch { errorMessage = String(describing: error) }
    }

    private func loadSettings() {
        let settings = AppSettings(defaults: .standard)
        autoModeEnabled = settings.autoMode
        extendedDetection = settings.extendedDetection
        chargingOnly = settings.chargingOnly
        thermalSafety = settings.thermalSafety
        alertsEnabled = settings.alerts
        lowBatteryPercent = settings.lowBatteryPercent
        watchdogMinutes = settings.watchdogMinutes
        webhookURL = settings.webhookURL
        webhookToken = settings.webhookToken
        customProcessRules = settings.customProcessRules
        language = AppLanguage(rawValue: settings.language) ?? .english
        closedLidChecklistAccepted = settings.closedLidChecklistAccepted
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private var settings: AppSettings {
        var settings = AppSettings()
        settings.autoMode = autoModeEnabled
        settings.extendedDetection = extendedDetection
        settings.chargingOnly = chargingOnly
        settings.thermalSafety = thermalSafety
        settings.alerts = alertsEnabled
        settings.lowBatteryPercent = lowBatteryPercent
        settings.watchdogMinutes = watchdogMinutes
        settings.webhookURL = webhookURL
        settings.webhookToken = webhookToken
        settings.customProcessRules = customProcessRules
        settings.language = language.rawValue
        settings.closedLidChecklistAccepted = closedLidChecklistAccepted
        return settings
    }

    private func saveSettings() { settings.save(to: .standard) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

