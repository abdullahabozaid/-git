import FamilyControls
import SwiftUI

/// Home. Every state is built the same way: one sentence, one dial, one quiet line, one action.
/// The dial is today's progress toward your goal, and it's also the button: tap it to scan.
struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPassSheet = false
    @State private var showBlockPicker = false
    @State private var showNoTag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Picks up passes started from the block screen and re-blocks if an extension callback was missed.
    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        // Minute-level updates: calm, no ticking seconds. The pass countdown is rendered by the system.
        TimelineView(.everyMinute) { context in
            // The context date is the start of the minute; use the real time so numbers agree.
            let now = max(context.date, Date())
            let state = model.homeState(now: now)
            GeometryReader { proxy in
                ZStack {
                    StateBackground(state: state, reduceMotion: reduceMotion)
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 0) {
                            header(state)
                                .padding(.top, 12)
                            Spacer(minLength: 28)
                            FocusDial(state: state, now: now) {
                                Task { await model.scanToToggle() }
                            }
                            Spacer(minLength: 20)
                            contextLine(state, now: now)
                            Spacer(minLength: 24)
                            actions(state)
                                .padding(.bottom, 24)
                        }
                        .padding(.horizontal, 24)
                        .frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .modifier(NightScheme(isNight: state.isDark))
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.7), value: state.kind)
        }
        .onReceive(ticker) { _ in model.reconcile() }
        .onAppear { if model.demoShowPassSheet { showPassSheet = true } }
        .familyActivityPicker(isPresented: $showBlockPicker, selection: Binding(
            get: { model.config.blocked },
            set: { selection in
                var config = model.config
                config.blocked = selection
                model.updateConfig(config)
            }
        ))
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

    // MARK: - One sentence

    private func header(_ state: HomeState) -> some View {
        VStack(spacing: 6) {
            Text(title(state))
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Theme.text)
            Text(subtitle(state))
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func title(_ state: HomeState) -> String {
        switch state.kind {
        case .idle: "Ready when you are"
        case .focusing: "Focusing"
        case .pass: "Quick pass"
        case .night: "Resting"
        case .morning: "Good morning"
        }
    }

    private func subtitle(_ state: HomeState) -> String {
        switch state.kind {
        case .idle: model.hasHistory ? "Your desk is the key." : "Your first session starts at your desk."
        case .focusing: "\(model.blockedSummary) resting."
        case .pass: "Apps rest again when the ring runs out."
        case .night: "Your phone is resting for the night."
        case .morning: "Your desk is waiting."
        }
    }

    // MARK: - One quiet line

    @ViewBuilder
    private func contextLine(_ state: HomeState, now: Date) -> some View {
        let line: (String, String)? = switch state {
        case .idle:
            contextForIdle()
        case .focusing:
            ("wave.3.right", "Tap your desk tag to finish")
        case .pass:
            model.currentPassIntention.map { ($0.symbol, "\($0.label) · pass #\(max(1, model.todayStats(now: now).passes)) today") }
                ?? ("hourglass", "Pass #\(max(1, model.todayStats(now: now).passes)) today")
        case .night:
            model.routine.wakeEnabled
                ? ("alarm", "Alarm at \(RoutineView.format(model.routine.wakeTime)) · passes still work")
                : ("moon.zzz", "Passes still work if you need one")
        case .morning:
            model.session.map { ("bed.double", "Your phone rested \(Formatting.duration(now.timeIntervalSince($0.startedAt)))") }
        }
        if let line {
            Label(line.1, systemImage: line.0)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private func contextForIdle() -> (String, String)? {
        var parts: [String] = []
        if let next = model.nextEventDescription { parts.append(next) }
        if model.hasHistory {
            let rhythm = model.rhythm
            parts.append("\(rhythm.met) of \(rhythm.of) days")
        }
        return parts.isEmpty ? nil : ("clock", parts.joined(separator: " · "))
    }

    // MARK: - One action

    @ViewBuilder
    private func actions(_ state: HomeState) -> some View {
        VStack(spacing: 14) {
            switch state {
            case .idle:
                if !model.canStartSession {
                    WideButton(title: "Choose apps to rest", symbol: "apps.iphone", fill: Theme.focus, text: Theme.onFocus) {
                        showBlockPicker = true
                    }
                } else if model.tags.isEmpty {
                    WideButton(title: "Add your desk tag", symbol: "wave.3.right", fill: Theme.focus, text: Theme.onFocus) {
                        Task { await model.enrollTag(name: "Desk", role: .desk) }
                    }
                } else if showNoTag {
                    HoldToStartButton()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Button("No tag nearby?") { withAnimation(.snappy) { showNoTag = true } }
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            case .focusing:
                SoftButton(title: "Take a pass", symbol: "hourglass", tint: Theme.passText) { showPassSheet = true }
            case .pass:
                WideButton(title: "Back to focus", symbol: "arrow.uturn.backward", fill: Theme.pass, text: Theme.onPass) {
                    model.endPassEarly()
                }
            case .night:
                Button("Need a pass?") { showPassSheet = true }
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            case .morning:
                EmptyView()
            }
        }
        .onChange(of: state.kind) { _, _ in showNoTag = false }
    }
}

// MARK: - The dial

/// Today's progress toward the goal, as a ring. Tapping it scans the desk tag.
private struct FocusDial: View {
    @EnvironmentObject private var model: AppModel
    let state: HomeState
    let now: Date
    let scan: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 272
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 64

    var body: some View {
        let today = model.todayStats(now: now).focusSeconds
        let goal = TimeInterval(model.dailyGoalMinutes * 60)
        let progress = goal > 0 ? min(1, today / goal) : 0
        let reached = today >= goal && goal > 0
        let diameter = min(max(size, 230), 320)

        Button(action: scan) {
            ZStack {
                Circle()
                    .fill(state.tint.opacity(state.isDark ? 0.12 : 0.08))
                Circle()
                    .stroke(state.tint.opacity(0.14), lineWidth: 14)

                ring(progress: progress, reached: reached)

                center(today: today, goal: goal, reached: reached)
                    .padding(36)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(DialPressStyle())
        .disabled(state.kind == .pass)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(today: today, goal: goal))
        .accessibilityHint(state.kind == .pass ? "" : "Double-tap to scan your desk tag.")
        .sensoryFeedback(.success, trigger: reached) { old, new in !old && new && model.hapticsEnabled }
    }

    @ViewBuilder
    private func ring(progress: Double, reached: Bool) -> some View {
        switch state {
        case .pass(let endsAt):
            // Drains smoothly, once a second.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, endsAt.timeIntervalSince(context.date)) / PassManager.duration
                Circle()
                    .trim(from: 0, to: remaining)
                    .stroke(Theme.pass, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
            }
        case .night, .morning:
            EmptyView()
        case .idle, .focusing:
            if (model.hasHistory || state.kind == .focusing) && progress > 0.005 {
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(reached ? Theme.gold : Theme.focus, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.8), value: progress)
            }
        }
    }

    @ViewBuilder
    private func center(today: TimeInterval, goal: TimeInterval, reached: Bool) -> some View {
        VStack(spacing: 6) {
            switch state {
            case .idle:
                Image(systemName: "wave.3.right")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.focus)
                Text("Tap to scan")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                if model.hasHistory {
                    Text("\(Formatting.duration(today)) of \(Formatting.duration(goal)) today")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            case .focusing(let startedAt):
                let minutes = Int(now.timeIntervalSince(startedAt) / 60)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(minutes >= 60 ? "\(minutes / 60):\(String(format: "%02d", minutes % 60))" : "\(minutes)")
                        .font(.system(size: min(numberSize, 88), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(minutes >= 60 ? "h" : "min")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                .foregroundStyle(Theme.text)
                Text(reached ? "Today's goal reached" : "\(Formatting.duration(today)) of \(Formatting.duration(goal)) today")
                    .font(.footnote.weight(reached ? .semibold : .regular))
                    .foregroundStyle(reached ? Theme.gold : Theme.secondaryText)
            case .pass(let endsAt):
                Text(timerInterval: now...max(now, endsAt), countsDown: true)
                    .font(.system(size: min(numberSize, 88), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.text)
                Text("left")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            case .night:
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.night)
                Text("Unlocks at \(RoutineView.format(model.routine.wakeTime))")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.text)
                Text("with your desk tag")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            case .morning:
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .symbolEffect(.breathe)
                Text("Tap to check in")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
        }
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
    }

    private func accessibilityText(today: TimeInterval, goal: TimeInterval) -> String {
        func spoken(_ seconds: TimeInterval) -> String {
            Duration.seconds(max(60, seconds)).formatted(.units(allowed: [.hours, .minutes], width: .wide))
        }
        let progress = "\(spoken(today)) of your \(spoken(goal)) goal today."
        switch state {
        case .idle: return "Ready. \(progress)"
        case .focusing(let start): return "Focusing for \(spoken(now.timeIntervalSince(start))). \(progress)"
        case .pass(let end): return "On a pass. \(spoken(end.timeIntervalSince(now))) left."
        case .night: return "Resting. Unlocks at \(RoutineView.format(model.routine.wakeTime)) with your desk tag."
        case .morning: return "Good morning. Scan your desk tag to check in."
        }
    }
}

private struct DialPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Night lock: the whole Focus screen (and its controls) render dark.
private struct NightScheme: ViewModifier {
    let isNight: Bool

    func body(content: Content) -> some View {
        if isNight {
            content
                .environment(\.colorScheme, .dark)
                .toolbarColorScheme(.dark, for: .tabBar)
        } else {
            content
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

    /// Used by the mini-player.
    var title: String {
        switch kind {
        case .idle: "Ready"
        case .focusing: "Focusing"
        case .pass: "Quick pass"
        case .night: "Resting"
        case .morning: "Good morning"
        }
    }
}

/// Calm per-state background with a slow "lamp" glow behind the dial.
private struct StateBackground: View {
    let state: HomeState
    let reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        ZStack {
            base
            RadialGradient(colors: [state.tint.opacity(state.kind == .idle ? 0.10 : 0.22), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 10, endRadius: 360)
                .scaleEffect(breathe ? 1.08 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 6).repeatForever(autoreverses: true), value: breathe)
        }
        .onAppear { breathe = true }
    }

    @ViewBuilder
    private var base: some View {
        switch state.kind {
        case .idle, .focusing, .pass:
            Theme.background
        case .night:
            LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.12), Color(red: 0.10, green: 0.12, blue: 0.22)],
                           startPoint: .top, endPoint: .bottom)
        case .morning:
            LinearGradient(colors: [Theme.gold.opacity(0.32), Theme.pass.opacity(0.10), Theme.background],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - Buttons

/// Full-width primary action with contrast-safe label colour.
struct WideButton: View {
    let title: String
    let symbol: String
    let fill: Color
    let text: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(text)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(fill))
        }
        .buttonStyle(.plain)
    }
}

/// Quiet secondary action: tinted outline capsule.
struct SoftButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

/// Deliberate start without the tag: hold for 3 seconds (revealed by "No tag nearby?").
private struct HoldToStartButton: View {
    @EnvironmentObject private var model: AppModel
    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var tick = 0

    private let duration: Double = 3

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Theme.focus.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.focus, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.focus)
            }
            .frame(width: 56, height: 56)
            Text(isPressing ? "Keep holding…" : "Hold for 3 seconds to start without the tag.\nYou'll still need it to finish.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Start without tag")
        .accessibilityHint("Hold for 3 seconds. Ending the session still needs your desk tag.")
        .accessibilityAction(named: "Start without tag") { model.startWithoutTag() }
    }
}

// MARK: - End-of-session summary

struct SessionSummarySheet: View {
    let summary: SessionSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: Double = 0
    @State private var sunrise = false

    private var isMorning: Bool { summary.checkedIn != nil }
    private var progress: Double { summary.goal > 0 ? min(1, summary.todayFocus / summary.goal) : 0 }
    private var reached: Bool { summary.goal > 0 && summary.todayFocus >= summary.goal }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                if isMorning {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.gold)
                        .symbolEffect(.bounce, value: sunrise)
                } else {
                    Circle().stroke(Theme.focus.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(reached ? Theme.gold : Theme.focus, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: reached ? "checkmark" : "leaf.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(reached ? Theme.gold : Theme.focus)
                }
            }
            .frame(width: 96, height: 96)

            Text(title)
                .font(.title.bold())
                .fontDesign(.rounded)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if let observation = summary.observation {
                Label(observation, systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.focus)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isMorning {
                LinearGradient(colors: [Theme.gold.opacity(0.4), Theme.pass.opacity(0.15), Theme.background],
                               startPoint: .top, endPoint: .bottom)
                    .opacity(sunrise || reduceMotion ? 1 : 0)
                    .ignoresSafeArea()
            } else {
                Theme.background.ignoresSafeArea()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                sunrise = true
                fill = progress
            }
        }
        .task {
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            dismiss()
        }
        .accessibilityAction(named: "Close") { dismiss() }
    }

    private var title: String {
        if let checkIn = summary.checkedIn {
            return "Checked in at \(checkIn.formatted(date: .omitted, time: .shortened))"
        }
        if summary.wasNightLock { return "Night lock lifted" }
        return "\(Formatting.duration(summary.duration)) of focus"
    }

    private var detail: String {
        if isMorning { return "Have a good day." }
        if summary.wasNightLock { return "Have a good day." }
        if reached { return "\(Formatting.duration(summary.todayFocus)) today · goal reached" }
        return "\(Formatting.duration(summary.todayFocus)) of \(Formatting.duration(summary.goal)) today"
    }
}
