
// Sample Shield UI Extension code. Add a new "Managed Settings UI Extension" target in Xcode,
// then include these classes in that target. This lets you customize the overlay shown
// when a blocked app is opened and implement an "Ask a Friend" button that defers.

#if canImport(ManagedSettingsUI)
import ManagedSettingsUI
import SwiftUI

final class ShieldDataSource: NSObject, ShieldConfigurationDataSource {
    func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            title: .text("BuddyLock"),
            subtitle: .text("This app is locked by your focus rules."),
            primaryButtonLabel: .text("Ask a Friend"),
            secondaryButtonLabel: .text("Not now")
        )
    }

    // Optional: Customize web/domain & category shields as well.
    func configuration(shielding applicationCategory: Application.Category) -> ShieldConfiguration {
        ShieldConfiguration(
            title: .text("Category blocked"),
            subtitle: .text("\(applicationCategory.localizedDisplayName) is limited right now."),
            primaryButtonLabel: .text("Ask a Friend"),
            secondaryButtonLabel: .text("Not now")
        )
    }
}

final class ShieldActionHandler: NSObject, ShieldActionDelegate {
    func handle(action: ShieldAction, for application: Application, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButton:
            // Defer while your main app/server asks a buddy.
            // When a buddy approves, remove the shield from ManagedSettingsStore in the main app.
            completionHandler(.defer)
        case .secondaryButton, .close:
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }
}
#endif
