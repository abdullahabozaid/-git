import Foundation
import ManagedSettings

/// Identifiers shared by the app and all of its extensions.
enum AppGroup {
    static let id = "group.uk.tawfeeq"
    static let linkHost = "tawfeeq.uk"

    static var defaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: id) else {
            fatalError("App Group \(id) is missing. Check the target's entitlements.")
        }
        return defaults
    }

    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else {
            #if DEBUG
            return FileManager.default.temporaryDirectory // e.g. an unsigned simulator build
            #else
            fatalError("App Group \(id) container is unavailable. Check the target's entitlements.")
            #endif
        }
        return url
    }
}

extension ManagedSettingsStore.Name {
    /// The one store Tawfeeq writes shields into. Ending a session clears all of it.
    static let focus = Self("uk.tawfeeq.focus")
}
