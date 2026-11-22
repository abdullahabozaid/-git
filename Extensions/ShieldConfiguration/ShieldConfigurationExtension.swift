import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown instead of a blocked app. Calm, rotating copy with the app's name,
/// the pass count, and the two-tap breathing flow for passes.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    private static let messages: [(String, String)] = [
        ("Not now", "{App} will keep."),
        ("Steady", "One more step on what matters, then decide."),
        ("Breathe", "Was that a choice, or a reflex?"),
        ("Still here", "Your focus is worth more than {App} right now."),
        ("Be present", "{App} can wait. This moment can't."),
    ]

    private func make(name: String?) -> ShieldConfiguration {
        let store = SharedStore.shared
        let now = Date()
        let app = name ?? "This app"
        let isNight = store.activeSession?.source == .nightLock
        let recent = PassManager.recent(now: now)
        let wait = TimeInterval(PassManager.waitSeconds(passesToday: recent.today))

        var title: String
        var subtitle: String
        var subtitleColor = UIColor.white.withAlphaComponent(0.8)
        var passLabel = "Take a 5-minute pass"

        if let requested = store.shieldPassRequestedAt, now.timeIntervalSince(requested) < ShieldPassFlow.requestValidity {
            // Step 2 of a pass: breathing wait.
            let remaining = Int(ceil(wait - now.timeIntervalSince(requested)))
            title = "Breathe"
            if remaining > 0 {
                subtitle = "Take \(remaining) slow second\(remaining == 1 ? "" : "s"). Then tap below if you still want \(app)."
                passLabel = "Unlock in \(remaining)s"
            } else {
                subtitle = "Still want \(app)? It unlocks for 5 minutes, then rests again."
                passLabel = "Unlock for 5 minutes"
            }
        } else if isNight {
            title = "Resting"
            subtitle = "\(app) is resting for the night.\nTap your desk tag in the morning."
        } else {
            let index = (Calendar.current.component(.minute, from: now) / 2) % Self.messages.count
            let message = Self.messages[index]
            title = message.0
            subtitle = message.1.replacingOccurrences(of: "{App}", with: app)
            if let session = store.activeSession {
                subtitle += "\nFocusing since \(session.startedAt.formatted(date: .omitted, time: .shortened))."
            }
        }

        if store.shieldPassRequestedAt == nil {
            if recent.inLast30Minutes >= 2 {
                subtitle += "\n\nThat would be pass #\(recent.inLast30Minutes + 1) in 30 minutes. Still worth it?"
                subtitleColor = Theme.uiPass
            } else if recent.today > 0, let last = recent.lastStartedAt {
                let minutes = Int(now.timeIntervalSince(last) / 60)
                subtitle += "\n\nPass #\(recent.today + 1) today · last one \(minutes)m ago."
            }
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: isNight ? Theme.uiNight.withAlphaComponent(0.9) : Theme.uiFocus.withAlphaComponent(0.9),
            icon: UIImage(systemName: isNight ? "moon.stars.fill" : "leaf.fill"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: subtitleColor),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Return", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: passLabel, color: .white)
        )
    }
}
