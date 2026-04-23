import SwiftUI

private enum BuddiesHubDestination: Identifiable {
    case tools
    case approvals
    case requests

    var id: String {
        switch self {
        case .tools:
            return "tools"
        case .approvals:
            return "approvals"
        case .requests:
            return "requests"
        }
    }
}

private enum BuddyHubFilter: String, CaseIterable, Identifiable {
    case all
    case buddies
    case groups

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .buddies:
            return "Buddies"
        case .groups:
            return "Groups"
        }
    }
}

private enum BuddyDirectorySortMode: String, CaseIterable, Identifiable {
    case smart
    case canApprove
    case recent
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart:
            return "Smart"
        case .canApprove:
            return "Can Approve"
        case .recent:
            return "Recent"
        case .alphabetical:
            return "A-Z"
        }
    }
}

private enum GroupDirectorySortMode: String, CaseIterable, Identifiable {
    case recent
    case alphabetical
    case largest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .alphabetical:
            return "A-Z"
        case .largest:
            return "Largest"
        }
    }
}

private struct BuddiesUnlockComposerContext: Identifiable {
    let id = UUID()
    let audienceType: BuddyAudienceType
    let buddyID: UUID?
    let buddyIDs: Set<UUID>
    let categoryID: UUID?
    let groupID: UUID?

    static func buddy(_ id: UUID) -> BuddiesUnlockComposerContext {
        BuddiesUnlockComposerContext(
            audienceType: .individual,
            buddyID: id,
            buddyIDs: [],
            categoryID: nil,
            groupID: nil
        )
    }

    static func group(_ id: UUID) -> BuddiesUnlockComposerContext {
        BuddiesUnlockComposerContext(
            audienceType: .group,
            buddyID: nil,
            buddyIDs: [],
            categoryID: nil,
            groupID: id
        )
    }

    static let quickStart = BuddiesUnlockComposerContext(
        audienceType: .individual,
        buddyID: nil,
        buddyIDs: [],
        categoryID: nil,
        groupID: nil
    )
}

private struct BuddyProfileSheetContext: Identifiable {
    let id: UUID
}

private struct QuickUnlockTarget: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let context: BuddiesUnlockComposerContext
}

