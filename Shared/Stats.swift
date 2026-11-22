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
    var endedWithoutTag = 0
    /// Streak kept alive by a grace day (one allowed per 7 days).
    var isGraceDay = false

    var id: Date { day }
    var focusMinutes: Double { focusSeconds / 60 }
}

struct StatsSummary: Equatable {
    var days: [DayStats]            // oldest → newest, one per calendar day
    var currentStreak: Int          // consecutive days meeting the goal, ending today (or yesterday)
    var bestStreak: Int
    var goalMinutes: Int
    var longestSession: TimeInterval
    var intentions: [String: Int] = [:]
    /// Passes by hour of day (0–23), for the gentle suggestion.
    var passHours: [Int: Int] = [:]
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
        var intentions: [String: Int] = [:]
        var passHours: [Int: Int] = [:]

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
                if event.info["endedBy"] == "breakGlass" { days[day]?.endedWithoutTag += 1 }
                if isNight {
                    days[day]?.nightLocked = true
                } else if let seconds = event.info["durationSeconds"].flatMap(TimeInterval.init) {
                    days[day]?.sessions += 1
                    addFocus(from: event.date.addingTimeInterval(-seconds), to: event.date)
                }
            case .passStarted:
                days[day]?.passes += 1
                if event.info["backToBack"] == "true" { days[day]?.backToBackPasses += 1 }
                let intention = event.info["intention"].flatMap { $0.isEmpty ? nil : $0 } ?? "unspecified"
                intentions[intention, default: 0] += 1
                passHours[calendar.component(.hour, from: event.date), default: 0] += 1
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

        var ordered = days.values.sorted { $0.day < $1.day }
        let goal = TimeInterval(goalMinutes * 60)
        let met = ordered.map { $0.focusSeconds >= goal && goal > 0 }

        // Today doesn't break a streak until it's over.
        let lastIndex = met.count - 1
        let current = streak(endingAt: (lastIndex >= 0 && !met[lastIndex]) ? lastIndex - 1 : lastIndex, met: met)
        var best = current.length
        for end in met.indices { best = max(best, streak(endingAt: end, met: met).length) }
        for index in current.graceIndices { ordered[index].isGraceDay = true }

        return StatsSummary(days: ordered, currentStreak: current.length, bestStreak: best,
                            goalMinutes: goalMinutes, longestSession: longest,
                            intentions: intentions, passHours: passHours)
    }

    /// Consecutive goal days ending at `end`, forgiving one missed day per 7 days
    /// (never two misses in a row, and a streak can't start or end on a grace day).
    static func streak(endingAt end: Int, met: [Bool]) -> (length: Int, graceIndices: [Int]) {
        guard end >= 0, end < met.count, met[end] else { return (0, []) }
        var length = 0
        var graces: [Int] = []
        var index = end
        while index >= 0 {
            if met[index] {
                length += 1
            } else {
                let previousMet = index > 0 && met[index - 1]
                let lastGrace = graces.last ?? Int.max
                guard previousMet, lastGrace - index >= 7 else { break }
                graces.append(index)
            }
            index -= 1
        }
        return (length, graces)
    }
}
