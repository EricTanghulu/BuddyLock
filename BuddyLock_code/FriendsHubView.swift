import SwiftUI

private enum BuddyHubItem: Identifiable {
    case buddy(LocalBuddy)
    case group(BuddyGroup)

    var id: String {
        switch self {
        case .buddy(let buddy):
            return "buddy-\(buddy.id.uuidString)"
        case .group(let group):
            return "group-\(group.id.uuidString)"
        }
    }
}

private enum FriendsHubDestination {
    case manageNetwork
    case approvals
    case requests
}

private struct FriendsUnlockComposerContext: Identifiable {
    let id = UUID()
    let audienceType: BuddyAudienceType
    let buddyID: UUID?
    let buddyIDs: Set<UUID>
    let categoryID: UUID?
    let groupID: UUID?

    static func buddy(_ id: UUID) -> FriendsUnlockComposerContext {
        FriendsUnlockComposerContext(
            audienceType: .individual,
            buddyID: id,
            buddyIDs: [],
            categoryID: nil,
            groupID: nil
        )
    }

    static func group(_ id: UUID) -> FriendsUnlockComposerContext {
        FriendsUnlockComposerContext(
            audienceType: .group,
            buddyID: nil,
            buddyIDs: [],
            categoryID: nil,
            groupID: id
        )
    }
}

