import SwiftUI

struct EditProfileView: View {
    @ObservedObject var buddyService: LocalBuddyService

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @State private var editableDisplayName: String = ""

    var body: some View {
        Form {
            Section("Profile") {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Display name" : displayName)
                            .font(.headline)

                        let count = buddyService.buddies.count
                        Text("\(count) \(count == 1 ? "buddy" : "buddies") connected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                TextField("Display name (optional)", text: $editableDisplayName)
                Text("This name is shown to your buddies and on leaderboards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            editableDisplayName = displayName
        }
        .onDisappear {
            let previousDisplayName = UserProfileStore.normalizeDisplayName(displayName) ?? ""
            let normalizedDisplayName = UserProfileStore.normalizeDisplayName(editableDisplayName) ?? ""
            guard normalizedDisplayName != previousDisplayName else {
                return
            }

            displayName = normalizedDisplayName
            Task {
                try? await UserProfileStore.updateCurrentUserDisplayName(normalizedDisplayName)
            }
        }
    }
}

#Preview {
    let service = LocalBuddyService()
    service.addBuddy(LocalBuddy(remoteID: "remote1",     // buddy doc ID
                                buddyUserID: "buddyID",               // friend's auth UID
                                )) 

    return NavigationStack {
        EditProfileView(buddyService: service)
    }
}
