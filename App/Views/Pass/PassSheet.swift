import SwiftUI

/// Honest friction before a pass: see the count, pick an intention, breathe, then unlock.
/// Unlimited, but each pass is conscious, logged, and slower than the last (5 s → 15 s → 30 s).
struct PassSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recent = PassManager.RecentPasses()
    @State private var intention: PassIntention?
    @State private var breathingEndsAt: Date?
    @State private var breatheIn = false

    var body: some View {
        VStack(spacing: 20) {
            if let endsAt = breathingEndsAt {
                breathing(endsAt: endsAt)
            } else {
                choose
            }
        }
        .padding(24)
        .onAppear { recent = PassManager.recent() }
    }

    // MARK: Step 1: count + intention

    private var choose: some View {
        VStack(spacing: 18) {
            Image(systemName: "hourglass")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.pass)
            Text("Take a 5-minute pass?")
                .font(.title2.bold())

            countLine

            VStack(alignment: .leading, spacing: 10) {
                Text("What's it for?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PassIntention.allCases) { option in
                        let selected = intention == option
                        Button {
                            intention = option
                        } label: {
                            Label(option.label, systemImage: option.symbol)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(selected ? Color.white : Theme.text)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selected ? Theme.pass : Theme.surface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let wait = PassManager.waitSeconds(passesToday: recent.today)
            Button {
                breathingEndsAt = Date().addingTimeInterval(TimeInterval(wait))
            } label: {
                Text("Breathe for \(wait) seconds first")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.pass)
            .controlSize(.large)
            .disabled(intention == nil)

            Button("Never mind, keep focusing") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private var countLine: some View {
        let next = recent.today + 1
        if recent.inLast30Minutes >= 2 {
            Label("That would be your \(Formatting.ordinal(recent.inLast30Minutes + 1)) pass in 30 minutes. Still worth it?",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.pass)
                .multilineTextAlignment(.center)
        } else if let last = recent.lastStartedAt, Calendar.current.isDateInToday(last) {
            Text("Pass #\(next) today · last one \(Formatting.duration(Date().timeIntervalSince(last))) ago")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        } else {
            Text("Your first pass today. Apps unlock for 5 minutes, then lock again on their own.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Step 2: breathe (can't be skipped), then unlock

    private func breathing(endsAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(ceil(endsAt.timeIntervalSince(context.date))))
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Theme.pass.opacity(0.15))
                        .scaleEffect(reduceMotion ? 1 : (breatheIn ? 1.0 : 0.65))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true), value: breatheIn)
                    Text(remaining > 0 ? "\(remaining)" : "✓")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(Theme.pass)
                }
                .frame(width: 200, height: 200)
                .onAppear { breatheIn = true }

                Text(remaining > 0 ? (breatheIn ? "Breathe in… and out." : "Breathe.") : "Still want it?")
                    .font(.title3.weight(.semibold))

                Button {
                    model.takePass(intention: intention)
                    dismiss()
                } label: {
                    Text("Unlock for 5 minutes")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.pass)
                .controlSize(.large)
                .disabled(remaining > 0)

                Button("Keep focusing instead") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
