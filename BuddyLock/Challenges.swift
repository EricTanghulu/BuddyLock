import Foundation

// MARK: - Challenge Models

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case duel
    case group

    var id: String { rawValue }

    /// User-facing label
    var label: String {
        switch self {
        case .duel:  return "Duel"
        case .group: return "Group"
        }
    }
}

struct Challenge: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var type: ChallengeType
    var participantIDs: [UUID]          // includes local user plus buddies
    var startDate: Date
    var endDate: Date
    var scores: [UUID: Int] = [:]       // minutes of focus per participant

    /// Optional: describes what the challenge is about (apps/category/etc.)
    var targetDescription: String? = nil
}

// MARK: - Challenge Service (local only)

@MainActor
final class ChallengeService: ObservableObject {
    // local user identity stored once
    private let localUserKey = "BuddyLock.localUserID"
    private(set) var localUserID: UUID

    @Published private(set) var challenges: [Challenge] = []

    private let key = "BuddyLock.challenges"

    init() {
        // Ensure stable local user id across launches
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: localUserKey),
           let id = try? JSONDecoder().decode(UUID.self, from: data) {
            localUserID = id
        } else {
            let id = UUID()
            localUserID = id
            if let data = try? JSONEncoder().encode(id) {
                defaults.set(data, forKey: localUserKey)
            }
        }
        load()
    }

    // MARK: - Creation

    /// Create a duel between the local user and exactly one buddy.
    func createDuel(
        with buddy: LocalBuddy,
        title: String = "Duel",
        days: Int = 7,
        targetDescription: String? = nil
    ) {
        let start = Date()
        let end = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: start
        ) ?? start.addingTimeInterval(TimeInterval(days) * 24 * 60 * 60)

        let participants = [localUserID, buddy.id]

        var challenge = Challenge(
            title: title,
            type: .duel,
            participantIDs: participants,
            startDate: start,
            endDate: end,
            scores: [:],
            targetDescription: targetDescription
        )

        challenge.scores = Dictionary(uniqueKeysWithValues: participants.map { ($0, 0) })
        challenges.insert(challenge, at: 0)
        save()
    }

    /// Create a group challenge with multiple buddies (+ local user auto-included).
    func createGroup(
        with buddies: [LocalBuddy],
        title: String = "Group challenge",
        days: Int = 7,
        targetDescription: String? = nil
    ) {
        let start = Date()
        let end = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: start
        ) ?? start.addingTimeInterval(TimeInterval(days) * 24 * 60 * 60)

        let participantIDs = [localUserID] + buddies.map { $0.id }

        var challenge = Challenge(
            title: title,
            type: .group,
            participantIDs: participantIDs,
            startDate: start,
            endDate: end,
            scores: [:],
            targetDescription: targetDescription
        )

        challenge.scores = Dictionary(
            uniqueKeysWithValues: participantIDs.map { ($0, 0) }
        )
        challenges.insert(challenge, at: 0)
        save()
    }

    // MARK: - Updating

    /// Record minutes for a participant across all active challenges they are in.
    func recordMinutes(for participantID: UUID, minutes: Int) {
        guard minutes > 0 else { return }
        let now = Date()
        var changed = false

        for index in challenges.indices {
            guard challenges[index].participantIDs.contains(participantID) else { continue }
            guard now >= challenges[index].startDate,
                  now <= challenges[index].endDate else { continue }

            challenges[index].scores[participantID, default: 0] += minutes
            changed = true
        }

        if changed { save() }
    }

    /// Convenience for local user (use when a focus session completes)
    func recordLocalFocus(minutes: Int) {
        recordMinutes(for: localUserID, minutes: minutes)
    }

    /// For debugging / manual tweaks
    func addManualMinutes(to challengeID: UUID, participantID: UUID, minutes: Int) {
        guard minutes > 0,
              let index = challenges.firstIndex(where: { $0.id == challengeID }) else { return }

        challenges[index].scores[participantID, default: 0] += minutes
        save()
    }

    func removeChallenge(_ challenge: Challenge) {
        challenges.removeAll { $0.id == challenge.id }
        save()
    }

    // MARK: - Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Challenge].self, from: data) {
            challenges = decoded
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: key)
        }
    }
}
