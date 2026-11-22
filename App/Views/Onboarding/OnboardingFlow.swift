import FamilyControls
import SwiftUI

/// First run: welcome → how it works → Screen Time → pick apps → desk tag → mornings → done.
struct OnboardingFlow: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: Step = .welcome
    @State private var showPicker = false
    @State private var showAllowPicker = false
    @State private var allowed = FamilyActivitySelection()
    @State private var selection = FamilyActivitySelection()
    @State private var routine = Routine()
    @State private var permissionAttempted = false
    @State private var showShortcutGuide = false

    enum Step: Int, CaseIterable {
        case welcome, howItWorks, permission, apps, tag, mornings, done
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    goBack()
                } label: {
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
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .opacity(step == .welcome ? 0 : 1)

            Group {
                switch step {
                case .welcome: welcome
                case .howItWorks: howItWorks
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
        .animation(.snappy, value: step)
        .familyActivityPicker(isPresented: $showPicker, selection: $selection)
        .familyActivityPicker(isPresented: $showAllowPicker, selection: $allowed)
        .onChange(of: allowed) { _, newValue in
            var config = model.config
            config.allowed = newValue
            model.updateConfig(config)
        }
        .onChange(of: selection) { _, newValue in
            var config = model.config
            config.blocked = newValue
            model.updateConfig(config)
        }
        .onChange(of: model.isAuthorized) { _, authorized in
            if authorized, step == .permission { advance() }
        }
        .sheet(isPresented: $showShortcutGuide) { ShortcutGuideSheet() }
        .onAppear {
            if step == .welcome { EventLog.append(.onboardingStarted) }
            selection = model.config.blocked
            allowed = model.config.allowed
            routine = model.routine
        }
        .sensoryFeedback(.selection, trigger: step)
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
        OnboardingPage(
            symbol: "wave.3.right.circle.fill",
            title: "Tawfeeq",
            message: "Your desk is the key.\nTap your NFC sticker to lock distracting apps. Tap it again to unlock. Your phone stays focused until you walk back to your desk."
        ) {
            PrimaryButton("Get started") { advance() }
        }
    }

    private var howItWorks: some View {
        OnboardingPage(symbol: "sparkles", title: "How it works", message: nil) {
            VStack(alignment: .leading, spacing: 22) {
                HowRow(symbol: "lock.fill", title: "Tap to lock", text: "Hold your phone to the desk sticker. The apps you choose are blocked.")
                HowRow(symbol: "hourglass", title: "5-minute passes", text: "Need something urgently? Take a pass from the block screen. Apps lock again on their own.")
                HowRow(symbol: "lock.open.fill", title: "Tap to unlock", text: "Walk back to your desk and tap again. That's the only way to end a session.")
                HowRow(symbol: "sunrise.fill", title: "Mornings", text: "Optional: lock apps overnight, and an alarm that only stops at your desk.")
            }
            .padding(.bottom, 8)
            PrimaryButton("Continue") { advance() }
        }
    }

    private var permission: some View {
        OnboardingPage(
            symbol: "hourglass.circle.fill",
            title: "Allow Screen Time",
            message: "Tawfeeq uses Apple's Screen Time to block apps. Your app usage never leaves your phone, and you can turn this off at any time in Settings."
        ) {
            if model.isAuthorized {
                PrimaryButton("Continue") { advance() }
            } else {
                if permissionAttempted {
                    Text("Screen Time wasn't allowed. You can try again, or turn it on in Settings → Screen Time → Apps with Screen Time Access.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                    SecondaryButton("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                PrimaryButton(permissionAttempted ? "Try again" : "Allow Screen Time access") {
                    Task {
                        await model.requestAuthorization()
                        model.alert = nil // the page explains it inline
                        permissionAttempted = true
                    }
                }
            }
        }
    }

    private var apps: some View {
        OnboardingPage(
            symbol: "apps.iphone",
            title: "What distracts you?",
            message: "Choose the apps, categories and websites to block during focus. You can change this later, but not during a session."
        ) {
            let count = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
            if count > 0 {
                Label("\(selection.applicationTokens.count) apps · \(selection.categoryTokens.count) categories · \(selection.webDomainTokens.count) sites",
                      systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
            }
            SecondaryButton(count > 0 ? "Change selection" : "Choose apps") { showPicker = true }
            if count > 0 {
                Button(allowed.applicationTokens.isEmpty
                       ? "Always allow some apps (Maps, banking…)"
                       : "\(allowed.applicationTokens.count) apps always allowed") { showAllowPicker = true }
                    .font(.subheadline)
            }
            PrimaryButton("Continue") { advance() }
                .disabled(count == 0)
        }
    }

    private var tag: some View {
        let hasDeskTag = model.tags.contains { $0.role == .desk }
        return OnboardingPage(
            symbol: hasDeskTag ? "checkmark.seal.fill" : "wave.3.right",
            title: hasDeskTag ? "Desk tag ready" : "Register your desk tag",
            message: hasDeskTag
                ? "Your desk sticker is set up.\n\nTip: register a spare sticker later (Settings → Tags) and keep it in a drawer, in case the desk one goes missing."
                : "Hold the top of your iPhone against the NFC sticker on your desk. You'll tap twice: once to read it, once to set it up.\n\nTip: put it somewhere you have to stand up and walk to."
        ) {
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
            }
        }
    }

    private var mornings: some View {
        OnboardingPage(
            symbol: "sunrise.fill",
            title: "Mornings",
            message: "Optional. Lock apps overnight, and wake up to an alarm that only stops when you tap your desk tag."
        ) {
            VStack(spacing: 0) {
                Toggle("Wake alarm", isOn: $routine.wakeEnabled)
                    .padding(.vertical, 10)
                if routine.wakeEnabled {
                    DatePicker("Wake up at", selection: timeBinding(\.wakeTime), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 6)
                }
                Divider()
                Toggle("Night lock", isOn: $routine.nightLockEnabled)
                    .padding(.vertical, 10)
                if routine.nightLockEnabled {
                    DatePicker("Lock apps from", selection: timeBinding(\.nightLockStart), displayedComponents: .hourAndMinute)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))

            PrimaryButton("Continue") {
                Task {
                    await model.updateRoutine(routine)
                    advance()
                }
            }
            Button("Skip for now") { advance() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var done: some View {
        OnboardingPage(
            symbol: "checkmark.circle.fill",
            title: "You're all set",
            message: "Tap your desk tag whenever you want to focus. Tap it again when you're done."
        ) {
            SecondaryButton("Make it one tap (Shortcuts)") { showShortcutGuide = true }
            PrimaryButton("Start using Tawfeeq") { model.completeOnboarding() }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Routine, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                let time = routine[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                routine[keyPath: keyPath] = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        )
    }
}

// MARK: - Building blocks

private struct OnboardingPage<Actions: View>: View {
    let symbol: String
    let title: String
    let message: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: symbol)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: symbol)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 24)
            VStack(spacing: 12) { actions }
        }
        .padding(24)
    }
}

private struct HowRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
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
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
