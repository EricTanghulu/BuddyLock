//
//  FriendRequest.swift
//  BuddyLock
//
//  Created by Stephanie Song on 1/6/26.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth


struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let fromUserID: String
    let toUserID: String
    let status: String   // "pending"
    let timestamp: Date
}


@MainActor
final class FriendRequestService: ObservableObject {

    @Published private(set) var incomingRequests: [FriendRequest] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let currentUserID: String
    private let buddyService: LocalBuddyService

    init(
        buddyService: LocalBuddyService
    ) {
        self.currentUserID = Auth.auth().currentUser?.uid ?? "unknown"
        self.buddyService = buddyService
        if let user = Auth.auth().currentUser {
            print("UID:", user.uid)
        } else {
            print("Not signed in!")
        }

        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listen for pending incoming requests
    private func startListening() {
        listener = db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: "pending")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self,
                      let documents = snapshot?.documents else {
                    print("❌ Friend request listener error:", error?.localizedDescription ?? "")
                    return
                }

                self.incomingRequests = documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                }
            }
    }

    // MARK: - Send friend request
    func sendRequest(toUserID: String) throws {
        let request = FriendRequest(
            fromUserID: currentUserID,
            toUserID: toUserID,
            status: "pending",
            timestamp: Date()
        )

        try db.collection("friendRequests").addDocument(from: request)
    }


    // MARK: - Accept request
    func accept(_ request: FriendRequest) {
        guard let requestID = request.id else { return }

        // 1️⃣ Add buddy (remoteID = sender)
        buddyService.addBuddy(
            LocalBuddy(
                buddyUserID: request.fromUserID,
            )
        )

        // 2️⃣ Mark request as accepted
        db.collection("friendRequests")
            .document(requestID)
            .updateData(["status": "accepted"])
    }

    // MARK: - Reject request
    func reject(_ request: FriendRequest) {
        guard let requestID = request.id else { return }

        db.collection("friendRequests")
            .document(requestID)
            .updateData(["status": "rejected"])
    }
}
