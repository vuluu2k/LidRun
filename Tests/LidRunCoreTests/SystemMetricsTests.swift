import Foundation
import Testing
@testable import LidRunCore

@Test func temperatureSeverityUsesVisibleSafetyThresholds() {
    #expect(TemperatureSeverity.classify(69) == .normal)
    #expect(TemperatureSeverity.classify(70) == .warm)
    #expect(TemperatureSeverity.classify(80) == .hot)
    #expect(TemperatureSeverity.classify(95) == .critical)
}

@Test func systemMetricsReturnsBoundedCPUUsage() {
    #expect(AppleSMCReader.keyDataSize == 80)
    let reader = SystemMetricsReader()
    _ = reader.snapshot()
    Thread.sleep(forTimeInterval: 0.05)
    let metrics = reader.snapshot()
    #expect((0...100).contains(metrics.cpuPercent))
}
