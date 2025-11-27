import SwiftUI

struct ProfileView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @AppStorage("BuddyLock.displayName") private var displayName: String = ""

    var body: some View {
        List {
            // Simple header
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Your Display Name" : displayName)
                            .font(.headline)
                        Text("BuddyLock user")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Placeholder stats (you can hook this into ScreenTime later)
            Section("Screen Time") {
                Text("Personal stats and achievements coming soon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Settings") {
                NavigationLink {
                    SettingsView(buddyService: buddyService)
                } label: {
                    Label("App Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Profile")
    }
}


#Preview {
    let buddies = LocalBuddyService()
    // Seed a fake buddy for the preview if you want
    buddies.addBuddy(name: "Preview Buddy")

    return NavigationStack {
        ProfileView(buddyService: buddies)
    }
}
