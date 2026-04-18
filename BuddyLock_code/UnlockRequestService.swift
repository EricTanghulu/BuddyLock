import FirebaseAuth
import FirebaseFirestore
import Foundation

enum UnlockRequestDecision: String, Codable {
    case pending
    case approved
    case denied
}

enum UnlockApprovalVote: String, Codable {
    case approved
    case denied
}

enum UnlockRequestUrgency: String, Codable, CaseIterable, Identifiable {
    case routine
    case distracting
    case urgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine:
            return "Routine"
        case .distracting:
            return "Tempted"
        case .urgent:
            return "Urgent"
        }
    }
}

struct UnlockApprovalResponse: Identifiable, Codable, Hashable {
    let responderID: String
    let responderName: String
    let vote: UnlockApprovalVote
    let approvedMinutes: Int?
    let note: String?
    let createdAt: Date

    var id: String { responderID }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "responderID": responderID,
            "responderName": responderName,
            "vote": vote.rawValue,
            "createdAt": Timestamp(date: createdAt),
        ]

        if let approvedMinutes {
            data["approvedMinutes"] = approvedMinutes
        }

        if let note, !note.isEmpty {
            data["note"] = note
        }

        return data
    }
}

struct UnlockRequest: Identifiable, Codable, Hashable {
    @DocumentID var id: String?

    let requesterID: String
    let requesterName: String
    let audienceTypeRaw: String
    let audienceReferenceID: String?
    let audienceLabel: String
    let recipientUserIDs: [String]
    let approvalRule: BuddyApprovalRule
    let minutesRequested: Int
    let targetDescription: String?
    let reason: String?
    let urgencyRaw: String

    var decision: UnlockRequestDecision
    var approvedMinutes: Int?
    var responses: [UnlockApprovalResponse]

    @ServerTimestamp var createdAt: Timestamp?

    init(
        id: String? = nil,
        requesterID: String,
        requesterName: String,
        audienceType: BuddyAudienceType,
        audienceReferenceID: String?,
        audienceLabel: String,
        recipientUserIDs: [String],
        approvalRule: BuddyApprovalRule,
        minutesRequested: Int,
        targetDescription: String?,
        reason: String?,
        urgency: UnlockRequestUrgency,
        decision: UnlockRequestDecision = .pending,
        approvedMinutes: Int? = nil,
        responses: [UnlockApprovalResponse] = [],
        createdAt: Timestamp? = nil
    ) {
        self.id = id
        self.requesterID = requesterID
        self.requesterName = requesterName
        self.audienceTypeRaw = audienceType.rawValue
        self.audienceReferenceID = audienceReferenceID
        self.audienceLabel = audienceLabel
        self.recipientUserIDs = recipientUserIDs
        self.approvalRule = approvalRule
        self.minutesRequested = minutesRequested
        self.targetDescription = targetDescription
        self.reason = reason
        self.urgencyRaw = urgency.rawValue
        self.decision = decision
        self.approvedMinutes = approvedMinutes
        self.responses = responses
        self.createdAt = createdAt
    }
}

extension UnlockRequest {
    var stableID: String {
        id ?? UUID().uuidString
    }

    var createdDate: Date {
        createdAt?.dateValue() ?? Date()
    }

    var audienceType: BuddyAudienceType {
        BuddyAudienceType(rawValue: audienceTypeRaw) ?? .individual
    }

    var urgency: UnlockRequestUrgency {
        UnlockRequestUrgency(rawValue: urgencyRaw) ?? .routine
    }

    var recipientCount: Int {
        max(recipientUserIDs.count, 1)
    }

    var requiredApprovals: Int {
        approvalRule.requiredApprovals(for: recipientCount)
    }

    var approvalCount: Int {
        responses.filter { $0.vote == .approved }.count
    }

    var denialCount: Int {
        responses.filter { $0.vote == .denied }.count
    }

    var pendingCount: Int {
        max(recipientCount - responses.count, 0)
    }

    var progressSummary: String {
        switch decision {
        case .approved:
            return "Approved"
        case .denied:
            return "Denied"
        case .pending:
            return "\(approvalCount)/\(requiredApprovals) approvals"
        }
    }
}

@MainActor
final class UnlockRequestService: ObservableObject {
    @Published private(set) var incoming: [UnlockRequest] = []
    @Published private(set) var outgoing: [UnlockRequest] = []

