import SwiftUI

private struct FriendsActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let createdAt: Date
    let destination: FriendsHubDestination?
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
                updatesSection
                peopleSection
                groupsSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Friends")
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

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Latest Updates",
                subtitle: "The most recent buddy activity, so you don’t have to dig for it."
            )

            if activityItems.isEmpty {
                emptyStateCard(
                    title: "Nothing new yet",
                    subtitle: "Once requests and approvals start moving, the important updates will show up here."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(activityItems) { item in
                        if let destination = item.destination {
                            NavigationLink {
                                destinationView(for: destination)
                            } label: {
                                activityRow(item, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            activityRow(item)
                        }
                    }
                }
            }
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Buddies",
                subtitle: "The people you already know and can lean on for accountability."
            )

            if featuredBuddies.isEmpty {
                emptyStateCard(
                    title: "No buddies yet",
                    subtitle: "Use Manage in the top-right to add someone you already know."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(featuredBuddies) { buddy in
                        buddyCard(for: buddy)
                    }

                    if orderedBuddies.count > featuredBuddies.count {
                        viewAllRow("Showing 4 of \(orderedBuddies.count) buddies")
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

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Groups",
                subtitle: "Small circles that can vote together when one person shouldn’t decide alone."
            )

            if orderedGroups.isEmpty {
                emptyStateCard(
                    title: "No groups yet",
                    subtitle: "Use Manage in the top-right to create a group for roommates, classmates, or close friends."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(featuredGroups) { group in
                        groupCard(for: group)
                    }

                    if orderedGroups.count > featuredGroups.count {
                        viewAllRow("Showing 3 of \(orderedGroups.count) groups")
                    }
                }
            }
        }
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

    private func activityRow(_ item: FriendsActivityItem, showsChevron: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34)
                .background(item.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relativeDateString(from: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func viewAllRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var featuredBuddies: [LocalBuddy] {
        Array(orderedBuddies.prefix(4))
    }

    private var orderedGroups: [BuddyGroup] {
        buddyService.groups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var featuredGroups: [BuddyGroup] {
        Array(orderedGroups.prefix(3))
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

    private var activityItems: [FriendsActivityItem] {
        var items: [FriendsActivityItem] = []

        items.append(contentsOf: friendRequestService.incomingRequests.map { request in
            FriendsActivityItem(
                title: "New buddy request",
                detail: "Someone wants to connect. Accept them to turn it into an accountability link.",
                systemImage: "person.badge.plus",
                tint: .blue,
                createdAt: request.timestamp,
                destination: .manageNetwork
            )
        })

        for request in requestService.incoming {
            if requestService.canCurrentUserRespond(to: request) {
                items.append(
                    FriendsActivityItem(
                        title: "\(request.requesterName) needs a decision",
                        detail: "\(request.minutesRequested)m request to \(request.audienceLabel). \(request.progressSummary).",
                        systemImage: "checkmark.seal",
                        tint: .green,
                        createdAt: request.createdDate,
                        destination: .approvals
                    )
                )
            } else if let response = requestService.currentUserResponse(for: request) {
                let responseTitle = response.vote == .approved
                    ? "You approved \(request.requesterName)"
                    : "You denied \(request.requesterName)"
                let responseDetail = response.vote == .approved
                    ? "Unlocked for \(response.approvedMinutes ?? request.minutesRequested)m."
                    : "They’ll need a different plan for now."

                items.append(
                    FriendsActivityItem(
                        title: responseTitle,
                        detail: responseDetail,
                        systemImage: response.vote == .approved ? "hand.thumbsup.fill" : "xmark.shield.fill",
                        tint: response.vote == .approved ? .green : .red,
                        createdAt: response.createdAt,
                        destination: .approvals
                    )
                )
            }
        }

        for request in requestService.outgoing {
            let title: String
            let detail: String
            let image: String
            let tint: Color

            switch request.decision {
            case .pending:
                title = "Waiting on \(request.audienceLabel)"
                detail = "\(request.progressSummary). \(request.minutesRequested)m request still open."
                image = "hourglass"
                tint = .orange
            case .approved:
                title = "\(request.audienceLabel) approved your unlock"
                detail = "You got \(request.approvedMinutes ?? request.minutesRequested)m of access."
                image = "checkmark.circle.fill"
                tint = .green
            case .denied:
                title = "\(request.audienceLabel) denied your unlock"
                detail = "That request didn’t go through. Stay with the block or try a different audience."
                image = "xmark.circle.fill"
                tint = .red
            }

            items.append(
                FriendsActivityItem(
                    title: title,
                    detail: detail,
                    systemImage: image,
                    tint: tint,
                    createdAt: request.createdDate,
                    destination: .requests
                )
            )
        }

        return Array(items.sorted { $0.createdAt > $1.createdAt }.prefix(6))
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
