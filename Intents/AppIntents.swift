import AppIntents
import Foundation

// Compiled into both the app and the Widgets extension. Intents with
// `openAppWhenRun = true` run in the app process, where TAWFEEQ_APP is defined.

/// For a Shortcuts personal automation: "When NFC tag *Desk* is scanned → Desk Tag Tapped".
/// Not focusing → starts a session. Focusing → opens the scan sheet (ending needs the real tag).
struct DeskTagTappedIntent: AppIntent {
    static var title: LocalizedStringResource = "Desk Tag Tapped"
    static var description = IntentDescription(
        "Starts a focus session, or opens Tawfeeq to scan your desk tag if you're already focusing. Use it in a Shortcuts NFC automation on your desk tag."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if TAWFEEQ_APP
        AppModel.shared.handleDeskTagShortcut()
        #endif
        return .result()
    }
}

/// Control Center / Lock Screen / Action button / widget: start focusing. Starting is
/// allowed remotely; ending always needs the desk tag.
struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus"
    static var description = IntentDescription("Starts a Tawfeeq focus session. Ending it needs your desk tag.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if TAWFEEQ_APP
        AppModel.shared.startFromControl()
        #endif
        return .result()
    }
}

/// Opens Tawfeeq straight into the desk-tag scan.
struct ScanDeskTagIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan Desk Tag"
    static var description = IntentDescription("Opens Tawfeeq and scans your desk tag to start, end or check in.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        #if TAWFEEQ_APP
        AppModel.shared.handleWakeScanRequest()
        #endif
        return .result()
    }
}

/// Live Activity button during a pass: end the pass and re-block now.
struct ReturnFromPassIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Return Now"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        PassManager.end(reason: "returnedFromLiveActivity")
        return .result()
    }
}

#if TAWFEEQ_APP
struct TawfeeqShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start focus with \(.applicationName)",
                "Start \(.applicationName)",
            ],
            shortTitle: "Start Focus",
            systemImageName: "circle.circle.fill"
        )
        AppShortcut(
            intent: ScanDeskTagIntent(),
            phrases: ["Scan my desk tag in \(.applicationName)"],
            shortTitle: "Scan Desk Tag",
            systemImageName: "wave.3.right"
        )
        AppShortcut(
            intent: DeskTagTappedIntent(),
            phrases: ["Desk tag tapped in \(.applicationName)"],
            shortTitle: "Desk Tag Tapped",
            systemImageName: "wave.3.right.circle"
        )
    }
}
#endif
