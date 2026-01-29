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
            print("Friend Request UID:", user.uid)
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
        listener = db.collection("users")
            .document(currentUserID)
            .collection("friendRequests")
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
    func sendRequest(targetID: String) async throws {
        print("gonna crash out")
        if let user = Auth.auth().currentUser {
            print("check in. fr rules, Current UID:", user.uid)
        } else {
            print("Not signed in")
        }
        guard targetID != currentUserID else {
            throw NSError(domain: "FriendRequest", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot friend yourself"])
        }
        
        let targetSnapshot = try await db.collection("usernames")
            .document(targetID)
            .getDocument()
        

        guard let targetUID = targetSnapshot.data()?["uid"] as? String else {
            throw NSError(domain: "FriendRequest", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }

        print("check 1. r they alr buddies")
        // 1️⃣ Check if already friends
        let friendDoc = try await db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .document(targetUID)
            .getDocument()
        if friendDoc.exists {
            throw NSError(domain: "FriendRequest", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "You are already friends"])
        }

        print("check 2. is req alr sente")
        // 2️⃣ Check if request already sent
        let requestDoc = try await db.collection("users")
            .document(targetUID)
            .collection("friendRequests")
            .document(currentUserID)
            .getDocument()
        if requestDoc.exists {
            throw NSError(domain: "FriendRequest", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Friend request already sent"])
        }
        
        print("hi ???")

        if let user = Auth.auth().currentUser {
            print("check in. fr rules, Current UID:", user.uid)
        } else {
            print("Not signed in")
        }

        // ✅ Write friend request
        try await db.collection("users")
            .document(targetUID)
            .collection("friendRequests")
            .document(currentUserID)
            .setData([
                "fromUserID": currentUserID,
                "status": "pending",
                "timestamp": Timestamp()
            ])
    }




    // MARK: - Accept request
    func accept(_ request: FriendRequest) async throws {
        guard let senderID = request.id else { return }

        let batch = db.batch()

        let myFriendsRef = db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .document(senderID)

        let senderFriendsRef = db.collection("users")
            .document(senderID)
            .collection("friends")
            .document(currentUserID)

        let requestRef = db.collection("users")
            .document(currentUserID)
            .collection("friendRequests")
            .document(senderID)

        batch.setData([
            "since": Timestamp()
        ], forDocument: myFriendsRef)

        batch.setData([
            "since": Timestamp()
        ], forDocument: senderFriendsRef)

        batch.deleteDocument(requestRef)

        try await batch.commit()
    }


    // MARK: - Reject request
    func reject(_ request: FriendRequest) async throws {
        guard let senderID = request.id else { return }

        try await db.collection("users")
            .document(currentUserID)
            .collection("friendRequests")
            .document(senderID)
            .delete()
    }

}
