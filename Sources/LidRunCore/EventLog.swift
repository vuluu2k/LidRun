import Foundation

public enum EventType: String, Codable, Sendable {
    case started
    case stopped
}

public struct RunEvent: Codable, Equatable, Sendable {
    public let time: Date
    public let type: EventType
    public let reason: String

    public init(time: Date = Date(), type: EventType, reason: String) {
        self.time = time
        self.type = type
        self.reason = reason
    }
}

public final class EventLog: @unchecked Sendable {
    public let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(url: URL = EventLog.defaultURL()) {
        self.url = url
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func append(_ event: RunEvent) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(event) + Data("\n".utf8)
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    public func recent(limit: Int = 20) throws -> [RunEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .suffix(limit)
            .compactMap { try? decoder.decode(RunEvent.self, from: Data($0.utf8)) }
    }

    public static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LidRunPersonal", isDirectory: true)
            .appendingPathComponent("events.jsonl")
    }
}
