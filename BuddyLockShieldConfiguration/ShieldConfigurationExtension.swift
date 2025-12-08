import Foundation
import ManagedSettings        // <-- Needed for Application, WebDomain, ActivityCategory
import ManagedSettingsUI
import UIKit

/// Configure how the system shield looks when BuddyLock blocks apps or websites.
/// Make sure this class name matches `NSExtensionPrincipalClass` in this
/// extension target's Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - App shields

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let titleLabel = ShieldConfiguration.Label(
            text: "Blocked by BuddyLock",
            color: .label
        )

        let subtitleText: String
        if let name = application.localizedDisplayName {
            subtitleText = "“\(name)” is blocked to protect your focus."
        } else {
            subtitleText = "This app is blocked to protect your focus."
        }

        let subtitleLabel = ShieldConfiguration.Label(
            text: subtitleText,
            color: .secondaryLabel
        )

        let primaryLabel = ShieldConfiguration.Label(
            text: "Ask for unlock",
            color: .white
        )

        let secondaryLabel = ShieldConfiguration.Label(
            text: "Stay focused",
            color: .systemBlue
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "lock.app.fill"),
            title: titleLabel,
            subtitle: subtitleLabel,
            primaryButtonLabel: primaryLabel,
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: secondaryLabel
        )
    }

    /// When an app is shielded because of its category (e.g. “Social”),
    /// we’ll use the same UI as for a direct app shield.
    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    // MARK: - Website shields

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let titleLabel = ShieldConfiguration.Label(
            text: "Website blocked by BuddyLock",
            color: .label
        )

        let subtitleLabel = ShieldConfiguration.Label(
            text: "“\(webDomain.domain)” is blocked to help you stay on track.",
            color: .secondaryLabel
        )

        let primaryLabel = ShieldConfiguration.Label(
            text: "Ask for unlock",
            color: .white
        )

        let secondaryLabel = ShieldConfiguration.Label(
            text: "Stay focused",
            color: .systemBlue
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "globe"),
            title: titleLabel,
            subtitle: subtitleLabel,
            primaryButtonLabel: primaryLabel,
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: secondaryLabel
        )
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
