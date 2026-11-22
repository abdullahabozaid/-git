import Charts
import DeviceActivity
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var range: StatsRange = .week
    @State private var summary: StatsSummary?

    enum StatsRange: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
        var label: String { self == .week ? "Week" : "Month" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(StatsRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if let summary {
                        StreakCard(summary: summary)
                        FocusChartCard(summary: summary)
                        PassesCard(summary: summary)
                        MorningCard(summary: summary)
                    }

                    ScreenTimeCard(days: range.days)
                }
                .padding()
            }
            .navigationTitle("Stats")
            .onAppear(perform: reload)
            .onChange(of: range) { _, _ in reload() }
        }
    }

    private func reload() {
        summary = model.stats(days: range.days)
    }
}

// MARK: - Cards

private struct Card<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

private struct StreakCard: View {
    let summary: StatsSummary

    var body: some View {
        Card(title: "Streak", symbol: "flame.fill") {
            HStack(alignment: .firstTextBaseline) {
                Text("\(summary.currentStreak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text(summary.currentStreak == 1 ? "day" : "days")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Best").font(.caption).foregroundStyle(.secondary)
                    Text("\(summary.bestStreak) days").font(.headline)
                }
            }
            Text("Days with at least \(Formatting.duration(TimeInterval(summary.goalMinutes * 60))) of focus.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FocusChartCard: View {
    let summary: StatsSummary

    var body: some View {
        Card(title: "Focus", symbol: "target") {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatting.duration(summary.totalFocus))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("total").foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Longest").font(.caption).foregroundStyle(.secondary)
                    Text(Formatting.duration(summary.longestSession)).font(.headline)
                }
            }
            Chart {
                ForEach(summary.days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Hours", day.focusSeconds / 3600)
                    )
                    .foregroundStyle(day.focusSeconds >= Double(summary.goalMinutes * 60) ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .cornerRadius(4)
                }
                RuleMark(y: .value("Goal", Double(summary.goalMinutes) / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { if let hours = value.as(Double.self) { Text("\(Int(hours))h") } }
                }
            }
            .frame(height: 160)
        }
    }
}

private struct PassesCard: View {
    let summary: StatsSummary

    var body: some View {
        let backToBack = summary.days.reduce(0) { $0 + $1.backToBackPasses }
        Card(title: "Passes", symbol: "hourglass") {
            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("\(summary.totalPasses)").font(.title.bold())
                    Text("taken").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("\(backToBack)").font(.title.bold())
                        .foregroundStyle(backToBack > 0 ? Color.orange : Color.primary)
                    Text("back-to-back").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if backToBack > 0 {
                Text("Back-to-back passes mean you reopened apps within 2 minutes of a pass ending.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MorningCard: View {
    let summary: StatsSummary

    var body: some View {
        let checkIns = summary.days.filter { $0.checkIn != nil }.suffix(7)
        Card(title: "Mornings", symbol: "sunrise.fill") {
            if checkIns.isEmpty {
                Text("Turn on the wake alarm in Routine. Each morning you tap your desk tag shows up here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(checkIns)) { day in
                    HStack {
                        Text(day.day.formatted(.dateTime.weekday(.abbreviated).day()))
                        Spacer()
                        if let checkIn = day.checkIn {
                            Text(checkIn.formatted(date: .omitted, time: .shortened)).monospacedDigit()
                        }
                        if let minutes = day.minutesFromAlarm {
                            Text(minutes <= 0 ? "on time" : "+\(minutes)m")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill((minutes <= 5 ? Color.green : Color.orange).opacity(0.2)))
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
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
        DeviceActivityReport(.screenTime, filter: filter)
            .frame(minHeight: 520)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}
