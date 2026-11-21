import Foundation

/// Persistent state in the App Group, readable by the app and its extensions.
final class SharedStore {
    static let shared = SharedStore()

    private enum Key {
        static let blockConfig = "blockConfig"
        static let tags = "tags"
        static let activeSession = "activeSession"
        static let lastKnownAuthorized = "lastKnownAuthorized"
        static let passExpiresAt = "passExpiresAt"
        static let lastPassEndedAt = "lastPassEndedAt"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    var blockConfig: BlockConfig {
        get { load(Key.blockConfig) ?? BlockConfig() }
        set { save(newValue, Key.blockConfig) }
    }

    var tags: [EnrolledTag] {
        get { load(Key.tags) ?? [] }
        set { save(newValue, Key.tags) }
    }

    var activeSession: FocusSession? {
        get { load(Key.activeSession) }
        set { save(newValue, Key.activeSession) }
    }

    var lastKnownAuthorized: Bool {
        get { defaults.bool(forKey: Key.lastKnownAuthorized) }
        set { defaults.set(newValue, forKey: Key.lastKnownAuthorized) }
    }

    /// Set while a temporary pass is running.
    var passExpiresAt: Date? {
        get { defaults.object(forKey: Key.passExpiresAt) as? Date }
        set { defaults.set(newValue, forKey: Key.passExpiresAt) }
    }

    var lastPassEndedAt: Date? {
        get { defaults.object(forKey: Key.lastPassEndedAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastPassEndedAt) }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
