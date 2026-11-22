import FamilyControls
import SwiftUI

/// Everything that decides what gets blocked, and when.
struct RulesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showAllowPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        BlockListView()
                    } label: {
                        RuleRow(symbol: "hand.raised.fill", tint: Theme.focus,
                                title: "Block list", detail: blockDetail)
                    }
                    Button {
                        showAllowPicker = true
                    } label: {
                        RuleRow(symbol: "checkmark.shield.fill", tint: Theme.focus,
                                title: "Always allowed",
                                detail: model.config.allowed.applicationTokens.isEmpty
                                    ? "Nothing yet. Add Maps, banking, 2FA…"
                                    : "\(model.config.allowed.applicationTokens.count) apps never blocked")
                    }
                    .foregroundStyle(Theme.text)
                } header: {
                    Text("During focus")
                } footer: {
                    if model.isFocusing {
                        Text("You're focusing: you can add apps now, removing them waits until the session ends.")
                    }
                }

                Section("Passes") {
                    RuleRow(symbol: "hourglass", tint: Theme.pass, title: "5-minute passes",
                            detail: "Unlimited · a short breath first")
                }

                Section("Night & morning") {
                    NavigationLink {
                        RoutineView()
                    } label: {
                        RuleRow(symbol: "moon.stars.fill", tint: Theme.night, title: "Night lock",
                                detail: model.routine.nightLockEnabled
                                    ? "From \(RoutineView.format(model.routine.nightLockStart)) until your desk tag"
                                    : "Off")
                    }
                    NavigationLink {
                        RoutineView()
                    } label: {
                        RuleRow(symbol: "alarm.fill", tint: Theme.gold, title: "Wake alarm",
                                detail: model.routine.wakeEnabled
                                    ? "\(RoutineView.format(model.routine.wakeTime)) · \(weekdaysDetail)"
                                    : "Off")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Rules")
            .familyActivityPicker(isPresented: $showAllowPicker, selection: Binding(
                get: { model.config.allowed },
                set: { selection in
                    var config = model.config
                    config.allowed = selection
                    model.updateConfig(config)
                }
            ))
        }
    }

    private var blockDetail: String {
        let blocked = model.config.blocked
        switch model.config.mode {
        case .everythingExceptAllowed:
            return "Everything except your allowed apps"
        case .selected:
            let total = blocked.applicationTokens.count + blocked.categoryTokens.count + blocked.webDomainTokens.count
            return total == 0
                ? "Nothing yet. Choose what distracts you"
                : "\(blocked.applicationTokens.count) apps · \(blocked.categoryTokens.count) categories · \(blocked.webDomainTokens.count) sites"
        }
    }

    private var weekdaysDetail: String {
        let days = model.routine.wakeDays
        if days == [2, 3, 4, 5, 6] { return "weekdays" }
        if days.count == 7 { return "every day" }
        if days == [1, 7] { return "weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.sorted().map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}

struct RuleRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}
