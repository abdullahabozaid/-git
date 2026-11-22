import DeviceActivity
import Foundation

struct TimeOfDay: Codable, Equatable, Hashable {
    var hour: Int
    var minute: Int

    var components: DateComponents { DateComponents(hour: hour, minute: minute) }
    var minutesSinceMidnight: Int { hour * 60 + minute }

    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

/// An alarm we want scheduled in AlarmKit.
struct PlannedAlarm: Codable, Hashable {
    var id: UUID
    var fireDate: Date
}

/// Wake alarm + night lock settings.
struct Routine: Codable, Equatable {
    var wakeEnabled = false
    var wakeTime = TimeOfDay(hour: 7, minute: 0)
    /// Calendar weekdays: 1 = Sunday … 7 = Saturday.
    var wakeDays: Set<Int> = [2, 3, 4, 5, 6]

    var nightLockEnabled = false
    var nightLockStart = TimeOfDay(hour: 22, minute: 30)

    /// Tapping the desk tag up to 2 h before the alarm counts as the morning check-in (and cancels it).
    static let checkInEarlyWindow: TimeInterval = 2 * 60 * 60
    /// The alarm keeps re-arming for up to 1 h after the wake time, then gives up.
    static let checkInLateWindow: TimeInterval = 60 * 60

    /// Upcoming wake times over the next `days` days, including today's while still within the late window.
    func wakeDates(from now: Date, days: Int = 8, calendar: Calendar = .current) -> [Date] {
        guard wakeEnabled else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  wakeDays.contains(calendar.component(.weekday, from: day)),
                  let wake = wakeTime.date(on: day, calendar: calendar),
                  wake.addingTimeInterval(Self.checkInLateWindow) > now
            else { return nil }
            return wake
        }
    }

    /// Whether `now` is between the night-lock start and the wake time.
    func isInNightWindow(_ now: Date, calendar: Calendar = .current) -> Bool {
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let start = nightLockStart.minutesSinceMidnight
        let end = wakeTime.minutesSinceMidnight
        return start < end ? (minutes >= start && minutes < end) : (minutes >= start || minutes < end)
    }

    /// The most recent night-lock start at or before `now`.
    func currentNightStart(_ now: Date, calendar: Calendar = .current) -> Date? {
        guard let today = nightLockStart.date(on: now, calendar: calendar) else { return nil }
        return today <= now ? today : calendar.date(byAdding: .day, value: -1, to: today)
    }

    /// DeviceActivity intervals must be at least 15 minutes.
    var nightLockIntervalIsValid: Bool {
        var minutes = wakeTime.minutesSinceMidnight - nightLockStart.minutesSinceMidnight
        if minutes <= 0 { minutes += 24 * 60 }
        return minutes >= 15
    }
}

extension DeviceActivityName {
    /// Repeats nightly from the night-lock start until the wake time.
    static let nightLock = Self("uk.tawfeeq.nightLock")
}

/// Night lock: an automatic focus session that starts at bedtime and only ends with the desk tag.
enum NightLock {
    static func sync(_ routine: Routine) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.nightLock])
        guard routine.nightLockEnabled, routine.nightLockIntervalIsValid else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: routine.nightLockStart.components,
            intervalEnd: routine.wakeTime.components,
            repeats: true
        )
        try center.startMonitoring(.nightLock, during: schedule)
    }

    static var isMonitoring: Bool {
        DeviceActivityCenter().activities.contains(.nightLock)
    }

    /// Called by the monitor extension when the night interval starts
    /// (also immediately when monitoring begins inside the window).
    static func begin(now: Date = Date()) {
        let store = SharedStore.shared
        let routine = store.routine
        guard routine.nightLockEnabled,
              routine.isInNightWindow(now),
              !store.isTraveling(at: now),
              store.activeSession == nil else { return }
        // Already unlocked with the tag tonight/this morning? Don't re-lock.
        if let windowStart = routine.currentNightStart(now),
           let ended = store.lastNightLockEndedAt, ended >= windowStart { return }
        if let checkIn = store.lastCheckIn,
           let windowStart = routine.currentNightStart(now), checkIn >= windowStart { return }

        let session = FocusSession(id: UUID(), startedAt: now, source: .nightLock, startTagID: nil)
        store.activeSession = session
        Blocker().apply(store.blockConfig)
        EventLog.append(.sessionStarted, info: [
            "sessionID": session.id.uuidString,
            "source": SessionSource.nightLock.rawValue,
        ])
        WidgetSync.reload()
        let wake = routine.wakeTime.date(on: now).map { $0.formatted(date: .omitted, time: .shortened) }
        PassNotifications.notifyNow(
            id: "uk.tawfeeq.nightLock",
            title: "Night lock is on",
            body: wake.map { "Rest well. Tap your desk tag after \($0) to unlock." } ?? "Rest well. Tap your desk tag in the morning to unlock."
        )
    }
}
