import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class LidRunAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var hotKeys: GlobalHotKeys?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        item.button?.image = NSImage(systemSymbolName: "moon", accessibilityDescription: "LidRun")
        item.button?.imagePosition = .imageOnly
        item.button?.title = ""
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        hotKeys = GlobalHotKeys(handlers: [
            .autoMode: { [weak model] in model?.setAutoMode(!(model?.autoModeEnabled ?? false)) },
            .keepAwake: { [weak model] in model?.toggleKeepAwake() },
            .closedLid: { [weak model] in model?.setClosedLid(!(model?.closedLidEnabled ?? false)) },
            .stop: { [weak model] in model?.stop() },
        ])
        model.setHotKeysReady(hotKeys?.isReady == true)

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 330, height: 510)
        popover.contentViewController = NSHostingController(rootView: LidRunView(model: model))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.showPopover()
        }

        Publishers.CombineLatest3(model.$session, model.$closedLidEnabled, model.$chargingOnly)
            .sink { [weak self] state, closedLid, chargingOnly in
                let symbol = closedLid ? "laptopcomputer.and.arrow.down" : state.isActive ? "sun.max.fill" : chargingOnly ? "bolt.fill" : "moon"
                self?.statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LidRun")
            }
            .store(in: &subscriptions)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        model.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
}

let app = NSApplication.shared
let delegate = LidRunAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.finishLaunching()
app.run()
