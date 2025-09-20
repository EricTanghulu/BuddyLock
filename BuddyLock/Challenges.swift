import Foundation

// MARK: - Challenge Models

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case headToHead
    case group
    var id: String { rawValue }
    var label: String { self == .headToHead ? "Head-to-Head" : "Group" }
}

struct Challenge: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var type: ChallengeType
    var participantIDs: [UUID]          // includes local user plus buddies
    var startDate: Date
    var endDate: Date
    var scores: [UUID: Int] = [:]       // minutes of focus per participant
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
        if let data = UserDefaults.standard.data(forKey: localUserKey),
           let id = try? JSONDecoder().decode(UUID.self, from: data) {
            localUserID = id
        } else {
            localUserID = UUID()
            if let data = try? JSONEncoder().encode(localUserID) {
                UserDefaults.standard.set(data, forKey: localUserKey)
            }
        }
        load()
    }

    // Create a head-to-head challenge between local user and exactly one buddy
    func createHeadToHead(with buddy: LocalBuddy, title: String = "Head-to-Head", days: Int = 7) {
        var c = Challenge(
            title: title,
            type: .headToHead,
            participantIDs: [localUserID, buddy.id],
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
        )
        c.scores = [localUserID: 0, buddy.id: 0]
        challenges.insert(c, at: 0)
        save()
    }

    // Create a group challenge with multiple buddies (+ local user auto-included)
    func createGroup(with buddies: [LocalBuddy], title: String = "Group Challenge", days: Int = 7) {
        let ids = [localUserID] + buddies.map { $0.id }
        var c = Challenge(
            title: title,
            type: .group,
            participantIDs: ids,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
        )
        c.scores = Dictionary(uniqueKeysWithValues: ids.map { ($0, 0) })
        challenges.insert(c, at: 0)
        save()
    }

    // Record minutes for a participant across all active challenges they are in
    func recordMinutes(for participantID: UUID, minutes: Int) {
        guard minutes > 0 else { return }
        var changed = false
        let now = Date()
        for i in challenges.indices {
            if challenges[i].participantIDs.contains(participantID),
               now >= challenges[i].startDate,
               now <= challenges[i].endDate {
                challenges[i].scores[participantID, default: 0] += minutes
                changed = true
            }
        }
        if changed { save() }
    }

    // Convenience for local user (use when a focus session completes)
    func recordLocalFocus(minutes: Int) {
        recordMinutes(for: localUserID, minutes: minutes)
    }

    func addManualMinutes(to challengeID: UUID, participantID: UUID, minutes: Int) {
        guard minutes > 0, let idx = challenges.firstIndex(where: { $0.id == challengeID }) else { return }
        challenges[idx].scores[participantID, default: 0] += minutes
        save()
    }

    func removeChallenge(_ challenge: Challenge) {
        challenges.removeAll { $0.id == challenge.id }
        save()
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Challenge].self, from: data) {
            challenges = decoded
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(challenges) {
            d.set(data, forKey: key)
        }
    }
}
