import Charts
import DeviceActivity
import SwiftUI

/// Your own data (focus, streaks, passes, mornings) plus Apple's Screen Time report.
struct InsightsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var range: Range = .week
    @State private var current: StatsSummary?
    @State private var previous: TimeInterval = 0
    @State private var calendar28: [DayStats] = []

    enum Range: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
        var label: String { self == .week ? "This week" : "30 days" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(Range.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if let current {
                        HeroCard(summary: current, previous: previous, range: range)
                        StreakCalendarCard(days: calendar28, summary: current)
                        FocusChartCard(summary: current)
                        PassesCard(summary: current)
                        MorningsCard(summary: current)
                        if let tip = suggestion(current) {
                            TipCard(text: tip)
                        }
                    }

                    ScreenTimeCard(days: range.days)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Insights")
            .onAppear(perform: reload)
            .onChange(of: range) { _, _ in reload() }
        }
    }

    private func reload() {
        let both = model.stats(days: range.days * 2)
        previous = both.days.prefix(range.days).reduce(0) { $0 + $1.focusSeconds }
        current = model.stats(days: range.days)
        calendar28 = model.stats(days: 28).days
    }

    /// One gentle, data-based suggestion.
    private func suggestion(_ summary: StatsSummary) -> String? {
        if summary.totalPasses >= 3, let peak = summary.passHours.max(by: { $0.value < $1.value })?.key {
            let start = Calendar.current.date(bySettingHour: peak, minute: 0, second: 0, of: Date()) ?? Date()
            let end = start.addingTimeInterval(3600)
            return "Most of your passes happen around \(start.formatted(.dateTime.hour())) – \(end.formatted(.dateTime.hour())). A short walk or a glass of water then might help."
        }
        let late = summary.days.compactMap(\.minutesFromAlarm).filter { $0 > 10 }
        if late.count >= 2 {
            return "Some mornings you reach your desk a while after the alarm. Try leaving your phone on the desk overnight."
        }
        if summary.currentStreak >= 3 {
            return "\(summary.currentStreak) days in a row. Keep it gentle and steady."
        }
        if summary.totalFocus == 0 {
            return "Tap your desk tag when you sit down to work. Your first session will show up here."
        }
        return nil
    }
}

// MARK: - Cards

struct InsightCard<Content: View>: View {
    let title: String
    let symbol: String
    var tint: Color = Theme.secondaryText
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
    }
}

private struct HeroCard: View {
    let summary: StatsSummary
    let previous: TimeInterval
    let range: InsightsView.Range

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(range == .week ? "Focus this week" : "Focus in 30 days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(Formatting.duration(summary.totalFocus))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            if previous > 0 {
                let delta = summary.totalFocus - previous
                Label("\(delta >= 0 ? "+" : "−")\(Formatting.duration(abs(delta))) vs previous \(range == .week ? "week" : "30 days")",
                      systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            HStack(spacing: 18) {
                heroStat("\(summary.days.reduce(0) { $0 + $1.sessions })", "sessions")
                heroStat(Formatting.duration(summary.longestSession), "longest")
                heroStat("\(summary.currentStreak)", "day streak")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Theme.focus, Theme.focus.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.75))
        }
    }
}

/// 4-week grid: filled = goal met, ring = some focus, gold dot = grace day.
private struct StreakCalendarCard: View {
    let days: [DayStats]
    let summary: StatsSummary

