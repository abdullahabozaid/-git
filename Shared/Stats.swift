import Foundation

/// Everything the Stats screen (and later the partner feed) shows that Tawfeeq records itself.
/// Screen time numbers come from the DeviceActivityReport extension instead, because iOS
/// doesn't let them leave that extension.
struct DayStats: Identifiable, Equatable {
    var day: Date            // start of day
    var focusSeconds: TimeInterval = 0
    var sessions = 0
    var passes = 0
    var backToBackPasses = 0
    var checkIn: Date?
    var minutesFromAlarm: Int?
    var nightLocked = false

    var id: Date { day }
    var focusMinutes: Double { focusSeconds / 60 }
}

struct StatsSummary: Equatable {
    var days: [DayStats]            // oldest → newest, one per calendar day
    var currentStreak: Int          // consecutive days meeting the goal, ending today (or yesterday)
    var bestStreak: Int
    var goalMinutes: Int
    var longestSession: TimeInterval
    var totalFocus: TimeInterval { days.reduce(0) { $0 + $1.focusSeconds } }
    var totalPasses: Int { days.reduce(0) { $0 + $1.passes } }
    var checkIns: Int { days.filter { $0.checkIn != nil }.count }
    var today: DayStats? { days.last }
}

enum StatsBuilder {
    /// Builds per-day stats for the last `dayCount` days (including today).
    /// The running session (if any) is included up to `now`.
    static func build(
        events: [LogEvent],
        activeSession: FocusSession?,
        dayCount: Int = 30,
        goalMinutes: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatsSummary {
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return StatsSummary(days: [], currentStreak: 0, bestStreak: 0, goalMinutes: goalMinutes, longestSession: 0)
        }
        var days: [Date: DayStats] = [:]
        for offset in 0..<dayCount {
            if let day = calendar.date(byAdding: .day, value: offset, to: firstDay) {
                days[day] = DayStats(day: day)
            }
        }

        var longest: TimeInterval = 0

        func addFocus(from start: Date, to end: Date) {
            guard end > start else { return }
            longest = max(longest, end.timeIntervalSince(start))
            // Split across midnights so each day gets its share.
            var cursor = start
            while cursor < end {
                let dayStart = calendar.startOfDay(for: cursor)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let sliceEnd = min(end, nextDay)
                days[dayStart]?.focusSeconds += sliceEnd.timeIntervalSince(cursor)
                cursor = sliceEnd
            }
        }

        for event in events where event.date >= firstDay {
            let day = calendar.startOfDay(for: event.date)
            switch event.kind {
            case .sessionEnded:
                let isNight = event.info["source"] == SessionSource.nightLock.rawValue
                if isNight {
                    days[day]?.nightLocked = true
                } else if let seconds = event.info["durationSeconds"].flatMap(TimeInterval.init) {
                    days[day]?.sessions += 1
                    addFocus(from: event.date.addingTimeInterval(-seconds), to: event.date)
                }
            case .passStarted:
                days[day]?.passes += 1
                if event.info["backToBack"] == "true" { days[day]?.backToBackPasses += 1 }
            case .morningCheckIn:
                days[day]?.checkIn = event.date
                days[day]?.minutesFromAlarm = event.info["minutesFromAlarm"].flatMap(Int.init)
            default:
                break
            }
        }

        if let session = activeSession {
            if session.source == .nightLock {
                days[today]?.nightLocked = true
            } else {
                days[today]?.sessions += 1
                addFocus(from: session.startedAt, to: now)
            }
        }

        let ordered = days.values.sorted { $0.day < $1.day }
        let goal = TimeInterval(goalMinutes * 60)
        let met = ordered.map { $0.focusSeconds >= goal && goal > 0 }

        var best = 0, run = 0
        for hit in met {
            run = hit ? run + 1 : 0
            best = max(best, run)
        }
        // Current streak: count back from today; if today isn't met yet, start from yesterday.
        var current = 0
        var index = met.count - 1
        if index >= 0, !met[index] { index -= 1 }
        while index >= 0, met[index] {
            current += 1
            index -= 1
        }

        return StatsSummary(days: ordered, currentStreak: current, bestStreak: best,
                            goalMinutes: goalMinutes, longestSession: longest)
    }
}
