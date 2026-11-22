#if DEBUG
import Foundation

/// Launch with `-demo <scene>` to show the app in a fixed state with fake data.
/// Used by .github/workflows/screenshots.yml to render every screen in the simulator.
enum DemoScene: String, CaseIterable {
    case idle, empty, focusing, pass, passSheet, night, morning, summary
    case insights, rules, settings, largeText
    case onboarding0, onboarding1, onboarding2, onboarding3, onboarding4, onboarding5, onboarding6

    static func fromLaunchArguments() -> DemoScene? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-demo"), index + 1 < args.count else { return nil }
        return DemoScene(rawValue: args[index + 1])
    }

    var tab: String? {
        switch self {
        case .insights: "insights"
        case .rules: "rules"
        case .settings: "settings"
        default: nil
        }
    }

    var onboardingStep: Int? {
        rawValue.hasPrefix("onboarding") ? Int(rawValue.dropFirst("onboarding".count)) : nil
    }
}

enum DemoData {
    static let tags: [EnrolledTag] = [
        EnrolledTag(id: UUID(), name: "Desk", role: .desk, uid: "04a1b2c3d4e5f6", secret: "demo", hasLink: true,
                    enrolledAt: Date().addingTimeInterval(-20 * 86400), lastScannedAt: Date().addingTimeInterval(-42 * 60)),
        EnrolledTag(id: UUID(), name: "Drawer", role: .spare, uid: "04ffeeddccbbaa", secret: "demo2", hasLink: true,
                    enrolledAt: Date().addingTimeInterval(-19 * 86400), lastScannedAt: nil),
    ]

    static var routine: Routine {
        var routine = Routine()
        routine.wakeEnabled = true
        routine.wakeTime = TimeOfDay(hour: 6, minute: 45)
        routine.nightLockEnabled = true
        routine.nightLockStart = TimeOfDay(hour: 22, minute: 30)
        return routine
    }

    /// A believable month: 1–4 sessions a day, a few passes, mornings, one missed day.
    static func events(now: Date) -> [LogEvent] {
        var events: [LogEvent] = []
        let calendar = Calendar.current
        let intentions: [PassIntention] = [.message, .message, .navigation, .work, .other]
        var seed: UInt64 = 42
        func random(_ range: ClosedRange<Int>) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return range.lowerBound + Int((seed >> 33) % UInt64(range.count))
        }

        for offset in stride(from: 34, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)) else { continue }
            if offset == 9 || offset == 23 { continue } // missed days
            let weekday = calendar.component(.weekday, from: day)

            if (2...6).contains(weekday), let checkIn = calendar.date(bySettingHour: 6, minute: 45 + random(0...14), second: 0, of: day) {
                if random(0...3) == 0 { events.append(LogEvent(date: checkIn.addingTimeInterval(-180), kind: .alarmStopped)) }
                events.append(LogEvent(date: checkIn, kind: .morningCheckIn,
                                       info: ["minutesFromAlarm": String(calendar.component(.minute, from: checkIn) - 45)]))
            }

            var hour = 9
            for _ in 0..<random(1...4) {
                let minutes = random(25...95)
                guard let start = calendar.date(bySettingHour: hour, minute: random(0...30), second: 0, of: day) else { continue }
                let end = start.addingTimeInterval(TimeInterval(minutes * 60))
                events.append(LogEvent(date: start, kind: .sessionStarted, info: ["source": "tagScan"]))
                if random(0...2) == 0 {
                    events.append(LogEvent(date: start.addingTimeInterval(1200), kind: .passStarted,
                                           info: ["source": random(0...1) == 0 ? "app" : "shield",
                                                  "intention": intentions[random(0...4)].rawValue,
                                                  "backToBack": random(0...6) == 0 ? "true" : "false"]))
                }
                if random(0...3) == 0 {
                    events.append(LogEvent(date: start.addingTimeInterval(1800), kind: .passAbandoned))
                }
                events.append(LogEvent(date: end, kind: .sessionEnded,
                                       info: ["source": "tagScan", "endedBy": "tag", "durationSeconds": String(minutes * 60)]))
                hour += 2 + random(0...2)
            }
        }

        // Today: one finished session, one pass, morning check-in.
        let today = calendar.startOfDay(for: now)
        if let checkIn = calendar.date(bySettingHour: 6, minute: 51, second: 0, of: today), checkIn < now {
            events.append(LogEvent(date: checkIn, kind: .morningCheckIn, info: ["minutesFromAlarm": "6"]))
        }
        if let start = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: today), start.addingTimeInterval(3000) < now {
            events.append(LogEvent(date: start.addingTimeInterval(3000), kind: .sessionEnded,
                                   info: ["source": "tagScan", "endedBy": "tag", "durationSeconds": "3000"]))
            events.append(LogEvent(date: start.addingTimeInterval(1500), kind: .passStarted,
                                   info: ["source": "app", "intention": "message", "backToBack": "false"]))
        }
        return events.sorted { $0.date < $1.date }
    }
}
#endif
