import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showShortcutGuide = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        TagsView()
                    } label: {
                        RuleRow(symbol: "wave.3.right", tint: Theme.focus, title: "Tags",
                                detail: tagsDetail)
                    }
                    Button {
                        showShortcutGuide = true
                    } label: {
                        RuleRow(symbol: "bolt.fill", tint: Theme.gold, title: "Make it one tap",
                                detail: "Start focus without opening the app")
                    }
                    .foregroundStyle(Theme.text)
                } header: {
                    Text("Your desk")
                }

                Section {
                    // One tap for common goals; the stepper fine-tunes.
                    HStack(spacing: 8) {
                        ForEach([60, 120, 180, 240, 360], id: \.self) { minutes in
                            let selected = model.dailyGoalMinutes == minutes
                            Button(Formatting.duration(TimeInterval(minutes * 60))) {
                                model.setDailyGoal(minutes: minutes)
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(selected ? Theme.onFocus : Theme.text)
                            .background(Capsule().fill(selected ? Theme.focus : Theme.secondaryText.opacity(0.12)))
                            .buttonStyle(.borderless)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    Menu {
                        Picker("Custom goal", selection: Binding(get: { model.dailyGoalMinutes },
                                                                 set: { model.setDailyGoal(minutes: $0) })) {
                            ForEach(Array(stride(from: 30, through: 600, by: 15)), id: \.self) { minutes in
                                Text(Formatting.duration(TimeInterval(minutes * 60))).tag(minutes)
                            }
                        }
                    } label: {
                        LabeledContent("Custom…", value: Formatting.duration(TimeInterval(model.dailyGoalMinutes * 60)))
                    }
                } header: {
                    Text("Daily focus goal")
                } footer: {
                    Text("Streaks count days you reach this.")
                }

                Section {
                    Toggle("Travel mode", isOn: Binding(
                        get: { model.travelUntil.map { $0 > Date() } ?? false },
                        set: { on in
                            Task {
                                await model.setTravel(until: on ? Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) : nil)
                            }
                        }
                    ))
                    if let until = model.travelUntil, until > Date() {
                        DatePicker("Back on", selection: Binding(
                            get: { until },
                            set: { date in Task { await model.setTravel(until: date) } }
                        ), in: Date()..., displayedComponents: .date)
                    }
                } header: {
                    Text("Away from your desk")
                } footer: {
                    Text("Pauses night lock and the wake alarm while you're away from your desk tag. Focus sessions still work with your spare tag.")
                }

                Section("Feel") {
                    Toggle("Haptics", isOn: Binding(get: { model.hapticsEnabled },
                                                    set: { model.setHaptics($0) }))
                }

                Section("Help") {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        RuleRow(symbol: "stethoscope", tint: Theme.secondaryText,
                                title: "Diagnostics", detail: "Scan reliability and usage, all on this iPhone")
                    }
                    NavigationLink {
                        LostTagView()
                    } label: {
                        RuleRow(symbol: "questionmark.circle.fill", tint: Theme.secondaryText,
                                title: "Lost your tag?", detail: "How to get out of a session")
                    }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                } footer: {
                    Text("Tawfeeq uses Apple's Screen Time. Your usage never leaves this iPhone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .sheet(isPresented: $showShortcutGuide) {
                ShortcutGuideSheet()
                    .presentationDetents([.large])
            }
        }
    }

    private var tagsDetail: String {
        let desk = model.tags.filter { $0.role == .desk }.count
        let spare = model.tags.filter { $0.role == .spare }.count
        if desk + spare == 0 { return "No tags yet" }
        return "\(desk) desk · \(spare) spare"
    }
}

/// Step-by-step: Shortcuts → Automation → NFC → Desk Tag Tapped.
struct ShortcutGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("app.badge.fill", "Open the Shortcuts app and go to Automation."),
        ("plus.circle.fill", "Tap + and choose NFC."),
        ("wave.3.right", "Tap Scan and hold your iPhone to your desk tag. Name it \"Desk\"."),
        ("bolt.fill", "Choose Run Immediately, and turn off Notify When Run."),
        ("square.stack.3d.up.fill", "Add the action Desk Tag Tapped from Tawfeeq."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(Theme.onFocus)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Theme.focus))
                            Label(step.1, systemImage: step.0)
                                .labelStyle(.titleOnly)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("Now one tap on your desk starts a session. To end it, Tawfeeq opens and asks you to scan the tag, so a shortcut alone can't end your focus.")
                }
                Section {
                    Button("Open Shortcuts") {
                        if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                    }
                }
            }
            .navigationTitle("Make it one tap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
