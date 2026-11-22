import SwiftUI

struct RoutineView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = Routine()
    @State private var isSaving = false

    var body: some View {
        Group {
            Form {
                if model.isFocusing {
                    Section {
                        Label("Locked during a focus session or night lock. Tap your desk tag to unlock first.",
                              systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Wake alarm", isOn: $draft.wakeEnabled)
                    if draft.wakeEnabled {
                        DatePicker("Time", selection: timeBinding(\.wakeTime), displayedComponents: .hourAndMinute)
                        WeekdayPicker(selection: $draft.wakeDays)
                    }
                } header: {
                    Text("Morning")
                } footer: {
                    Text("Rings through Silent mode and Focus. Pressing Stop makes it ring again 30 seconds later. The only way to turn it off is to tap your desk tag. Gives up after 1 hour. Tapping your desk tag up to 2 hours early cancels that morning's alarm.")
                }

                Section {
                    Toggle("Night lock", isOn: $draft.nightLockEnabled)
                    if draft.nightLockEnabled {
                        DatePicker("Starts at", selection: timeBinding(\.nightLockStart), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Night")
                } footer: {
                    Text("From \(Self.format(draft.nightLockStart)), your block list locks automatically and stays locked until you tap your desk tag in the morning (from \(Self.format(draft.wakeTime))). 5-minute passes still work.")
                }

                if draft != model.routine {
                    Section {
                        Button {
                            isSaving = true
                            Task {
                                await model.updateRoutine(draft)
                                draft = model.routine
                                isSaving = false
                            }
                        } label: {
                            Text("Save routine").frame(maxWidth: .infinity)
                        }
                        .disabled(isSaving)
                        Button("Discard changes", role: .cancel) { draft = model.routine }
                            .frame(maxWidth: .infinity)
                    }
                }

                Section {
                    Button("Test alarm (rings in 30 seconds)") {
                        Task { await model.testAlarm() }
                    }
                }
            }
            .disabled(model.isFocusing)
            .navigationTitle("Routine")
            .onAppear { draft = model.routine }
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<Routine, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                let time = draft[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft[keyPath: keyPath] = TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
            }
        )
    }

    static func format(_ time: TimeOfDay) -> String {
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// Seven round day toggles, starting on the locale's first weekday.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let days = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(calendar.veryShortWeekdaySymbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15)))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
