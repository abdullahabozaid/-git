import DeviceActivity
import Foundation

extension DeviceActivityName {
    /// One-off interval whose end re-applies the shields after a temporary pass.
    static let pass = Self("uk.tawfeeq.pass")
}

enum PassError: LocalizedError {
    case noSession
    case scheduleFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSession: "There's no focus session running."
        case .scheduleFailed(let reason): "Couldn't schedule the re-block, so the pass wasn't started. \(reason)"
        }
    }
}

/// The emergency override: unlimited 5-minute passes, all logged.
///
/// Callable from the app *and* the ShieldAction extension (the "5-min pass" button on the
/// block screen). Re-blocking is done by the DeviceActivityMonitor extension when the
/// `.pass` interval ends; the app also re-checks on every foreground in case that callback is missed.
enum PassManager {
    static let duration: TimeInterval = 5 * 60
    /// A pass started within this long after the previous one ended counts as "back-to-back".
    static let backToBackWindow: TimeInterval = 2 * 60

    static func isOnPass(now: Date = Date()) -> Bool {
        guard let expiresAt = SharedStore.shared.passExpiresAt else { return false }
        return expiresAt > now
    }

    /// Lifts the shields for `duration`. Idempotent while a pass is already running.
    @discardableResult
    static func start(source: String, intention: PassIntention? = nil, now: Date = Date()) throws -> Date {
        let store = SharedStore.shared
        guard let session = store.activeSession else { throw PassError.noSession }
        if let current = store.passExpiresAt, current > now { return current }

        let expiresAt = now.addingTimeInterval(duration)
        let backToBack = store.lastPassEndedAt.map { now.timeIntervalSince($0) < backToBackWindow } ?? false

        // Schedule the re-block *before* lifting anything: if scheduling fails, stay blocked.
        let center = DeviceActivityCenter()
        center.stopMonitoring([.pass])
        do {
            try center.startMonitoring(.pass, during: schedule(endingAt: expiresAt, now: now))
        } catch {
            throw PassError.scheduleFailed(error.localizedDescription)
        }

        store.passExpiresAt = expiresAt
        store.shieldPassRequestedAt = nil
        Blocker().liftShields()
        PassNotifications.schedule(expiresAt: expiresAt, now: now)
        WidgetSync.reload()
        EventLog.append(.passStarted, info: [
            "sessionID": session.id.uuidString,
            "source": source,
            "backToBack": String(backToBack),
            "intention": intention?.rawValue ?? "",
            "expiresAt": ISO8601DateFormatter().string(from: expiresAt),
        ])
        return expiresAt
    }

    /// Ends the pass and re-blocks (if the session is still running).
    static func end(reason: String, now: Date = Date()) {
        let store = SharedStore.shared
        guard store.passExpiresAt != nil else { return }
        store.passExpiresAt = nil
        store.lastPassEndedAt = now
        DeviceActivityCenter().stopMonitoring([.pass])
        if reason != "expired" { PassNotifications.cancel() }
        if store.activeSession != nil {
            Blocker().apply(store.blockConfig)
        }
        EventLog.append(.passEnded, info: ["reason": reason])
        WidgetSync.reload()
    }

    /// Drops any running pass without re-blocking. Used when the session itself ends.
    static func cancelForSessionEnd(now: Date = Date()) {
        let store = SharedStore.shared
        guard store.passExpiresAt != nil else { return }
        store.passExpiresAt = nil
        store.lastPassEndedAt = now
        DeviceActivityCenter().stopMonitoring([.pass])
        PassNotifications.cancel()
        EventLog.append(.passEnded, info: ["reason": "sessionEnded"])
    }

    /// iOS rejects DeviceActivity intervals shorter than 15 minutes. Like Foqos, we start the
    /// interval in the past (midnight) so it's long enough, and only its *end* matters.
    static func schedule(endingAt end: Date, now: Date) -> DeviceActivitySchedule {
        let calendar = Calendar.current
        func clock(_ date: Date) -> DateComponents {
            calendar.dateComponents([.hour, .minute, .second], from: date)
        }

        if !calendar.isDate(end, inSameDayAs: now) {
            // Pass crosses midnight: an interval that started an hour ago and wraps past 00:00.
            return DeviceActivitySchedule(
                intervalStart: clock(now.addingTimeInterval(-3600)),
                intervalEnd: clock(end),
                repeats: false
            )
        }

        // Just after midnight the 00:00 → end interval would be under 15 min; stretch it.
        // The app still re-blocks at the real expiry whenever it's opened.
        let earliestValidEnd = calendar.startOfDay(for: now).addingTimeInterval(16 * 60)
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: clock(max(end, earliestValidEnd)),
            repeats: false
        )
    }

    // MARK: - Stats

    struct DaySummary {
        var passes = 0
        var backToBack = 0
    }

    static func summary(for day: Date = Date(), events: [LogEvent] = EventLog.all()) -> DaySummary {
        let calendar = Calendar.current
        var summary = DaySummary()
        for event in events where event.kind == .passStarted && calendar.isDate(event.date, inSameDayAs: day) {
            summary.passes += 1
            if event.info["backToBack"] == "true" { summary.backToBack += 1 }
        }
        return summary
    }
}

// MARK: - Friction

/// Why a pass was taken. Shown as chips before a pass and summarised in Insights.
enum PassIntention: String, CaseIterable, Identifiable, Codable {
    case message, navigation, work, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .message: "Reply to someone"
        case .navigation: "Directions"
        case .work: "Work"
        case .other: "Something else"
        }
    }

    var symbol: String {
        switch self {
        case .message: "bubble.left.fill"
        case .navigation: "map.fill"
        case .work: "briefcase.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

extension PassManager {
    /// Escalating breathing wait before a pass: 5 s, then 15 s, then 30 s.
    static func waitSeconds(passesToday: Int) -> Int {
        switch passesToday {
        case 0: 5
        case 1: 15
        default: 30
        }
    }

    struct RecentPasses {
        var today = 0
        var lastStartedAt: Date?
        var inLast30Minutes = 0
    }

    static func recent(now: Date = Date(), events: [LogEvent] = EventLog.all()) -> RecentPasses {
        var result = RecentPasses()
        let calendar = Calendar.current
        for event in events where event.kind == .passStarted {
            if calendar.isDate(event.date, inSameDayAs: now) { result.today += 1 }
            if now.timeIntervalSince(event.date) < 30 * 60 { result.inLast30Minutes += 1 }
            if result.lastStartedAt.map({ event.date > $0 }) ?? true { result.lastStartedAt = event.date }
        }
        return result
    }
}

/// Shared between the ShieldAction and ShieldConfiguration extensions.
enum ShieldPassFlow {
    /// A first tap on "Take a 5-minute pass" stays valid for this long.
    static let requestValidity: TimeInterval = 3 * 60
}
