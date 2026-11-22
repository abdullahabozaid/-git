import SwiftUI

/// Escape hatch for a lost/broken tag: crack the glass (3 taps), then slide to end. Logged.
struct LostTagView: View {
    @EnvironmentObject private var model: AppModel
    @State private var cracks = 0

    var body: some View {
        List {
            Section {
                HelpRow(number: 1, title: "Use your spare tag",
                        text: "A spare tag can end any session. Add one in Settings → Tags and keep it somewhere away from your desk.")
                HelpRow(number: 2, title: "Take a 5-minute pass",
                        text: "From the block screen or the Focus tab. Apps lock again on their own.")
                HelpRow(number: 3, title: "Break the glass",
                        text: "Ends the session without a tag. It's always available, and always recorded in your history.")
            } header: {
                Text("If your desk tag is lost or broken")
            }

            if model.isFocusing {
                Section {
                    VStack(spacing: 18) {
                        BreakGlass(cracks: $cracks)
                        if cracks >= 3 {
                            SlideToConfirm(title: "Slide to end without tag", tint: Theme.pass) {
                                model.endSessionWithoutTag()
                                cracks = 0
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 8)
                    .animation(.spring, value: cracks)
                } footer: {
                    Text("This will show as \"ended without tag\" in Insights.")
                }
            }
        }
        .navigationTitle("Lost your tag?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpRow: View {
    let number: Int
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.focus))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Tap three times to crack the glass. Each tap adds cracks and a light haptic.
private struct BreakGlass: View {
    @EnvironmentObject private var model: AppModel
    @Binding var cracks: Int

    var body: some View {
        Button {
            if cracks < 3 { cracks += 1 }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.pass.opacity(0.5), lineWidth: 2))
                CrackShape(level: cracks)
                    .stroke(Theme.text.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                VStack(spacing: 6) {
                    Image(systemName: cracks >= 3 ? "exclamationmark.triangle.fill" : "hammer.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.pass)
                    Text(cracks >= 3 ? "Glass broken" : "Tap \(3 - cracks) more time\(3 - cracks == 1 ? "" : "s") to break")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                }
            }
            .frame(height: 120)
        }
        .buttonStyle(.plain)
        .disabled(cracks >= 3)
        .sensoryFeedback(trigger: cracks) { _, new in
            guard model.hapticsEnabled else { return nil }
            return new >= 3 ? .success : .impact(weight: .light)
        }
    }
}

private struct CrackShape: Shape {
    let level: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.1)
        let rays: [(CGFloat, CGFloat)] = [(0.1, 0.9), (1.2, 0.8), (2.3, 1.0), (3.3, 0.7), (4.4, 0.95), (5.4, 0.75)]
        let count = min(rays.count, level * 2)
        for (angle, length) in rays.prefix(count) {
            path.move(to: center)
            let mid = CGPoint(x: center.x + cos(angle + 0.15) * rect.width * 0.18 * length,
                              y: center.y + sin(angle + 0.15) * rect.height * 0.35 * length)
            let end = CGPoint(x: center.x + cos(angle) * rect.width * 0.38 * length,
                              y: center.y + sin(angle) * rect.height * 0.7 * length)
            path.addLine(to: mid)
            path.addLine(to: end)
        }
        return path
    }
}

/// Apple Clock-style slider for destructive actions.
struct SlideToConfirm: View {
    let title: String
    let tint: Color
    let action: () -> Void

    @State private var offset: CGFloat = 0
    private let knob: CGFloat = 52

    var body: some View {
        GeometryReader { proxy in
            let maxOffset = proxy.size.width - knob - 8
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(offset / max(maxOffset, 1)))
                Circle()
                    .fill(tint)
                    .overlay(Image(systemName: "chevron.right.2").foregroundStyle(.white).font(.headline))
                    .frame(width: knob, height: knob)
                    .offset(x: 4 + offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in offset = min(max(0, value.translation.width), maxOffset) }
                            .onEnded { _ in
                                if offset >= maxOffset * 0.92 {
                                    action()
                                }
                                withAnimation(.spring) { offset = 0 }
                            }
                    )
            }
        }
        .frame(height: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}
