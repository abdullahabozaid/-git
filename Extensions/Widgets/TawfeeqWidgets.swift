import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TawfeeqWidgets: WidgetBundle {
    var body: some Widget {
        FocusLiveActivity()
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenFocusView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(state.title, systemImage: state.symbol)
                        .font(.headline)
                        .foregroundStyle(state.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: state)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(state.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: state.symbol).foregroundStyle(state.tint)
            } compactTrailing: {
                TimerText(state: state)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
                    .foregroundStyle(state.tint)
            } minimal: {
                Image(systemName: state.symbol).foregroundStyle(state.tint)
            }
        }
    }
}

private struct LockScreenFocusView: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(state.tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(state.tint.opacity(0.2)))
            VStack(alignment: .leading, spacing: 2) {
                Text(state.title).font(.headline)
                Text(state.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            TimerText(state: state)
                .font(.title2.monospacedDigit().weight(.semibold))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(16)
    }
}

private struct TimerText: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        if state.mode == .pass, let end = state.passEndsAt, end > Date() {
            Text(timerInterval: Date()...end, countsDown: true)
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

extension FocusActivityAttributes.ContentState {
    var title: String {
        switch mode {
        case .focusing: "Focusing"
        case .pass: "On a pass"
        case .nightLock: "Night lock"
        }
    }

    var subtitle: String {
        switch mode {
        case .focusing: "Tap your desk tag to end"
        case .pass: "Apps lock again when this runs out"
        case .nightLock: "Tap your desk tag in the morning"
        }
    }

    var symbol: String {
        switch mode {
        case .focusing: "lock.fill"
        case .pass: "hourglass"
        case .nightLock: "moon.fill"
        }
    }

    var tint: Color {
        switch mode {
        case .focusing: Color(red: 0.36, green: 0.80, blue: 0.62)
        case .pass: .orange
        case .nightLock: Color(red: 0.55, green: 0.58, blue: 0.95)
        }
    }
}
