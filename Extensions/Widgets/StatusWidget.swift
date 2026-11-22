import AppIntents
import SwiftUI
import WidgetKit

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), snapshot: WidgetSnapshot(mode: .idle, sessionStart: nil, passEnd: nil,
                                                           focusToday: 4500, goal: 7200, streak: 5))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), snapshot: context.isPreview ? placeholder(in: context).snapshot : .current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.current(now: now)
        var entries = [StatusEntry(date: now, snapshot: snapshot)]
        // When a pass ends, flip back to "focusing" without waiting for the app.
        if let passEnd = snapshot.passEnd {
            var after = snapshot
            after.mode = .focusing
            after.passEnd = nil
            entries.append(StatusEntry(date: passEnd, snapshot: after))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "uk.tawfeeq.status", provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.background }
        }
        .configurationDisplayName("Tawfeeq")
        .description("Your focus right now, today's progress and your streak.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
    }
}

enum WidgetPalette {
    static let background = Theme.background
    static func tint(_ mode: WidgetSnapshot.Mode) -> Color {
        switch mode {
        case .idle, .focusing: Theme.focus
        case .pass: Theme.pass
        case .night: Theme.night
        }
    }

    static func symbol(_ mode: WidgetSnapshot.Mode) -> String {
        switch mode {
        case .idle: "wave.3.right"
        case .focusing: "lock.fill"
        case .pass: "hourglass"
        case .night: "moon.stars.fill"
        }
    }

    static func title(_ mode: WidgetSnapshot.Mode) -> String {
        switch mode {
        case .idle: "Ready"
        case .focusing: "Focusing"
        case .pass: "On a pass"
        case .night: "Night lock"
        }
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var progress: Double { snapshot.goal > 0 ? min(1, snapshot.focusToday / snapshot.goal) : 0 }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // Lock Screen: focus ring vs goal.
    private var circular: some View {
        Gauge(value: progress) {
            Image(systemName: WidgetPalette.symbol(snapshot.mode))
        } currentValueLabel: {
            Text(Self.shortDuration(snapshot.focusToday))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    // Lock Screen: status line.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(WidgetPalette.title(snapshot.mode), systemImage: WidgetPalette.symbol(snapshot.mode))
                .font(.headline)
                .widgetAccentable()
            timerOrToday
                .font(.body.monospacedDigit())
            Text("\(snapshot.streak)-day streak")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        switch snapshot.mode {
        case .idle: Text("\(Image(systemName: "flame.fill")) \(snapshot.streak)-day streak · \(Self.shortDuration(snapshot.focusToday)) today")
        default: Text("\(Image(systemName: WidgetPalette.symbol(snapshot.mode))) \(WidgetPalette.title(snapshot.mode))")
        }
    }

    @ViewBuilder
    private var timerOrToday: some View {
        switch snapshot.mode {
        case .pass:
            if let end = snapshot.passEnd { Text(timerInterval: entry.date...end, countsDown: true) }
        case .focusing, .night:
            if let start = snapshot.sessionStart { Text(timerInterval: start...Date.distantFuture, countsDown: false) }
        case .idle:
            Text("\(Self.shortDuration(snapshot.focusToday)) today")
        }
    }

    // Home Screen small: state + start button.
    private var small: some View {
        let tint = WidgetPalette.tint(snapshot.mode)
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: WidgetPalette.symbol(snapshot.mode))
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
            Text(WidgetPalette.title(snapshot.mode))
                .font(.headline)
                .foregroundStyle(Theme.text)
            timerOrToday
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            if snapshot.mode == .idle {
                Button(intent: StartFocusIntent()) {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.focus)
            } else {
                Text("\(snapshot.streak)-day streak")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Home Screen medium: today's ring + stats.
    private var medium: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Theme.focus.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.focus, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(Self.shortDuration(snapshot.focusToday))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(Theme.text)
                    Text("of \(Self.shortDuration(snapshot.goal))")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 8) {
                Label(WidgetPalette.title(snapshot.mode), systemImage: WidgetPalette.symbol(snapshot.mode))
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.tint(snapshot.mode))
                timerOrToday
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.text)
                Label("\(snapshot.streak)-day streak", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gold)
                if snapshot.mode == .idle {
                    Button(intent: StartFocusIntent()) {
                        Text("Start focus").font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.focus)
                }
            }
            Spacer(minLength: 0)
        }
    }

    static func shortDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        return minutes >= 60 ? "\(minutes / 60)h\(minutes % 60 == 0 ? "" : "\(minutes % 60)")" : "\(minutes)m"
    }
}

// MARK: - Control Center / Lock Screen / Action button

struct StartFocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "uk.tawfeeq.control.start") {
            ControlWidgetButton(action: StartFocusIntent()) {
                Label("Start Focus", systemImage: "circle.circle.fill")
            }
        }
        .displayName("Start Focus")
        .description("Start a Tawfeeq session. Ending it needs your desk tag.")
    }
}

struct ScanTagControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "uk.tawfeeq.control.scan") {
            ControlWidgetButton(action: ScanDeskTagIntent()) {
                Label("Scan Desk Tag", systemImage: "wave.3.right")
            }
        }
        .displayName("Scan Desk Tag")
        .description("Open Tawfeeq straight into a desk-tag scan.")
    }
}
