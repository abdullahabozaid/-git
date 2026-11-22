import FamilyControls
import Foundation
import SwiftUI
import UserNotifications

struct AppAlert: Identifiable {
    /// A way out of the problem, shown as the alert's main button.
    enum Action {
        case none, openSettings, retryScan, chooseApps, lostTag

        var title: String? {
            switch self {
            case .none: nil
            case .openSettings: "Open Settings"
            case .retryScan: "Try again"
            case .chooseApps: "Choose apps"
            case .lostTag: "Lost your tag?"
            }
        }
    }

    let id = UUID()
    var title: String = "Tawfeeq"
    let message: String
    var action: Action = .none
}

/// Shown when a session ends ("52 minutes of focus. 1 pass.").
struct SessionSummary: Identifiable {
    let id = UUID()
    let duration: TimeInterval
    let passes: Int
    let wasNightLock: Bool
    let checkedIn: Date?
    // Filled in by AppModel so the sheet can say something specific.
    var todayFocus: TimeInterval = 0
    var goal: TimeInterval = 0
    var observation: String?
    var enriched = false
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
    @Published var lastSummary: SessionSummary? {
        didSet {
            if let summary = lastSummary, !summary.enriched { lastSummary = enrich(summary) }
        }
    }
    @Published private(set) var hapticsEnabled: Bool
    @Published private(set) var dailyGoalMinutes: Int
    @Published private(set) var travelUntil: Date?
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
        travelUntil = store.travelUntil
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        #if DEBUG
        if let scene = DemoScene.fromLaunchArguments() { applyDemo(scene) }
        #endif
    }

    // MARK: - Demo mode (DEBUG): fake data for simulator screenshots

    /// Set in demo mode; stops the app touching Screen Time, alarms or the real event log.
    private(set) var isDemo = false
    private var demoEvents: [LogEvent]?
    private var demoBlockedApps = 0
    @Published private(set) var demoTab: String?
    @Published private(set) var demoOnboardingStep: Int?
    @Published var demoShowPassSheet = false

    var canStartSession: Bool { isDemo ? demoBlockedApps > 0 : config.hasAnythingToBlock }

    #if DEBUG
    private func applyDemo(_ scene: DemoScene) {
        isDemo = true
        let now = Date()
        isAuthorized = true
        onboardingCompleted = scene.onboardingStep == nil
        demoOnboardingStep = scene.onboardingStep
        demoTab = scene.tab
        demoBlockedApps = scene == .empty ? 0 : 14
        tags = scene == .empty ? [] : DemoData.tags
        routine = DemoData.routine
        demoEvents = scene == .empty ? [] : DemoData.events(now: now)
        dailyGoalMinutes = 120

        switch scene {
        case .focusing, .passSheet, .insights, .rules, .settings, .largeText:
            session = FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-42 * 60 - 17), source: .tagScan, startTagID: nil)
        case .pass:
            session = FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-63 * 60), source: .tagScan, startTagID: nil)
            passExpiresAt = now.addingTimeInterval(3 * 60 + 12)
        case .night:
            session = FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-3 * 3600 - 25 * 60), source: .nightLock, startTagID: nil)
        case .morning:
            session = FocusSession(id: UUID(), startedAt: now.addingTimeInterval(-8 * 3600), source: .nightLock, startTagID: nil)
            pendingWake = now.addingTimeInterval(-4 * 60)
        case .summary:
            lastSummary = SessionSummary(duration: 52 * 60, passes: 1, wasNightLock: false, checkedIn: nil)
        case .idle, .empty, .onboarding0, .onboarding1, .onboarding2, .onboarding3, .onboarding4, .onboarding5, .onboarding6:
            break
        }
        demoShowPassSheet = scene == .passSheet
        statsCache = stats(days: 35, now: now)
        statsCacheDate = now
    }
    #endif

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

    /// Travel mode pauses night lock and the wake alarm. Logged like any routine edit.
    func setTravel(until date: Date?) async {
        travelUntil = date
        store.travelUntil = date
        EventLog.append(.routineEdited, info: ["travelUntil": date.map { ISO8601DateFormatter().string(from: $0) } ?? "off"])
        await WakeAlarms.sync()
    }

    /// Control Center / widget / Siri start. Opens the app; ending still needs the tag.
    func startFromControl() {
        guard !isFocusing else { return }
        startSession(with: nil, source: .control)
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
            alert = AppAlert(
                title: "Screen Time is off",
                message: "Tawfeeq needs Screen Time to block apps. Turn it on in Settings → Screen Time → Apps with Screen Time Access.",
                action: .openSettings
            )
        }
        refreshAuthorization()
    }

    private func refreshAuthorization() {
        guard !isDemo else { return }
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
        EventLog.append(.onboardingCompleted)
    }

    func logPassSheet(opened: Bool) {
        EventLog.append(opened ? .passSheetOpened : .passAbandoned)
    }

    // MARK: - Lifecycle

    /// Called every time the app comes to the foreground.
    func onForeground() {
        guard !isDemo else { return }
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
        guard !isDemo else { return }
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
            alert = AppAlert(title: "No desk tag yet", message: "Add your desk sticker in Settings → Tags. It takes two taps.")
            return
        }
        let wake = WakeAlarms.pendingWake()
        if wake == nil, !isFocusing, let problem = startProblem() {
            alert = problem
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
                known.contains { $0.matches(uid: result.uid) } ? nil : "That's not one of your Tawfeeq tags."
            }
            EventLog.append(.scanSucceeded)
            guard let tag = known.first(where: { $0.matches(uid: result.uid) }) else { return }
            if let index = tags.firstIndex(where: { $0.id == tag.id }) {
                tags[index].lastScannedAt = Date()
                store.tags = tags
            }
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
            alert = scanAlert(for: error)
        }
    }

    /// Specific, recoverable NFC errors (logged for the scan success-rate metric).
    private func scanAlert(for error: Error) -> AppAlert {
        let scanError = error as? ScanError
        EventLog.append(.scanFailed, info: ["reason": error.localizedDescription])
        switch scanError {
        case .unavailable:
            return AppAlert(title: "NFC isn't available", message: "This iPhone can't read NFC tags right now. Check that Airplane Mode is off, then try again.", action: .retryScan)
        case .rejected(let message):
            return AppAlert(title: "Not your desk tag", message: message + " Use the sticker you registered, or your spare.", action: .lostTag)
        default:
            return AppAlert(title: "Didn't catch the tag", message: "Hold the top edge of your iPhone flat against the sticker for a second.", action: .retryScan)
        }
    }

    private func startProblem() -> AppAlert? {
        if !isAuthorized {
            return AppAlert(title: "Screen Time is off", message: "Tawfeeq needs Screen Time to block apps.", action: .openSettings)
        }
        if !config.hasAnythingToBlock {
            return AppAlert(title: "Nothing to block yet", message: "Choose the apps that distract you, then tap your desk tag.", action: .chooseApps)
        }
        if config.exceedsAppLimit {
            return AppAlert(title: "Too many apps", message: "iOS can block up to \(BlockConfig.maxAppTokens) individual apps. Block a whole category instead, like Social.", action: .chooseApps)
        }
        return nil
    }

    private func startSession(with tag: EnrolledTag?, source: SessionSource) {
        if let problem = startProblem() {
            alert = problem
            return
        }
        blocker.apply(config)
        let newSession = FocusSession(id: UUID(), startedAt: Date(), source: source, startTagID: tag?.id)
        session = newSession
        store.activeSession = newSession
        LiveActivityController.sync(session: newSession, passExpiresAt: nil)
        WidgetSync.reload()
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
        defer { WidgetSync.reload() }
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
        WidgetSync.reload()
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
            alert = AppAlert(title: "Unknown tag", message: "That sticker isn't registered on this iPhone. Add it in Settings → Tags.")
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
            alert = scanAlert(for: error)
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
            alert = AppAlert(title: "Night lock too short", message: "Night lock needs to start at least 15 minutes before your wake time.")
            return
        }
        if newRoutine.wakeEnabled, !(await WakeAlarms.authorize()) {
            alert = AppAlert(title: "Alarms are off", message: "Allow Tawfeeq to ring alarms in Settings → Tawfeeq → Alarms.", action: .openSettings)
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
            alert = AppAlert(title: "Alarms are off", message: "Allow Tawfeeq to ring alarms in Settings → Tawfeeq → Alarms.", action: .openSettings)
            return
        }
        await WakeAlarms.scheduleTest()
        alert = AppAlert(title: "Test alarm set", message: "It rings in about 30 seconds. Lock your phone to see it full screen.")
    }

    // MARK: - Stats

    /// Adds today's progress and one specific, positive observation.
    private func enrich(_ summary: SessionSummary, now: Date = Date()) -> SessionSummary {
        var summary = summary
        summary.enriched = true
        refreshStats(now: now)
        let stats = statsCache
        summary.todayFocus = todayStats(now: now).focusSeconds
        summary.goal = TimeInterval(dailyGoalMinutes * 60)
        let lastWeek = stats?.days.suffix(7) ?? []
        if summary.checkedIn != nil {
            summary.observation = summary.duration > 0 ? "Your phone rested \(Formatting.duration(summary.duration))." : nil
        } else if !summary.wasNightLock {
            if summary.duration >= 20 * 60, summary.duration >= (stats?.longestSession ?? 0) - 1 {
                summary.observation = "Your longest session this month."
            } else if summary.todayFocus >= summary.goal, summary.todayFocus - summary.duration < summary.goal {
                summary.observation = "That's your goal for today. Lovely."
            } else if (stats?.currentStreak ?? 0) >= 2 {
                summary.observation = "\(stats?.currentStreak ?? 0) days in a row."
            } else if summary.passes == 0 {
                summary.observation = "No passes. Steady."
            } else if lastWeek.filter({ $0.focusSeconds > 0 }).count >= 4 {
                summary.observation = "You've focused on \(lastWeek.filter { $0.focusSeconds > 0 }.count) of the last 7 days."
            }
        }
        return summary
    }

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

    /// Days in the last 28 that met the goal ("rhythm"), a gentler framing than a streak.
    var rhythm: (met: Int, of: Int) {
        let days = statsCache?.days.suffix(28) ?? []
        let goal = TimeInterval(dailyGoalMinutes * 60)
        return (days.filter { $0.focusSeconds >= goal }.count, max(days.count, 1))
    }

    var currentPassIntention: PassIntention? {
        isDemo ? .navigation : store.passIntention.flatMap(PassIntention.init(rawValue:))
    }

    /// Whether the user has ever focused (first-run home shows no ring).
    var hasHistory: Bool { (statsCache?.totalFocus ?? 0) > 0 || session != nil }

    /// "14 apps", "14 apps and 3 categories", "all but 5 apps"
    var blockedSummary: String {
        if isDemo { return demoBlockedApps == 0 ? "Nothing is" : "\(demoBlockedApps) apps are" }
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
            events: demoEvents ?? EventLog.all(),
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
