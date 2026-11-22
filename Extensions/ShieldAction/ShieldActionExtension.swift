import ManagedSettings

/// Handles the buttons on the block screen.
/// Primary ("Close") closes the app. Secondary starts a 5-minute pass.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(respond(to: action))
    }

    private func respond(to action: ShieldAction) -> ShieldActionResponse {
        switch action {
        case .primaryButtonPressed:
            SharedStore.shared.shieldPassRequestedAt = nil
            return .close
        case .secondaryButtonPressed:
            // Two taps: the first starts a breathing wait (shown on the shield),
            // the second unlocks once the wait is over. `.defer` re-renders the shield.
            let store = SharedStore.shared
            let now = Date()
            let wait = TimeInterval(PassManager.waitSeconds(passesToday: PassManager.recent(now: now).today))
            guard let requested = store.shieldPassRequestedAt,
                  now.timeIntervalSince(requested) < ShieldPassFlow.requestValidity else {
                store.shieldPassRequestedAt = now
                return .defer
            }
            guard now.timeIntervalSince(requested) >= wait else {
                return .defer // too early: shield shows the remaining wait
            }
            do {
                try PassManager.start(source: "shield", now: now)
                return .defer // shield lifted, so the app opens
            } catch {
                store.shieldPassRequestedAt = nil
                return .close
            }
        default:
            // iOS 26 submenu items etc. aren't used by Tawfeeq.
            return .close
        }
    }
}
