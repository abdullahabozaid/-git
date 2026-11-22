import DeviceActivity
import Foundation

/// Runs in the background, woken by iOS at schedule boundaries.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == .nightLock {
            NightLock.begin()
        }
        // .pass intervals start in the past on purpose; nothing to do at their start.
    }

    /// Night lock deliberately does nothing at the interval end:
    /// it stays on until the desk tag is scanned in the app.

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .pass {
            // Re-block after a temporary pass. Ending a little early is the safe direction,
            // so we don't second-guess the timing here.
            PassManager.end(reason: "expired")
        }
    }
}
