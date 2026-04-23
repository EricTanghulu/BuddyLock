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

    @State private var newCategoryName: String = ""
    @State private var addBuddyPresented = false
    @State private var createGroupPresented = false
    @State private var feedbackMessage: String?
    @State private var showingOrganization = true
    @State private var showingMaintenance = true

    var body: some View {
        List {
            networkOverviewSection
            connectionToolsSection
            organizationSection
            maintenanceSection
        }
        .navigationTitle("Organize Buddies")
        .sheet(isPresented: $addBuddyPresented) {
            NavigationStack {
                AddBuddyView(friendRequests: friendRequests)
            }
        }
        .sheet(isPresented: $createGroupPresented) {
            NavigationStack {
                GroupEditorView(buddyService: buddyService)
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

    private var networkOverviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Buddies is for live buddy work. Organize Buddies is for setup, cleanup, and organization.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    overviewMetric(title: "Buddies", value: buddyService.buddies.count)
                    overviewMetric(title: "Groups", value: buddyService.groups.count)
                    overviewMetric(title: "Lists", value: buddyService.categories.count)
                }

                if !friendRequests.incomingRequests.isEmpty {
                    Label("\(friendRequests.incomingRequests.count) incoming request\(friendRequests.incomingRequests.count == 1 ? "" : "s") waiting on the Buddies tab", systemImage: "bell.badge")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var connectionToolsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connection Tools")
                    .font(.headline)

                Text("Add a buddy when you want one person to handle quick accountability. Create a group when more than one buddy should decide together.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    addBuddyPresented = true
                } label: {
                    Label("Add Buddy", systemImage: "person.badge.plus")
                }

                Button {
                    createGroupPresented = true
                } label: {
                    Label("New Group", systemImage: "person.3.fill")
                }
                .disabled(buddyService.buddies.isEmpty)

                if buddyService.buddies.isEmpty {
                    Text("Groups stay disabled until you have at least one buddy to put in them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var organizationSection: some View {
        Section {
            DisclosureGroup("Organization", isExpanded: $showingOrganization) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lists are optional. They help once your buddy network is large enough that you want named clusters like roommates, classmates, or Best Buddies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(orderedCategories) { category in
                        NavigationLink {
                            CategoryDetailView(
                                buddyService: buddyService,
                                categoryID: category.id
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Label(category.name, systemImage: category.iconSystemName)
                                    Spacer()
                                    Text("\(buddyService.buddies(in: category).count)")
                                        .foregroundStyle(.secondary)
                                }

                                Text(categorySummary(for: category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    HStack {
                        TextField("New list", text: $newCategoryName)
                        Button("Add") {
                            if buddyService.createCategory(name: newCategoryName) != nil {
                                newCategoryName = ""
                            }
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        } header: {
            EmptyView()
        } footer: {
            Text("Individual buddies and groups stay on the main Buddies tab so this screen does not duplicate your live network.")
        }
    }

    private var maintenanceSection: some View {
        Section {
            DisclosureGroup("Maintenance", isExpanded: $showingMaintenance) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use this area for cleanup, not daily buddy work.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if emptyCustomCategories.isEmpty && emptyGroups.isEmpty {
                        Text("No cleanup needed right now. Your buddy lists and groups look healthy.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        if !emptyCustomCategories.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(emptyCustomCategories.count) empty list\(emptyCustomCategories.count == 1 ? "" : "s")")
                                        .font(.subheadline.weight(.semibold))
                                    Text("These lists have no buddies in them yet.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Remove Empty Lists") {
                                    for category in emptyCustomCategories {
                                        buddyService.removeCategory(category)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        if !emptyGroups.isEmpty {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(emptyGroups.count) empty group\(emptyGroups.count == 1 ? "" : "s")")
                                        .font(.subheadline.weight(.semibold))
                                    Text("These groups no longer have any buddies in them.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Remove Empty Groups") {
                                    for group in emptyGroups {
                                        buddyService.removeGroup(group)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private func overviewMetric(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedCategories: [BuddyCategory] {
        buddyService.categories.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var emptyCustomCategories: [BuddyCategory] {
        orderedCategories.filter { !$0.isBuiltIn && buddyService.buddies(in: $0).isEmpty }
    }

    private var emptyGroups: [BuddyGroup] {
        buddyService.groups.filter { $0.memberIDs.isEmpty }
    }

    private func categorySummary(for category: BuddyCategory) -> String {
        if category.isBuiltIn {
            return "Built-in buddy list"
        }

        let memberCount = buddyService.buddies(in: category).count
        if memberCount == 0 {
            return "Custom list • Empty right now"
        }
        return "Custom list • \(memberCount) buddy\(memberCount == 1 ? "" : "ies")"
    }
}

struct AddBuddyView: View {
    @ObservedObject var friendRequests: FriendRequestService
    @Environment(\.dismiss) private var dismiss

    @State private var friendUserID = ""
    @State private var feedbackMessage: String?
    @State private var isSending = false

    var body: some View {
        Form {
            Section("Add Buddy") {
                TextField("Buddy's username", text: $friendUserID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Text("BuddyLock works best with buddies you already know. Send them your username so they can connect quickly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let feedbackMessage {
                Section {
                    Text(feedbackMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Add Buddy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isSending ? "Sending..." : "Send") {
                    sendRequest()
                }
                .disabled(isSending || friendUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func sendRequest() {
        let username = friendUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return }

        isSending = true
        feedbackMessage = nil

        Task {
            do {
                try await friendRequests.sendRequest(targetID: username)
                await MainActor.run {
                    isSending = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    feedbackMessage = error.localizedDescription
                }
            }
        }
    }
}

struct BuddyDetailView: View {
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
                            Text("Best Buddies are limited to \(BuddyDataConstants.maxBestBuddies) buddies so the category stays meaningful.")
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

struct CategoryDetailView: View {
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

struct GroupDetailView: View {
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

struct GroupEditorView: View {
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
