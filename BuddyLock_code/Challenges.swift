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

enum ChallengePhase {
    case active
    case upcoming
    case completed
}

enum ChallengeActivityKind: String, Codable {
    case created
    case rematchStarted
    case minutesLogged
}

struct ChallengeActivityItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var challengeID: UUID
    var challengeTitle: String
    var participantID: UUID?
    var minutes: Int?
    var kind: ChallengeActivityKind
    var createdAt: Date = .now
}

extension Challenge {
    var participantCount: Int {
        participantIDs.count
    }

    var trimmedTargetDescription: String? {
        let trimmed = targetDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        switch type {
        case .duel:
            return "Duel"
        case .group:
            return "Group challenge"
        }
    }

    func phase(relativeTo date: Date = .now) -> ChallengePhase {
        if date < startDate {
            return .upcoming
        }

        if date > endDate {
            return .completed
        }

        return .active
    }

    func durationInDays(calendar: Calendar = .current) -> Int {
        max(
            calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0,
            0
        ) + 1
    }

    func rematch(startingAt startDate: Date = .now) -> Challenge {
        let duration = durationInDays()
        let endDate = Calendar.current.date(
            byAdding: .day,
            value: max(duration - 1, 0),
            to: startDate
        ) ?? startDate

        return Challenge(
            title: resolvedTitle,
            type: type,
            participantIDs: participantIDs,
            startDate: startDate,
            endDate: endDate,
            scores: Dictionary(uniqueKeysWithValues: participantIDs.map { ($0, 0) }),
            targetDescription: trimmedTargetDescription
        )
    }
}

// MARK: - Challenge Service (local only)

@MainActor
final class ChallengeService: ObservableObject {
    // local user identity stored once
    private let localUserKey = "BuddyLock.localUserID"
    private(set) var localUserID: UUID

    @Published private(set) var challenges: [Challenge] = []
    @Published private(set) var activity: [ChallengeActivityItem] = []

    private let key = "BuddyLock.challenges"
    private let activityKey = "BuddyLock.challengeActivity"

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
        loadActivity()
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
        logActivity(
            ChallengeActivityItem(
                challengeID: challenge.id,
                challengeTitle: challenge.resolvedTitle,
                participantID: localUserID,
                minutes: nil,
                kind: .created
            )
        )
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
        logActivity(
            ChallengeActivityItem(
                challengeID: challenge.id,
                challengeTitle: challenge.resolvedTitle,
                participantID: localUserID,
                minutes: nil,
                kind: .created
            )
        )
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
            logActivity(
                ChallengeActivityItem(
                    challengeID: challenges[index].id,
                    challengeTitle: challenges[index].resolvedTitle,
                    participantID: participantID,
                    minutes: minutes,
                    kind: .minutesLogged
                )
            )
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
        logActivity(
            ChallengeActivityItem(
                challengeID: challenges[index].id,
                challengeTitle: challenges[index].resolvedTitle,
                participantID: participantID,
                minutes: minutes,
                kind: .minutesLogged
            )
        )
        save()
    }

    func removeChallenge(_ challenge: Challenge) {
        challenges.removeAll { $0.id == challenge.id }
        save()
    }

    func createRematch(from challenge: Challenge) {
        let rematch = challenge.rematch()
        challenges.insert(rematch, at: 0)
        logActivity(
            ChallengeActivityItem(
                challengeID: rematch.id,
                challengeTitle: rematch.resolvedTitle,
                participantID: localUserID,
                minutes: nil,
                kind: .rematchStarted
            )
        )
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

    private func loadActivity() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: activityKey),
           let decoded = try? JSONDecoder().decode([ChallengeActivityItem].self, from: data) {
            activity = decoded.sorted { $0.createdAt > $1.createdAt }
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: key)
        }
    }

    private func saveActivity() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(activity) {
            defaults.set(data, forKey: activityKey)
        }
    }

    private func logActivity(_ item: ChallengeActivityItem) {
        activity.insert(item, at: 0)
        activity = Array(activity.prefix(25))
        saveActivity()
    }
}
