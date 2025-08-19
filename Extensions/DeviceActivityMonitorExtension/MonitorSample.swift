
// Sample Device Activity Monitor extension code. Add a "Device Activity Monitor Extension" target
// in Xcode and include this file. You can observe thresholds and schedule windows here.

#if canImport(DeviceActivity)
import DeviceActivity
import ManagedSettings

final class FocusMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Called when a scheduled activity interval begins.
        // You could apply shields here for scheduled blocks.
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Remove shields when interval ends.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }
}
#endif
