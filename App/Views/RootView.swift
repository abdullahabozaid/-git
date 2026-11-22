import SwiftUI

import FamilyControls

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showBlockPicker = false
    @State private var showLostTag = false
    @State private var tab = "focus"

    var body: some View {
        Group {
            if !model.onboardingCompleted {
                OnboardingFlow(initialStep: model.demoOnboardingStep)
            } else if model.isAuthorized {
                TabView(selection: $tab) {
                    Tab("Focus", systemImage: "circle.circle.fill", value: "focus") { FocusView() }
                    Tab("Rules", systemImage: "slider.horizontal.3", value: "rules") { RulesView() }
                    Tab("Insights", systemImage: "chart.bar.fill", value: "insights") { InsightsView() }
                    Tab("Settings", systemImage: "gearshape.fill", value: "settings") { SettingsView() }
                }
                .onAppear { if let demoTab = model.demoTab { tab = demoTab } }
                .tabViewBottomAccessory { MiniPlayer() }
                .tabBarMinimizeBehavior(.onScrollDown)
                .tint(Theme.focus)
            } else {
                OnboardingView()
            }
        }
        .alert(
            model.alert?.title ?? "Tawfeeq",
            isPresented: Binding(
                get: { model.alert != nil },
                set: { if !$0 { model.alert = nil } }
            ),
            presenting: model.alert
        ) { alert in
            if let actionTitle = alert.action.title {
                Button(actionTitle) { perform(alert.action) }
                Button("Not now", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        // Night lock turns the whole app dark (tab bar, mini-player, cards), not just the background.
        .preferredColorScheme(model.homeState().kind == .night ? .dark : nil)
        .familyActivityPicker(isPresented: $showBlockPicker, selection: Binding(
            get: { model.config.blocked },
            set: { selection in
                var config = model.config
                config.blocked = selection
                if config.mode == .everythingExceptAllowed { config.mode = .selected }
                model.updateConfig(config)
            }
        ))
        .sheet(isPresented: $showLostTag) {
            NavigationStack {
                LostTagView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showLostTag = false } }
                    }
            }
        }
    }

    private func perform(_ action: AppAlert.Action) {
        switch action {
        case .none: break
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .retryScan:
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await model.scanToToggle()
            }
        case .chooseApps:
            showBlockPicker = true
        case .lostTag:
            showLostTag = true
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wave.3.right.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Tawfeeq")
                .font(.largeTitle.bold())
            Text("Tap your desk tag to lock distracting apps. Tap it again to unlock. Your phone stays focused until you go back to your desk.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Tawfeeq uses Screen Time to block apps. Nothing leaves your phone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await model.requestAuthorization() }
            } label: {
                Text("Allow Screen Time access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
    }
}
