import SwiftUI

struct AskBuddyView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @State private var audienceType: BuddyAudienceType = .individual
    @State private var selectedBuddyID: UUID?
    @State private var selectedBuddyIDs: Set<UUID> = []
    @State private var selectedCategoryID: UUID?
    @State private var selectedGroupID: UUID?

    @State private var minutes: Int = 10
    @State private var targetDescription: String = ""
    @State private var reason: String = ""
    @State private var urgency: UnlockRequestUrgency = .routine

    @State private var overrideApprovalRule = false
    @State private var customApprovalRule = BuddyApprovalRule(kind: .majority)
    @State private var showingSentConfirmation = false

    var body: some View {
        Form {
            audienceSection
            requestDetailsSection

            if shouldShowApprovalRuleEditor {
                approvalRuleSection
            }

            outgoingSection
        }
        .navigationTitle("Ask for Unlock")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    requestService.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
        .onAppear {
            requestService.refresh()
            preselectFirstBuddyIfNeeded()
        }
        .alert("Request sent", isPresented: $showingSentConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your selected audience will be able to approve or deny this unlock request from their Approvals screen.")
        }
    }

    private var audienceSection: some View {
        Section("Who should decide?") {
            if buddyService.buddies.filter(\.canApproveUnlocks).isEmpty {
                Text("Add at least one buddy with unlock permissions before sending a request.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Audience", selection: $audienceType) {
                    ForEach(BuddyAudienceType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)

                switch audienceType {
                case .individual:
                    Picker("Buddy", selection: $selectedBuddyID) {
                        Text("Select a buddy").tag(Optional<UUID>.none)
                        ForEach(unlockCapableBuddies) { buddy in
                            Text(buddy.resolvedDisplayName).tag(Optional(buddy.id))
                        }
                    }

                case .selectedBuddies:
                    ForEach(unlockCapableBuddies) { buddy in
                        Toggle(
                            buddy.resolvedDisplayName,
                            isOn: Binding(
                                get: { selectedBuddyIDs.contains(buddy.id) },
                                set: { newValue in
                                    if newValue {
                                        selectedBuddyIDs.insert(buddy.id)
                                    } else {
                                        selectedBuddyIDs.remove(buddy.id)
                                    }
                                }
                            )
                        )
                    }

                case .category:
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Select a category").tag(Optional<UUID>.none)
                        ForEach(availableCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                case .group:
                    Picker("Group", selection: $selectedGroupID) {
                        Text("Select a group").tag(Optional<UUID>.none)
                        ForEach(availableGroups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }

                case .everyone:
                    Text("This will notify all buddies who still have unlock approval turned on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let resolvedAudience {
                    Text("Audience: \(resolvedAudience.label)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var requestDetailsSection: some View {
        Section {
            Stepper(
                "\(minutes) minute\(minutes == 1 ? "" : "s")",
                value: $minutes,
                in: 5...60,
                step: 5
            )

            TextField("App or category (optional)", text: $targetDescription)
                .textInputAutocapitalization(.sentences)

            Picker("Urgency", selection: $urgency) {
                ForEach(UnlockRequestUrgency.allCases) { urgency in
                    Text(urgency.title).tag(urgency)
                }
            }

            TextField("Why do you need access?", text: $reason, axis: .vertical)
                .lineLimit(2...4)

            Button {
                sendRequest()
            } label: {
                Label("Send request", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(!canSend)
        } header: {
            Text("Request Details")
        } footer: {
            Text("BuddyLock keeps this lightweight: send the request, then let your people decide if you really need the unlock.")
        }
    }

    private var approvalRuleSection: some View {
        Section("Approval Rule") {
            if let resolvedAudience {
                Toggle("Override the default rule", isOn: $overrideApprovalRule)

                if overrideApprovalRule {
                    ApprovalRuleEditor(
                        rule: $customApprovalRule,
                        recipientCount: resolvedAudience.recipientCount
                    )
                } else {
                    Text(resolvedAudience.defaultApprovalRule.summary(for: resolvedAudience.recipientCount))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var outgoingSection: some View {
        Section("Recent Requests") {
            if requestService.outgoing.isEmpty {
                Text("You haven’t sent any unlock requests yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.outgoing.sorted { $0.createdDate > $1.createdDate }, id: \.stableID) { request in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.audienceLabel)
                                    .font(.headline)
                                Text("\(request.minutesRequested) minute\(request.minutesRequested == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            StatusPill(request: request)
                        }

                        Text(request.progressSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let target = request.targetDescription, !target.isEmpty {
                            Text("For: \(target)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let reason = request.reason, !reason.isEmpty {
                            Text("“\(reason)”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !request.responses.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(request.responses) { response in
                                    Text(responseLine(for: response))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Text(relativeDateString(from: request.createdDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var unlockCapableBuddies: [LocalBuddy] {
        buddyService.buddies.filter(\.canApproveUnlocks)
    }

    private var availableCategories: [BuddyCategory] {
        buddyService.categories.filter { buddyService.audienceForCategory($0) != nil }
    }

    private var availableGroups: [BuddyGroup] {
        buddyService.groups.filter { buddyService.audienceForGroup($0) != nil }
    }

    private var resolvedAudience: BuddyAudience? {
        switch audienceType {
        case .individual:
            guard let selectedBuddyID,
                  let buddy = buddyService.buddy(for: selectedBuddyID),
                  buddy.canApproveUnlocks else {
                return nil
            }
            return buddyService.audienceForBuddy(buddy)

        case .selectedBuddies:
            return buddyService.audienceForSelectedBuddies(selectedBuddyIDs)

        case .category:
            guard let selectedCategoryID,
                  let category = buddyService.category(for: selectedCategoryID) else {
                return nil
            }
            return buddyService.audienceForCategory(category)

        case .group:
            guard let selectedGroupID,
                  let group = buddyService.group(for: selectedGroupID) else {
                return nil
            }
            return buddyService.audienceForGroup(group)

        case .everyone:
            return buddyService.audienceForEveryone()
        }
    }

    private var shouldShowApprovalRuleEditor: Bool {
        guard let resolvedAudience else { return false }
        return resolvedAudience.allowsRuleOverride && resolvedAudience.recipientCount > 1
    }

    private var canSend: Bool {
        resolvedAudience != nil && minutes > 0
    }

    private func preselectFirstBuddyIfNeeded() {
        if selectedBuddyID == nil {
            selectedBuddyID = unlockCapableBuddies.first?.id
        }

        if selectedCategoryID == nil {
            selectedCategoryID = availableCategories.first?.id
        }

        if selectedGroupID == nil {
            selectedGroupID = availableGroups.first?.id
        }
    }

    private func sendRequest() {
        guard let resolvedAudience else { return }

        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "You"
            : displayName

        requestService.sendRequest(
            requesterName: name,
            audience: resolvedAudience,
            minutes: minutes,
            targetDescription: targetDescription,
            reason: reason,
            urgency: urgency,
            approvalRule: overrideApprovalRule ? customApprovalRule : nil
        )

        targetDescription = ""
        reason = ""
        showingSentConfirmation = true
    }

    private func responseLine(for response: UnlockApprovalResponse) -> String {
        let action = response.vote == .approved
            ? "approved"
            : "denied"
        let note = response.note.map { " - \($0)" } ?? ""
        return "\(response.responderName) \(action)\(note)"
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
