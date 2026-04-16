import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
final class LocalBuddyService: ObservableObject {
    @Published private(set) var buddies: [LocalBuddy] = []
    @Published private(set) var categories: [BuddyCategory] = []
    @Published private(set) var groups: [BuddyGroup] = []

    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let currentUserID: String
    private let storeKey: String
    private let hasSignedInUser: Bool

    private var listener: ListenerRegistration?

    init() {
        let sessionUserID = Auth.auth().currentUser?.uid ?? "preview-user"
        currentUserID = sessionUserID
        hasSignedInUser = Auth.auth().currentUser != nil
        storeKey = "BuddyLock.buddyNetwork.\(sessionUserID)"

        load()
        ensureBuiltInCategory()
        normalizeState()
        startListeningIfNeeded()
    }

    deinit {
        listener?.remove()
    }

    var bestBuddiesCategory: BuddyCategory? {
        categories.first(where: { $0.id == BuddyDataConstants.bestBuddiesCategoryID })
    }

    var bestBuddyCount: Int {
        buddies.filter(isBestBuddy).count
    }

    func buddy(for id: UUID) -> LocalBuddy? {
        buddies.first(where: { $0.id == id })
    }

    func category(for id: UUID) -> BuddyCategory? {
        categories.first(where: { $0.id == id })
    }

    func group(for id: UUID) -> BuddyGroup? {
        groups.first(where: { $0.id == id })
    }

    func displayName(for buddyID: UUID) -> String {
        buddy(for: buddyID)?.resolvedDisplayName ?? "Unknown"
    }

