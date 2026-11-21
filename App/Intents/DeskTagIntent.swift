import AppIntents

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
        AppModel.shared.handleDeskTagShortcut()
        return .result()
    }
}

struct TawfeeqShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DeskTagTappedIntent(),
            phrases: [
                "Desk tag tapped in \(.applicationName)",
                "Toggle focus in \(.applicationName)",
            ],
            shortTitle: "Desk Tag Tapped",
            systemImageName: "wave.3.right"
        )
    }
}
