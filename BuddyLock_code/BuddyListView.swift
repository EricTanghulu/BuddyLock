import SwiftUI

struct BuddyListView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequests: FriendRequestService

    @State private var friendUserID: String = ""
    @State private var sent = false

    var body: some View {
        Form {

            // MARK: - Send friend request
            Section("Add Buddy") {
                TextField("Friend's user ID", text: $friendUserID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task { // async context
                        do {
                            try await friendRequests.sendRequest(targetID: friendUserID)
                            friendUserID = ""
                            sent = true
                        } catch {
                            print("❌ Failed to send friend request:", error.localizedDescription)
                            sent = false
                        }
                    }
                } label: {
                    Label("Send friend request", systemImage: "paperplane.fill")
                }
                .disabled(friendUserID.isEmpty)

                if sent {
                    Text("Friend request sent")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }

            // MARK: - Buddy list
            Section("Your Buddies") {
                if buddyService.buddies.isEmpty {
                    Text("No buddies yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(buddyService.buddies) { buddy in
                        HStack {
                            Image(systemName: "person.fill")
                            Text(buddy.displayName ?? buddy.buddyUserID)
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { // async context
                                    do {
                                        try await buddyService.removeBuddy(buddy)
                                    } catch {
                                        print("❌ Failed to remove buddy:", error.localizedDescription)
                                    }
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Buddies")
    }
}