    private let db = Firestore.firestore()
    private let defaults = UserDefaults.standard
    private let currentUserID: String
    private let hasSignedInUser: Bool
    private let consumedApprovalsKey: String

    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?

    init() {
        let userID = Auth.auth().currentUser?.uid ?? "preview-user"
        currentUserID = userID
        hasSignedInUser = Auth.auth().currentUser != nil
        consumedApprovalsKey = "BuddyLock.consumedApprovedUnlockRequests.\(userID)"
        attachListenersIfNeeded()
    }

    deinit {
        incomingListener?.remove()
        outgoingListener?.remove()
    }

    func refresh() {
        // Firestore listeners stay live.
    }

    func sendRequest(
        requesterName: String,
        audience: BuddyAudience,
        minutes: Int,
        targetDescription: String? = nil,
        reason: String?,
        urgency: UnlockRequestUrgency,
        approvalRule: BuddyApprovalRule? = nil
    ) {
        let cleanedTarget = targetDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = UnlockRequest(
            requesterID: currentUserID,
            requesterName: requesterName,
            audienceType: audience.type,
            audienceReferenceID: audience.referenceID,
            audienceLabel: audience.label,
            recipientUserIDs: audience.recipientUserIDs,
            approvalRule: approvalRule ?? audience.defaultApprovalRule,
            minutesRequested: max(1, minutes),
            targetDescription: cleanedTarget?.isEmpty == true ? nil : cleanedTarget,
            reason: cleanedReason?.isEmpty == true ? nil : cleanedReason,
            urgency: urgency
        )

        if !hasSignedInUser {
            var localRequest = request
            localRequest.id = UUID().uuidString
            outgoing.insert(localRequest, at: 0)
            return
        }

        do {
            _ = try db.collection("unlockRequests").addDocument(from: request)
        } catch {
            print("Failed to send unlock request: \(error)")
        }
    }

    func sendRequest(
        requesterName: String,
        buddyID: String,
        minutes: Int,
        reason: String?
    ) {
        let audience = BuddyAudience(
            type: .individual,
            referenceID: buddyID,
            label: "Buddy",
            recipientBuddyIDs: [],
            recipientUserIDs: [buddyID],
            defaultApprovalRule: BuddyApprovalRule(kind: .anyOne),
            allowsRuleOverride: false
        )
        sendRequest(
            requesterName: requesterName,
            audience: audience,
            minutes: minutes,
            reason: reason,
            urgency: .routine
        )
    }

    func approve(requestID: String, minutes: Int, note: String? = nil) {
        submitResponse(
            requestID: requestID,
            vote: .approved,
            approvedMinutes: max(1, minutes),
            note: note
        )
    }

    func deny(requestID: String, note: String? = nil) {
        submitResponse(
            requestID: requestID,
            vote: .denied,
            approvedMinutes: nil,
            note: note
        )
    }

    func canCurrentUserRespond(to request: UnlockRequest) -> Bool {
        request.decision == .pending &&
        request.recipientUserIDs.contains(currentUserID) &&
        !request.responses.contains(where: { $0.responderID == currentUserID })
    }

    func currentUserResponse(for request: UnlockRequest) -> UnlockApprovalResponse? {
        request.responses.first(where: { $0.responderID == currentUserID })
    }

    func consumeApprovedOutgoingRequest() -> UnlockRequest? {
        var consumed = Set(defaults.stringArray(forKey: consumedApprovalsKey) ?? [])
        guard let request = outgoing.first(where: {
            $0.decision == .approved && !consumed.contains($0.stableID)
        }) else {
            return nil
        }

        consumed.insert(request.stableID)
        defaults.set(Array(consumed), forKey: consumedApprovalsKey)
        return request
    }

