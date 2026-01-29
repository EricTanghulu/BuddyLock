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
            // MARK: - Pending friend requests
            if !friendRequests.incomingRequests.isEmpty {
                Section("Pending Requests") {
                    ForEach(friendRequests.incomingRequests) { request in
                        HStack {
                            Text(request.fromUserID) // later: username / displayName
                                .font(.subheadline)

                            Spacer()

                            Button("Accept") {
                                Task {
                                    do {
                                        try await friendRequests.accept(request)
                                    } catch {
                                        print("❌ Failed to accept:", error.localizedDescription)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)

                            Button("Deny") {
                                Task {
                                    do {
                                        try await friendRequests.reject(request)
                                    } catch {
                                        print("❌ Failed to reject request:", error.localizedDescription)
                                    }
                                }
                            }

                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
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
                                buddyService.removeBuddy(buddy)
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
