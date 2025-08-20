
import Foundation
import SwiftUI

// MARK: - Models

struct Buddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var role: BuddyRole = .gatekeeper
}

enum BuddyRole: String, CaseIterable, Codable, Identifiable {
    case gatekeeper, cheerleader, mirror

    var id: String { rawValue }
    var label: String {
        switch self {
        case .gatekeeper: return "Gatekeeper"
        case .cheerleader: return "Cheerleader"
        case .mirror: return "Mirror"
        }
    }
}

enum RequestDecision: String, Codable {
    case pending, approved, denied
}

struct BuddyApprovalRequest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var requesterName: String
    var buddyID: UUID
    var minutesRequested: Int
    var reason: String?
    var decision: RequestDecision = .pending
    var approvedMinutes: Int? = nil
}

// MARK: - LocalBuddyService (demo, no backend)

@MainActor
final class LocalBuddyService: ObservableObject {
    @Published var buddies: [Buddy] = []
    @Published var incoming: [BuddyApprovalRequest] = []
    @Published var outgoing: [BuddyApprovalRequest] = []

    private let buddiesKey = "BuddyLock.buddies"
    private let incomingKey = "BuddyLock.requests.incoming"
    private let outgoingKey = "BuddyLock.requests.outgoing"

    init() {
        load()
    }

    // Persistence using UserDefaults for demo purposes
    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: buddiesKey),
           let items = try? JSONDecoder().decode([Buddy].self, from: data) {
            buddies = items
        }
        if let data = d.data(forKey: incomingKey),
           let items = try? JSONDecoder().decode([BuddyApprovalRequest].self, from: data) {
            incoming = items
        }
        if let data = d.data(forKey: outgoingKey),
           let items = try? JSONDecoder().decode([BuddyApprovalRequest].self, from: data) {
            outgoing = items
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(buddies) {
            d.set(data, forKey: buddiesKey)
        }
        if let data = try? JSONEncoder().encode(incoming) {
            d.set(data, forKey: incomingKey)
        }
        if let data = try? JSONEncoder().encode(outgoing) {
            d.set(data, forKey: outgoingKey)
        }
    }

    func addBuddy(name: String, role: BuddyRole) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        buddies.append(Buddy(displayName: name, role: role))
        save()
    }

    func removeBuddy(_ buddy: Buddy) {
        buddies.removeAll { $0.id == buddy.id }
        // Clean up any requests pointing to this buddy
        incoming.removeAll { $0.buddyID == buddy.id }
        outgoing.removeAll { $0.buddyID == buddy.id }
        save()
    }

    // Send a request to a buddy (demo: we also create an 'incoming' mirror for local approval)
    @discardableResult
    func sendUnlockRequest(to buddy: Buddy, requesterName: String, minutes: Int, reason: String?) -> BuddyApprovalRequest {
        let req = BuddyApprovalRequest(requesterName: requesterName, buddyID: buddy.id, minutesRequested: minutes, reason: reason)
        outgoing.insert(req, at: 0)

        // Demo: also add to incoming so you can approve on the same device
        incoming.insert(req, at: 0)
        save()
        return req
    }

    // Approve/deny a request
    func approve(requestID: UUID, minutes: Int) {
        updateRequest(id: requestID) { r in
            r.decision = .approved
            r.approvedMinutes = minutes
        }
    }

    func deny(requestID: UUID) {
        updateRequest(id: requestID) { r in
            r.decision = .denied
            r.approvedMinutes = nil
        }
    }

    private func updateRequest(id: UUID, mutate: (inout BuddyApprovalRequest) -> Void) {
        if let idx = incoming.firstIndex(where: { $0.id == id }) {
            var r = incoming[idx]
            mutate(&r)
            incoming[idx] = r
        }
        if let idx = outgoing.firstIndex(where: { $0.id == id }) {
            var r = outgoing[idx]
            mutate(&r)
            outgoing[idx] = r
        }
        save()
    }
}
