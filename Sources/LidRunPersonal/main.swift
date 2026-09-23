import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class LidRunAppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var fallbackWindow: NSWindow?
    private var hotKeys: GlobalHotKeys?
    private var subscriptions = Set<AnyCancellable>()
    private var countdown: Timer?

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

        // SwiftUI onAppear fires when the popover is built, not shown, so track visibility here.
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        let hosting = NSHostingController(rootView: LidRunView(model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        Publishers.CombineLatest3(model.$session, model.$closedLidEnabled, model.$chargingOnly)
            .sink { [weak self] state, closedLid, chargingOnly in
                let symbol = closedLid ? "laptopcomputer.and.arrow.down" : state.isActive ? "sun.max.fill" : chargingOnly ? "bolt.fill" : "moon"
                self?.statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "LidRun")
                self?.updateCountdown(releaseAt: state.releaseAt)
            }
            .store(in: &subscriptions)

        // Menu bar icon can be hidden behind the notch on a crowded menu bar; open the panel so launch is never silent.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.statusItemVisible == false { self?.showWindow() }
        }
    }

    // Double-clicking the app again (Finder/Launchpad) lands here.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItemVisible ? showPopover() : showWindow()
        return false
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // terminateLater lets shutdown deliver the "stopped" webhook before the process exits.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await model.shutdown()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // lidrun://start?minutes=60 etc. — for Shortcuts, Raycast, Alfred, scripts (`open lidrun://stop`).
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(model.handle)
    }

    /// Timed sessions show the time left next to the menu bar icon ("1:12"); refreshed twice a minute.
    private func updateCountdown(releaseAt: Date?) {
        countdown?.invalidate()
        countdown = nil
        guard let item = statusItem, let button = item.button else { return }
        guard let releaseAt else {
            item.length = NSStatusItem.squareLength
            button.title = ""
            button.imagePosition = .imageOnly
            return
        }
        let render = {
            let minutes = max(0, Int(releaseAt.timeIntervalSinceNow / 60))
            button.title = " " + String(format: "%d:%02d", minutes / 60, minutes % 60)
        }
        item.length = NSStatusItem.variableLength
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        render()
        countdown = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in render() }
        }
    }

    func popoverDidShow(_ notification: Notification) { model.setPanelVisible(true) }
    func popoverDidClose(_ notification: Notification) { model.setPanelVisible(false) }
    func windowWillClose(_ notification: Notification) { model.setPanelVisible(false) }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private var statusItemVisible: Bool {
        guard let window = statusItem?.button?.window, window.occlusionState.contains(.visible),
              let screen = window.screen else { return false }
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return true }
        let notch = NSRect(x: left.maxX, y: left.minY, width: right.minX - left.maxX, height: left.height)
        return !window.frame.intersects(notch)
    }

    private func showWindow() {
        if fallbackWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: LidRunView(model: model)))
            window.title = "LidRun Personal"
            // Content starts below a dark title bar; a full-size content view put the header under it and
            // left twice the padding at the bottom.
            window.styleMask = [.titled, .closable]
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            fallbackWindow = window
        }
        model.refresh()
        model.setPanelVisible(true)
        fallbackWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
// Accessory apps show no menu bar, but ⌘X/C/V/A/Z in text fields only work through Edit menu key equivalents.
let editMenu = NSMenu(title: "Edit")
for (title, action, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"),
                             ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
    editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
}
let mainMenu = NSMenu()
mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu
app.mainMenu = mainMenu
app.finishLaunching()
app.run()
