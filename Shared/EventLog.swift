import Foundation

/// Append-only history of everything that happens. Stats, streaks and the
/// accountability partner feed are all derived from this.
struct LogEvent: Codable, Identifiable {
    enum Kind: String, Codable {
        case sessionStarted
        case sessionEnded
        case tagEnrolled
        case tagRemoved
        case blockListEdited
        case shieldRepaired
        case authorizationLost
        case authorizationGranted
        case passStarted
        case passEnded
    }

    var id = UUID()
    var date = Date()
    var kind: Kind
    var info: [String: String] = [:]
}

enum EventLog {
    private static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("events.jsonl")
    }

    private static let queue = DispatchQueue(label: "uk.tawfeeq.eventlog")

    static func append(_ kind: LogEvent.Kind, info: [String: String] = [:]) {
        let event = LogEvent(kind: kind, info: info)
        queue.sync {
            guard var line = try? JSONEncoder().encode(event) else { return }
            line.append(0x0A) // newline
            let url = fileURL
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: line)
            } else {
                try? line.write(to: url, options: .atomic)
            }
        }
    }

    static func all() -> [LogEvent] {
        queue.sync {
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            let decoder = JSONDecoder()
            return data.split(separator: 0x0A).compactMap { try? decoder.decode(LogEvent.self, from: $0) }
        }
    }

    /// Total focused seconds since `start`, from completed sessions only.
    static func focusedSeconds(since start: Date) -> TimeInterval {
        all()
            .filter { $0.kind == .sessionEnded && $0.date >= start }
            .compactMap { $0.info["durationSeconds"].flatMap(TimeInterval.init) }
            .reduce(0, +)
    }
}
