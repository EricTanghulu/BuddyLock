import SwiftUI

struct FriendsHubView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService
    @EnvironmentObject var screenTime: ScreenTimeManager

    var body: some View {
        List {
            Section("Quick Actions") {
                NavigationLink {
                    AskBuddyView(
                        buddyService: buddyService,
                        requestService: requestService
                    )
                    .environmentObject(screenTime)
                } label: {
                    Label("Ask a Buddy", systemImage: "paperplane.fill")
                }

                NavigationLink {
                    ApprovalsView(
                        buddyService: buddyService,
                        requestService: requestService
                    ) { minutes in
                        // Fallback path: general exception
                        screenTime.grantTemporaryException(minutes: minutes)
                    }
                    .environmentObject(screenTime)
                } label: {
                    Label("Approve Requests", systemImage: "checkmark.seal")
                }
            }

            Section("Buddies") {
                NavigationLink {
                    BuddyListView(buddyService: buddyService,
                                  friendRequests: friendRequestService)
                } label: {
                    Label("Manage Buddies", systemImage: "person.badge.plus")
                }

                Text("Buddies can approve unlock requests and join challenges.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Friends")
    }
}
