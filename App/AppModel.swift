import FamilyControls
import Foundation
import SwiftUI
import UserNotifications

struct AppAlert: Identifiable {
    let id = UUID()
    let message: String
}

/// Shown when a session ends ("52 minutes of focus. 1 pass.").
struct SessionSummary: Identifiable {
    let id = UUID()
    let duration: TimeInterval
    let passes: Int
    let wasNightLock: Bool
    let checkedIn: Date?
}

/// What the Focus home (and mini-player) should show.
enum HomeState: Equatable {
    case idle
    case focusing(startedAt: Date)
    case pass(endsAt: Date)
    case night(startedAt: Date)
    case morning(wake: Date)
}

@MainActor
final class AppModel: ObservableObject {
    /// Single instance, shared with App Intents (Shortcuts NFC automation).
    static let shared = AppModel()

    @Published private(set) var isAuthorized = false
    @Published private(set) var config: BlockConfig
    @Published private(set) var tags: [EnrolledTag]
    @Published private(set) var session: FocusSession?
    /// Set while a 5-minute pass is running (may be started from the block screen, i.e. another process).
    @Published private(set) var passExpiresAt: Date?
    @Published private(set) var passSummary = PassManager.DaySummary()
    @Published private(set) var routine: Routine
    /// Set around the wake time until the desk tag is scanned (morning check-in).
    @Published private(set) var pendingWake: Date?
    @Published private(set) var isScanning = false
    @Published var alert: AppAlert?
    @Published private(set) var onboardingCompleted: Bool
    @Published var lastSummary: SessionSummary?
    @Published private(set) var hapticsEnabled: Bool
    @Published private(set) var dailyGoalMinutes: Int
    /// Bumped on events that deserve a haptic; views attach .sensoryFeedback to these.
    @Published private(set) var successTick = 0
    @Published private(set) var warningTick = 0
    @Published private(set) var statsCache: StatsSummary?
    private var statsCacheDate = Date.distantPast

    private let store = SharedStore.shared
    private let blocker = Blocker()
    private let scanner = TagScanner()

    init() {
        config = store.blockConfig
        tags = store.tags
        session = store.activeSession
        passExpiresAt = store.passExpiresAt
        routine = store.routine
        onboardingCompleted = store.onboardingCompleted
        hapticsEnabled = store.hapticsEnabled
        dailyGoalMinutes = store.dailyGoalMinutes
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    var isFocusing: Bool { session != nil }

    func homeState(now: Date = Date()) -> HomeState {
        if let wake = pendingWake { return .morning(wake: wake) }
        guard let session else { return .idle }
        if let passExpiresAt, passExpiresAt > now { return .pass(endsAt: passExpiresAt) }
        if session.source == .nightLock { return .night(startedAt: session.startedAt) }
        return .focusing(startedAt: session.startedAt)
    }

    // MARK: - Settings

    func setHaptics(_ enabled: Bool) {
        hapticsEnabled = enabled
        store.hapticsEnabled = enabled
    }

    func setDailyGoal(minutes: Int) {
        dailyGoalMinutes = minutes
        store.dailyGoalMinutes = minutes
    }

    /// Hold-to-start from the app (no tag needed to *start*; ending still needs it).
    func startWithoutTag() {
        startSession(with: nil, source: .hold)
    }

    func isOnPass(now: Date = Date()) -> Bool {
        guard let passExpiresAt else { return false }
        return passExpiresAt > now
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            alert = AppAlert(message: "Screen Time permission wasn't granted. \(error.localizedDescription)")
        }
        refreshAuthorization()
    }

