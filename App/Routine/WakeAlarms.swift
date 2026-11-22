import AlarmKit
import AppIntents
import CryptoKit
import Foundation
import SwiftUI

struct WakeMetadata: AlarmMetadata {}

/// Wake alarm that only fully turns off with the desk tag (pattern from Touchstone, MIT).
///
/// iOS always shows a Stop button we can't remove, so:
/// - Stop runs `RearmWakeIntent`, which schedules another alarm 30 s later (for up to 1 h).
/// - 15 "chaser" alarms are pre-scheduled every minute after the wake time, because iOS
///   doesn't always run the stop intent (e.g. pressing the power button).
/// - Scanning the desk tag (the alert's "Scan desk tag" button opens the app) checks in,
///   which cancels everything left for that morning.
enum WakeAlarms {
    static let chaserCount = 15
    static let chaserInterval: TimeInterval = 60
    static let rearmDelay: TimeInterval = 30

    private static var manager: AlarmManager { .shared }

    static var isAuthorized: Bool { manager.authorizationState == .authorized }

    static func authorize() async -> Bool {
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return (try? await manager.requestAuthorization()) == .authorized
        @unknown default: return false
        }
    }

    // MARK: - Check-in state

    /// The wake time we're currently around (2 h before → 1 h after) and haven't checked in for.
    static func pendingWake(now: Date = Date(), store: SharedStore = .shared) -> Date? {
        store.routine.wakeDates(from: now, days: 2).first { wake in
            now >= wake.addingTimeInterval(-Routine.checkInEarlyWindow)
                && now <= wake.addingTimeInterval(Routine.checkInLateWindow)
                && !isCheckedIn(for: wake, store: store)
        }
    }

    static func isCheckedIn(for wake: Date, store: SharedStore = .shared) -> Bool {
        guard let last = store.lastCheckIn else { return false }
        return last >= wake.addingTimeInterval(-Routine.checkInEarlyWindow)
            && last <= wake.addingTimeInterval(Routine.checkInLateWindow)
    }

    /// Records the morning check-in and silences/cancels the rest of this morning's alarms.
    /// Returns the wake time checked in for, or nil if no wake was pending.
    @discardableResult
    static func checkIn(now: Date = Date()) async -> Date? {
        let store = SharedStore.shared
        guard let wake = pendingWake(now: now, store: store) else { return nil }
        store.lastCheckIn = now
        store.extraAlarms = []
        EventLog.append(.morningCheckIn, info: [
            "wakeTime": ISO8601DateFormatter().string(from: wake),
            "minutesFromAlarm": String(Int(now.timeIntervalSince(wake) / 60)),
        ])
        await sync(now: now)
        return wake
    }

    /// Stop was pressed without scanning: ring again shortly (while the wake is still pending).
    static func rearmIfNeeded(now: Date = Date()) async {
        let store = SharedStore.shared
        guard let wake = pendingWake(now: now, store: store), now >= wake else { return }
        store.extraAlarms.append(PlannedAlarm(id: UUID(), fireDate: now.addingTimeInterval(rearmDelay)))
        EventLog.append(.alarmStopped, info: ["rearmed": "true"])
        await sync(now: now)
    }

    static func scheduleTest(now: Date = Date()) async {
        SharedStore.shared.extraAlarms.append(PlannedAlarm(id: UUID(), fireDate: now.addingTimeInterval(30)))
        await sync(now: now)
    }

    // MARK: - Scheduling

    /// Everything that should be scheduled right now.
    static func plan(now: Date, store: SharedStore = .shared) -> [PlannedAlarm] {
        let wakes = store.routine.wakeDates(from: now).filter { !isCheckedIn(for: $0, store: store) }
        var alarms: [PlannedAlarm] = []
        for (index, wake) in wakes.enumerated() {
            alarms.append(PlannedAlarm(id: stableID(wake, 0), fireDate: wake))
            // Chasers only for the next wake, to stay well under the system's alarm limit.
            if index == 0 {
                for n in 1...chaserCount {
                    alarms.append(PlannedAlarm(id: stableID(wake, n),
                                               fireDate: wake.addingTimeInterval(Double(n) * chaserInterval)))
                }
            }
        }
        alarms += store.extraAlarms
        return alarms.filter { $0.fireDate > now }
    }

    /// Makes AlarmKit match `plan`. Safe to call often (app foreground, after edits, check-in).
    static func sync(now: Date = Date()) async {
        guard isAuthorized else { return }
        let store = SharedStore.shared
        store.extraAlarms = store.extraAlarms.filter { $0.fireDate > now.addingTimeInterval(-Routine.checkInLateWindow) }

        let wanted = plan(now: now, store: store)
        let wantedIDs = Set(wanted.map(\.id))
        // Don't silence an alarm that's ringing for a wake that hasn't been checked in yet.
        let keepRinging = pendingWake(now: now, store: store) != nil

        guard let existing = try? manager.alarms else { return }
        for alarm in existing where !wantedIDs.contains(alarm.id) {
            if alarm.state == .alerting {
                if keepRinging { continue }
                try? manager.stop(id: alarm.id)
            }
            try? manager.cancel(id: alarm.id)
        }

        let scheduled = Set(existing.map(\.id))
        for alarm in wanted where !scheduled.contains(alarm.id) {
            _ = try? await manager.schedule(id: alarm.id, configuration: configuration(firingAt: alarm.fireDate))
        }
    }

    private static func configuration(firingAt date: Date) -> AlarmManager.AlarmConfiguration<WakeMetadata> {
        let scanButton = AlarmButton(text: "Scan desk tag", textColor: .white, systemImageName: "wave.3.right")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            // 26.1+: the system draws its own slide-to-stop control.
            alert = AlarmPresentation.Alert(
                title: "Time to get up",
                secondaryButton: scanButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: "Time to get up",
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
                secondaryButton: scanButton,
                secondaryButtonBehavior: .custom
            )
        }
        return .alarm(
            schedule: .fixed(date),
            attributes: AlarmAttributes(presentation: AlarmPresentation(alert: alert), tintColor: .green),
            stopIntent: RearmWakeIntent(),
            secondaryIntent: ScanForWakeIntent()
        )
    }

    /// Same wake + index → same ID, so re-syncing never duplicates alarms.
    static func stableID(_ wake: Date, _ index: Int) -> UUID {
        let digest = Array(SHA256.hash(data: Data("tawfeeq-wake-\(Int(wake.timeIntervalSince1970))-\(index)".utf8)))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}

/// The alert's Stop button. Unless the tag was scanned, it rings again 30 s later.
struct RearmWakeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ring again"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await WakeAlarms.rearmIfNeeded()
        return .result()
    }
}

/// The alert's "Scan desk tag" button: opens Tawfeeq straight into a scan.
struct ScanForWakeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Scan desk tag"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.handleWakeScanRequest()
        return .result()
    }
}
