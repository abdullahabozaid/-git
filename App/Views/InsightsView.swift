import Charts
import DeviceActivity
import SwiftUI

/// Motivating, never shaming: what went well first, honest detail after.
struct InsightsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var current: StatsSummary?
    @State private var previousWeek: TimeInterval = 0
    @State private var month: StatsSummary?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let current, let month {
                        WeekCard(summary: current, previousWeek: previousWeek)
                        if let tip = suggestion(month) {
                            TipCard(text: tip)
                        }
                        RhythmCard(month: month)
                        FocusChartCard(summary: month)
                        PassesCard(summary: month)
                        MorningsCard(summary: current)
                    }
                    ScreenTimeCard()
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Insights")
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        let twoWeeks = model.stats(days: 14)
        previousWeek = twoWeeks.days.prefix(7).reduce(0) { $0 + $1.focusSeconds }
        current = model.stats(days: 7)
        month = model.stats(days: 28)
    }

    /// One specific, positive suggestion from your own data.
    private func suggestion(_ summary: StatsSummary) -> String? {
        if summary.changedMind >= 2 {
            return "You paused and changed your mind \(summary.changedMind) times this month. That's the habit forming."
        }
        if summary.totalPasses >= 4, let peak = summary.passHours.max(by: { $0.value < $1.value })?.key {
            let start = Calendar.current.date(bySettingHour: peak, minute: 0, second: 0, of: Date()) ?? Date()
            return "Passes cluster around \(start.formatted(.dateTime.hour())). A short walk then might help."
        }
        if let best = summary.days.max(by: { $0.focusSeconds < $1.focusSeconds }), best.focusSeconds > 0 {
            return "Your best day was \(best.day.formatted(.dateTime.weekday(.wide))): \(Formatting.duration(best.focusSeconds))."
        }
        return summary.totalFocus == 0 ? "Tap your desk tag when you sit down to work. Your first session will appear here." : nil
    }
}

// MARK: - Cards

struct InsightCard<Content: View>: View {
    let title: String
    let symbol: String
    var tint: Color = Theme.secondaryText
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
    }
}

/// Seven daily rings (filled toward the goal) and the week's total.
private struct WeekCard: View {
    let summary: StatsSummary
    let previousWeek: TimeInterval

    @ScaledMetric(relativeTo: .largeTitle) private var totalSize: CGFloat = 40

    var body: some View {
        let goal = TimeInterval(summary.goalMinutes * 60)
        let daysOnGoal = summary.days.filter { $0.focusSeconds >= goal }.count
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 0) {
                ForEach(summary.days) { day in
                    VStack(spacing: 6) {
                        DayRing(progress: goal > 0 ? min(1, day.focusSeconds / goal) : 0,
                                reached: day.focusSeconds >= goal && goal > 0,
                                isToday: Calendar.current.isDateInToday(day.day))
                            .frame(width: 34, height: 34)
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.day.formatted(.dateTime.weekday(.wide))): \(Formatting.duration(day.focusSeconds))")
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Formatting.duration(summary.totalFocus))
                    .font(.system(size: min(totalSize, 60), weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(caption(daysOnGoal: daysOnGoal))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface))
    }

    /// Only ever good news or neutral; never a negative delta.
    private func caption(daysOnGoal: Int) -> String {
        let goalPart = "\(daysOnGoal) of 7 days on goal"
        let delta = summary.totalFocus - previousWeek
        if previousWeek > 0, delta >= 15 * 60 {
            return "\(goalPart) · \(Formatting.duration(delta)) more than the week before"
        }
        return summary.totalFocus > 0 ? "\(goalPart) · steady" : "Your week starts at your desk"
    }
}

private struct DayRing: View {
    let progress: Double
    let reached: Bool
    let isToday: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Theme.focus.opacity(0.14), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(reached ? Theme.gold : Theme.focus, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isToday {
                Circle().fill(Theme.text.opacity(0.7)).frame(width: 4, height: 4)
            }
        }
    }
}

/// "Rhythm": days on goal in the last 4 weeks, with a weekday-labelled grid.
private struct RhythmCard: View {
    let month: StatsSummary

