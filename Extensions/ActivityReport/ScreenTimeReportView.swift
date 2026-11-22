import Charts
import SwiftUI

struct ScreenTimeReportView: View {
    let summary: ScreenTimeSummary

    private var today: DayUsage? {
        summary.days.first { Calendar.current.isDateInToday($0.day) }
    }

    private var dailyAverage: TimeInterval {
        let days = summary.days.filter { $0.duration > 0 }
        return days.isEmpty ? 0 : days.reduce(0) { $0 + $1.duration } / Double(days.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen time today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Self.format(today?.duration ?? 0))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Daily average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Self.format(dailyAverage))
                        .font(.headline.monospacedDigit())
                }
            }

            if summary.days.count > 1 {
                Chart(summary.days) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("Hours", day.duration / 3600)
                    )
                    .foregroundStyle(Calendar.current.isDateInToday(day.day) ? Color.accentColor : Color.accentColor.opacity(0.35))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel { if let hours = value.as(Double.self) { Text("\(Int(hours))h") } }
                    }
                }
                .frame(height: 140)
            }

            HStack(spacing: 12) {
                stat("Pickups", "\(summary.pickups)", symbol: "iphone.radiowaves.left.and.right")
                stat("First pickup", summary.firstPickup?.formatted(date: .omitted, time: .shortened) ?? "–", symbol: "sunrise")
            }

            if !summary.topApps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Most used")
                        .font(.headline)
                    let maxDuration = summary.topApps.first?.duration ?? 1
                    ForEach(summary.topApps) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.name).font(.subheadline).lineLimit(1)
                                Spacer()
                                Text(Self.format(app.duration))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.6))
                                    .frame(width: max(4, proxy.size.width * app.duration / max(maxDuration, 1)))
                            }
                            .frame(height: 4)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func stat(_ title: String, _ value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.1)))
    }

    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
