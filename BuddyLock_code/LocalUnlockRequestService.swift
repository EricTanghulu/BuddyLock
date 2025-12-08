import Foundation

// MARK: - Local Unlock Request (simulated buddy approvals on same device)

enum LocalRequestDecision: String, Codable {
    case pending
    case approved
    case denied
}

struct LocalUnlockRequest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var requesterName: String
    var buddyID: UUID              // who you're asking
    var minutesRequested: Int
    var reason: String?
    var decision: LocalRequestDecision = .pending
    var approvedMinutes: Int? = nil
}

/// Local-only request store that simulates both sides (your outgoing requests
/// and your buddy's incoming requests) on the same device.
@MainActor
final class LocalUnlockRequestService: ObservableObject {
    @Published private(set) var incoming: [LocalUnlockRequest] = []
    @Published private(set) var outgoing: [LocalUnlockRequest] = []

    private let incomingKey = "BuddyLock.local.incomingRequests"
    private let outgoingKey = "BuddyLock.local.outgoingRequests"

    init() {
        load()
    }

    // MARK: - Public API used by views

    func refresh() {
        load()
    }

    /// Create a new unlock request. Because this is a local-only simulation,
    /// we mirror the same request into both `incoming` and `outgoing`.
    func sendRequest(
        requesterName: String,
        buddyID: UUID,
        minutes: Int,
        reason: String?
    ) {
        let clamped = max(1, minutes)
        var req = LocalUnlockRequest(
            requesterName: requesterName,
            buddyID: buddyID,
            minutesRequested: clamped,
            reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        // Newest first in both lists
        incoming.insert(req, at: 0)
        outgoing.insert(req, at: 0)
        save()
    }

    func approve(requestID: UUID, minutes: Int) {
        let clamped = max(1, minutes)
        update(requestID: requestID, decision: .approved, approvedMinutes: clamped)
    }

    func deny(requestID: UUID) {
        update(requestID: requestID, decision: .denied, approvedMinutes: nil)
    }

    // MARK: - Internal helpers

    private func update(
        requestID: UUID,
        decision: LocalRequestDecision,
        approvedMinutes: Int?
    ) {
        var changed = false

        for index in incoming.indices {
            if incoming[index].id == requestID {
                incoming[index].decision = decision
                incoming[index].approvedMinutes = approvedMinutes
                changed = true
            }
        }

        for index in outgoing.indices {
            if outgoing[index].id == requestID {
                outgoing[index].decision = decision
                outgoing[index].approvedMinutes = approvedMinutes
                changed = true
            }
        }

        if changed {
            save()
        }
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: incomingKey),
           let decoded = try? JSONDecoder().decode([LocalUnlockRequest].self, from: data) {
            incoming = decoded
        } else {
            incoming = []
        }

        if let data = d.data(forKey: outgoingKey),
           let decoded = try? JSONDecoder().decode([LocalUnlockRequest].self, from: data) {
            outgoing = decoded
        } else {
            outgoing = []
        }
    }

    private func save() {
        let d = UserDefaults.standard

        if let data = try? JSONEncoder().encode(incoming) {
            d.set(data, forKey: incomingKey)
        }
        if let data = try? JSONEncoder().encode(outgoing) {
            d.set(data, forKey: outgoingKey)
        }
    }
}
