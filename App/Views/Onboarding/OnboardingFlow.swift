import FamilyControls
import ManagedSettings
import SwiftUI

/// First run, under two minutes: welcome → try it → Screen Time → apps → desk tag → mornings → first session.
struct OnboardingFlow: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Step
    @State private var showPicker = false
    @State private var showAllowPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var allowed = FamilyActivitySelection()
    @State private var routine = Routine()
    @State private var permissionAttempted = false
    @State private var demoLocked = false

    init(initialStep: Int? = nil) {
        _step = State(initialValue: Step(rawValue: initialStep ?? 0) ?? .welcome)
    }

    enum Step: Int, CaseIterable {
        case welcome, tryIt, permission, apps, tag, mornings, done
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Group {
                switch step {
                case .welcome: welcome
                case .tryIt: tryIt
                case .permission: permission
                case .apps: apps
                case .tag: tag
                case .mornings: mornings
                case .done: done
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.focus)
        .animation(.snappy, value: step)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .familyActivityPicker(isPresented: $showAllowPicker, selection: $allowed)
        .onChange(of: selection) { _, newValue in
            var config = model.config
            config.blocked = newValue
            model.updateConfig(config)
        }
        .onChange(of: allowed) { _, newValue in
            var config = model.config
            config.allowed = newValue
            model.updateConfig(config)
        }
        .onChange(of: model.isAuthorized) { _, authorized in
            if authorized, step == .permission { advance() }
        }
        .onAppear {
            if step == .welcome { EventLog.append(.onboardingStarted) }
            selection = model.config.blocked
            allowed = model.config.allowed
            routine = model.routine
        }
        .sensoryFeedback(.selection, trigger: step) { _, _ in model.hapticsEnabled }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .opacity(step == .welcome || step == .done ? 0 : 1)
            .disabled(step == .welcome || step == .done)

            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(Theme.focus)
                .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .opacity(step == .welcome ? 0 : 1)
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    // MARK: - Steps

    private var welcome: some View {
        Page {
            TagRipple()
                .frame(width: 200, height: 200)
            VStack(spacing: 6) {
                Text("توفيق")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .accessibilityHidden(true)
                Text("Tawfeeq")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.text)
                Text("Success, made easier.")
                    .font(.title3)
                    .foregroundStyle(Theme.secondaryText)
            }
            Text("Your desk becomes the key to your phone. Tap to rest distracting apps, tap again when you're done.")
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        } actions: {
            PrimaryButton("Begin") { advance() }
        }
    }

    /// Learn by doing: tap the circle like you'd tap your desk tag.
    private var tryIt: some View {
        Page {
            Text("Try it")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Tap the circle, the way you'll tap your desk tag.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.spring(duration: 0.6)) { demoLocked.toggle() }
            } label: {
                ZStack {
                    Circle().fill((demoLocked ? Theme.focus : Theme.secondaryText).opacity(0.10))
                    Circle()
                        .trim(from: 0, to: demoLocked ? 1 : 0)
                        .stroke(Theme.focus, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Image(systemName: demoLocked ? "lock.fill" : "wave.3.right")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(Theme.focus)
                            .contentTransition(.symbolEffect(.replace))
                        Text(demoLocked ? "Apps resting" : "Tap")
                            .font(.headline)
                    }
                }
                .frame(width: 220, height: 220)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: demoLocked) { _, _ in model.hapticsEnabled }
            Text(demoLocked
                 ? "That's a session. Need something? A 5-minute pass is always there, after a short breath."
                 : "Tap again when you're done. Only your desk tag can end a session.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
        } actions: {
            PrimaryButton("Continue") { advance() }
        }
    }

    private var permission: some View {
        Page {
            Image(systemName: "hourglass.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.focus)
            Text("Allow Screen Time")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("Tawfeeq uses Apple's Screen Time to rest the apps you choose. iOS will ask you to confirm with Face ID.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            Label("Your usage never leaves this iPhone. No account, no tracking.", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.focus)
                .multilineTextAlignment(.center)
            if permissionAttempted, !model.isAuthorized {
                Text("Screen Time wasn't allowed. Try again, or turn it on in Settings → Screen Time → Apps with Screen Time Access.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        } actions: {
            if model.isAuthorized {
                PrimaryButton("Continue") { advance() }
            } else {
                PrimaryButton(permissionAttempted ? "Try again" : "Allow Screen Time") {
                    Task {
                        await model.requestAuthorization()
                        model.alert = nil // explained inline
                        permissionAttempted = true
                    }
                }
                if permissionAttempted {
                    SecondaryButton("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
            }
        }
    }

    private var apps: some View {
        let count = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        return Page {
            Text("What pulls you away?")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text("Most people start with Social and Entertainment. You can always add more later.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if count > 0 {
                AppIconRow(tokens: Array(selection.applicationTokens.prefix(6)),
                           extra: count - min(6, selection.applicationTokens.count))
                if !allowed.applicationTokens.isEmpty {
                    Label("\(allowed.applicationTokens.count) apps always allowed", systemImage: "checkmark.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.focus)
                }
            }
        } actions: {
            if count == 0 {
                PrimaryButton("Choose apps") { showPicker = true }
            } else {
                PrimaryButton("Continue") { advance() }
                HStack(spacing: 12) {
                    SecondaryButton("Change") { showPicker = true }
                    SecondaryButton("Always allow…") { showAllowPicker = true }
                }
            }
        }
    }

    /// The hero moment: the first real tap on the desk tag.
    private var tag: some View {
        let hasDeskTag = model.tags.contains { $0.role == .desk }
        return Page {
            ZStack {
                Circle().fill(Theme.focus.opacity(hasDeskTag ? 0.18 : 0.08))
                Circle()
                    .trim(from: 0, to: hasDeskTag ? 1 : 0)
                    .stroke(Theme.focus, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.9), value: hasDeskTag)
                Image(systemName: hasDeskTag ? "checkmark.seal.fill" : "wave.3.right")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Theme.focus)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: hasDeskTag)
            }
            .frame(width: 220, height: 220)
            .sensoryFeedback(.success, trigger: hasDeskTag) { old, new in !old && new && model.hapticsEnabled }
            Text(hasDeskTag ? "Your desk is ready" : "Meet your desk tag")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text(hasDeskTag
                 ? "From now on, this sticker starts and ends your focus."
                 : "Hold the top of your iPhone flat against the sticker. You'll tap twice: once to read it, once to set it up.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        } actions: {
            if hasDeskTag {
                PrimaryButton("Continue") { advance() }
            } else {
                PrimaryButton(model.isScanning ? "Scanning…" : "Scan desk tag") {
                    Task { await model.enrollTag(name: "Desk", role: .desk) }
                }
                .disabled(model.isScanning)
                Button("Sticker not here? Do this later") { advance() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(minHeight: 44)
            }
        }
    }

    private var mornings: some View {
        Page {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.gold)
            Text("Calmer nights and mornings")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text("Optional. Rest your apps overnight, and wake to an alarm that stops when you reach your desk.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                TimeChoice(title: "Night lock from", symbol: "moon.stars.fill", tint: Theme.night, onTint: Theme.onNight,
                           isOn: $routine.nightLockEnabled, time: timeBinding(\.nightLockStart),
                           presets: [TimeOfDay(hour: 22, minute: 0), TimeOfDay(hour: 22, minute: 30), TimeOfDay(hour: 23, minute: 0)])
                TimeChoice(title: "Wake alarm at", symbol: "alarm.fill", tint: Theme.gold, onTint: Theme.onGold,
                           isOn: $routine.wakeEnabled, time: timeBinding(\.wakeTime),
                           presets: [TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 6, minute: 30), TimeOfDay(hour: 7, minute: 0)])
            }
        } actions: {
            PrimaryButton(routine.wakeEnabled || routine.nightLockEnabled ? "Continue" : "Skip for now") {
                Task {
                    await model.updateRoutine(routine)
                    advance()
                }
            }
        }
    }

    private var done: some View {
        Page {
            TagRipple()
                .frame(width: 180, height: 180)
            Text("Begin your first focus")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
            Text(model.tags.isEmpty
                 ? "Add your desk tag from the Focus screen when it's nearby."
                 : "Tap your phone on your desk tag now. Bismillah.")
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        } actions: {
            if !model.tags.isEmpty {
                PrimaryButton("Scan desk tag") {
                    model.completeOnboarding()
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        await model.scanToToggle()
                    }
                }
            }
            SecondaryButton(model.tags.isEmpty ? "Go to Tawfeeq" : "Later") { model.completeOnboarding() }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Routine, TimeOfDay>) -> Binding<TimeOfDay> {
        Binding(get: { routine[keyPath: keyPath] }, set: { routine[keyPath: keyPath] = $0 })
    }
}

// MARK: - Building blocks

private struct Page<Content: View, Actions: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 12)
                    content
                    Spacer(minLength: 24)
                    VStack(spacing: 12) { actions }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(Theme.text)
    }
}

