import CryptoKit
import Foundation

enum BuddyVisibilityBucket: String, Codable, CaseIterable, Identifiable {
    case progress
    case challenges
    case unlockActivity
    case milestones
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .progress:
            return "Progress"
        case .challenges:
            return "Challenges"
        case .unlockActivity:
            return "Unlock Activity"
        case .milestones:
            return "Milestones & Posts"
        case .status:
            return "Status"
        }
    }
}

enum BuddyVisibilityPreset: String, Codable, CaseIterable, Identifiable {
    case close
    case standard
    case privateMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .close:
            return "Close"
        case .standard:
            return "Standard"
        case .privateMode:
            return "Private"
        }
    }

    var subtitle: String {
        switch self {
        case .close:
            return "Share progress, challenges, unlocks, milestones, and status."
        case .standard:
            return "Share progress, challenges, milestones, and status."
        case .privateMode:
            return "Share only the essentials."
        }
    }

    var defaultBuckets: Set<BuddyVisibilityBucket> {
        switch self {
        case .close:
            return Set(BuddyVisibilityBucket.allCases)
        case .standard:
            return [.progress, .challenges, .milestones, .status]
        case .privateMode:
            return [.progress, .status]
        }
    }
}

struct BuddyVisibilitySettings: Codable, Hashable {
    var preset: BuddyVisibilityPreset
    var visibleBuckets: Set<BuddyVisibilityBucket>

    init(
        preset: BuddyVisibilityPreset = .standard,
        visibleBuckets: Set<BuddyVisibilityBucket>? = nil
    ) {
        self.preset = preset
        self.visibleBuckets = visibleBuckets ?? preset.defaultBuckets
    }

    mutating func applyPreset(_ preset: BuddyVisibilityPreset) {
        self.preset = preset
        visibleBuckets = preset.defaultBuckets
    }
}

enum BuddyApprovalRuleKind: String, Codable, CaseIterable, Identifiable {
    case anyOne
    case majority
    case atLeastCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anyOne:
            return "Any 1"
        case .majority:
            return "Majority"
        case .atLeastCount:
            return "At Least N"
        }
    }
}

struct BuddyApprovalRule: Codable, Hashable {
    var kind: BuddyApprovalRuleKind
    var customCount: Int

    init(kind: BuddyApprovalRuleKind = .anyOne, customCount: Int = 2) {
        self.kind = kind
        self.customCount = max(customCount, 1)
    }

    func requiredApprovals(for recipientCount: Int) -> Int {
        let safeCount = max(recipientCount, 1)

        switch kind {
        case .anyOne:
            return 1
        case .majority:
            return (safeCount / 2) + 1
        case .atLeastCount:
            return min(max(customCount, 1), safeCount)
        }
    }

    func summary(for recipientCount: Int? = nil) -> String {
        switch kind {
        case .anyOne:
            return "Any 1 person can approve"
        case .majority:
            if let recipientCount {
                return "Majority approves (\(requiredApprovals(for: recipientCount)) needed)"
            }
            return "Majority approves"
        case .atLeastCount:
            if let recipientCount {
                return "At least \(requiredApprovals(for: recipientCount)) approval(s)"
            }
            return "At least \(customCount) approval(s)"
        }
    }
}

struct LocalBuddy: Identifiable, Codable, Hashable {
    var id: UUID
    var remoteID: String?
    var buddyUserID: String
    var displayName: String?
    var joinedAt: Date
    var categoryIDs: Set<UUID>
    var visibility: BuddyVisibilitySettings
    var canApproveUnlocks: Bool
    var note: String?

    init(
        id: UUID? = nil,
        remoteID: String? = nil,
        buddyUserID: String,
        displayName: String? = nil,
        joinedAt: Date = .now,
        categoryIDs: Set<UUID> = [],
        visibility: BuddyVisibilitySettings = BuddyVisibilitySettings(),
        canApproveUnlocks: Bool = true,
        note: String? = nil
    ) {
        self.id = id ?? UUID.stable(from: buddyUserID)
        self.remoteID = remoteID
        self.buddyUserID = buddyUserID
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.categoryIDs = categoryIDs
        self.visibility = visibility
        self.canApproveUnlocks = canApproveUnlocks
        self.note = note
    }

    var resolvedDisplayName: String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? buddyUserID : trimmed
    }
}

struct BuddyCategory: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var iconSystemName: String
    var isBuiltIn: Bool
    var visibility: BuddyVisibilitySettings

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String = "person.2.fill",
        isBuiltIn: Bool = false,
        visibility: BuddyVisibilitySettings = BuddyVisibilitySettings()
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.isBuiltIn = isBuiltIn
        self.visibility = visibility
    }
}

struct BuddyGroup: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var summary: String
    var memberIDs: Set<UUID>
    var coAdminIDs: Set<UUID>
    var visibility: BuddyVisibilitySettings
    var defaultApprovalRule: BuddyApprovalRule
    var allowRequesterOverride: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        memberIDs: Set<UUID>,
        coAdminIDs: Set<UUID> = [],
        visibility: BuddyVisibilitySettings = BuddyVisibilitySettings(preset: .close),
        defaultApprovalRule: BuddyApprovalRule = BuddyApprovalRule(),
        allowRequesterOverride: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.memberIDs = memberIDs
        self.coAdminIDs = coAdminIDs
        self.visibility = visibility
        self.defaultApprovalRule = defaultApprovalRule
        self.allowRequesterOverride = allowRequesterOverride
        self.createdAt = createdAt
    }
}

enum BuddyAudienceType: String, Codable, CaseIterable, Identifiable {
    case individual
    case selectedBuddies
    case category
    case group
    case everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .individual:
            return "One Buddy"
        case .selectedBuddies:
            return "Specific Buddies"
        case .category:
            return "Category"
        case .group:
            return "Group"
        case .everyone:
            return "Everyone"
        }
    }
}

struct BuddyAudience: Identifiable, Codable, Hashable {
    var type: BuddyAudienceType
    var referenceID: String?
    var label: String
    var recipientBuddyIDs: [UUID]
    var recipientUserIDs: [String]
    var defaultApprovalRule: BuddyApprovalRule
    var allowsRuleOverride: Bool

    var id: String {
        "\(type.rawValue)-\(referenceID ?? label)"
    }

    var recipientCount: Int {
        max(recipientUserIDs.count, 1)
    }
}

struct BuddyNetworkStore: Codable {
    var buddies: [LocalBuddy] = []
    var categories: [BuddyCategory] = []
    var groups: [BuddyGroup] = []
}

enum BuddyDataConstants {
    static let bestBuddiesCategoryID = UUID(uuidString: "D9A9EF2A-B2FD-4BCB-9EC9-3A5D9E0683AE")!
    static let maxBestBuddies = 5
}

extension UUID {
    static func stable(from seed: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let first = String(hex.prefix(8))
        let second = String(hex.dropFirst(8).prefix(4))
        let third = String(hex.dropFirst(12).prefix(4))
        let fourth = String(hex.dropFirst(16).prefix(4))
        let fifth = String(hex.dropFirst(20).prefix(12))
        let uuidString = "\(first)-\(second)-\(third)-\(fourth)-\(fifth)"

        return UUID(uuidString: uuidString) ?? UUID()
    }
}
