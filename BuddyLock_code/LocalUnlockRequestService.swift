import Foundation

// MARK: - Local Unlock Request (simulated buddy approvals on same device)
enum LocalRequestDecision: String, Codable {
    case pending, approved, denied
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

    // NEW: optional requested app name (display-only; approver will match it to a token)
    var requestedAppName: String? = nil
}

@MainActor
final class LocalUnlockRequestService: ObservableObject {
    @Published private(set) var incoming: [LocalUnlockRequest] = []
    @Published private(set) var outgoing: [LocalUnlockRequest] = []

    private let incomingKey = "BuddyLock.local.requests.incoming"
    private let outgoingKey = "BuddyLock.local.requests.outgoing"

    init() {
        load()
    }

    func refresh() {
        load()
    }

    // Create a new request and mirror it into incoming (demo: same device)
    func sendRequest(to buddy: LocalBuddy,
                     requesterName: String,
                     minutes: Int,
                     reason: String?,
                     requestedAppName: String? = nil) {
        let req = LocalUnlockRequest(
            requesterName: requesterName,
            buddyID: buddy.id,
            minutesRequested: minutes,
            reason: reason,
            decision: .pending,
            approvedMinutes: nil,
            requestedAppName: requestedAppName
        )
        outgoing.insert(req, at: 0)
        incoming.insert(req, at: 0) // mirror locally for demo approvals
        save()
    }

    func approve(requestID: UUID, minutes: Int) {
        update(requestID: requestID) { r in
            r.decision = .approved
            r.approvedMinutes = minutes
        }
    }

    func deny(requestID: UUID) {
        update(requestID: requestID) { r in
            r.decision = .denied
            r.approvedMinutes = nil
        }
    }

    // MARK: - Helpers

    private func update(requestID: UUID, mutate: (inout LocalUnlockRequest) -> Void) {
        if let idx = incoming.firstIndex(where: { $0.id == requestID }) {
            var r = incoming[idx]
            mutate(&r)
            incoming[idx] = r
        }
        if let idx = outgoing.firstIndex(where: { $0.id == requestID }) {
            var r = outgoing[idx]
            mutate(&r)
            outgoing[idx] = r
        }
        save()
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: incomingKey),
           let decoded = try? JSONDecoder().decode([LocalUnlockRequest].self, from: data) {
            incoming = decoded
        }
        if let data = d.data(forKey: outgoingKey),
           let decoded = try? JSONDecoder().decode([LocalUnlockRequest].self, from: data) {
            outgoing = decoded
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