private struct BuddyHubUnavailableStateView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct BuddiesHubView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService
    @EnvironmentObject var screenTime: ScreenTimeManager

    @State private var requestComposerContext: BuddiesUnlockComposerContext?
    @State private var buddyProfileContext: BuddyProfileSheetContext?
    @State private var pushedDestination: BuddiesHubDestination?
    @State private var feedbackMessage: String?
    @State private var searchText = ""
    @State private var filter: BuddyHubFilter = .all
    @State private var buddySort: BuddyDirectorySortMode = .smart
    @State private var groupSort: GroupDirectorySortMode = .recent
    @State private var buddiesExpanded = true
    @State private var groupsExpanded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                inboxSection
                quickActionsSection
                networkSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Buddies")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search buddies and groups")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    destinationView(for: .tools)
                } label: {
                    Text("Organize")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .navigationDestination(item: $pushedDestination) { destination in
            destinationView(for: destination)
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
        .sheet(item: $buddyProfileContext) { context in
            NavigationStack {
                BuddyQuickProfileView(
                    buddyService: buddyService,
                    buddyID: context.id,
                    onAskForUnlock: { buddyID in
                        buddyProfileContext = nil
                        requestComposerContext = .buddy(buddyID)
                    }
                )
            }
        }
        .alert("Buddies", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { newValue in
                if !newValue {
                    feedbackMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                feedbackMessage = nil
            }
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Buddy Inbox",
                subtitle: "Home can point you here, but this is where the full buddy work gets resolved: approvals first, new buddy requests second, outgoing unlocks third."
            )

            if approvalsNeedingResponse.isEmpty && pendingBuddyRequests.isEmpty && outgoingPendingRequests.isEmpty {
                calmStateCard
            } else {
                VStack(spacing: 14) {
                    if !approvalsNeedingResponse.isEmpty {
                        inboxGroupHeader(
                            title: "Needs your response",
                            subtitle: "Unlock decisions waiting on you.",
                            systemImage: "checkmark.seal.fill",
                            tint: .green
                        )

                        VStack(spacing: 10) {
                            ForEach(Array(approvalsNeedingResponse.prefix(2))) { request in
                                approvalInboxCard(request)
                            }
                        }

                        if approvalsNeedingResponse.count > 2 {
                            NavigationLink {
                                destinationView(for: .approvals)
                            } label: {
                                compactLinkRow(
                                    title: "See \(approvalsNeedingResponse.count - 2) more approval\(approvalsNeedingResponse.count - 2 == 1 ? "" : "s")",
                                    subtitle: "Open Approvals for the rest of your incoming unlock decisions."
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !pendingBuddyRequests.isEmpty {
                        inboxGroupHeader(
                            title: "New buddy requests",
                            subtitle: "People asking to join your accountability network.",
                            systemImage: "person.badge.plus",
                            tint: .blue
                        )

                        VStack(spacing: 10) {
                            ForEach(Array(pendingBuddyRequests.prefix(2))) { request in
                                buddyRequestCard(request)
                            }
                        }

                        if pendingBuddyRequests.count > 2 {
                            NavigationLink {
                                destinationView(for: .tools)
                            } label: {
                                compactLinkRow(
                                    title: "See \(pendingBuddyRequests.count - 2) more buddy request\(pendingBuddyRequests.count - 2 == 1 ? "" : "s")",
                                    subtitle: "Use Buddy Tools if you need the setup side of your network."
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !outgoingPendingRequests.isEmpty {
                        inboxGroupHeader(
                            title: "Waiting on your buddies",
                            subtitle: "Outgoing unlock requests still in progress.",
                            systemImage: "hourglass",
                            tint: .orange
                        )

                        VStack(spacing: 10) {
                            ForEach(Array(outgoingPendingRequests.prefix(2))) { request in
                                outgoingInboxCard(request)
                            }
                        }

                        if outgoingPendingRequests.count > 2 {
                            NavigationLink {
                                destinationView(for: .requests)
                            } label: {
                                compactLinkRow(
                                    title: "Track \(outgoingPendingRequests.count - 2) more pending unlock\(outgoingPendingRequests.count - 2 == 1 ? "" : "s")",
                                    subtitle: "Open your outgoing unlock requests."
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Shortcuts",
                subtitle: "These jump straight into active buddy work. Setup and structure live behind Organize."
            )

            HStack(spacing: 10) {
                quickActionButton(
                    title: approvalsNeedingResponse.isEmpty ? "Approvals" : "Review Approvals",
                    systemImage: "checkmark.seal.fill",
                    tint: .green,
                    isEnabled: approvalsNeedingResponse.isEmpty == false
                ) {
                    openApprovals()
                }

                quickActionButton(
                    title: outgoingPendingRequests.isEmpty ? "Pending Unlocks" : "Track Unlocks",
                    systemImage: "hourglass",
                    tint: .orange,
                    isEnabled: outgoingPendingRequests.isEmpty == false
                ) {
                    openRequests()
                }

                quickActionButton(
                    title: "Organize",
                    systemImage: "square.grid.2x2",
                    tint: .blue
                ) {
                    openTools()
                }
            }
        }
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Your Network",
                subtitle: "Buddies are single-person asks. Groups are shared buddy votes. Organize handles setup and cleanup."
            )

            Picker("Filter", selection: $filter) {
                ForEach(BuddyHubFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                if shouldShowBuddiesSection {
                    Menu {
                        Picker("Sort Buddies", selection: $buddySort) {
                            ForEach(BuddyDirectorySortMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } label: {
                        controlChip(title: "Sort Buddies: \(buddySort.title)", systemImage: "arrow.up.arrow.down")
                    }
                }

                if shouldShowGroupsSection {
                    Menu {
                        Picker("Sort Groups", selection: $groupSort) {
                            ForEach(GroupDirectorySortMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    } label: {
                        controlChip(title: "Sort Groups: \(groupSort.title)", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }

            if shouldShowBuddiesSection {
                buddyNetworkSection
            }

            if shouldShowGroupsSection {
                groupNetworkSection
            }

            if filteredBuddies.isEmpty && filteredGroups.isEmpty {
                noResultsSection
            }
        }
    }

    private var buddyNetworkSection: some View {
        Group {
            if shouldUseCollapsibleBuddies {
                DisclosureGroup("Buddies (\(filteredBuddies.count))", isExpanded: $buddiesExpanded) {
                    buddyNetworkBody
                        .padding(.top, 10)
                }
                .font(.headline)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                buddyNetworkBody
            }
        }
    }

    private var buddyNetworkBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !shouldUseCollapsibleBuddies {
                sectionTitle(
                    "Buddies",
                    subtitle: filteredBuddies.isEmpty
                        ? "No buddies match that search yet."
                        : "Keep the next move obvious: ask, review the relationship, or see who is most useful right now."
                )
            }

            if filteredBuddies.isEmpty {
                emptyStateCard(
                    title: "No buddies to show",
                    subtitle: searchText.isEmpty
                        ? "Add your first buddy to turn this tab into a real accountability loop."
                        : "Try a different name, a group name, or switch back to all results."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredBuddies) { buddy in
                        buddyCard(for: buddy)
                    }
                }
            }
        }
    }

    private var groupNetworkSection: some View {
        Group {
            if shouldUseCollapsibleGroups {
                DisclosureGroup("Groups (\(filteredGroups.count))", isExpanded: $groupsExpanded) {
                    groupNetworkBody
                        .padding(.top, 10)
                }
                .font(.headline)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                groupNetworkBody
            }
        }
    }

    private var groupNetworkBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !shouldUseCollapsibleGroups {
                sectionTitle(
                    "Groups",
                    subtitle: filteredGroups.isEmpty
                        ? "No groups match that search yet."
                        : "Groups are for shared votes. The card should tell you who is in it, what rule it uses, and whether you can ask them right now."
                )
            }

            if filteredGroups.isEmpty {
                emptyStateCard(
                    title: "No groups to show",
                    subtitle: searchText.isEmpty
                        ? "Create a group once more than one buddy should decide together."
                        : "Try another search term or switch back to all results."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredGroups) { group in
                        groupCard(for: group)
                    }
                }
            }
        }
    }

    private var noResultsSection: some View {
        emptyStateCard(
            title: searchText.isEmpty ? "Nothing here yet" : "No results",
            subtitle: searchText.isEmpty
                ? "Start with Add Buddy, then create groups once you have a few buddies you trust."
                : "Try another search, switch filters, or use Buddy Tools for setup work."
        )
    }

    private var calmStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("All caught up")
                        .font(.headline)
                    Text("No buddy requests are waiting, no approvals need your vote, and none of your unlock requests are stuck.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button("Open Organize") {
                    openTools()
                }
                .buttonStyle(.bordered)

                Button("Organize") {
                    openTools()
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.footnote.weight(.semibold))
        }
        .hubCardStyle()
    }

    private func inboxGroupHeader(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            iconTile(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func buddyRequestCard(_ request: FriendRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "person.badge.plus", tint: .blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.resolvedName)
                        .font(.headline)
                    Text("Wants to become your buddy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(relativeDateString(from: request.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button("Deny") {
                    reject(request)
                }
                .buttonStyle(.bordered)

                Button("Accept") {
                    accept(request)
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.footnote.weight(.semibold))
        }
        .hubCardStyle()
    }

    private func approvalInboxCard(_ request: UnlockRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "checkmark.seal.fill", tint: .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.requesterName)
                        .font(.headline)
                    Text("\(request.minutesRequested)m unlock request")
                        .font(.subheadline)

                    if let reason = request.reason, !reason.isEmpty {
                        Text("“\(reason)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let target = request.targetDescription, !target.isEmpty {
                        Text("For \(target)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                StatusPill(request: request)
            }

            HStack(spacing: 8) {
                metadataChip(title: request.audienceLabel, tint: .green)

                if request.recipientCount > 1 {
                    metadataChip(
                        title: plainLanguageRuleDescription(for: request.approvalRule, recipientCount: request.recipientCount),
                        tint: .secondary,
                        isMuted: true
                    )
                }
            }

            HStack(spacing: 10) {
                Button("Deny") {
                    guard let requestID = request.id else { return }
                    requestService.deny(requestID: requestID)
                }
                .buttonStyle(.bordered)

                Button("Approve \(request.minutesRequested)m") {
                    guard let requestID = request.id else { return }
                    requestService.approve(requestID: requestID, minutes: request.minutesRequested)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    destinationView(for: .approvals)
                } label: {
                    Text("Review")
                }
                .buttonStyle(.bordered)
            }
            .font(.footnote.weight(.semibold))
        }
        .hubCardStyle()
    }

    private func outgoingInboxCard(_ request: UnlockRequest) -> some View {
        let approvedNames = responseNames(for: request, vote: .approved)
        let deniedNames = responseNames(for: request, vote: .denied)
        let pendingNames = pendingResponderSummary(for: request)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "hourglass", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.audienceLabel)
                        .font(.headline)
                    Text("\(request.minutesRequested)m unlock request")
                        .font(.subheadline)
                    Text(request.progressSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusPill(request: request)
            }

            if let reason = request.reason, !reason.isEmpty {
                Text("“\(reason)”")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let approvedNames, !approvedNames.isEmpty {
                    Text("Approved: \(approvedNames)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let deniedNames, !deniedNames.isEmpty {
                    Text("Denied: \(deniedNames)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let pendingNames, !pendingNames.isEmpty {
                    Text("Still waiting on \(pendingNames)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                NavigationLink {
                    destinationView(for: .requests)
                } label: {
                    Text("Track")
                }
                .buttonStyle(.bordered)

                if let retryContext = composerContext(for: request) {
                    Button("Ask Again") {
                        requestComposerContext = retryContext
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .hubCardStyle()
    }

    private func buddyCard(for buddy: LocalBuddy) -> some View {
        let categories = buddyService.categories(for: buddy)
        let groups = buddyService.groups(containing: buddy.id)
        let note = buddy.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoriesLine = categories.prefix(2).map(\.name).joined(separator: " • ")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                avatar(for: buddy)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(buddy.resolvedDisplayName)
                            .font(.headline)

                        if buddyService.isBestBuddy(buddy) {
                            metadataChip(title: "Best Buddy", tint: .yellow)
                        }
                    }

                    Text(buddy.canApproveUnlocks ? "Approvals on" : "Approvals off")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !categoriesLine.isEmpty {
                        Text(categoriesLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !groups.isEmpty {
                        Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 8) {
                metadataChip(
                    title: groups.isEmpty ? "Direct buddy ask" : "In \(groups.count) group\(groups.count == 1 ? "" : "s")",
                    tint: .secondary,
                    isMuted: true
                )

                if let activityLabel = buddyActivityLabel(for: buddy) {
                    metadataChip(title: activityLabel, tint: .blue)
                }
            }

            if let note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if buddy.canApproveUnlocks {
                    Button {
                        requestComposerContext = .buddy(buddy.id)
                    } label: {
                        labeledAction(title: "Ask", systemImage: "paperplane.fill", tint: .blue)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    buddyProfileContext = BuddyProfileSheetContext(id: buddy.id)
                } label: {
                    labeledAction(title: "Relationship", systemImage: "person.crop.circle", tint: .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .hubCardStyle()
    }

    private func groupCard(for group: BuddyGroup) -> some View {
        let memberNames = group.memberIDs
            .compactMap { buddyService.buddy(for: $0)?.resolvedDisplayName }
            .sorted()
        let previewNames = memberNames.prefix(3).joined(separator: ", ")
        let summary = group.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let audienceAvailable = buddyService.audienceForGroup(group) != nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "person.3.fill", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)

                    if !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Shared buddy vote")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !previewNames.isEmpty {
                        Text(previewNames)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 8) {
                metadataChip(title: "\(group.memberIDs.count) member\(group.memberIDs.count == 1 ? "" : "s")", tint: .orange)
                metadataChip(
                    title: plainLanguageRuleDescription(for: group.defaultApprovalRule, recipientCount: group.memberIDs.count),
                    tint: .secondary,
                    isMuted: true
                )

                if let activityLabel = groupActivityLabel(for: group) {
                    metadataChip(title: activityLabel, tint: .blue)
                }
            }

            HStack(spacing: 10) {
                Button {
                    requestComposerContext = .group(group.id)
                } label: {
                    labeledAction(title: "Request Vote", systemImage: "paperplane.fill", tint: .blue)
                }
                .buttonStyle(.plain)
                .disabled(audienceAvailable == false)

                NavigationLink {
                    GroupDetailView(
                        buddyService: buddyService,
                        groupID: group.id
                    )
                } label: {
                    labeledAction(title: "Manage", systemImage: "slider.horizontal.3", tint: .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .hubCardStyle()
    }

    private func quickActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func controlChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func compactLinkRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.circle")
                .font(.headline)
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)
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

    private func avatar(for buddy: LocalBuddy) -> some View {
        Circle()
            .fill(Color.orange.opacity(0.18))
            .frame(width: 48, height: 48)
            .overlay(
                Text(String(buddy.resolvedDisplayName.prefix(1)).uppercased())
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.orange)
            )
    }

    private func iconTile(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metadataChip(title: String, tint: Color, isMuted: Bool = false) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(isMuted ? 0.1 : 0.12), in: Capsule())
    }

    private func labeledAction(title: String, systemImage: String, tint: Color) -> some View {
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

    @ViewBuilder
    private func destinationView(for destination: BuddiesHubDestination) -> some View {
        switch destination {
        case .tools:
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

    private func openTools() {
        pushedDestination = .tools
    }

    private func openApprovals() {
        pushedDestination = .approvals
    }

    private func openRequests() {
        pushedDestination = .requests
    }

    private func accept(_ request: FriendRequest) {
        Task {
            do {
                try await friendRequestService.accept(request)
            } catch {
                feedbackMessage = error.localizedDescription
            }
        }
    }

    private func reject(_ request: FriendRequest) {
        Task {
            do {
                try await friendRequestService.reject(request)
            } catch {
                feedbackMessage = error.localizedDescription
            }
        }
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func buddyRecipientID(for buddy: LocalBuddy) -> String {
        buddy.remoteID ?? buddy.buddyUserID
    }

    private func composerContext(for request: UnlockRequest) -> BuddiesUnlockComposerContext? {
        switch request.audienceType {
        case .individual:
            guard let referenceID = request.audienceReferenceID,
                  let buddyID = UUID(uuidString: referenceID) else { return nil }
            return .buddy(buddyID)
        case .group:
            guard let referenceID = request.audienceReferenceID,
                  let groupID = UUID(uuidString: referenceID) else { return nil }
            return .group(groupID)
        case .selectedBuddies:
            let matchingIDs = Set(
                orderedBuddies
                    .filter { request.recipientUserIDs.contains(buddyRecipientID(for: $0)) }
                    .map(\.id)
            )
            guard !matchingIDs.isEmpty else { return nil }
            return BuddiesUnlockComposerContext(
                audienceType: .selectedBuddies,
                buddyID: nil,
                buddyIDs: matchingIDs,
                categoryID: nil,
                groupID: nil
            )
        case .category:
            guard let referenceID = request.audienceReferenceID,
                  let categoryID = UUID(uuidString: referenceID) else { return nil }
            return BuddiesUnlockComposerContext(
                audienceType: .category,
                buddyID: nil,
                buddyIDs: [],
                categoryID: categoryID,
                groupID: nil
            )
        case .everyone:
            return BuddiesUnlockComposerContext(
                audienceType: .everyone,
                buddyID: nil,
                buddyIDs: [],
                categoryID: nil,
                groupID: nil
            )
        }
    }

    private func plainLanguageRuleDescription(for rule: BuddyApprovalRule, recipientCount: Int) -> String {
        switch rule.kind {
        case .anyOne:
            return "Any 1 buddy can approve"
        case .majority:
            return "\(rule.requiredApprovals(for: recipientCount)) of \(max(recipientCount, 1)) buddies approve"
        case .atLeastCount:
            return "Need \(rule.requiredApprovals(for: recipientCount)) buddy approvals"
        }
    }

    private func latestRequestDate(for buddy: LocalBuddy) -> Date? {
        let recipientID = buddyRecipientID(for: buddy)
        return (requestService.incoming + requestService.outgoing)
            .filter { request in
                request.requesterID == recipientID || request.recipientUserIDs.contains(recipientID)
            }
            .map(\.createdDate)
            .max()
    }

    private func latestGroupRequestDate(for group: BuddyGroup) -> Date? {
        let groupReference = group.id.uuidString
        return requestService.outgoing
            .filter { $0.audienceReferenceID == groupReference }
            .map(\.createdDate)
            .max()
    }

    private func buddyActivityLabel(for buddy: LocalBuddy) -> String? {
        guard let date = latestRequestDate(for: buddy) else { return nil }
        return "Active \(relativeDateString(from: date))"
    }

    private func groupActivityLabel(for group: BuddyGroup) -> String? {
        guard let date = latestGroupRequestDate(for: group) else { return nil }
        return "Used \(relativeDateString(from: date))"
    }

    private func responseNames(for request: UnlockRequest, vote: UnlockApprovalVote) -> String? {
        let names = request.responses
            .filter { $0.vote == vote }
            .map(\.responderName)

        guard !names.isEmpty else { return nil }
        if names.count == 1 {
            return names[0]
        }
        if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        }
        return "\(names[0]), \(names[1]), and \(names.count - 2) more"
    }

    private func pendingResponderSummary(for request: UnlockRequest) -> String? {
        let responderIDs = Set(request.responses.map(\.responderID))
        let pendingIDs = request.recipientUserIDs.filter { !responderIDs.contains($0) }
        guard !pendingIDs.isEmpty else { return nil }

        let names = pendingIDs.map { pendingID in
            orderedBuddies.first { buddyRecipientID(for: $0) == pendingID }?.resolvedDisplayName ?? "1 buddy"
        }

        if names.count == 1 {
            return names[0]
        }
        if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        }
        return "\(names[0]), \(names[1]), and \(names.count - 2) more"
    }

    private var orderedBuddies: [LocalBuddy] {
        buddyService.buddies.sorted { lhs, rhs in
            switch buddySort {
            case .alphabetical:
                return lhs.resolvedDisplayName.localizedCaseInsensitiveCompare(rhs.resolvedDisplayName) == .orderedAscending
            case .canApprove:
                if lhs.canApproveUnlocks != rhs.canApproveUnlocks {
                    return lhs.canApproveUnlocks && !rhs.canApproveUnlocks
                }
                return lhs.resolvedDisplayName.localizedCaseInsensitiveCompare(rhs.resolvedDisplayName) == .orderedAscending
            case .recent:
                let lhsDate = latestRequestDate(for: lhs) ?? .distantPast
                let rhsDate = latestRequestDate(for: rhs) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.resolvedDisplayName.localizedCaseInsensitiveCompare(rhs.resolvedDisplayName) == .orderedAscending
            case .smart:
                let lhsBest = buddyService.isBestBuddy(lhs)
                let rhsBest = buddyService.isBestBuddy(rhs)
                if lhsBest != rhsBest {
                    return lhsBest && !rhsBest
                }
                if lhs.canApproveUnlocks != rhs.canApproveUnlocks {
                    return lhs.canApproveUnlocks && !rhs.canApproveUnlocks
                }
                let lhsDate = latestRequestDate(for: lhs) ?? .distantPast
                let rhsDate = latestRequestDate(for: rhs) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.resolvedDisplayName.localizedCaseInsensitiveCompare(rhs.resolvedDisplayName) == .orderedAscending
            }
        }
    }

    private var orderedGroups: [BuddyGroup] {
        buddyService.groups.sorted { lhs, rhs in
            switch groupSort {
            case .alphabetical:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .largest:
                if lhs.memberIDs.count != rhs.memberIDs.count {
                    return lhs.memberIDs.count > rhs.memberIDs.count
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .recent:
                let lhsDate = latestGroupRequestDate(for: lhs) ?? lhs.createdAt
                let rhsDate = latestGroupRequestDate(for: rhs) ?? rhs.createdAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private var filteredBuddies: [LocalBuddy] {
        guard !searchText.isEmpty else { return orderedBuddies }
        return orderedBuddies.filter { buddy in
            buddy.resolvedDisplayName.localizedCaseInsensitiveContains(searchText) ||
            buddy.buddyUserID.localizedCaseInsensitiveContains(searchText) ||
            buddyService.categories(for: buddy).contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
            buddyService.groups(containing: buddy.id).contains { $0.name.localizedCaseInsensitiveContains(searchText) } ||
            (buddy.note?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var filteredGroups: [BuddyGroup] {
        guard !searchText.isEmpty else { return orderedGroups }
        return orderedGroups.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText) ||
            group.summary.localizedCaseInsensitiveContains(searchText) ||
            group.memberIDs.contains { buddyID in
                buddyService.displayName(for: buddyID).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var shouldShowBuddiesSection: Bool {
        filter == .all || filter == .buddies
    }

    private var shouldShowGroupsSection: Bool {
        filter == .all || filter == .groups
    }

    private var shouldUseCollapsibleBuddies: Bool {
        filteredBuddies.count > 4
    }

    private var shouldUseCollapsibleGroups: Bool {
        filteredGroups.count > 3
    }

    private var pendingBuddyRequests: [FriendRequest] {
        friendRequestService.incomingRequests
    }

    private var approvalsNeedingResponse: [UnlockRequest] {
        requestService.incoming
            .filter { requestService.canCurrentUserRespond(to: $0) }
            .sorted { $0.createdDate > $1.createdDate }
    }

    private var outgoingPendingRequests: [UnlockRequest] {
        requestService.outgoing
            .filter { $0.decision == .pending }
            .sorted { lhs, rhs in
                if lhs.pendingCount != rhs.pendingCount {
                    return lhs.pendingCount > rhs.pendingCount
                }
                return lhs.createdDate > rhs.createdDate
            }
    }

}

private struct BuddyQuickProfileView: View {
    @ObservedObject var buddyService: LocalBuddyService
    let buddyID: UUID
    let onAskForUnlock: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingRemoveConfirmation = false

    private var buddy: LocalBuddy? {
        buddyService.buddy(for: buddyID)
    }

    var body: some View {
        Group {
            if let buddy {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        profileHeader(for: buddy)
                        relationshipActions(for: buddy)
                        contextSection(for: buddy)
                        dangerZone(for: buddy)
                    }
                    .padding()
                }
                .navigationTitle(buddy.resolvedDisplayName)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Remove Buddy?", isPresented: $showingRemoveConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Remove", role: .destructive) {
                        buddyService.removeBuddy(buddy)
                        dismiss()
                    }
                } message: {
                    Text("This removes the buddy relationship, turns off their unlock access, and removes them from any buddy groups that depended on them.")
                }
            } else {
                BuddyHubUnavailableStateView(title: "Buddy not found", systemImage: "person.slash")
            }
        }
    }

    private func profileHeader(for buddy: LocalBuddy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(buddy.resolvedDisplayName.prefix(1)).uppercased())
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.orange)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(buddy.resolvedDisplayName)
                        .font(.title3.weight(.bold))
                    Text("@\(buddy.buddyUserID)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                statusChip(title: buddy.canApproveUnlocks ? "Approvals on" : "Approvals off", tint: buddy.canApproveUnlocks ? .green : .secondary)

                if buddyService.isBestBuddy(buddy) {
                    statusChip(title: "Best Buddy", tint: .yellow)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func relationshipActions(for buddy: LocalBuddy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Relationship")
                .font(.headline)

            if buddy.canApproveUnlocks {
                Button("Ask for Unlock") {
                    onAskForUnlock(buddy.id)
                }
                .buttonStyle(.borderedProminent)
            }

            Button(buddy.canApproveUnlocks ? "Turn Approvals Off" : "Turn Approvals On") {
                var updated = buddy
                updated.canApproveUnlocks.toggle()
                buddyService.updateBuddy(updated)
            }
            .buttonStyle(.bordered)

            Button(buddyService.isBestBuddy(buddy) ? "Remove Best Buddy" : "Make Best Buddy") {
                _ = buddyService.setBestBuddy(!buddyService.isBestBuddy(buddy), for: buddy)
            }
            .buttonStyle(.bordered)

            NavigationLink {
                BuddyDetailView(
                    buddyService: buddyService,
                    buddyID: buddy.id
                )
            } label: {
                Text("Open Full Details")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func contextSection(for buddy: LocalBuddy) -> some View {
        let categories = buddyService.categories(for: buddy)
        let groups = buddyService.groups(containing: buddy.id)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Context")
                .font(.headline)

            Text(categories.isEmpty ? "No buddy lists yet." : "Lists: \(categories.map(\.name).joined(separator: ", "))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(groups.isEmpty ? "No buddy groups yet." : "Groups: \(groups.map(\.name).joined(separator: ", "))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let note = buddy.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func dangerZone(for buddy: LocalBuddy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)

            Text("Use this only when you really want to end the buddy relationship.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Remove Buddy", role: .destructive) {
                showingRemoveConfirmation = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statusChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct StatusPill: View {
    let request: UnlockRequest

    var body: some View {
        switch request.decision {
        case .pending:
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        case .approved:
            Text("Approved \(request.approvedMinutes ?? request.minutesRequested)m")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2), in: Capsule())
        case .denied:
            Text("Denied")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2), in: Capsule())
        }
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
