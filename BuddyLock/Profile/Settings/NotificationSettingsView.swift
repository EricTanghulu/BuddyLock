import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage("BuddyLock.settings.dailySummaryEnabled")
    private var dailySummaryEnabled: Bool = true

    @AppStorage("BuddyLock.settings.challengeRemindersEnabled")
    private var challengeRemindersEnabled: Bool = true

    @AppStorage("BuddyLock.settings.newBuddyAlertsEnabled")
    private var newBuddyAlertsEnabled: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Daily summary", isOn: $dailySummaryEnabled)
                Toggle("Challenge reminders", isOn: $challengeRemindersEnabled)
                Toggle("Buddy activity", isOn: $newBuddyAlertsEnabled)
            }
        }
        .navigationTitle("Notifications")
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