    func categories(for buddy: LocalBuddy) -> [BuddyCategory] {
        categories
            .filter { buddy.categoryIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.isBuiltIn != rhs.isBuiltIn {
                    return lhs.isBuiltIn && !rhs.isBuiltIn
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func buddies(in category: BuddyCategory) -> [LocalBuddy] {
        buddies(inCategoryID: category.id)
    }

    func buddies(inCategoryID categoryID: UUID) -> [LocalBuddy] {
        buddies
            .filter { $0.categoryIDs.contains(categoryID) }
            .sorted { $0.resolvedDisplayName.localizedCaseInsensitiveCompare($1.resolvedDisplayName) == .orderedAscending }
    }

    func groups(containing buddyID: UUID) -> [BuddyGroup] {
        groups
            .filter { $0.memberIDs.contains(buddyID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func isBestBuddy(_ buddy: LocalBuddy) -> Bool {
        buddy.categoryIDs.contains(BuddyDataConstants.bestBuddiesCategoryID)
    }

    func audienceForBuddy(_ buddy: LocalBuddy) -> BuddyAudience {
        BuddyAudience(
            type: .individual,
            referenceID: buddy.id.uuidString,
            label: buddy.resolvedDisplayName,
            recipientBuddyIDs: [buddy.id],
            recipientUserIDs: [buddy.buddyUserID],
            defaultApprovalRule: BuddyApprovalRule(kind: .anyOne),
            allowsRuleOverride: false
        )
    }

    func audienceForCategory(_ category: BuddyCategory) -> BuddyAudience? {
        let categoryBuddies = buddies(in: category).filter(\.canApproveUnlocks)
        guard !categoryBuddies.isEmpty else { return nil }

        return BuddyAudience(
            type: .category,
            referenceID: category.id.uuidString,
            label: category.name,
            recipientBuddyIDs: categoryBuddies.map(\.id),
            recipientUserIDs: categoryBuddies.map(\.buddyUserID),
            defaultApprovalRule: BuddyApprovalRule(
                kind: categoryBuddies.count == 1 ? .anyOne : .majority
            ),
            allowsRuleOverride: true
        )
    }

    func audienceForGroup(_ group: BuddyGroup) -> BuddyAudience? {
        let memberBuddies = buddies
            .filter { group.memberIDs.contains($0.id) && $0.canApproveUnlocks }
            .sorted { $0.resolvedDisplayName.localizedCaseInsensitiveCompare($1.resolvedDisplayName) == .orderedAscending }
        guard !memberBuddies.isEmpty else { return nil }

        return BuddyAudience(
            type: .group,
            referenceID: group.id.uuidString,
            label: group.name,
            recipientBuddyIDs: memberBuddies.map(\.id),
            recipientUserIDs: memberBuddies.map(\.buddyUserID),
            defaultApprovalRule: group.defaultApprovalRule,
            allowsRuleOverride: group.allowRequesterOverride
        )
    }

    func audienceForEveryone() -> BuddyAudience? {
        let recipients = buddies.filter(\.canApproveUnlocks)
        guard !recipients.isEmpty else { return nil }

        return BuddyAudience(
            type: .everyone,
            referenceID: "everyone",
            label: "Everyone",
            recipientBuddyIDs: recipients.map(\.id),
            recipientUserIDs: recipients.map(\.buddyUserID),
            defaultApprovalRule: BuddyApprovalRule(
                kind: recipients.count == 1 ? .anyOne : .majority
            ),
            allowsRuleOverride: true
        )
    }

    func audienceForSelectedBuddies(_ buddyIDs: Set<UUID>) -> BuddyAudience? {
        let selected = buddies
            .filter { buddyIDs.contains($0.id) && $0.canApproveUnlocks }
            .sorted { $0.resolvedDisplayName.localizedCaseInsensitiveCompare($1.resolvedDisplayName) == .orderedAscending }
        guard !selected.isEmpty else { return nil }

        let label: String
        if selected.count == 1 {
            label = selected[0].resolvedDisplayName
        } else {
            label = "\(selected.count) selected buddies"
        }

        return BuddyAudience(
            type: .selectedBuddies,
            referenceID: "selected",
            label: label,
            recipientBuddyIDs: selected.map(\.id),
            recipientUserIDs: selected.map(\.buddyUserID),
            defaultApprovalRule: BuddyApprovalRule(
                kind: selected.count == 1 ? .anyOne : .majority
            ),
            allowsRuleOverride: true
        )
    }

    func addBuddy(_ buddy: LocalBuddy) {
        upsertBuddy(buddy)
    }

    func updateBuddy(_ buddy: LocalBuddy) {
        guard let index = buddies.firstIndex(where: { $0.id == buddy.id }) else { return }
        buddies[index] = buddy
        normalizeState()
        save()
    }

    @discardableResult
    func setBestBuddy(_ isBest: Bool, for buddy: LocalBuddy) -> Bool {
        guard let index = buddies.firstIndex(where: { $0.id == buddy.id }) else { return false }

        if isBest,
           !buddies[index].categoryIDs.contains(BuddyDataConstants.bestBuddiesCategoryID),
           bestBuddyCount >= BuddyDataConstants.maxBestBuddies {
            return false
        }

        if isBest {
            buddies[index].categoryIDs.insert(BuddyDataConstants.bestBuddiesCategoryID)
        } else {
            buddies[index].categoryIDs.remove(BuddyDataConstants.bestBuddiesCategoryID)
        }

        save()
        return true
    }

    func setBuddy(_ buddyID: UUID, inCategory categoryID: UUID, isMember: Bool) {
        guard let index = buddies.firstIndex(where: { $0.id == buddyID }) else { return }
        if isMember {
            buddies[index].categoryIDs.insert(categoryID)
        } else {
            buddies[index].categoryIDs.remove(categoryID)
        }
        normalizeState()
        save()
    }

    @discardableResult
    func createCategory(
        name: String,
        iconSystemName: String = "person.3.fill"
    ) -> BuddyCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !categories.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return nil
        }

        let category = BuddyCategory(
            name: trimmed,
            iconSystemName: iconSystemName,
            visibility: BuddyVisibilitySettings()
        )
        categories.append(category)
        normalizeState()
        save()
        return category
    }

    func updateCategory(_ category: BuddyCategory) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        normalizeState()
        save()
    }

    func removeCategory(_ category: BuddyCategory) {
        guard !category.isBuiltIn else { return }
        categories.removeAll { $0.id == category.id }
        for index in buddies.indices {
            buddies[index].categoryIDs.remove(category.id)
        }
        normalizeState()
        save()
    }

    @discardableResult
    func createGroup(
        name: String,
        summary: String = "",
        memberIDs: Set<UUID>,
        defaultApprovalRule: BuddyApprovalRule,
        allowRequesterOverride: Bool = true
    ) -> BuddyGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let validMembers = Set(memberIDs.filter { buddy(for: $0) != nil })
        guard !validMembers.isEmpty else { return nil }

        let group = BuddyGroup(
            name: trimmed,
            summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
            memberIDs: validMembers,
            visibility: BuddyVisibilitySettings(preset: .close),
            defaultApprovalRule: defaultApprovalRule,
            allowRequesterOverride: allowRequesterOverride
        )
        groups.append(group)
        normalizeState()
        save()
        return group
    }

    func updateGroup(_ group: BuddyGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index] = group
        normalizeState()
        save()
    }

    func removeGroup(_ group: BuddyGroup) {
        groups.removeAll { $0.id == group.id }
        normalizeState()
        save()
    }

    func removeBuddy(_ buddy: LocalBuddy) {
        buddies.removeAll { $0.id == buddy.id }
        for index in groups.indices {
            groups[index].memberIDs.remove(buddy.id)
            groups[index].coAdminIDs.remove(buddy.id)
        }
        groups.removeAll { $0.memberIDs.isEmpty }
        save()

        guard hasSignedInUser else { return }
        let buddyID = buddy.remoteID ?? buddy.buddyUserID

        db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .document(buddyID)
            .delete()

        db.collection("users")
            .document(buddyID)
            .collection("friends")
            .document(currentUserID)
            .delete()
    }

    private func startListeningIfNeeded() {
        guard hasSignedInUser else { return }

        listener = db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    print("Buddy listener error: \(error)")
                    return
                }

                let documents = snapshot?.documents ?? []
                let remoteFriendIDs = Set(documents.map(\.documentID))
                let namesByRemoteID = documents.reduce(into: [String: String]()) { partialResult, document in
                    if let displayName = document.data()["displayName"] as? String {
                        partialResult[document.documentID] = displayName
                    }
                }

                syncRemoteFriends(remoteFriendIDs, namesByRemoteID: namesByRemoteID)
            }
    }

    private func syncRemoteFriends(
        _ remoteFriendIDs: Set<String>,
        namesByRemoteID: [String: String]
    ) {
        buddies.removeAll { buddy in
            guard let remoteID = buddy.remoteID else { return false }
            return !remoteFriendIDs.contains(remoteID)
        }

        for remoteID in remoteFriendIDs {
            let existingIndex = buddies.firstIndex {
                $0.remoteID == remoteID || $0.buddyUserID == remoteID
            }

            if let existingIndex {
                buddies[existingIndex].remoteID = remoteID
                if let remoteName = namesByRemoteID[remoteID],
                   (buddies[existingIndex].displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                    buddies[existingIndex].displayName = remoteName
                }
            } else {
                let buddy = LocalBuddy(
                    remoteID: remoteID,
                    buddyUserID: remoteID,
                    displayName: namesByRemoteID[remoteID]
                )
                buddies.append(buddy)
            }
        }

        normalizeState()
        save()
    }

    private func upsertBuddy(_ buddy: LocalBuddy) {
        if let index = buddies.firstIndex(where: {
            $0.id == buddy.id ||
            $0.buddyUserID == buddy.buddyUserID ||
            (buddy.remoteID != nil && $0.remoteID == buddy.remoteID)
        }) {
            let existing = buddies[index]
            buddies[index] = LocalBuddy(
                id: existing.id,
                remoteID: buddy.remoteID ?? existing.remoteID,
                buddyUserID: buddy.buddyUserID,
                displayName: buddy.displayName ?? existing.displayName,
                joinedAt: existing.joinedAt,
                categoryIDs: existing.categoryIDs.union(buddy.categoryIDs),
                visibility: buddy.visibility,
                canApproveUnlocks: buddy.canApproveUnlocks,
                note: buddy.note ?? existing.note
            )
        } else {
            buddies.append(buddy)
        }

        normalizeState()
        save()
    }

    private func ensureBuiltInCategory() {
        guard !categories.contains(where: { $0.id == BuddyDataConstants.bestBuddiesCategoryID }) else {
            return
        }

        categories.append(
            BuddyCategory(
                id: BuddyDataConstants.bestBuddiesCategoryID,
                name: "Best Buddies",
                iconSystemName: "star.fill",
                isBuiltIn: true,
                visibility: BuddyVisibilitySettings(preset: .close)
            )
        )
    }

    private func normalizeState() {
        let validCategoryIDs = Set(categories.map(\.id))
        for index in buddies.indices {
            buddies[index].categoryIDs = buddies[index].categoryIDs.intersection(validCategoryIDs)
        }

        let validBuddyIDs = Set(buddies.map(\.id))
        for index in groups.indices {
            groups[index].memberIDs = groups[index].memberIDs.intersection(validBuddyIDs)
            groups[index].coAdminIDs = groups[index].coAdminIDs.intersection(validBuddyIDs)
        }
        groups.removeAll { $0.memberIDs.isEmpty }

        buddies.sort { $0.resolvedDisplayName.localizedCaseInsensitiveCompare($1.resolvedDisplayName) == .orderedAscending }
        categories.sort { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn {
                return lhs.isBuiltIn && !rhs.isBuiltIn
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        groups.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func load() {
        guard let data = defaults.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode(BuddyNetworkStore.self, from: data) else {
            buddies = []
            categories = []
            groups = []
            return
        }

        buddies = decoded.buddies
        categories = decoded.categories
        groups = decoded.groups
    }

    private func save() {
        let store = BuddyNetworkStore(
            buddies: buddies,
            categories: categories,
            groups: groups
        )
        if let data = try? JSONEncoder().encode(store) {
            defaults.set(data, forKey: storeKey)
        }
    }
}
