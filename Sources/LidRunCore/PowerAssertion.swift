import Foundation
import IOKit.pwr_mgt

public protocol SleepAssertion: AnyObject, Sendable {
    var isHeld: Bool { get }
    func acquire(reason: String) throws
    func release()
}

public enum PowerAssertionError: Error, Equatable {
    case acquireFailed(IOReturn)
}

public enum PowerAssertionKind: Sendable {
    case idleSleep
    case systemSleep

    var type: CFString {
        switch self {
        case .idleSleep: kIOPMAssertionTypeNoIdleSleep as CFString
        case .systemSleep: kIOPMAssertionTypePreventSystemSleep as CFString
        }
    }
}

public final class SystemPowerAssertion: SleepAssertion, @unchecked Sendable {
    private var assertionID: IOPMAssertionID = 0
    private let kind: PowerAssertionKind
    public private(set) var isHeld = false

    public init(kind: PowerAssertionKind = .idleSleep) {
        self.kind = kind
    }

    public func acquire(reason: String) throws {
        if isHeld { release() }
        let result = IOPMAssertionCreateWithName(
            kind.type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else { throw PowerAssertionError.acquireFailed(result) }
        isHeld = true
    }

    public func release() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isHeld = false
    }

    deinit {
        release()
    }
}
