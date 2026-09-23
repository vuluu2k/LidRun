import Foundation
import IOKit

/// Real sleep control. Closed-lid needs `pmset disablesleep`, which is root-only, so a one-time admin prompt
/// installs a sudoers rule allowing exactly `pmset -a disablesleep 0|1` for the current user — free, no signed helper.
public enum SystemSleep {
    public static let sudoersPath = "/etc/sudoers.d/lidrun"
    private static let pmset = "/usr/bin/pmset"

    /// Puts the Mac to sleep now; allowed for any logged-in user.
    public static func sleepNow() { run(pmset, ["sleepnow"]) }

    public static var isLidClosed: Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        defer { IOObjectRelease(root) }
        let value = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return (value?.takeRetainedValue() as? Bool) ?? false
    }

    public static var closedLidHelperInstalled: Bool { FileManager.default.fileExists(atPath: sudoersPath) }

    /// Returns false when the sudoers rule is missing or pmset refused.
    @discardableResult
    public static func setSleepDisabled(_ disabled: Bool) -> Bool {
        closedLidHelperInstalled && run("/usr/bin/sudo", ["-n", pmset, "-a", "disablesleep", disabled ? "1" : "0"]) == 0
    }

    public static func sudoersRule(user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: \(pmset) -a disablesleep 0, \(pmset) -a disablesleep 1\n"
    }

    /// Shows the macOS admin password prompt once; validates the rule with visudo before installing it.
    public static func installClosedLidHelper() -> Bool {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("lidrun-sudoers")
        guard (try? sudoersRule(user: NSUserName()).write(to: temp, atomically: true, encoding: .utf8)) != nil else { return false }
        let script = "/usr/sbin/visudo -cf '\(temp.path)' && /usr/bin/install -m 0440 -o root -g wheel '\(temp.path)' \(sudoersPath)"
        return runAsAdmin(script)
    }

    public static func removeClosedLidHelper() -> Bool {
        runAsAdmin("\(pmset) -a disablesleep 0; /bin/rm -f \(sudoersPath)")
    }

    private static func runAsAdmin(_ shell: String) -> Bool {
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return run("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"]) == 0
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
