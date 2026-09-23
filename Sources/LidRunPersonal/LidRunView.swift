import AppKit
import SwiftUI

@MainActor
struct LidRunView: View {
    @ObservedObject var model: AppModel
    @State private var showReport = false
    @State private var showAlerts = false
    @State private var showSettings = false
    @State private var webhookDraft = ""
    @State private var customRulesDraft = ""

    private var lang: AppLanguage { model.language }
    private func t(_ key: String) -> String { L10n.text(key, lang) }

    var body: some View {
        VStack(spacing: 0) {
            header
            metrics
            line
            controls
            line
            navigation
            line
            settingsRow
            quitRow
        }
        .padding(14)
        .frame(width: 330, height: 510)
        .background(background)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.16)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundStyle(Color.white.opacity(0.94))
        .onAppear {
            webhookDraft = model.webhookURL
            customRulesDraft = model.customProcessRules
            model.refresh()
        }
        .alert("LidRun", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .sheet(isPresented: $showReport) { detailSheet(t("tasksReports"), report) }
        .sheet(isPresented: $showAlerts) { detailSheet(t("notifications"), alerts) }
        .sheet(isPresented: $showSettings) { detailSheet(t("settings"), settings) }
    }

    private var modeIcon: String {
        if model.closedLidEnabled { return "laptopcomputer.and.arrow.down" }
        if model.session.isActive { return "sun.max.fill" }
        if model.chargingOnly { return "bolt.fill" }
        return "moon"
    }

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.105, green: 0.095, blue: 0.125), Color(red: 0.19, green: 0.145, blue: 0.135)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var line: some View {
        Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1).padding(.vertical, 7)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: modeIcon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 37, height: 37)
                .background(Color.indigo.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("LidRun").font(.system(size: 14, weight: .bold))
                Text(model.session.isActive ? model.session.whyAwake : t("ready"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Label(model.isCharging ? t("charging") : t("battery"), systemImage: model.isCharging ? "bolt.fill" : "battery.75percent")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(model.isCharging ? .green : .orange)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background((model.isCharging ? Color.green : Color.orange).opacity(0.16), in: Capsule())
        }
        .padding(.bottom, 10)
    }

    private var metrics: some View {
        HStack(spacing: 5) {
            metric("battery.75percent", model.batteryText)
            metric("thermometer.medium", model.temperatureText, accent: temperatureColor)
            metric("cpu", model.cpuText)
            metric("fanblades", model.fanText)
            metric("laptopcomputer", model.closedLidEnabled ? "On" : "Off")
        }
    }

    private var temperatureColor: Color? {
        switch model.temperatureSeverity {
        case .normal: nil
        case .warm: .yellow
        case .hot: .orange
        case .critical: .red
        }
    }

    private func metric(_ icon: String, _ value: String, accent: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(accent ?? Color.white.opacity(0.48))
            Text(value).lineLimit(1).minimumScaleFactor(0.75)
        }
        .font(.system(size: 9, weight: .semibold)).foregroundStyle(accent ?? Color.white.opacity(0.76))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 4).frame(height: 29)
        .background(accent?.opacity(0.12) ?? Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent?.opacity(0.28) ?? Color.white.opacity(0.05)))
        .animation(.easeInOut(duration: 0.2), value: model.temperatureSeverity)
    }

    private var controls: some View {
        VStack(spacing: 0) {
            toggleRow(t("autoMode"), "lock.fill", .white, Binding(get: { model.autoModeEnabled }, set: { model.setAutoMode($0) }), "⌃⌥A")
            toggleRow(t("keepAwake"), "eye", .white, Binding(get: { model.session.isActive }, set: { _ in model.toggleKeepAwake() }), "⌃⌥S")
            toggleRow(t("chargingOnly"), "bolt.fill", .orange, Binding(get: { model.chargingOnly }, set: { model.setChargingOnly($0) }), "")
            Menu {
                ForEach([30, 60, 120, 240, 480], id: \.self) { value in
                    Button(value < 60 ? "\(value) min" : "\(value / 60)h") { model.startTimer(minutes: value) }
                }
            } label: { actionRow(t("timer"), "timer", .secondary, model.session.nextRelease, true) }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .frame(height: 31)
            toggleRow(t("closedLid"), "laptopcomputer.and.arrow.down", .white, Binding(get: { model.closedLidEnabled }, set: { model.setClosedLid($0) }), "⌃⌥L")
            toggleRow(t("cooling"), "lock.fill", .white, Binding(get: { model.thermalSafety }, set: { model.setThermalSafety($0) }), "")
            Button(action: model.stop) { actionRow(t("stop"), "stop.fill", .red, "⌃⌥X", false) }
                .buttonStyle(.plain).disabled(!model.session.isActive).opacity(model.session.isActive ? 1 : 0.55)
        }
    }

    private func toggleRow(_ title: String, _ icon: String, _ color: Color, _ binding: Binding<Bool>, _ shortcut: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18, height: 18, alignment: .center)
                .foregroundStyle(color)
            Text(title).font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            if !shortcut.isEmpty { Text(shortcut).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary) }
            Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch).controlSize(.mini).tint(.purple)
        }
        .frame(height: 31)
    }

    private func actionRow(_ title: String, _ icon: String, _ color: Color, _ value: String, _ chevron: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18, height: 18, alignment: .center)
                .foregroundStyle(color)
            Text(title).font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            if chevron { Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(.secondary) }
        }
        .frame(height: 31).contentShape(Rectangle())
    }

    private var navigation: some View {
        VStack(spacing: 0) {
            navRow(t("status"), "gauge.with.dots.needle.33percent", model.session.isActive ? t("protected") : t("idle")) {}
            navRow(t("tasksReports"), "list.bullet.clipboard", "›") { showReport = true }
            navRow(t("notifications"), "bell", model.alertsEnabled ? "On" : "›") { showAlerts = true }
        }
    }

    private func navRow(_ title: String, _ icon: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18, height: 18, alignment: .center)
                Text(title).font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                Text(value).font(.system(size: 9)).foregroundStyle(.secondary)
            }.frame(height: 32).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var settingsRow: some View {
        navRow(t("settings"), "gearshape", "›") { showSettings = true }.padding(.top, 3)
    }

    private var report: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) { stat(t("protectedTime"), model.protectedTimeText); stat(t("sessions"), "\(model.protectedSessions)"); stat(t("safetyStops"), "\(model.safetyStops)") }
            ForEach(Array(model.weeklyEvents.suffix(3).reversed()), id: \.time) { event in
                HStack { Text(event.type.rawValue.capitalized); Text(event.reason).lineLimit(1); Spacer() }
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Button(t("copyReport")) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.weeklyReport, forType: .string)
            }.controlSize(.mini)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.headline); Text(title).font(.system(size: 8)).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("notificationHelp")).font(.caption).foregroundStyle(.secondary)
            toggleRow(t("macAlerts"), "bell.badge", .orange, Binding(get: { model.alertsEnabled }, set: { model.setAlerts($0) }), "")
            HStack {
                Text(model.notificationStatus).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.notificationStatus == "Denied" {
                    Button(t("openSystemSettings")) { model.openNotificationSettings() }.controlSize(.small)
                } else {
                    Button(t("testNotification")) { model.sendTestNotification() }.controlSize(.small)
                }
            }
            Divider()
            TextField(t("webhook"), text: $webhookDraft).textFieldStyle(.roundedBorder).controlSize(.small)
            HStack { Text(t("detectedPlatform")); Spacer(); Text(model.webhookPlatform(for: webhookDraft)) }
                .font(.caption).foregroundStyle(.secondary)
            SecureField(t("webhookToken"), text: $model.webhookToken).textFieldStyle(.roundedBorder).controlSize(.small)
            HStack {
                Text(model.webhookStatus).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(t("testWebhook")) { model.webhookURL = webhookDraft; model.sendTestWebhook() }.controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleRow(t("launchAtLogin"), "power", .white, Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }), "")
            HStack {
                Text(t("hotkeys")).font(.caption)
                Spacer()
                Text(model.hotKeysReady ? "Ready" : "Unavailable").font(.caption).foregroundStyle(model.hotKeysReady ? .green : .red)
            }
            Text(t("hotkeysHelp")).font(.system(size: 9)).foregroundStyle(.secondary)
            settingPicker(t("language"), selection: Binding(get: { model.language.rawValue }, set: { model.setLanguage(AppLanguage(rawValue: $0) ?? .english) }), values: [("en", "English"), ("vi", "Tiếng Việt")])
            settingPicker(t("lowBattery"), selection: Binding(get: { model.lowBatteryPercent ?? 0 }, set: { model.setLowBattery($0 == 0 ? nil : $0) }), values: [(0, "Off"), (5, "5%"), (10, "10%"), (15, "15%")])
            settingPicker(t("watchdog"), selection: Binding(get: { model.watchdogMinutes ?? 0 }, set: { model.setWatchdog(minutes: $0 == 0 ? nil : $0) }), values: [(0, "Off"), (60, "1h"), (240, "4h"), (480, "8h")])
            TextField(t("smartRules"), text: $customRulesDraft).textFieldStyle(.roundedBorder).controlSize(.small)
            Button(t("save")) { model.saveCustomRules(customRulesDraft) }.controlSize(.mini)
            Text(t("safetyNote")).font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(9)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
    }

    private func settingPicker<T: Hashable>(_ title: String, selection: Binding<T>, values: [(T, String)]) -> some View {
        HStack { Text(title).font(.caption).frame(maxWidth: .infinity, alignment: .leading); Picker("", selection: selection) { ForEach(values, id: \.0) { Text($0.1).tag($0.0) } }.frame(width: 100) }
    }

    private func detailSheet<Content: View>(_ title: String, _ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(t("done")) { showReport = false; showAlerts = false; showSettings = false }
            }
            content
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 350, height: 400, alignment: .topLeading)
    }

    private var quitRow: some View {
        Button { NSApplication.shared.terminate(nil) } label: {
            HStack(spacing: 9) {
                Image(systemName: "power").font(.system(size: 12, weight: .medium)).frame(width: 18, height: 18, alignment: .center)
                Text(t("quit")).frame(maxWidth: .infinity, alignment: .leading)
                if let version = model.availableUpdate {
                    Button(model.isUpdating ? t("updating") : "\(t("update")) v\(version)", action: model.installUpdate)
                        .buttonStyle(.borderedProminent).tint(.indigo).controlSize(.small).disabled(model.isUpdating)
                }
            }
            .font(.system(size: 12, weight: .semibold)).frame(height: 31)
        }.buttonStyle(.plain)
    }
}
