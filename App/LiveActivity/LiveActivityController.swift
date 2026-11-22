import ActivityKit
import Foundation

/// Keeps one Live Activity in sync with the current session / pass.
@MainActor
enum LiveActivityController {
    static func sync(session: FocusSession?, passExpiresAt: Date?, now: Date = Date()) {
        let activities = Activity<FocusActivityAttributes>.activities

        guard let session else {
            for activity in activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let onPass = (passExpiresAt ?? .distantPast) > now
        let mode: FocusActivityAttributes.ContentState.Mode =
            onPass ? .pass : (session.source == .nightLock ? .nightLock : .focusing)
        let state = FocusActivityAttributes.ContentState(
            mode: mode,
            startedAt: session.startedAt,
            passEndsAt: onPass ? passExpiresAt : nil
        )
        let content = ActivityContent(state: state, staleDate: onPass ? passExpiresAt : nil)

        if let activity = activities.first {
            if activity.content.state != state {
                Task { await activity.update(content) }
            }
            for extra in activities.dropFirst() {
                Task { await extra.end(nil, dismissalPolicy: .immediate) }
            }
        } else {
            _ = try? Activity.request(
                attributes: FocusActivityAttributes(title: "Tawfeeq"),
                content: content,
                pushType: nil
            )
        }
    }
}
