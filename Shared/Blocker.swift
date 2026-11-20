import Foundation
import ManagedSettings

/// Applies and removes shields. Used by the app now, and by the
/// DeviceActivity extensions in later phases (passes, schedules).
struct Blocker {
    private let store = ManagedSettingsStore(named: .focus)

    func apply(_ config: BlockConfig) {
        let allowedApps = config.allowed.applicationTokens

        switch config.mode {
        case .selected:
            let apps = config.blocked.applicationTokens.subtracting(allowedApps)
            store.shield.applications = apps.isEmpty ? nil : apps

            let categories = config.blocked.categoryTokens
            store.shield.applicationCategories = categories.isEmpty
                ? nil
                : .specific(categories, except: allowedApps)

            let domains = config.blocked.webDomainTokens
            store.shield.webDomains = domains.isEmpty ? nil : domains

        case .everythingExceptAllowed:
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: allowedApps)
            store.shield.webDomains = nil
        }

        store.application.denyAppRemoval = config.preventAppRemoval ? true : nil
    }

    func clear() {
        // Nil each setting explicitly before clearAllSettings(); some iOS versions
        // have left shields stuck when only clearAllSettings() was called.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.application.denyAppRemoval = nil
        store.clearAllSettings()
    }

    var isShielding: Bool {
        store.shield.applications != nil
            || store.shield.applicationCategories != nil
            || store.shield.webDomains != nil
    }
}
