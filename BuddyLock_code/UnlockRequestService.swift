import Foundation
// MARK: - Local Unlock Request (simulated buddy approvals on same device)
import FirebaseFirestore
import FirebaseAuth

enum UnlockRequestDecision: String, Codable {
    case pending
    case approved
    case denied
}

struct UnlockRequest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    let requesterID: String
    let requesterName: String
    let buddyID: String

    let minutesRequested: Int
    let reason: String?

    let createdAt: Timestamp

    var decision: UnlockRequestDecision
    var approvedMinutes: Int?
}
extension UnlockRequest {
    var stableID: String { id ?? UUID().uuidString }
}


@MainActor
final class UnlockRequestService: ObservableObject {

    @Published private(set) var incoming: [UnlockRequest] = []
    @Published private(set) var outgoing: [UnlockRequest] = []

    private let db = Firestore.firestore()
    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?

    private let myUserID: String

    init() {
        let myUserID = Auth.auth().currentUser!.uid
        self.myUserID = myUserID
        attachListeners()
    }

    deinit {
        incomingListener?.remove()
        outgoingListener?.remove()
    }

    // MARK: - Public API (unchanged shape)

    func refresh() {
        // No-op now: Firestore listeners are live
    }

    func sendRequest(
        requesterName: String,
        buddyID: String,
        minutes: Int,
        reason: String?
    ) {
        let clamped = max(1, minutes)

        let request = UnlockRequest(
            requesterID: myUserID,
            requesterName: requesterName,
            buddyID: buddyID,
            minutesRequested: clamped,
            reason: reason?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Timestamp(),
            decision: .pending,
            approvedMinutes: nil
        )

        do {
            _ = try db.collection("unlockRequests")
                .addDocument(from: request)
        } catch {
            print("Failed to send unlock request:", error)
        }
    }

    func approve(requestID: String, minutes: Int) {
        update(
            requestID: requestID,
            decision: .approved,
            approvedMinutes: max(1, minutes)
        )
    }

    func deny(requestID: String) {
        update(
            requestID: requestID,
            decision: .denied,
            approvedMinutes: nil
        )
    }

    // MARK: - Firestore wiring (new, but isolated)

    private func attachListeners() {
        // Incoming (I'm the buddy)
        incomingListener = db.collection("unlockRequests")
            .whereField("buddyID", isEqualTo: myUserID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self?.incoming = docs.compactMap {
                    try? $0.data(as: UnlockRequest.self)
                }
            }

        // Outgoing (I requested)
        outgoingListener = db.collection("unlockRequests")
            .whereField("requesterID", isEqualTo: myUserID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self?.outgoing = docs.compactMap {
                    try? $0.data(as: UnlockRequest.self)
                }
            }
    }

    private func update(
        requestID: String,
        decision: UnlockRequestDecision,
        approvedMinutes: Int?
    ) {
        var data: [String: Any] = [
            "decision": decision.rawValue
        ]

        if let approvedMinutes {
            data["approvedMinutes"] = approvedMinutes
        } else {
            data["approvedMinutes"] = FieldValue.delete()
        }

        db.collection("unlockRequests")
            .document(requestID)
            .updateData(data)
    }
}