    var body: some View {
        let goal = TimeInterval(month.goalMinutes * 60)
        let met = month.days.filter { $0.focusSeconds >= goal }.count
        let calendar = Calendar.current
        // Align the grid so columns are weekdays.
        let firstWeekday = calendar.component(.weekday, from: month.days.first?.day ?? Date())
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let symbols = (0..<7).map { calendar.veryShortWeekdaySymbols[(calendar.firstWeekday - 1 + $0) % 7] }

        InsightCard(title: "Rhythm", symbol: "leaf.fill", tint: Theme.focus) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(met)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("of \(month.days.count) days on goal")
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                if month.currentStreak >= 2 {
                    Label("\(month.currentStreak) in a row", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 26) }
                ForEach(month.days) { day in
                    ZStack {
                        if day.focusSeconds >= goal {
                            Circle().fill(Theme.focus)
                        } else if day.focusSeconds > 0 {
                            Circle().stroke(Theme.focus.opacity(0.6), lineWidth: 2)
                        } else {
                            Circle().fill(Theme.secondaryText.opacity(0.10))
                        }
                        if day.isGraceDay {
                            Circle().fill(Theme.gold).frame(width: 7, height: 7)
                        }
                    }
                    .frame(height: 26)
                    .overlay(Circle().stroke(Theme.text.opacity(calendar.isDateInToday(day.day) ? 0.55 : 0), lineWidth: 1.5).padding(-3))
                    .accessibilityLabel("\(day.day.formatted(date: .abbreviated, time: .omitted)): \(Formatting.duration(day.focusSeconds))")
                }
            }
            Text("Filled: \(Formatting.duration(goal)) or more. Gold dot: a missed day that's forgiven (one a week).")
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
                    .foregroundStyle(day.focusSeconds >= Double(summary.goalMinutes * 60) ? Theme.focus : Theme.focus.opacity(0.35))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Goal", Double(summary.goalMinutes) / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.gold)
                    .annotation(position: .top, alignment: .leading) {
                        Text("goal").font(.caption2).foregroundStyle(Theme.gold)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
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

/// Leads with the good news: times you changed your mind.
private struct PassesCard: View {
    let summary: StatsSummary

    var body: some View {
        InsightCard(title: "Passes", symbol: "hourglass", tint: Theme.passText) {
            if summary.changedMind > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.changedMind)")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.focus)
                    Text(summary.changedMind == 1 ? "time you changed your mind" : "times you changed your mind")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            let backToBack = summary.days.reduce(0) { $0 + $1.backToBackPasses }
            Text("\(summary.totalPasses) pass\(summary.totalPasses == 1 ? "" : "es") taken\(backToBack > 0 ? " · \(backToBack) close together" : "")")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            let sorted = summary.intentions.sorted { $0.value > $1.value }
            let total = max(1, sorted.reduce(0) { $0 + $1.value })
            if !sorted.isEmpty {
                VStack(spacing: 10) {
                    ForEach(sorted, id: \.key) { key, count in
                        let intention = PassIntention(rawValue: key)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(intention?.label ?? "No reason given", systemImage: intention?.symbol ?? "questionmark.circle")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.secondaryText)
                            }
                            GeometryReader { proxy in
                                Capsule().fill(Theme.pass.opacity(0.5))
                                    .frame(width: max(6, proxy.size.width * Double(count) / Double(total)))
                            }
                            .frame(height: 5)
                        }
                    }
                }
            }
        }
    }
}

/// Check-ins as positive stamps. Never "late".
private struct MorningsCard: View {
    let summary: StatsSummary

    var body: some View {
        InsightCard(title: "Mornings", symbol: "sunrise.fill", tint: Theme.gold) {
            HStack(spacing: 4) {
                ForEach(summary.days) { day in
                    VStack(spacing: 6) {
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                        ZStack {
                            Circle().fill(day.checkIn != nil ? Theme.gold : Theme.secondaryText.opacity(0.10))
                            if day.checkIn != nil {
                                Image(systemName: "sun.max.fill").font(.caption2).foregroundStyle(Theme.onGold)
                            }
                        }
                        .frame(width: 30, height: 30)
                        Text(day.checkIn?.formatted(.dateTime.hour().minute()) ?? " ")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
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
            Image(systemName: "sparkles")
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
    private var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end)) ?? end
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
                .padding([.top, .horizontal], 18)
            DeviceActivityReport(.screenTime, filter: filter)
                .frame(minHeight: 520)
            Text("Shown privately by iOS. Tawfeeq can't read or share these numbers.")
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
                .padding([.bottom, .horizontal], 18)
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
    }
}
