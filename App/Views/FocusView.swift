import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(model.isFocusing ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                                .frame(width: 220, height: 220)
                            VStack(spacing: 8) {
                                Image(systemName: model.isFocusing ? "lock.fill" : "lock.open")
                                    .font(.system(size: 44, weight: .semibold))
                                if let session = model.session {
                                    Text(Self.format(context.date.timeIntervalSince(session.startedAt)))
                                        .font(.system(.title, design: .rounded).monospacedDigit().bold())
                                } else {
                                    Text("Not focusing")
                                        .font(.title3.weight(.semibold))
                                }
                            }
                            .foregroundStyle(model.isFocusing ? Color.accentColor : .secondary)
                        }
                        Text("Focused today: \(Self.format(model.focusedToday(now: context.date)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if model.tags.isEmpty {
                    Label("Add your desk tag in the Tags tab to get started.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !model.config.hasAnythingToBlock {
                    Label("Pick apps to block in the Block list tab.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await model.scanToToggle() }
                } label: {
                    Label(model.isFocusing ? "Tap desk tag to end" : "Tap desk tag to start",
                          systemImage: "wave.3.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isScanning)
            }
            .padding(24)
            .navigationTitle("Tawfeeq")
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(max(0, Int(seconds))).formatted(.time(pattern: .hourMinuteSecond))
    }
}
