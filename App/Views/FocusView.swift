import SwiftUI

/// Home. Changes completely by state: idle, focusing, pass, night lock, morning check-in.
struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPassSheet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Re-checks state every few seconds while visible: picks up passes started from the
    /// block screen and re-blocks promptly if a pass expired but the extension didn't fire.
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = model.homeState(now: context.date)
            ZStack {
                StateBackground(state: state)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    header(state)
                    Spacer(minLength: 8)
                    StateDial(state: state, now: context.date, wakeTime: model.routine.wakeTime)
                    Spacer(minLength: 8)
                    TodayStrip(now: context.date)
                    nextEvent(state)
                    actions(state)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.6), value: state.kind)
        }
        .onReceive(ticker) { _ in model.reconcile() }
        .sheet(isPresented: $showPassSheet) {
            PassSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $model.lastSummary) { summary in
            SessionSummarySheet(summary: summary)
                .presentationDetents([.medium])
        }
        .sensoryFeedback(.success, trigger: model.successTick) { _, _ in model.hapticsEnabled }
        .sensoryFeedback(.warning, trigger: model.warningTick) { _, _ in model.hapticsEnabled }
    }

    // MARK: - Pieces

    private func header(_ state: HomeState) -> some View {
        VStack(spacing: 4) {
            Text(state.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(state.isDark ? Color.white : Theme.text)
            Text(state.subtitle(appCount: model.blockedSummary))
                .font(.subheadline)
                .foregroundStyle(state.isDark ? Color.white.opacity(0.7) : Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func nextEvent(_ state: HomeState) -> some View {
        if let next = model.nextEventDescription, state == .idle {
            Label(next, systemImage: "clock")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder
    private func actions(_ state: HomeState) -> some View {
        VStack(spacing: 12) {
            switch state {
            case .idle:
                ScanButton(title: model.tags.isEmpty ? "Add your desk tag in Settings" : "Scan desk tag to begin",
                           tint: Theme.focus)
                    .disabled(model.tags.isEmpty)
                HoldToStartButton()
            case .focusing:
                ScanButton(title: "Scan desk tag to finish", tint: Theme.focus)
                Button("Take a 5-minute pass") { showPassSheet = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            case .pass:
                Button {
                    model.endPassEarly()
                } label: {
                    Label("Return now", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.pass)
                .controlSize(.large)
            case .night:
                ScanButton(title: "Scan desk tag to unlock", tint: Theme.night)
                Button("Take a 5-minute pass") { showPassSheet = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            case .morning:
                ScanButton(title: "Scan desk tag to check in", tint: Theme.gold)
            }
        }
    }
}

// MARK: - State presentation

extension HomeState {
    enum Kind { case idle, focusing, pass, night, morning }

    var kind: Kind {
        switch self {
        case .idle: .idle
        case .focusing: .focusing
        case .pass: .pass
        case .night: .night
        case .morning: .morning
        }
    }

    var isDark: Bool { kind == .night }

    var tint: Color {
        switch kind {
        case .idle, .focusing: Theme.focus
        case .pass: Theme.pass
        case .night: Theme.night
        case .morning: Theme.gold
        }
    }

    var title: String {
        switch kind {
        case .idle: "Ready when you are"
        case .focusing: "Focusing"
        case .pass: "On a pass"
        case .night: "Night lock"
        case .morning: "Good morning"
        }
    }

    func subtitle(appCount: String) -> String {
        switch kind {
        case .idle: "Tap your desk tag to begin."
        case .focusing: "\(appCount) resting."
        case .pass: "Apps lock again when the timer runs out."
        case .night: "Resting until your morning check-in."
        case .morning: "Tap your desk tag to begin the day."
        }
    }
}

private struct StateBackground: View {
    let state: HomeState

    var body: some View {
        switch state.kind {
        case .idle:
            Theme.background
        case .focusing:
            LinearGradient(colors: [Theme.focus.opacity(0.22), Theme.background], startPoint: .top, endPoint: .bottom)
        case .pass:
            LinearGradient(colors: [Theme.pass.opacity(0.22), Theme.background], startPoint: .top, endPoint: .bottom)
        case .night:
            LinearGradient(colors: [Color(red: 0.06, green: 0.07, blue: 0.13), Color(red: 0.11, green: 0.13, blue: 0.24)],
                           startPoint: .top, endPoint: .bottom)
        case .morning:
            LinearGradient(colors: [Theme.gold.opacity(0.35), Theme.pass.opacity(0.12), Theme.background],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

/// The big circle in the middle: tag glyph, elapsed timer, pass ring, moon or sun.
private struct StateDial: View {
    let state: HomeState
    let now: Date
    let wakeTime: TimeOfDay

    var body: some View {
        ZStack {
            Circle()
                .fill(state.tint.opacity(state.isDark ? 0.18 : 0.10))
            Circle()
                .stroke(state.tint.opacity(0.25), lineWidth: 2)

            if case .pass(let endsAt) = state {
                let remaining = max(0, endsAt.timeIntervalSince(now))
                Circle()
                    .trim(from: 0, to: remaining / PassManager.duration)
                    .stroke(state.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(4)
                    .opacity(remaining < 10 ? 0.6 + 0.4 * abs(sin(now.timeIntervalSince1970 * 2)) : 1)
            }

            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: state.kind == .idle ? 64 : 30, weight: .semibold))
                    .foregroundStyle(state.tint)
                    .symbolEffect(.pulse, isActive: state.kind == .idle || state.kind == .morning)
                if let big = bigText {
                    Text(big)
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: state.kind == .pass))
                        .foregroundStyle(state.isDark ? Color.white : Theme.text)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                if let small = smallText {
                    Text(small)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(state.isDark ? Color.white.opacity(0.7) : Theme.secondaryText)
                }
            }
            .padding(24)
        }
        .frame(width: 260, height: 260)
        .animation(.default, value: bigText)
    }

    private var symbol: String {
        switch state.kind {
        case .idle: "wave.3.right.circle.fill"
        case .focusing: "lock.fill"
        case .pass: "hourglass"
        case .night: "moon.stars.fill"
        case .morning: "sunrise.fill"
        }
    }

    private var bigText: String? {
        switch state {
        case .idle: nil
        case .focusing(let startedAt), .night(let startedAt): Formatting.clock(now.timeIntervalSince(startedAt))
        case .pass(let endsAt): Formatting.clock(max(0, endsAt.timeIntervalSince(now)))
        case .morning(let wake): now >= wake ? Formatting.clock(now.timeIntervalSince(wake)) : nil
        }
    }

    private var smallText: String? {
        switch state {
        case .idle: nil
        case .focusing: "focused"
        case .pass: "left on your pass"
        case .night: "until \(RoutineView.format(wakeTime))"
        case .morning(let wake): now >= wake ? "since your alarm" : "alarm at \(wake.formatted(date: .omitted, time: .shortened))"
        }
    }
}

/// Today at a glance: focus, sessions, passes, streak.
private struct TodayStrip: View {
    @EnvironmentObject private var model: AppModel
    let now: Date

    var body: some View {
        let today = model.todayStats(now: now)
        HStack(spacing: 10) {
            chip(value: Formatting.duration(today.focusSeconds), label: "today", symbol: "target", tint: Theme.focus)
            chip(value: "\(today.sessions)", label: today.sessions == 1 ? "session" : "sessions", symbol: "circle.circle", tint: Theme.focus)
            chip(value: "\(today.passes)", label: today.passes == 1 ? "pass" : "passes", symbol: "hourglass",
                 tint: today.backToBackPasses > 0 ? Theme.pass : Theme.secondaryText)
            chip(value: "\(model.currentStreak)", label: "streak", symbol: "flame.fill", tint: Theme.gold)
        }
    }

    private func chip(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface.opacity(0.85)))
    }
}

/// Primary action: opens the NFC scan sheet.
private struct ScanButton: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let tint: Color

    var body: some View {
        Button {
            Task { await model.scanToToggle() }
        } label: {
            Label(title, systemImage: "wave.3.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
        .disabled(model.isScanning)
    }
}

/// Brick-style deliberate start without the tag: hold for 3 seconds.
private struct HoldToStartButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var tick = 0

    private let duration: Double = 3

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Theme.focus.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.focus, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.focus)
            }
            .frame(width: 28, height: 28)
            Text(isPressing ? "Keep holding…" : "Or hold here to start without the tag")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: duration) {
            progress = 0
            isPressing = false
            model.startWithoutTag()
        } onPressingChanged: { pressing in
            isPressing = pressing
            if pressing {
                tick += 1
                withAnimation(.linear(duration: duration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .sensoryFeedback(.increase, trigger: tick) { _, _ in model.hapticsEnabled }
        .accessibilityLabel("Hold for 3 seconds to start a focus session without scanning the tag")
    }
}

// MARK: - End-of-session summary

struct SessionSummarySheet: View {
    let summary: SessionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: summary.checkedIn != nil ? "sunrise.fill" : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(summary.checkedIn != nil ? Theme.gold : Theme.focus)
                .symbolEffect(.bounce, value: summary.id)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.focus)
                .controlSize(.large)
        }
        .padding(28)
    }

    private var title: String {
        if let checkIn = summary.checkedIn {
            return "Checked in at \(checkIn.formatted(date: .omitted, time: .shortened))"
        }
        if summary.wasNightLock { return "Night lock lifted" }
        return "\(Formatting.duration(summary.duration)) of focus"
    }

    private var detail: String {
        if summary.checkedIn != nil { return "Have a good day." }
        if summary.wasNightLock { return "Rested well. Have a good day." }
        switch summary.passes {
        case 0: return "No passes. Well done."
        case 1: return "1 pass. Well done."
        default: return "\(summary.passes) passes. Every session counts."
        }
    }
}
