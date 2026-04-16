import SwiftUI

struct FriendsHubView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService
    @EnvironmentObject var screenTime: ScreenTimeManager

    var body: some View {
        List {
            overviewSection
            quickActionsSection
            groupsSection
        }
        .navigationTitle("Friends")
    }

    private var overviewSection: some View {
        Section("Accountability Network") {
            statRow(
                title: "Buddies",
                value: "\(buddyService.buddies.count)",
                note: "People who can help you stay on track"
            )
            statRow(
                title: "Best Buddies",
                value: "\(buddyService.bestBuddyCount)",
                note: "Priority people for closer accountability"
            )
            statRow(
                title: "Groups",
                value: "\(buddyService.groups.count)",
                note: "Private circles for shared rules and challenges"
            )
        }
    }

    private func statRow(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .font(.headline)
            }

            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var quickActionsSection: some View {
        Section("Quick Actions") {
            NavigationLink {
                AskBuddyView(
                    buddyService: buddyService,
                    requestService: requestService
                )
                .environmentObject(screenTime)
            } label: {
                Label("Request an Unlock", systemImage: "paperplane.fill")
            }

            NavigationLink {
                ApprovalsView(
                    buddyService: buddyService,
                    requestService: requestService
                )
                .environmentObject(screenTime)
            } label: {
                Label("Review Approvals", systemImage: "checkmark.seal")
            }

            NavigationLink {
                BuddyListView(
                    buddyService: buddyService,
                    friendRequests: friendRequestService
                )
            } label: {
                Label("Manage Buddy System", systemImage: "person.3.fill")
            }
        }
    }

    private var groupsSection: some View {
        Section("Your Groups") {
            if buddyService.groups.isEmpty {
                Text("Once you make a private group, it’ll show up here so you can route unlocks and future challenges through it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddyService.groups.prefix(3)) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.headline)
                        Text(group.defaultApprovalRule.summary(for: group.memberIDs.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
