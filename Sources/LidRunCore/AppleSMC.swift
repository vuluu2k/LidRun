import Foundation
import IOKit

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private let zeroSMCBytes: SMCBytes = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
    var reserved: (UInt8, UInt8, UInt8) = (0, 0, 0)
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimit = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = zeroSMCBytes
}

private struct SMCValue {
    let type: UInt32
    let bytes: [UInt8]

    var typeName: String { String(bytes: type.bigEndianBytes, encoding: .ascii) ?? "" }

    var number: Double? {
        switch typeName {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            return Double(Float(bitPattern: UInt32(littleEndianBytes: bytes)))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int16(bitPattern: UInt16(bigEndianBytes: bytes))) / 256
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bigEndianBytes: bytes)) / 4
        case "ui8 ": return bytes.first.map(Double.init)
        case "ui16": return bytes.count >= 2 ? Double(UInt16(bigEndianBytes: bytes)) : nil
        case "ui32": return bytes.count >= 4 ? Double(UInt32(bigEndianBytes: bytes)) : nil
        default: return nil
        }
    }
}

public final class AppleSMCReader: @unchecked Sendable {
    static var keyDataSize: Int { MemoryLayout<SMCKeyData>.size }
    private let connection: io_connect_t
    private var infoCache: [UInt32: (size: UInt32, type: UInt32)] = [:]
    private var temperatureKeys: [String]?
    private let lock = NSLock()

    public init?() {
        guard let matching = IOServiceMatching("AppleSMC") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        guard result == KERN_SUCCESS else { return nil }
        self.connection = connection
    }

    deinit { IOServiceClose(connection) }

    public func metrics() -> (temperatureCelsius: Int?, hotspotTemperatureCelsius: Int?, fanRPM: Int?) {
        lock.lock()
        defer { lock.unlock() }
        return (temperature(), hotspotTemperature(), fanRPM())
    }

    private func fanRPM() -> Int? {
        guard let count = read("FNum")?.number.map(Int.init), count > 0 else { return nil }
        let values = (0..<count).compactMap { read("F\($0)Ac")?.number }.filter { $0 >= 0 && $0 < 20_000 }
        guard !values.isEmpty else { return nil }
        return Int(values.reduce(0, +) / Double(values.count))
    }

    private func temperature() -> Int? {
        for key in ["TCMb", "TCMz", "TPMP"] {
            if let value = read(key)?.number, (15...115).contains(value) {
                return Int(value.rounded())
            }
        }
        if temperatureKeys == nil { temperatureKeys = discoverTemperatureKeys() }
        let values = (temperatureKeys ?? []).compactMap { read($0)?.number }.filter { (15...115).contains($0) }
        guard !values.isEmpty else { return nil }
        return Int((values.reduce(0, +) / Double(values.count)).rounded())
    }

    private func hotspotTemperature() -> Int? {
        if let value = read("TCMz")?.number, (15...115).contains(value) { return Int(value.rounded()) }
        return temperature()
    }

    private func discoverTemperatureKeys() -> [String] {
        guard let count = read("#KEY")?.number.map(Int.init), count > 0, count < 100_000 else { return [] }
        return (0..<count).compactMap { key(at: UInt32($0)) }.filter { key in
            guard key.first == "T", let value = read(key) else { return false }
            return ["flt ", "sp78"].contains(value.typeName) && value.number.map { (15...115).contains($0) } == true
        }
    }

    private func read(_ name: String) -> SMCValue? {
        guard let key = name.fourCC, let info = keyInfo(key), info.size <= 32 else { return nil }
        var input = SMCKeyData()
        input.key = key
        input.keyInfo.dataSize = info.size
        input.data8 = 5
        guard let output = call(input), output.result == 0 else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.size))) }
        return SMCValue(type: info.type, bytes: bytes)
    }

    private func keyInfo(_ key: UInt32) -> (size: UInt32, type: UInt32)? {
        if let cached = infoCache[key] { return cached }
        var input = SMCKeyData()
        input.key = key
        input.data8 = 9
        guard let output = call(input), output.result == 0 else { return nil }
        let info = (output.keyInfo.dataSize, output.keyInfo.dataType)
        infoCache[key] = info
        return info
    }

    private func key(at index: UInt32) -> String? {
        var input = SMCKeyData()
        input.data8 = 8
        input.data32 = index
        guard let output = call(input), output.result == 0 else { return nil }
        return String(bytes: output.key.bigEndianBytes, encoding: .ascii)
    }

    private func call(_ input: SMCKeyData) -> SMCKeyData? {
        var input = input
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.size
        guard MemoryLayout<SMCKeyData>.size == 80 else { return nil }
        let result = IOConnectCallStructMethod(
            connection,
            2,
            &input,
            MemoryLayout<SMCKeyData>.size,
            &output,
            &outputSize
        )
        return result == KERN_SUCCESS ? output : nil
    }
}

private extension String {
    var fourCC: UInt32? {
        let bytes = Array(utf8)
        guard bytes.count == 4 else { return nil }
        return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 24) & 0xff), UInt8((self >> 16) & 0xff), UInt8((self >> 8) & 0xff), UInt8(self & 0xff)]
    }

    init(littleEndianBytes bytes: [UInt8]) {
        self = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
    }

    init(bigEndianBytes bytes: [UInt8]) {
        self = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }
}

private extension UInt16 {
    init(bigEndianBytes bytes: [UInt8]) {
        self = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }
}
