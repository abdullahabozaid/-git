import SwiftUI

/// UX metrics from the local event log (never sent anywhere). See docs/usability.md §4.
struct DiagnosticsView: View {
    @State private var report = Report()

    struct Report {
        var scans = 0
        var scanFailures = 0
        var topFailure: String?
        var timeToFirstSession: TimeInterval?
        var passSheets = 0
        var passesTaken = 0
        var changedMind = 0
        var events = 0

        var scanSuccessRate: Double? { scans + scanFailures == 0 ? nil : Double(scans) / Double(scans + scanFailures) }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Scan success", value: report.scanSuccessRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "No scans yet")
                LabeledContent("Scans", value: "\(report.scans + report.scanFailures)")
                if let reason = report.topFailure {
                    LabeledContent("Most common problem", value: reason)
                }
            } header: {
                Text("NFC (last 30 days)")
            } footer: {
                if let rate = report.scanSuccessRate, rate < 0.9 {
                    Text("Under 90%: try moving the sticker so the top edge of your iPhone rests flat on it, away from metal.")
                }
            }

            Section("Passes (last 30 days)") {
                LabeledContent("Pass screens opened", value: "\(report.passSheets)")
                LabeledContent("Passes taken", value: "\(report.passesTaken)")
                LabeledContent("Changed my mind", value: "\(report.changedMind)")
            }

            Section {
                LabeledContent("Setup to first session",
                               value: report.timeToFirstSession.map { Formatting.duration(max(60, $0)) } ?? "–")
                LabeledContent("Events recorded", value: "\(report.events)")
            } header: {
                Text("Getting started")
            } footer: {
                Text("Everything here is calculated on your iPhone from Tawfeeq's own history.")
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .task { report = Self.build() }
    }

    static func build(now: Date = Date()) -> Report {
        let events = EventLog.all()
        let since = now.addingTimeInterval(-30 * 24 * 3600)
        var report = Report(events: events.count)
        var failures: [String: Int] = [:]
        var onboardingStart: Date?
        var firstSession: Date?

        for event in events {
            switch event.kind {
            case .onboardingStarted: onboardingStart = onboardingStart ?? event.date
            case .sessionStarted: firstSession = firstSession ?? event.date
            default: break
            }
            guard event.date >= since else { continue }
            switch event.kind {
            case .scanSucceeded: report.scans += 1
            case .scanFailed:
                report.scanFailures += 1
                failures[event.info["reason"] ?? "Unknown", default: 0] += 1
            case .passSheetOpened, .shieldPassRequested: report.passSheets += 1
            case .passStarted: report.passesTaken += 1
            case .passAbandoned: report.changedMind += 1
            default: break
            }
        }
        report.topFailure = failures.max { $0.value < $1.value }?.key
        if let start = onboardingStart, let first = firstSession, first > start {
            report.timeToFirstSession = first.timeIntervalSince(start)
        }
        return report
    }
}
