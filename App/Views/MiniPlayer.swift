import SwiftUI

/// iOS 26 tab-bar accessory: the live session on every tab.
struct MiniPlayer: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = model.homeState(now: context.date)
            HStack(spacing: 10) {
                Image(systemName: symbol(state))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(state.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title(state))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if placement != .inline, let detail = detail(state) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if let timer = timer(state, now: context.date) {
                    Text(timer)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                        .foregroundStyle(state.tint)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func symbol(_ state: HomeState) -> String {
        switch state.kind {
        case .idle: "wave.3.right"
        case .focusing: "lock.fill"
        case .pass: "hourglass"
        case .night: "moon.stars.fill"
        case .morning: "sunrise.fill"
        }
    }

    private func title(_ state: HomeState) -> String {
        switch state.kind {
        case .idle: "Ready"
        default: state.title
        }
    }

    private func detail(_ state: HomeState) -> String? {
        switch state.kind {
        case .idle: model.nextEventDescription ?? "Tap your desk tag to begin"
        case .focusing: "Tap your desk tag to finish"
        case .pass: "Apps lock again soon"
        case .night: "Until your morning check-in"
        case .morning: "Tap your desk tag to check in"
        }
    }

    private func timer(_ state: HomeState, now: Date) -> String? {
        switch state {
        case .idle, .morning: nil
        case .focusing(let start), .night(let start): Formatting.clock(now.timeIntervalSince(start))
        case .pass(let end): Formatting.clock(max(0, end.timeIntervalSince(now)))
        }
    }
}