    private func attachListenersIfNeeded() {
        guard hasSignedInUser else { return }

        incomingListener = db.collection("unlockRequests")
            .whereField("recipientUserIDs", arrayContains: currentUserID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if error != nil {
                    return
                }

                let docs = snapshot?.documents ?? []
                self?.incoming = docs.compactMap { try? $0.data(as: UnlockRequest.self) }
            }

        outgoingListener = db.collection("unlockRequests")
            .whereField("requesterID", isEqualTo: currentUserID)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if error != nil {
                    return
                }

                let docs = snapshot?.documents ?? []
                self?.outgoing = docs.compactMap { try? $0.data(as: UnlockRequest.self) }
            }
    }

    private func submitResponse(
        requestID: String,
        vote: UnlockApprovalVote,
        approvedMinutes: Int?,
        note: String?
    ) {
        if !hasSignedInUser {
            applyLocalResponse(
                requestID: requestID,
                vote: vote,
                approvedMinutes: approvedMinutes,
                note: note
            )
            return
        }

        let responderName = resolvedDisplayName()
        let response = UnlockApprovalResponse(
            responderID: currentUserID,
            responderName: responderName,
            vote: vote,
            approvedMinutes: approvedMinutes,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )

        let requestRef = db.collection("unlockRequests").document(requestID)
        db.runTransaction({ transaction, errorPointer in
            let snapshot: DocumentSnapshot

            do {
                snapshot = try transaction.getDocument(requestRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let request = try? snapshot.data(as: UnlockRequest.self) else {
                errorPointer?.pointee = NSError(
                    domain: "UnlockRequestService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not decode request."]
                )
                return nil
            }

            guard request.decision == .pending else { return nil }

            var responses = request.responses.filter { $0.responderID != self.currentUserID }
            responses.append(response)

            let nextDecision = Self.decision(
                for: responses,
                rule: request.approvalRule,
                recipientCount: request.recipientCount
            )
            let nextApprovedMinutes = Self.approvedMinutes(
                for: responses,
                requestedMinutes: request.minutesRequested,
                decision: nextDecision
            )

            var payload: [String: Any] = [
                "responses": responses.map(\.firestoreData),
                "decision": nextDecision.rawValue,
            ]

            if let nextApprovedMinutes {
                payload["approvedMinutes"] = nextApprovedMinutes
            } else {
                payload["approvedMinutes"] = FieldValue.delete()
            }

            transaction.updateData(payload, forDocument: requestRef)
            return nil
        }) { _, error in
            if let error {
                print("Failed to update unlock request: \(error)")
            }
        }
    }

    private func applyLocalResponse(
        requestID: String,
        vote: UnlockApprovalVote,
        approvedMinutes: Int?,
        note: String?
    ) {
        let response = UnlockApprovalResponse(
            responderID: currentUserID,
            responderName: resolvedDisplayName(),
            vote: vote,
            approvedMinutes: approvedMinutes,
            note: note,
            createdAt: Date()
        )

        updateLocalRequests { request in
            guard request.id == requestID else { return request }
            var updated = request
            updated.responses.removeAll(where: { $0.responderID == currentUserID })
            updated.responses.append(response)
            updated.decision = Self.decision(
                for: updated.responses,
                rule: updated.approvalRule,
                recipientCount: updated.recipientCount
            )
            updated.approvedMinutes = Self.approvedMinutes(
                for: updated.responses,
                requestedMinutes: updated.minutesRequested,
                decision: updated.decision
            )
            return updated
        }
    }

    private func updateLocalRequests(_ transform: (UnlockRequest) -> UnlockRequest) {
        outgoing = outgoing.map(transform)
        incoming = incoming.map(transform)
    }

    private func resolvedDisplayName() -> String {
        let savedName = defaults.string(forKey: "BuddyLock.displayName")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return savedName.isEmpty ? "Buddy" : savedName
    }

    private static func decision(
        for responses: [UnlockApprovalResponse],
        rule: BuddyApprovalRule,
        recipientCount: Int
    ) -> UnlockRequestDecision {
        let threshold = rule.requiredApprovals(for: recipientCount)
        let approvals = responses.filter { $0.vote == .approved }.count
        let denials = responses.filter { $0.vote == .denied }.count

        if approvals >= threshold {
            return .approved
        }

        let maxPossibleApprovals = recipientCount - denials
        if maxPossibleApprovals < threshold {
            return .denied
        }

        return .pending
    }

    private static func approvedMinutes(
        for responses: [UnlockApprovalResponse],
        requestedMinutes: Int,
        decision: UnlockRequestDecision
    ) -> Int? {
        guard decision == .approved else { return nil }

        let positiveMinutes = responses
            .filter { $0.vote == .approved }
            .compactMap(\.approvedMinutes)

        return positiveMinutes.min() ?? requestedMinutes
    }
}
