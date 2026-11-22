import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if !model.onboardingCompleted {
                OnboardingFlow()
            } else if model.isAuthorized {
                TabView {
                    Tab("Focus", systemImage: "circle.circle.fill") { FocusView() }
                    Tab("Rules", systemImage: "slider.horizontal.3") { RulesView() }
                    Tab("Insights", systemImage: "chart.bar.fill") { InsightsView() }
                    Tab("Settings", systemImage: "gearshape.fill") { SettingsView() }
                }
                .tabViewBottomAccessory { MiniPlayer() }
                .tabBarMinimizeBehavior(.onScrollDown)
                .tint(Theme.focus)
            } else {
                OnboardingView()
            }
        }
        .alert(
            "Tawfeeq",
            isPresented: Binding(
                get: { model.alert != nil },
                set: { if !$0 { model.alert = nil } }
            ),
            presenting: model.alert
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
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
