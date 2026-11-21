import DeviceActivity
import Foundation

/// Runs in the background, woken by iOS at schedule boundaries.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .pass {
            // Re-block after a temporary pass. Ending a little early is the safe direction,
            // so we don't second-guess the timing here.
            PassManager.end(reason: "expired")
        }
    }
}