struct FriendsHubView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService
    @EnvironmentObject var screenTime: ScreenTimeManager

    @State private var requestComposerContext: FriendsUnlockComposerContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pendingSection
                circleSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Buddies")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    destinationView(for: .manageNetwork)
                } label: {
                    Text("Manage")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .sheet(item: $requestComposerContext) { context in
            NavigationStack {
                AskBuddyView(
                    buddyService: buddyService,
                    requestService: requestService,
                    initialAudienceType: context.audienceType,
                    initialBuddyID: context.buddyID,
                    initialBuddyIDs: context.buddyIDs,
                    initialCategoryID: context.categoryID,
                    initialGroupID: context.groupID
                )
                .environmentObject(screenTime)
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Pending",
                subtitle: "Invites, approvals, and unlock requests that still need a response."
            )

            if pendingFriendRequestsCount == 0 &&
                pendingApprovalsCount == 0 &&
                outgoingPendingCount == 0 {
                calmStateCard
            } else {
                VStack(spacing: 10) {
                    if pendingFriendRequestsCount > 0 {
                        NavigationLink {
                            destinationView(for: .manageNetwork)
                        } label: {
                            inboxRow(
                                icon: "person.badge.plus",
                                tint: .blue,
                                title: "\(pendingFriendRequestsCount) buddy request\(pendingFriendRequestsCount == 1 ? "" : "s")",
                                subtitle: "Accept or deny incoming requests."
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if pendingApprovalsCount > 0 {
                        NavigationLink {
                            destinationView(for: .approvals)
                        } label: {
                            inboxRow(
                                icon: "checkmark.seal.fill",
                                tint: .green,
                                title: "\(pendingApprovalsCount) unlock decision\(pendingApprovalsCount == 1 ? "" : "s") needed",
                                subtitle: "Your buddies are waiting to hear from you."
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if outgoingPendingCount > 0 {
                        NavigationLink {
                            destinationView(for: .requests)
                        } label: {
                            inboxRow(
                                icon: "hourglass",
                                tint: .orange,
                                title: "\(outgoingPendingCount) request\(outgoingPendingCount == 1 ? "" : "s") still pending",
                                subtitle: "Check who still needs to respond."
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var calmStateCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("All clear")
                    .font(.headline)
                Text("No buddy requests, no approvals waiting on you, and no unlocks still hanging open.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func inboxRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var circleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Your Buddies",
                subtitle: "People and private groups all live here, so you only have one place to browse your accountability network."
            )

            if circleItems.isEmpty {
                emptyStateCard(
                    title: "No buddies yet",
                    subtitle: "Use Manage in the top-right to add someone you already know."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(circleItems) { item in
                        switch item {
                        case .buddy(let buddy):
                            buddyCard(for: buddy)
                        case .group(let group):
                            groupCard(for: group)
                        }
                    }
                }
            }
        }
    }

    private func buddyCard(for buddy: LocalBuddy) -> some View {
        let categories = buddyService.categories(for: buddy)
        let groupCount = buddyService.groups(containing: buddy.id).count
        let categoryText = categories.isEmpty
            ? "Not in a list yet"
            : categories.map(\.name).joined(separator: " • ")
        let cleanedNote = buddy.note?.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(buddy.resolvedDisplayName.prefix(1)).uppercased())
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.orange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(buddy.resolvedDisplayName)
                            .font(.headline)

                        if buddyService.isBestBuddy(buddy) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text(categoryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(groupCount == 0
                        ? "Not in a group yet • Visibility: \(buddy.visibility.preset.title)"
                        : "In \(groupCount) group\(groupCount == 1 ? "" : "s") • Visibility: \(buddy.visibility.preset.title)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge(
                    title: buddy.canApproveUnlocks ? "Can approve" : "View only",
                    tint: buddy.canApproveUnlocks ? .green : .secondary
                )
            }

            if let cleanedNote, !cleanedNote.isEmpty {
                Text(cleanedNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if buddy.canApproveUnlocks {
                Button {
                    requestComposerContext = .buddy(buddy.id)
                } label: {
                    actionPill(
                        title: "Ask for Unlock",
                        systemImage: "paperplane.fill",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .hubCardStyle()
    }

    private func groupCard(for group: BuddyGroup) -> some View {
        let memberNames = Array(
            group.memberIDs
                .compactMap { buddyService.buddy(for: $0)?.resolvedDisplayName }
                .prefix(4)
        ).joined(separator: ", ")

        let cleanedSummary = group.summary.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)

                    if !cleanedSummary.isEmpty {
                        Text(cleanedSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(group.memberIDs.count) members")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(memberNames.isEmpty ? "No members yet" : memberNames)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Approval rule: \(group.defaultApprovalRule.summary(for: group.memberIDs.count))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Visibility: \(group.visibility.preset.title)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if group.allowRequesterOverride {
                Text("Requesters can adjust the rule for a specific unlock when needed.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                requestComposerContext = .group(group.id)
            } label: {
                actionPill(
                    title: "Request Group Vote",
                    systemImage: "person.3.fill",
                    tint: .blue
                )
            }
            .buttonStyle(.plain)
            .disabled(buddyService.audienceForGroup(group) == nil)
        }
        .hubCardStyle()
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyStateCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func actionPill(
        title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func destinationView(for destination: FriendsHubDestination) -> some View {
        switch destination {
        case .manageNetwork:
            BuddyListView(
                buddyService: buddyService,
                friendRequests: friendRequestService
            )
        case .approvals:
            ApprovalsView(
                buddyService: buddyService,
                requestService: requestService
            )
            .environmentObject(screenTime)
        case .requests:
            AskBuddyView(
                buddyService: buddyService,
                requestService: requestService
            )
            .environmentObject(screenTime)
        }
    }

    private var orderedBuddies: [LocalBuddy] {
        buddyService.buddies.sorted { lhs, rhs in
            let lhsBest = buddyService.isBestBuddy(lhs)
            let rhsBest = buddyService.isBestBuddy(rhs)

            if lhsBest != rhsBest {
                return lhsBest && !rhsBest
            }

            return lhs.resolvedDisplayName.localizedCaseInsensitiveCompare(rhs.resolvedDisplayName) == .orderedAscending
        }
    }

    private var orderedGroups: [BuddyGroup] {
        buddyService.groups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var circleItems: [BuddyHubItem] {
        let buddies = orderedBuddies.map(BuddyHubItem.buddy)
        let groups = orderedGroups.map(BuddyHubItem.group)
        return buddies + groups
    }

    private var pendingFriendRequestsCount: Int {
        friendRequestService.incomingRequests.count
    }

    private var pendingApprovalsCount: Int {
        requestService.incoming.filter { requestService.canCurrentUserRespond(to: $0) }.count
    }

    private var outgoingPendingCount: Int {
        requestService.outgoing.filter { $0.decision == .pending }.count
    }

}

private extension View {
    func hubCardStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