    private func refreshAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if isAuthorized != store.lastKnownAuthorized {
            EventLog.append(isAuthorized ? .authorizationGranted : .authorizationLost,
                            info: ["duringSession": isFocusing ? "true" : "false"])
            store.lastKnownAuthorized = isAuthorized
        }
    }

    func completeOnboarding() {
        store.onboardingCompleted = true
        onboardingCompleted = true
    }

    // MARK: - Lifecycle

    /// Called every time the app comes to the foreground.
    func onForeground() {
        refreshAuthorization()
        reconcile()
        if routine.nightLockEnabled, !NightLock.isMonitoring {
            try? NightLock.sync(routine)
        }
        Task {
            await WakeAlarms.sync()
            pendingWake = WakeAlarms.pendingWake()
        }
    }

    /// Self-heal: make the real shield state match what it should be.
    /// Covers stuck shields and missed extension callbacks (e.g. a pass that never re-blocked).
    /// Also called every few seconds while the Focus screen is visible.
    func reconcile(now: Date = Date()) {
        // State can change in other processes (pass button on the block screen, monitor extension).
        session = store.activeSession
        if let expiresAt = store.passExpiresAt, expiresAt <= now {
            PassManager.end(reason: "expiredRepairedByApp", now: now)
        }
        passExpiresAt = store.passExpiresAt
        passSummary = PassManager.summary(for: now)
        refreshStats(now: now)
        pendingWake = WakeAlarms.pendingWake(now: now)

        LiveActivityController.sync(session: session, passExpiresAt: passExpiresAt, now: now)

        guard isAuthorized else { return }
        let shouldShield = isFocusing && !isOnPass(now: now)
        if shouldShield, !blocker.isShielding {
            blocker.apply(config)
            EventLog.append(.shieldRepaired, info: ["reason": "missingDuringSession"])
        } else if !shouldShield, blocker.isShielding {
            if isFocusing { blocker.liftShields() } else { blocker.clear() }
            EventLog.append(.shieldRepaired, info: ["reason": isFocusing ? "shieldedDuringPass" : "staleAfterSession"])
        }
    }

    // MARK: - Temporary pass (emergency override)

    func takePass(intention: PassIntention? = nil) {
        do {
            try PassManager.start(source: "app", intention: intention)
            if PassManager.recent().inLast30Minutes >= 3 { warningTick += 1 }
        } catch {
            alert = AppAlert(message: error.localizedDescription)
        }
        reconcile()
    }

    func endPassEarly() {
        PassManager.end(reason: "endedEarly")
        reconcile()
    }

    // MARK: - Shortcuts NFC automation

    /// Run by the "Desk Tag Tapped" App Intent. Starting is allowed straight from the shortcut;
    /// ending always needs a real in-app scan, because a shortcut can be run by hand.
    func handleDeskTagShortcut() {
        if isFocusing {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await scanToToggle()
            }
        } else {
            let tag = tags.first { $0.role == .desk } ?? tags.first
            startSession(with: tag, source: .shortcut)
        }
    }

    // MARK: - Morning

    /// Run by the alarm's "Scan desk tag" button.
    func handleWakeScanRequest() {
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await scanToToggle()
        }
    }

    // MARK: - Sessions

    /// Main button: scan a tag, then start or end a session.
    func scanToToggle() async {
        guard !isScanning else { return }
        guard !tags.isEmpty else {
            alert = AppAlert(message: "Add your desk tag first in the Tags tab.")
            return
        }
        let wake = WakeAlarms.pendingWake()
        if wake == nil, !isFocusing, let problem = startProblem() {
            alert = AppAlert(message: problem)
            return
        }

        let known = tags
        let prompt = wake != nil
            ? "Good morning! Hold your iPhone near your desk tag to check in."
            : isFocusing
                ? "Hold your iPhone near your desk tag to end the session."
                : "Hold your iPhone near your desk tag to start focusing."

        isScanning = true
        defer { isScanning = false }
        do {
            let result = try await scanner.read(prompt: prompt) { result in
                known.contains { $0.matches(uid: result.uid) } ? nil : "That tag isn't registered with Tawfeeq."
            }
            guard let tag = known.first(where: { $0.matches(uid: result.uid) }) else { return }
            if wake != nil {
                // Morning check-in: silences the alarm and ends the night lock (or any session),
                // but never starts a new session.
                let checkedInAt = Date()
                await WakeAlarms.checkIn()
                pendingWake = WakeAlarms.pendingWake()
                if isFocusing {
                    endSession(with: tag, checkedIn: checkedInAt)
                } else {
                    lastSummary = SessionSummary(duration: 0, passes: 0, wasNightLock: false, checkedIn: checkedInAt)
                    successTick += 1
                }
            } else if isFocusing {
                endSession(with: tag)
            } else {
                startSession(with: tag, source: .tagScan)
            }
        } catch let error as ScanError where error == .cancelled {
            // User closed the sheet.
        } catch {
            alert = AppAlert(message: error.localizedDescription)
        }
    }

    private func startProblem() -> String? {
        if !isAuthorized { return "Tawfeeq needs Screen Time permission first." }
        if !config.hasAnythingToBlock { return "Choose apps to block first in the Block list tab." }
        if config.exceedsAppLimit { return "iOS can only block \(BlockConfig.maxAppTokens) individual apps. Remove some, or block a whole category instead." }
        return nil
    }

    private func startSession(with tag: EnrolledTag?, source: SessionSource) {
        if let problem = startProblem() {
            alert = AppAlert(message: problem)
            return
        }
        blocker.apply(config)
        let newSession = FocusSession(id: UUID(), startedAt: Date(), source: source, startTagID: tag?.id)
        session = newSession
        store.activeSession = newSession
        LiveActivityController.sync(session: newSession, passExpiresAt: nil)
        successTick += 1
        Task { await requestNotificationsIfNeeded() }
        EventLog.append(.sessionStarted, info: [
            "sessionID": newSession.id.uuidString,
            "source": source.rawValue,
            "tag": tag?.name ?? "",
            "tagRole": tag?.role.rawValue ?? "",
        ])
    }

    private func endSession(with tag: EnrolledTag, checkedIn: Date? = nil) {
        guard let current = session else { return }
        PassManager.cancelForSessionEnd()
        passExpiresAt = nil
        if current.source == .nightLock {
            store.lastNightLockEndedAt = Date()
        }
        blocker.clear()
        if blocker.isShielding { blocker.clear() } // one retry for the stuck-shield bug
        session = nil
        store.activeSession = nil
        LiveActivityController.sync(session: nil, passExpiresAt: nil)
        EventLog.append(.sessionEnded, info: [
            "sessionID": current.id.uuidString,
            "endedBy": "tag",
            "source": current.source.rawValue,
            "tag": tag.name,
            "tagRole": tag.role.rawValue,
            "durationSeconds": String(Int(Date().timeIntervalSince(current.startedAt))),
        ])
        let passes = EventLog.all().filter { $0.kind == .passStarted && $0.info["sessionID"] == current.id.uuidString }.count
        lastSummary = SessionSummary(
            duration: Date().timeIntervalSince(current.startedAt),
            passes: passes,
            wasNightLock: current.source == .nightLock,
            checkedIn: checkedIn
        )
        successTick += 1
    }

    /// Asked in context (first session), not during onboarding.
    private func requestNotificationsIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        if (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true {
            PassNotifications.scheduleWeeklySummary()
        }
    }

    /// Break-glass escape for a lost tag. Always allowed, always logged.
    func endSessionWithoutTag() {
        guard let current = session else { return }
        PassManager.cancelForSessionEnd()
        passExpiresAt = nil
        if current.source == .nightLock {
            store.lastNightLockEndedAt = Date()
        }
        blocker.clear()
        session = nil
        store.activeSession = nil
        LiveActivityController.sync(session: nil, passExpiresAt: nil)
        let duration = Date().timeIntervalSince(current.startedAt)
        EventLog.append(.sessionEnded, info: [
            "sessionID": current.id.uuidString,
            "endedBy": "breakGlass",
            "source": current.source.rawValue,
            "durationSeconds": String(Int(duration)),
        ])
        lastSummary = SessionSummary(duration: duration, passes: 0, wasNightLock: current.source == .nightLock, checkedIn: nil)
        refreshStats()
    }

    // MARK: - Tag links (https://tawfeeq.uk/t/<secret>)

    /// Opened when a tag is tapped while the phone is unlocked (background tag reading → notification).
    /// A link can start a session, but ending one always requires a real in-app scan,
    /// because a URL can be opened without the tag.
    func handle(url: URL) {
        guard url.host?.lowercased() == AppGroup.linkHost,
              url.pathComponents.count >= 3,
              url.pathComponents[1] == "t" else { return }
        let secret = url.pathComponents[2]
        guard let tag = tags.first(where: { $0.secret == secret }) else {
            alert = AppAlert(message: "This tag isn't registered on this phone.")
            return
        }
        if isFocusing {
            Task {
                // Give the app a moment to become active before showing the NFC sheet.
                try? await Task.sleep(for: .milliseconds(600))
                await scanToToggle()
            }
        } else {
            startSession(with: tag, source: .tagLink)
        }
    }

    // MARK: - Tag enrollment

    func enrollTag(name: String, role: TagRole) async {
        guard !isScanning else { return }
        guard !isFocusing else {
            alert = AppAlert(message: "You can't change tags during a focus session.")
            return
        }
        let knownUIDs = tags.map(\.uid)

        isScanning = true
        defer { isScanning = false }
        do {
            // Tap 1: read the UID.
            let first = try await scanner.read(prompt: "Hold your iPhone near the new tag.") { result in
                knownUIDs.contains { $0.caseInsensitiveCompare(result.uid) == .orderedSame }
                    ? "This tag is already registered."
                    : nil
            }

            // Short pause so the first sheet can dismiss before the second appears.
            try? await Task.sleep(for: .milliseconds(800))

            // Tap 2: confirm the UID is stable, then write our link onto the tag.
            let secret = Self.makeSecret()
            guard let url = URL(string: "https://\(AppGroup.linkHost)/t/\(secret)") else { return }
            let firstUID = first.uid
            let second = try await scanner.write(url: url, prompt: "Tap the same tag again to finish setting it up.") { result in
                result.uid == firstUID
                    ? nil
                    : "That's a different tag, or its ID changes on every tap. Use an NTAG sticker."
            }

            let tag = EnrolledTag(
                id: UUID(),
                name: name.isEmpty ? role.label : name,
                role: role,
                uid: second.uid,
                secret: secret,
                hasLink: second.wroteURL,
                enrolledAt: Date()
            )
            tags.append(tag)
            store.tags = tags
            EventLog.append(.tagEnrolled, info: ["tag": tag.name, "tagRole": role.rawValue, "hasLink": String(tag.hasLink)])
        } catch let error as ScanError where error == .cancelled {
            // User closed the sheet.
        } catch {
            alert = AppAlert(message: error.localizedDescription)
        }
    }

    func removeTag(_ tag: EnrolledTag) {
        guard !isFocusing else {
            alert = AppAlert(message: "You can't remove tags during a focus session.")
            return
        }
        tags.removeAll { $0.id == tag.id }
        store.tags = tags
        EventLog.append(.tagRemoved, info: ["tag": tag.name, "tagRole": tag.role.rawValue])
    }

    private static func makeSecret() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    // MARK: - Block list

    /// Returns false (and explains why) if editing is locked.
    @discardableResult
    func updateConfig(_ newConfig: BlockConfig) -> Bool {
        guard newConfig != config else { return true }
        if isFocusing, !newConfig.isAtLeastAsStrict(as: config) {
            alert = AppAlert(message: "You can add apps during a session. Removing apps waits until your session ends.")
            warningTick += 1
            return false
        }
        config = newConfig
        store.blockConfig = newConfig
        if isFocusing, !isOnPass() {
            blocker.apply(newConfig) // tightened mid-session: apply right away
        }
        EventLog.append(.blockListEdited, info: [
            "mode": newConfig.mode.rawValue,
            "blockedApps": String(newConfig.blocked.applicationTokens.count),
            "blockedCategories": String(newConfig.blocked.categoryTokens.count),
            "allowedApps": String(newConfig.allowed.applicationTokens.count),
        ])
        return true
    }

    // MARK: - Routine (wake alarm + night lock)

    func updateRoutine(_ newRoutine: Routine) async {
        guard newRoutine != routine else { return }
        guard !isFocusing else {
            alert = AppAlert(message: "Your routine is locked during a focus session or night lock.")
            return
        }
        if newRoutine.nightLockEnabled, !newRoutine.nightLockIntervalIsValid {
            alert = AppAlert(message: "Night lock must start at least 15 minutes before your wake time.")
            return
        }
        if newRoutine.wakeEnabled, !(await WakeAlarms.authorize()) {
            alert = AppAlert(message: "Tawfeeq needs permission to ring alarms. Turn it on in Settings → Tawfeeq → Alarms.")
            return
        }

        routine = newRoutine
        store.routine = newRoutine
        do {
            try NightLock.sync(newRoutine)
        } catch {
            alert = AppAlert(message: "Couldn't schedule the night lock. \(error.localizedDescription)")
        }
        await WakeAlarms.sync()
        EventLog.append(.routineEdited, info: [
            "wakeEnabled": String(newRoutine.wakeEnabled),
            "wakeTime": String(format: "%02d:%02d", newRoutine.wakeTime.hour, newRoutine.wakeTime.minute),
            "nightLockEnabled": String(newRoutine.nightLockEnabled),
            "nightLockStart": String(format: "%02d:%02d", newRoutine.nightLockStart.hour, newRoutine.nightLockStart.minute),
        ])
        reconcile()
    }

    func testAlarm() async {
        guard await WakeAlarms.authorize() else {
            alert = AppAlert(message: "Tawfeeq needs permission to ring alarms. Turn it on in Settings → Tawfeeq → Alarms.")
            return
        }
        await WakeAlarms.scheduleTest()
        alert = AppAlert(message: "A test alarm will ring in about 30 seconds. Lock your phone to see it full screen.")
    }

    // MARK: - Stats

    func refreshStats(now: Date = Date()) {
        statsCache = stats(days: 35, now: now)
        statsCacheDate = now
    }

    /// Today's numbers, kept live between refreshes by adding the running session time.
    func todayStats(now: Date = Date()) -> DayStats {
        let calendar = Calendar.current
        var today = statsCache?.today.flatMap { calendar.isDate($0.day, inSameDayAs: now) ? $0 : nil }
            ?? DayStats(day: calendar.startOfDay(for: now))
        if let session, session.source != .nightLock, statsCache != nil {
            today.focusSeconds += max(0, now.timeIntervalSince(max(statsCacheDate, session.startedAt)))
        }
        return today
    }

    var currentStreak: Int { statsCache?.currentStreak ?? 0 }

    /// "14 apps", "14 apps and 3 categories", "all but 5 apps"
    var blockedSummary: String {
        switch config.mode {
        case .everythingExceptAllowed:
            let allowed = config.allowed.applicationTokens.count
            return allowed == 0 ? "All apps are" : "All apps except \(allowed) are"
        case .selected:
            let apps = config.blocked.applicationTokens.count
            let categories = config.blocked.categoryTokens.count
            var parts: [String] = []
            if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
            if categories > 0 { parts.append("\(categories) categor\(categories == 1 ? "y" : "ies")") }
            return parts.isEmpty ? "Nothing is" : parts.joined(separator: " and ") + ((apps + categories) == 1 ? " is" : " are")
        }
    }

    /// "Night lock at 22:30" or "Alarm Tue 07:00", whichever is sooner.
    var nextEventDescription: String? {
        let now = Date()
        let calendar = Calendar.current
        var candidates: [(Date, String)] = []
        if routine.nightLockEnabled, var start = routine.nightLockStart.date(on: now) {
            if start <= now { start = calendar.date(byAdding: .day, value: 1, to: start) ?? start }
            candidates.append((start, "Night lock at \(start.formatted(date: .omitted, time: .shortened))"))
        }
        if let wake = routine.wakeDates(from: now).first(where: { $0 > now }) {
            let day = calendar.isDateInToday(wake) ? "today" : calendar.isDateInTomorrow(wake) ? "tomorrow" : wake.formatted(.dateTime.weekday(.wide))
            candidates.append((wake, "Alarm \(day) at \(wake.formatted(date: .omitted, time: .shortened))"))
        }
        return candidates.min { $0.0 < $1.0 }?.1
    }

    func stats(days: Int, now: Date = Date()) -> StatsSummary {
        StatsBuilder.build(
            events: EventLog.all(),
            activeSession: session,
            dayCount: days,
            goalMinutes: store.dailyGoalMinutes,
            now: now
        )
    }

    func focusedToday(now: Date = Date()) -> TimeInterval {
        let startOfDay = Calendar.current.startOfDay(for: now)
        var total = EventLog.focusedSeconds(since: startOfDay)
        if let session, session.source != .nightLock {
            total += now.timeIntervalSince(max(session.startedAt, startOfDay))
        }
        return total
    }
}
