import Foundation
import ManagedSettings

/// Handles what happens when the user taps the buttons on the
/// BuddyLock Screen Time shield.
///
/// Make sure this class name matches `NSExtensionPrincipalClass`
/// in the BuddyLockShieldExtension target's Info.plist.
class ShieldActionExtension: ShieldActionDelegate {

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
    /// the shield. Change the suiteName to match your App Group ID.
    private func sharedDefaults() -> UserDefaults? {
        // TODO: replace with your App Group identifier, e.g.
        // "group.com.yourteam.BuddyLock"
        let suiteName = "group.com.yourteam.BuddyLock"
        return UserDefaults(suiteName: suiteName)
    }

    private func recordUnlockRequest(for application: ApplicationToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: "BuddyLock_Shield_UnlockRequested")
        // You could also store more info later if needed.
    }

    private func recordUnlockRequest(for webDomain: WebDomainToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: "BuddyLock_Shield_UnlockRequested")
    }

    private func recordUnlockRequest(for category: ActivityCategoryToken) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(true, forKey: "BuddyLock_Shield_UnlockRequested")
    }
}
