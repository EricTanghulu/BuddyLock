import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private enum SharedKeys {
        static let appGroup = "group.com.example.BuddyLock"
        static let selection = "BuddyLock_UsageLimit_Selection"
        static let enabled = "BuddyLock_UsageLimit_Enabled"
        static let minutes = "BuddyLock_UsageLimit_Minutes"
        static let exceeded = "BuddyLock_UsageLimit_Exceeded"
        static let exceededAt = "BuddyLock_UsageLimit_ExceededAt"
    }

    private let usageLimitStore = ManagedSettingsStore(named: .buddyLockUsageLimitStore)

    override func intervalDidStart(for activity: DeviceActivityName) {
        guard activity == .buddyLockUsageLimit else { return }
        resetUsageLimitState()
        applyImmediateUsageLimitIfNeeded()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity == .buddyLockUsageLimit else { return }
        resetUsageLimitState()
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        guard activity == .buddyLockUsageLimit, event == .buddyLockUsageLimitThreshold else { return }
        guard isUsageLimitEnabled, let selection = loadSelection() else { return }

        applyShield(using: selection)
        markLimitExceeded()
    }

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedKeys.appGroup)
    }

    private var isUsageLimitEnabled: Bool {
        sharedDefaults?.bool(forKey: SharedKeys.enabled) ?? false
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard
            let defaults = sharedDefaults,
            let data = defaults.data(forKey: SharedKeys.selection)
        else {
            return nil
        }

        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private var storedUsageLimitMinutes: Int? {
        guard let defaults = sharedDefaults, defaults.object(forKey: SharedKeys.minutes) != nil else {
            return nil
        }

        return defaults.integer(forKey: SharedKeys.minutes)
    }

    private func applyShield(using selection: FamilyActivitySelection) {
        usageLimitStore.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        usageLimitStore.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        usageLimitStore.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    private func applyImmediateUsageLimitIfNeeded() {
        guard isUsageLimitEnabled, storedUsageLimitMinutes == 0, let selection = loadSelection() else { return }
        applyShield(using: selection)
        markLimitExceeded()
    }

    private func markLimitExceeded() {
        guard let defaults = sharedDefaults else { return }
        defaults.set(true, forKey: SharedKeys.exceeded)
        defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.exceededAt)
    }

    private func resetUsageLimitState() {
        usageLimitStore.clearAllSettings()

        guard let defaults = sharedDefaults else { return }
        defaults.set(false, forKey: SharedKeys.exceeded)
        defaults.removeObject(forKey: SharedKeys.exceededAt)
    }
}

private extension DeviceActivityName {
    static let buddyLockUsageLimit = Self("buddylock.usage-limit")
}

private extension DeviceActivityEvent.Name {
    static let buddyLockUsageLimitThreshold = Self("buddylock.usage-limit-threshold")
}

private extension ManagedSettingsStore.Name {
    static let buddyLockUsageLimitStore = Self("buddylock.usage-limit-store")
}
