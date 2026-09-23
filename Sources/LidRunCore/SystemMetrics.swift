import CoreGraphics
import Darwin.Mach
import Foundation

public enum TemperatureSeverity: Equatable, Sendable {
    case normal
    case warm
    case hot
    case critical

    public static func classify(_ celsius: Int?) -> TemperatureSeverity {
        guard let celsius else { return .normal }
        if celsius >= 95 { return .critical }
        if celsius >= 80 { return .hot }
        if celsius >= 70 { return .warm }
        return .normal
    }
}

public struct SystemMetrics: Equatable, Sendable {
    public let cpuPercent: Int
    public let displayIsAsleep: Bool
    public let temperatureCelsius: Int?
    public let hotspotTemperatureCelsius: Int?
    public let fanRPM: Int?

    public init(cpuPercent: Int, displayIsAsleep: Bool, temperatureCelsius: Int? = nil, hotspotTemperatureCelsius: Int? = nil, fanRPM: Int? = nil) {
        self.cpuPercent = cpuPercent
        self.displayIsAsleep = displayIsAsleep
        self.temperatureCelsius = temperatureCelsius
        self.hotspotTemperatureCelsius = hotspotTemperatureCelsius
        self.fanRPM = fanRPM
    }
}

public final class SystemMetricsReader: @unchecked Sendable {
    private var previous: (active: UInt64, total: UInt64)?
    private let smc = AppleSMCReader()
    private let lock = NSLock()

    public init() {}

    public func snapshot() -> SystemMetrics {
        lock.lock()
        defer { lock.unlock() }
        let hardware = smc?.metrics()
        return SystemMetrics(
            cpuPercent: cpuPercent(),
            displayIsAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0,
            temperatureCelsius: hardware?.temperatureCelsius,
            hotspotTemperatureCelsius: hardware?.hotspotTemperatureCelsius,
            fanRPM: hardware?.fanRPM
        )
    }

    private func cpuPercent() -> Int {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let active = UInt64(info.cpu_ticks.0) + UInt64(info.cpu_ticks.1) + UInt64(info.cpu_ticks.3)
        let total = active + UInt64(info.cpu_ticks.2)
        defer { previous = (active, total) }
        guard let previous, total > previous.total else { return 0 }
        return Int(((active - previous.active) * 100) / (total - previous.total))
    }
}
