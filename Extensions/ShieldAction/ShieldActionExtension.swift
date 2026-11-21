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
            return .close
        case .secondaryButtonPressed:
            do {
                try PassManager.start(source: "shield")
                // .defer re-evaluates the shield; since it's lifted, the app opens.
                return .defer
            } catch {
                return .close
            }
        @unknown default:
            return .close
        }
    }
}
