import Foundation
import WidgetKit

/// Shared state for widgets and controls, plus a reload trigger callable from any process.
struct WidgetSnapshot {
    enum Mode { case idle, focusing, pass, night }

    var mode: Mode
    var sessionStart: Date?
    var passEnd: Date?
    var focusToday: TimeInterval
    var goal: TimeInterval
    var streak: Int

    static func current(now: Date = Date()) -> WidgetSnapshot {
        let store = SharedStore.shared
        let session = store.activeSession
        let passEnd = store.passExpiresAt.flatMap { $0 > now ? $0 : nil }
        let stats = StatsBuilder.build(events: EventLog.all(), activeSession: session, dayCount: 35,
                                       goalMinutes: store.dailyGoalMinutes, now: now)
        let mode: Mode
        if session == nil { mode = .idle }
        else if passEnd != nil { mode = .pass }
        else if session?.source == .nightLock { mode = .night }
        else { mode = .focusing }
        return WidgetSnapshot(
            mode: mode,
            sessionStart: session?.startedAt,
            passEnd: passEnd,
            focusToday: stats.today?.focusSeconds ?? 0,
            goal: TimeInterval(store.dailyGoalMinutes * 60),
            streak: stats.currentStreak
        )
    }
}

enum WidgetSync {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}
