import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @ObservedObject var buddyService: LocalBuddyService

    var body: some View {
        Form {
            appSettingsSection
            dataSection
            aboutSection
            accountSection
        }
        .navigationTitle("Settings")
    }

    private var appSettingsSection: some View {
        Section("App Settings") {
            NavigationLink {
                ScreenTimeDefaultsSettingsView()
            } label: {
                settingsRow(
                    icon: "timer",
                    title: "Screen Time Defaults",
                    subtitle: "Focus length & warm-up"
                )
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                settingsRow(
                    icon: "bell.badge",
                    title: "Notifications",
                    subtitle: "Daily summary & challenge alerts"
                )
            }

            NavigationLink {
                PrivacySettingsView()
            } label: {
                settingsRow(
                    icon: "lock.shield",
                    title: "Privacy & Sharing",
                    subtitle: "Leaderboard visibility"
                )
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            HStack {
                Text("Buddies on device")
                Spacer()
                Text("\(buddyService.buddies.count)")
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {} label: {
                Text("Reset local data")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "lock.circle")
                    .foregroundColor(.blue)

                VStack(alignment: .leading) {
                    Text("BuddyLock")
                    Text("Screen time & challenges")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Version")
                Spacer()
                Text("1.0")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
    
    private var accountSection: some View {
        Section("Account") {
            Button(role: .destructive) {
                signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                    Spacer()
                }
            }
        }
    }

    // Add this helper method
    private func signOut() {
        // Example using Firebase Auth
        do {
            try Auth.auth().signOut()
            // Optionally navigate to login screen here
            print("Signed out successfully")
        } catch {
            print("Sign out failed: \(error.localizedDescription)")
        }
    }

}

#Preview {
    let service = LocalBuddyService()
    return NavigationStack {
        SettingsView(buddyService: service)
    }
}
