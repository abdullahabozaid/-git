import Foundation
import FamilyControls

/// What an enrolled NFC tag is allowed to do.
enum TagRole: String, Codable, CaseIterable, Identifiable {
    /// Lives on the desk. Starts and ends sessions.
    case desk
    /// Backup kept somewhere else (drawer, car). Can also end a session.
    case spare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .desk: "Desk tag"
        case .spare: "Spare tag"
        }
    }

    var symbol: String {
        switch self {
        case .desk: "desktopcomputer"
        case .spare: "key.fill"
        }
    }
}

struct EnrolledTag: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var role: TagRole
    /// Hardware UID as lowercase hex. NTAG UIDs are fixed, so this is what we match on.
    var uid: String
    /// Random 128-bit hex string written into the tag's URL (https://tawfeeq.uk/t/<secret>).
    var secret: String
    /// Whether the URL was successfully written to the tag.
    var hasLink: Bool
    var enrolledAt: Date

    func matches(uid other: String) -> Bool {
        uid.caseInsensitiveCompare(other) == .orderedSame
    }
}

enum BlockMode: String, Codable, CaseIterable, Identifiable {
    /// Block the apps/categories picked in `blocked`, except anything in `allowed`.
    case selected
    /// Block everything except the apps in `allowed`.
    case everythingExceptAllowed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .selected: "Apps I pick"
        case .everythingExceptAllowed: "Everything except allowed"
        }
    }
}

struct BlockConfig: Codable, Equatable {
    var mode: BlockMode = .selected
    var blocked = FamilyActivitySelection()
    var allowed = FamilyActivitySelection()
    /// Prevent deleting apps (including Tawfeeq) while a session runs.
    var preventAppRemoval = true

    /// iOS silently shields nothing if a store gets more than 50 app tokens.
    static let maxAppTokens = 50

    var hasAnythingToBlock: Bool {
        switch mode {
        case .selected:
            !blocked.applicationTokens.isEmpty || !blocked.categoryTokens.isEmpty || !blocked.webDomainTokens.isEmpty
        case .everythingExceptAllowed:
            true
        }
    }

    var exceedsAppLimit: Bool {
        blocked.applicationTokens.count > Self.maxAppTokens
            || allowed.applicationTokens.count > Self.maxAppTokens
    }
}

enum SessionSource: String, Codable {
    case tagScan
    case tagLink
    case shortcut
}

struct FocusSession: Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var source: SessionSource
    var startTagID: UUID?
}
