import Foundation
import ManagedSettings
import UserNotifications

/// Handles what happens when the user taps the buttons on the
/// BuddyLock Screen Time shield.
///
/// Make sure this class name matches `NSExtensionPrincipalClass`
/// in the BuddyLockShieldExtension target's Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    private enum SharedKeys {
        static let appGroup = "group.com.example.BuddyLock"
        static let unlockRequested = "BuddyLock_Shield_UnlockRequested"
        static let unlockRequestedAt = "BuddyLock_Shield_UnlockRequestedAt"
        static let notificationIdentifier = "BuddyLock_Shield_UnlockRequested_Notification"
        static let destinationKey = "buddylockDestination"
        static let shieldUnlockDestination = "shieldUnlock"
    }

    // MARK: - App shields

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // "Ask for unlock" (from ShieldConfiguration)
            // For now we just mark that the user asked, and tell the
            // system we're deferring the decision (shield stays up).
            recordUnlockRequest(for: application)
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // "Stay focused" – just close the shield UI.
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Website shields

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            recordUnlockRequest(for: webDomain)
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Category shields (e.g. "Social" category as a whole)

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            recordUnlockRequest(for: category)
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Shared "unlock requested" markers

    /// These helpers write a simple flag into an App Group so your main
    /// BuddyLock app can see that the user tapped "Ask for unlock" on
    /// the shield.
    private func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedKeys.appGroup)
    }

    private func recordUnlockRequest(for application: ApplicationToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: SharedKeys.unlockRequested)
        defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.unlockRequestedAt)
        scheduleUnlockNotification()
    }

    private func recordUnlockRequest(for webDomain: WebDomainToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: SharedKeys.unlockRequested)
        defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.unlockRequestedAt)
        scheduleUnlockNotification()
    }

    private func recordUnlockRequest(for category: ActivityCategoryToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: SharedKeys.unlockRequested)
        defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.unlockRequestedAt)
        scheduleUnlockNotification()
    }

    private func scheduleUnlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Open BuddyLock to request an unlock"
        content.body = "Tap to send an unlock request or use your backup options."
        content.sound = .default
        content.userInfo = [
            SharedKeys.destinationKey: SharedKeys.shieldUnlockDestination
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: SharedKeys.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [SharedKeys.notificationIdentifier])
        center.add(request) { error in
            if let error {
                print("Failed to schedule unlock notification: \(error)")
            }
        }
    }
}
