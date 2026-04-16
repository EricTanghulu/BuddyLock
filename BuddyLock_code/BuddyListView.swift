import SwiftUI

private struct UnavailableStateView: View {
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

struct BuddyListView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequests: FriendRequestService

    @State private var friendUserID: String = ""
    @State private var newCategoryName: String = ""
    @State private var createGroupPresented = false
    @State private var feedbackMessage: String?

    var body: some View {
        List {
            addBuddySection

            if !friendRequests.incomingRequests.isEmpty {
                pendingRequestsSection
            }

            summarySection
            categoriesSection
            groupsSection
            buddiesSection
        }
        .navigationTitle("Buddy System")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createGroupPresented = true
                } label: {
                    Label("New Group", systemImage: "person.3.fill")
                }
            }
        }
        .sheet(isPresented: $createGroupPresented) {
            NavigationStack {
                GroupEditorView(buddyService: buddyService)
            }
        }
    }

    private var addBuddySection: some View {
        Section {
            TextField("Friend's username", text: $friendUserID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task {
                    do {
                        try await friendRequests.sendRequest(targetID: friendUserID)
                        friendUserID = ""
                        feedbackMessage = "Buddy request sent."
                    } catch {
                        feedbackMessage = error.localizedDescription
                    }
                }
            } label: {
                Label("Send buddy request", systemImage: "paperplane.fill")
            }
            .disabled(friendUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Add Buddy")
        } footer: {
            Text("BuddyLock works best with people you already know. Send them your username so they can connect quickly.")
        }
    }

    private var pendingRequestsSection: some View {
        Section("Pending Requests") {
            ForEach(friendRequests.incomingRequests) { request in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.fromUserID)
                            .font(.headline)
                        Text("Wants to become your buddy.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(spacing: 8) {
                        Button("Accept") {
                            Task {
                                do {
                                    try await friendRequests.accept(request)
                                } catch {
                                    feedbackMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Deny") {
                            Task {
                                do {
                                    try await friendRequests.reject(request)
                                } catch {
                                    feedbackMessage = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.footnote)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var summarySection: some View {
        Section("Overview") {
            summaryRow(
                title: "Buddies",
                value: "\(buddyService.buddies.count)",
                note: "People who can support your focus"
            )
            summaryRow(
                title: "Best Buddies",
                value: "\(buddyService.bestBuddyCount)/\(BuddyDataConstants.maxBestBuddies)",
                note: "Priority people for closer accountability"
            )
            summaryRow(
                title: "Groups",
                value: "\(buddyService.groups.count)",
                note: "Private circles for approvals and challenges"
            )
        }
    }

    private func summaryRow(title: String, value: String, note: String) -> some View {
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

    private var categoriesSection: some View {
        Section {
            ForEach(buddyService.categories) { category in
                NavigationLink {
                    CategoryDetailView(
                        buddyService: buddyService,
                        categoryID: category.id
                    )
                } label: {
                    HStack {
                        Label(category.name, systemImage: category.iconSystemName)
                        Spacer()
                        Text("\(buddyService.buddies(in: category).count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                TextField("New category", text: $newCategoryName)
                Button("Add") {
                    if buddyService.createCategory(name: newCategoryName) != nil {
                        newCategoryName = ""
                    }
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Use categories like Best Buddies, roommates, or study partners to control visibility and unlock audiences.")
        }
    }

    private var groupsSection: some View {
        Section("Groups") {
            if buddyService.groups.isEmpty {
                Text("Create a private group for roommates, study friends, or anyone you want to challenge together.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddyService.groups) { group in
                    NavigationLink {
                        GroupDetailView(
                            buddyService: buddyService,
                            groupID: group.id
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name)
                                .font(.headline)
                            Text(group.defaultApprovalRule.summary(for: group.memberIDs.count))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var buddiesSection: some View {
        Section("Your Buddies") {
            if buddyService.buddies.isEmpty {
                Text("No buddies yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddyService.buddies) { buddy in
                    NavigationLink {
                        BuddyDetailView(
                            buddyService: buddyService,
                            buddyID: buddy.id
                        )
                    } label: {
                        BuddyRow(
                            buddy: buddy,
                            categories: buddyService.categories(for: buddy),
                            isBestBuddy: buddyService.isBestBuddy(buddy)
                        )
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            _ = buddyService.setBestBuddy(!buddyService.isBestBuddy(buddy), for: buddy)
                        } label: {
                            Label(
                                buddyService.isBestBuddy(buddy) ? "Unstar" : "Best Buddy",
                                systemImage: buddyService.isBestBuddy(buddy) ? "star.slash" : "star.fill"
                            )
                        }
                        .tint(.yellow)
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
}

private struct BuddyRow: View {
    let buddy: LocalBuddy
    let categories: [BuddyCategory]
    let isBestBuddy: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(buddy.resolvedDisplayName)
                    .font(.headline)
                if isBestBuddy {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(buddy.visibility.preset.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !categories.isEmpty {
                Text(categories.map(\.name).joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BuddyDetailView: View {
    @ObservedObject var buddyService: LocalBuddyService
    let buddyID: UUID

    @Environment(\.dismiss) private var dismiss

    private var buddy: LocalBuddy? {
        buddyService.buddy(for: buddyID)
    }

    var body: some View {
        Group {
            if let buddy {
                Form {
                    Section("Profile") {
                        Text(buddy.resolvedDisplayName)
                            .font(.headline)
                        Text("@\(buddy.buddyUserID)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Access") {
                        Toggle("Can approve unlock requests", isOn: canApproveBinding)

                        Toggle("Best Buddy", isOn: bestBuddyBinding)

                        if !buddyService.isBestBuddy(buddy),
                           buddyService.bestBuddyCount >= BuddyDataConstants.maxBestBuddies {
                            Text("Best Buddies are limited to \(BuddyDataConstants.maxBestBuddies) people so the category stays meaningful.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Categories") {
                        ForEach(buddyService.categories) { category in
                            Toggle(
                                category.name,
                                isOn: categoryMembershipBinding(for: category.id)
                            )
                            .disabled(isMembershipToggleDisabled(for: category, buddy: buddy))
                        }
                    }

                    Section("Visibility") {
                        VisibilitySettingsEditor(settings: visibilityBinding)
                    }

                    Section("Notes") {
                        TextField("Optional note", text: noteBinding, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section {
                        Button(role: .destructive) {
                            buddyService.removeBuddy(buddy)
                            dismiss()
                        } label: {
                            Text("Remove Buddy")
                        }
                    }
                }
            } else {
                UnavailableStateView(title: "Buddy not found", systemImage: "person.slash")
            }
        }
        .navigationTitle(buddy?.resolvedDisplayName ?? "Buddy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var visibilityBinding: Binding<BuddyVisibilitySettings> {
        Binding(
            get: { buddy?.visibility ?? BuddyVisibilitySettings() },
            set: { newValue in
                guard var buddy else { return }
                buddy.visibility = newValue
                buddyService.updateBuddy(buddy)
            }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { buddy?.note ?? "" },
            set: { newValue in
                guard var buddy else { return }
                buddy.note = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newValue
                buddyService.updateBuddy(buddy)
            }
        )
    }

    private var canApproveBinding: Binding<Bool> {
        Binding(
            get: { buddy?.canApproveUnlocks ?? true },
            set: { newValue in
                guard var buddy else { return }
                buddy.canApproveUnlocks = newValue
                buddyService.updateBuddy(buddy)
            }
        )
    }

    private var bestBuddyBinding: Binding<Bool> {
        Binding(
            get: { buddy.map(buddyService.isBestBuddy) ?? false },
            set: { newValue in
                guard let buddy else { return }
                _ = buddyService.setBestBuddy(newValue, for: buddy)
            }
        )
    }

    private func categoryMembershipBinding(for categoryID: UUID) -> Binding<Bool> {
        Binding(
            get: { buddy?.categoryIDs.contains(categoryID) ?? false },
            set: { newValue in
                buddyService.setBuddy(buddyID, inCategory: categoryID, isMember: newValue)
            }
        )
    }

    private func isMembershipToggleDisabled(for category: BuddyCategory, buddy: LocalBuddy) -> Bool {
        category.id == BuddyDataConstants.bestBuddiesCategoryID &&
        !buddy.categoryIDs.contains(category.id) &&
        buddyService.bestBuddyCount >= BuddyDataConstants.maxBestBuddies
    }
}

private struct CategoryDetailView: View {
    @ObservedObject var buddyService: LocalBuddyService
    let categoryID: UUID

    @Environment(\.dismiss) private var dismiss

    private var category: BuddyCategory? {
        buddyService.category(for: categoryID)
    }

    var body: some View {
        Group {
            if let category {
                Form {
                    if !category.isBuiltIn {
                        Section("Name") {
                            TextField("Category name", text: categoryNameBinding)
                        }
                    }

                    Section("Visibility") {
                        VisibilitySettingsEditor(settings: visibilityBinding)
                    }

                    Section("Members") {
                        ForEach(buddyService.buddies) { buddy in
                            Toggle(
                                buddy.resolvedDisplayName,
                                isOn: memberBinding(buddyID: buddy.id)
                            )
                        }
                    }

                    if !category.isBuiltIn {
                        Section {
                            Button(role: .destructive) {
                                buddyService.removeCategory(category)
                                dismiss()
                            } label: {
                                Text("Delete Category")
                            }
                        }
                    }
                }
            } else {
                UnavailableStateView(title: "Category not found", systemImage: "tag.slash")
            }
        }
        .navigationTitle(category?.name ?? "Category")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var categoryNameBinding: Binding<String> {
        Binding(
            get: { category?.name ?? "" },
            set: { newValue in
                guard var category else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                category.name = trimmed
                buddyService.updateCategory(category)
            }
        )
    }

    private var visibilityBinding: Binding<BuddyVisibilitySettings> {
        Binding(
            get: { category?.visibility ?? BuddyVisibilitySettings() },
            set: { newValue in
                guard var category else { return }
                category.visibility = newValue
                buddyService.updateCategory(category)
            }
        )
    }

    private func memberBinding(buddyID: UUID) -> Binding<Bool> {
        Binding(
            get: { buddyService.buddy(for: buddyID)?.categoryIDs.contains(categoryID) ?? false },
            set: { newValue in
                buddyService.setBuddy(buddyID, inCategory: categoryID, isMember: newValue)
            }
        )
    }
}

private struct GroupDetailView: View {
    @ObservedObject var buddyService: LocalBuddyService
    let groupID: UUID

    @Environment(\.dismiss) private var dismiss

    private var group: BuddyGroup? {
        buddyService.group(for: groupID)
    }

    var body: some View {
        Group {
            if let group {
                Form {
                    Section("Basics") {
                        TextField("Group name", text: groupNameBinding)
                        TextField("Short description", text: groupSummaryBinding, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Section("Approvals") {
                        ApprovalRuleEditor(
                            rule: approvalRuleBinding,
                            recipientCount: group.memberIDs.count
                        )
                        Toggle("Allow requester override", isOn: requesterOverrideBinding)
                    }

                    Section("Visibility") {
                        VisibilitySettingsEditor(settings: visibilityBinding)
                    }

                    Section("Members") {
                        ForEach(buddyService.buddies) { buddy in
                            Toggle(
                                buddy.resolvedDisplayName,
                                isOn: memberBinding(buddyID: buddy.id)
                            )
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            buddyService.removeGroup(group)
                            dismiss()
                        } label: {
                            Text("Delete Group")
                        }
                    }
                }
            } else {
                UnavailableStateView(title: "Group not found", systemImage: "person.3.sequence")
            }
        }
        .navigationTitle(group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupNameBinding: Binding<String> {
        Binding(
            get: { group?.name ?? "" },
            set: { newValue in
                guard var group else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                group.name = trimmed
                buddyService.updateGroup(group)
            }
        )
    }

    private var groupSummaryBinding: Binding<String> {
        Binding(
            get: { group?.summary ?? "" },
            set: { newValue in
                guard var group else { return }
                group.summary = newValue
                buddyService.updateGroup(group)
            }
        )
    }

    private var requesterOverrideBinding: Binding<Bool> {
        Binding(
            get: { group?.allowRequesterOverride ?? true },
            set: { newValue in
                guard var group else { return }
                group.allowRequesterOverride = newValue
                buddyService.updateGroup(group)
            }
        )
    }

    private var approvalRuleBinding: Binding<BuddyApprovalRule> {
        Binding(
            get: { group?.defaultApprovalRule ?? BuddyApprovalRule() },
            set: { newValue in
                guard var group else { return }
                group.defaultApprovalRule = newValue
                buddyService.updateGroup(group)
            }
        )
    }

    private var visibilityBinding: Binding<BuddyVisibilitySettings> {
        Binding(
            get: { group?.visibility ?? BuddyVisibilitySettings() },
            set: { newValue in
                guard var group else { return }
                group.visibility = newValue
                buddyService.updateGroup(group)
            }
        )
    }

    private func memberBinding(buddyID: UUID) -> Binding<Bool> {
        Binding(
            get: { group?.memberIDs.contains(buddyID) ?? false },
            set: { newValue in
                guard var group else { return }
                if newValue {
                    group.memberIDs.insert(buddyID)
                } else {
                    group.memberIDs.remove(buddyID)
                }
                buddyService.updateGroup(group)
            }
        )
    }

    private func unavailableState(title: String, systemImage: String) -> some View {
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

private struct GroupEditorView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var summary = ""
    @State private var selectedMembers: Set<UUID> = []
    @State private var approvalRule = BuddyApprovalRule(kind: .majority)
    @State private var allowRequesterOverride = true

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Group name", text: $name)
                TextField("Description (optional)", text: $summary, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Members") {
                if buddyService.buddies.isEmpty {
                    Text("Add buddies first, then build a group around them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(buddyService.buddies) { buddy in
                        Toggle(
                            buddy.resolvedDisplayName,
                            isOn: Binding(
                                get: { selectedMembers.contains(buddy.id) },
                                set: { newValue in
                                    if newValue {
                                        selectedMembers.insert(buddy.id)
                                    } else {
                                        selectedMembers.remove(buddy.id)
                                    }
                                }
                            )
                        )
                    }
                }
            }

            Section("Approvals") {
                ApprovalRuleEditor(
                    rule: $approvalRule,
                    recipientCount: selectedMembers.count
                )
                Toggle("Allow requester override", isOn: $allowRequesterOverride)
            }
        }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    if buddyService.createGroup(
                        name: name,
                        summary: summary,
                        memberIDs: selectedMembers,
                        defaultApprovalRule: approvalRule,
                        allowRequesterOverride: allowRequesterOverride
                    ) != nil {
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedMembers.isEmpty)
            }
        }
    }

    private func unavailableState(title: String, systemImage: String) -> some View {
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

struct VisibilitySettingsEditor: View {
    @Binding var settings: BuddyVisibilitySettings

    var body: some View {
        Picker("Preset", selection: presetBinding) {
            ForEach(BuddyVisibilityPreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }

        ForEach(BuddyVisibilityBucket.allCases) { bucket in
            Toggle(
                bucket.title,
                isOn: Binding(
                    get: { settings.visibleBuckets.contains(bucket) },
                    set: { newValue in
                        if newValue {
                            settings.visibleBuckets.insert(bucket)
                        } else {
                            settings.visibleBuckets.remove(bucket)
                        }
                    }
                )
            )
        }
    }

    private var presetBinding: Binding<BuddyVisibilityPreset> {
        Binding(
            get: { settings.preset },
            set: { newValue in
                settings.applyPreset(newValue)
            }
        )
    }

    private func unavailableState(title: String, systemImage: String) -> some View {
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

struct ApprovalRuleEditor: View {
    @Binding var rule: BuddyApprovalRule
    let recipientCount: Int

    var body: some View {
        Picker("Approval rule", selection: ruleKindBinding) {
            ForEach(BuddyApprovalRuleKind.allCases) { kind in
                Text(kind.title).tag(kind)
            }
        }

        if rule.kind == .atLeastCount {
            Stepper(
                "Approvals needed: \(min(max(rule.customCount, 1), max(recipientCount, 1)))",
                value: customCountBinding,
                in: 1...max(recipientCount, 1)
            )
        }

        Text(rule.summary(for: recipientCount))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var ruleKindBinding: Binding<BuddyApprovalRuleKind> {
        Binding(
            get: { rule.kind },
            set: { newValue in
                rule.kind = newValue
                if newValue == .anyOne {
                    rule.customCount = 1
                } else if newValue == .majority {
                    rule.customCount = max(2, (recipientCount / 2) + 1)
                }
            }
        )
    }

    private var customCountBinding: Binding<Int> {
        Binding(
            get: { min(max(rule.customCount, 1), max(recipientCount, 1)) },
            set: { newValue in
                rule.customCount = max(newValue, 1)
            }
        )
    }
}

#Preview {
    let buddyService = LocalBuddyService()
    buddyService.addBuddy(LocalBuddy(buddyUserID: "sam", displayName: "Sam"))
    buddyService.addBuddy(LocalBuddy(buddyUserID: "jules", displayName: "Jules"))
    _ = buddyService.createCategory(name: "Roommates")
    let groupMembers = Set(buddyService.buddies.map(\.id))
    _ = buddyService.createGroup(
        name: "Apartment Crew",
        memberIDs: groupMembers,
        defaultApprovalRule: BuddyApprovalRule(kind: .majority)
    )

    return NavigationStack {
        BuddyListView(
            buddyService: buddyService,
            friendRequests: FriendRequestService(buddyService: buddyService)
        )
    }
}