    var body: some View {
        InsightCard(title: "Streak", symbol: "flame.fill", tint: Theme.gold) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(summary.currentStreak)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(summary.currentStreak == 1 ? "day" : "days").foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("Best \(summary.bestStreak)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryText)
            }
            let goal = TimeInterval(summary.goalMinutes * 60)
            let grace = Set(summary.days.filter(\.isGraceDay).map(\.day))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days) { day in
                    let isToday = Calendar.current.isDateInToday(day.day)
                    ZStack {
                        if day.focusSeconds >= goal {
                            Circle().fill(Theme.focus)
                        } else if day.focusSeconds > 0 {
                            Circle().stroke(Theme.focus, lineWidth: 2)
                        } else {
                            Circle().fill(Theme.secondaryText.opacity(0.12))
                        }
                        if grace.contains(day.day) {
                            Circle().fill(Theme.gold).frame(width: 7, height: 7)
                        }
                    }
                    .frame(height: 28)
                    .overlay(Circle().stroke(Theme.text.opacity(isToday ? 0.6 : 0), lineWidth: 1.5).padding(-3))
                    .accessibilityLabel("\(day.day.formatted(date: .abbreviated, time: .omitted)): \(Formatting.duration(day.focusSeconds))")
                }
            }
            Text("A day counts when you focus for \(Formatting.duration(goal)). One missed day a week is forgiven (gold dot).")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct FocusChartCard: View {
    let summary: StatsSummary

    var body: some View {
        InsightCard(title: "Focus by day", symbol: "chart.bar.fill", tint: Theme.focus) {
            Chart {
                ForEach(summary.days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Hours", day.focusSeconds / 3600)
                    )
                    .foregroundStyle(day.focusSeconds >= Double(summary.goalMinutes * 60) ? Theme.focus : Theme.focus.opacity(0.4))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", Double(summary.goalMinutes) / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.gold)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("goal").font(.caption2).foregroundStyle(Theme.gold)
                    }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let hours = value.as(Double.self) { Text("\(Int(hours))h") } }
                }
            }
            .frame(height: 170)
        }
    }
}

private struct PassesCard: View {
    let summary: StatsSummary

    var body: some View {
        let backToBack = summary.days.reduce(0) { $0 + $1.backToBackPasses }
        let withoutTag = summary.days.reduce(0) { $0 + $1.endedWithoutTag }
        InsightCard(title: "Passes", symbol: "hourglass", tint: Theme.pass) {
            HStack(spacing: 24) {
                number("\(summary.totalPasses)", "taken", Theme.text)
                number("\(backToBack)", "back-to-back", backToBack > 0 ? Theme.passText : Theme.text)
                number("\(withoutTag)", "ended without tag", Theme.text)
            }
            if summary.changedMind > 0 {
                Label("You changed your mind \(summary.changedMind) time\(summary.changedMind == 1 ? "" : "s"). That's the breathing pause working.",
                      systemImage: "leaf.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.focus)
            }
            let sorted = summary.intentions.sorted { $0.value > $1.value }
            if !sorted.isEmpty {
                VStack(spacing: 8) {
                    ForEach(sorted, id: \.key) { key, count in
                        let intention = PassIntention(rawValue: key)
                        HStack {
                            Label(intention?.label ?? "Not specified", systemImage: intention?.symbol ?? "questionmark.circle")
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)").font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func number(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct MorningsCard: View {
    let summary: StatsSummary

    var body: some View {
        InsightCard(title: "Mornings", symbol: "sunrise.fill", tint: Theme.gold) {
            let week = summary.days.suffix(7)
            HStack(spacing: 6) {
                ForEach(Array(week)) { day in
                    VStack(spacing: 6) {
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        ZStack {
                            Circle().fill(day.checkIn != nil ? Theme.gold : Theme.secondaryText.opacity(0.12))
                            if day.checkIn != nil {
                                Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 30, height: 30)
                        Text(day.checkIn?.formatted(.dateTime.hour().minute()) ?? " ")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if summary.snoozes > 0 {
                Text("Alarm stopped \(summary.snoozes) time\(summary.snoozes == 1 ? "" : "s") before reaching your desk.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            if summary.checkIns == 0 {
                Text("Turn on the wake alarm in Rules. Each morning you tap your desk tag shows up here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }
}

private struct TipCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Theme.gold)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.gold.opacity(0.12)))
    }
}

private struct ScreenTimeCard: View {
    let days: Int

    private var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end)) ?? end
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Screen Time", systemImage: "iphone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding([.top, .horizontal], 16)
            DeviceActivityReport(.screenTime, filter: filter)
                .frame(minHeight: 520)
            Text("Shown privately by iOS. Tawfeeq can't read or share these numbers.")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .padding([.bottom, .horizontal], 16)
        }
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
    }
}
