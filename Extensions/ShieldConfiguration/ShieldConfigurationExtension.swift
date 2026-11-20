import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown instead of a blocked app.
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

    private func make(name: String?) -> ShieldConfiguration {
        var subtitle = "\(name ?? "This app") is blocked while you focus."
        if let session = SharedStore.shared.activeSession {
            subtitle += "\nFocusing since \(session.startedAt.formatted(date: .omitted, time: .shortened))."
        }
        subtitle += "\nTap your desk tag to end the session."

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.12, blue: 0.10, alpha: 1),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Tawfeeq", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor.white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }
}
