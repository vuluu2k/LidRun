import Carbon.HIToolbox
import Foundation

final class GlobalHotKeys: @unchecked Sendable {
    enum Action: UInt32, CaseIterable {
        case autoMode = 1
        case keepAwake = 2
        case closedLid = 3
        case stop = 4
    }

    private var handlers: [UInt32: @MainActor () -> Void]
    private var refs: [EventHotKeyRef?] = []
    private(set) var registeredCount = 0
    var isReady: Bool { registeredCount == Action.allCases.count }
    private var eventHandler: EventHandlerRef?

    init(handlers: [Action: @MainActor () -> Void]) {
        self.handlers = Dictionary(uniqueKeysWithValues: handlers.map { ($0.key.rawValue, $0.value) })

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }
            let manager = Unmanaged<GlobalHotKeys>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in manager.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        register(.autoMode, key: UInt32(kVK_ANSI_A))
        register(.keepAwake, key: UInt32(kVK_ANSI_S))
        register(.closedLid, key: UInt32(kVK_ANSI_L))
        register(.stop, key: UInt32(kVK_ANSI_X))
    }

    private func register(_ action: Action, key: UInt32) {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x4C44524E, id: action.rawValue)
        let status = RegisterEventHotKey(key, UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { registeredCount += 1 }
        refs.append(ref)
    }

    deinit {
        refs.forEach { if let ref = $0 { UnregisterEventHotKey(ref) } }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
