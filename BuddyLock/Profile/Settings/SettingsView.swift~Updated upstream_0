import SwiftUI

struct SettingsView: View {
    @ObservedObject var buddyService: LocalBuddyService

    @AppStorage("BuddyLock.displayName") private var displayName: String = ""

    var body: some View {
        Form {
            // Profile
            Section("Profile") {
                TextField("Display name (optional)", text: $displayName)
                Text("Your name can be shown to buddies and on challenge leaderboards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Buddies management lives here now
            Section("Buddies") {
                NavigationLink {
                    BuddyListView(service: buddyService)
                } label: {
                    Label("Manage Buddies", systemImage: "person.2.fill")
                }
                Text("Add or remove buddies. Buddies can approve unlock requests and join challenges.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // App preferences (placeholders you can flesh out)
            Section("Preferences") {
                Toggle(isOn: .constant(true)) {
                    Text("Enable motivational nudges")
                }
                .disabled(true)

                Toggle(isOn: .constant(true)) {
                    Text("Daily summary notifications")
                }
                .disabled(true)

                Text("More preferences coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1 (Prototype)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text("Local-only demo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}
