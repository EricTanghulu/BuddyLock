import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage("BuddyLock.settings.shareUsageWithBuddies")
    private var shareUsageWithBuddies: Bool = true

    @AppStorage("BuddyLock.settings.showOnLeaderboards")
    private var showOnLeaderboards: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle("Share screen time with buddies", isOn: $shareUsageWithBuddies)
                Toggle("Show me on leaderboards", isOn: $showOnLeaderboards)
            }

            Section {
                Text("BuddyLock stores your data locally on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & Sharing")
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
