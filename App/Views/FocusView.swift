import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmPass = false

    /// Re-checks state every few seconds while visible: picks up passes started from the
    /// block screen and re-blocks promptly if a pass expired but the extension didn't fire.
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 12) {
                        statusCircle(now: context.date)
                        Text("Focused today: \(Self.format(model.focusedToday(now: context.date)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if model.passSummary.passes > 0 {
                            passSummaryLabel
                        }
                    }
                }

                Spacer()

                hint

                VStack(spacing: 12) {
                    Button {
                        Task { await model.scanToToggle() }
                    } label: {
                        Label(mainButtonTitle, systemImage: "wave.3.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.isScanning)

                    if model.isFocusing {
                        if model.isOnPass() {
                            Button("Re-block now") { model.endPassEarly() }
                                .controlSize(.large)
                        } else {
                            Button("Take a 5-minute pass") { confirmPass = true }
                                .controlSize(.large)
                        }
                    }
                }
            }
            .padding(24)
            .navigationTitle("Tawfeeq")
            .onReceive(ticker) { _ in model.reconcile() }
            .confirmationDialog("Take a 5-minute pass?", isPresented: $confirmPass, titleVisibility: .visible) {
                Button("Unblock for 5 minutes") { model.takePass() }
            } message: {
                Text("Your apps unblock for 5 minutes, then lock again automatically. Passes are logged in your stats.")
            }
        }
    }

    @ViewBuilder
    private func statusCircle(now: Date) -> some View {
        let onPass = model.isOnPass(now: now)
        let tint: Color = onPass ? .orange : (model.isFocusing ? .accentColor : .secondary)

        ZStack {
            Circle()
                .fill(tint.opacity(model.isFocusing ? 0.15 : 0.1))
                .frame(width: 220, height: 220)
            VStack(spacing: 8) {
                Image(systemName: onPass ? "hourglass" : (model.isFocusing ? "lock.fill" : "lock.open"))
                    .font(.system(size: 44, weight: .semibold))
                if onPass, let expiresAt = model.passExpiresAt {
                    Text(Self.format(expiresAt.timeIntervalSince(now)))
                        .font(.system(.title, design: .rounded).monospacedDigit().bold())
                    Text("pass left").font(.caption)
                } else if let session = model.session {
                    Text(Self.format(now.timeIntervalSince(session.startedAt)))
                        .font(.system(.title, design: .rounded).monospacedDigit().bold())
                    if session.source == .nightLock {
                        Text("night lock").font(.caption)
                    }
                } else {
                    Text("Not focusing")
                        .font(.title3.weight(.semibold))
                }
            }
            .foregroundStyle(tint)
        }
    }

    private var passSummaryLabel: some View {
        let summary = model.passSummary
        var text = "\(summary.passes) pass\(summary.passes == 1 ? "" : "es") today"
        if summary.backToBack > 0 { text += " · \(summary.backToBack) back-to-back" }
        return Label(text, systemImage: summary.backToBack > 0 ? "exclamationmark.triangle.fill" : "hourglass")
            .font(.footnote)
            .foregroundStyle(summary.backToBack > 0 ? Color.orange : Color.secondary)
    }

    private var mainButtonTitle: String {
        if model.pendingWake != nil { return "Tap desk tag to check in" }
        return model.isFocusing ? "Tap desk tag to end" : "Tap desk tag to start"
    }

    @ViewBuilder
    private var hint: some View {
        if model.pendingWake != nil {
            Label("Good morning. Tap your desk tag to check in and silence your alarm.", systemImage: "sun.max.fill")
                .font(.footnote)
                .foregroundStyle(.orange)
        } else if model.tags.isEmpty {
            Label("Add your desk tag in the Tags tab to get started.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if !model.config.hasAnythingToBlock {
            Label("Pick apps to block in the Block list tab.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, Int(seconds))).formatted(.time(pattern: .hourMinuteSecond))
    }
}
