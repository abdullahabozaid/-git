import ActivityKit
import Foundation

/// Live Activity shown on the Lock Screen and in the Dynamic Island during a session.
struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Mode: String, Codable, Hashable {
            case focusing
            case pass
            case nightLock
        }

        var mode: Mode
        var startedAt: Date
        var passEndsAt: Date?
    }

    var title: String
}
