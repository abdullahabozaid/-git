import DeviceActivity
import ManagedSettings
import SwiftUI

/// Screen-time charts shown inside Tawfeeq's Stats tab.
/// iOS runs this in a sandbox: it can show usage, but can't send it anywhere.
@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ScreenTimeReport { summary in
            ScreenTimeReportView(summary: summary)
        }
    }
}


struct AppUsage: Identifiable {
    let id: String
    let name: String
    let token: ApplicationToken?
    let duration: TimeInterval
    let pickups: Int
}

struct DayUsage: Identifiable {
    let day: Date
    let duration: TimeInterval
    var id: Date { day }
}

struct ScreenTimeSummary {
    var total: TimeInterval = 0
    var pickups = 0
    var firstPickup: Date?
    var days: [DayUsage] = []
    var topApps: [AppUsage] = []
}

struct ScreenTimeReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .screenTime
    let content: (ScreenTimeSummary) -> ScreenTimeReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeSummary {
        var summary = ScreenTimeSummary()
        var perDay: [Date: TimeInterval] = [:]
        var apps: [String: AppUsage] = [:]
        let calendar = Calendar.current

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                perDay[day, default: 0] += segment.totalActivityDuration
                summary.total += segment.totalActivityDuration
                summary.pickups += segment.totalPickupsWithoutApplicationActivity
                if let first = segment.firstPickup, calendar.isDateInToday(first) {
                    summary.firstPickup = min(summary.firstPickup ?? first, first)
                }
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "App"
                        let key = app.application.bundleIdentifier ?? name
                        let previous = apps[key]
                        apps[key] = AppUsage(
                            id: key,
                            name: name,
                            token: app.application.token,
                            duration: (previous?.duration ?? 0) + app.totalActivityDuration,
                            pickups: (previous?.pickups ?? 0) + app.numberOfPickups
                        )
                        summary.pickups += app.numberOfPickups
                    }
                }
            }
        }

        summary.days = perDay.map { DayUsage(day: $0.key, duration: $0.value) }.sorted { $0.day < $1.day }
        summary.topApps = Array(apps.values.sorted { $0.duration > $1.duration }.prefix(8))
        return summary
    }
}