/// A tag with gentle ripples: the core gesture, animated.
private struct TagRipple: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                PhaseAnimator([0.0, 1.0]) { phase in
                    ZStack {
                        ForEach(0..<3) { ring in
                            let scale = 0.45 + (phase + Double(ring) / 3).truncatingRemainder(dividingBy: 1) * 0.55
                            Circle()
                                .stroke(Theme.focus.opacity(0.35 * (1 - scale)), lineWidth: 2)
                                .scaleEffect(scale)
                        }
                    }
                } animation: { _ in .linear(duration: 2.4) }
            }
            Circle()
                .fill(Theme.focus)
                .frame(width: 84, height: 84)
                .overlay(Image(systemName: "wave.3.right").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.onFocus))
                .shadow(color: Theme.focus.opacity(0.35), radius: 18, y: 6)
        }
        .accessibilityHidden(true)
    }
}

private struct AppIconRow: View {
    let tokens: [ApplicationToken]
    let extra: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(tokens, id: \.self) { token in
                Label(token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.6)
                    .frame(width: 40, height: 40)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.headline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.secondaryText.opacity(0.12)))
            }
        }
        .padding(.vertical, 8)
    }
}

/// Toggle + one-tap time presets (no fiddly wheel unless you want it).
private struct TimeChoice: View {
    let title: String
    let symbol: String
    let tint: Color
    let onTint: Color
    @Binding var isOn: Bool
    @Binding var time: TimeOfDay
    let presets: [TimeOfDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isOn) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            }
            .tint(tint)
            if isOn {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        let selected = preset == time
                        Button(RoutineView.format(preset)) { time = preset }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(selected ? onTint : Theme.text)
                            .background(Capsule().fill(selected ? tint : Theme.secondaryText.opacity(0.12)))
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.onFocus)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(Theme.focus))
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.focus)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(Theme.focus.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
