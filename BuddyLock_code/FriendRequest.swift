//
//  FriendRequest.swift
//  BuddyLock
//
//  Created by Stephanie Song on 1/6/26.
//


import Foundation
import FirebaseFirestore

struct FriendRequest: Codable, Identifiable {
    @DocumentID var id: String?
    let fromUserID: String  // sender remoteID
    let toUserID: String    // receiver remoteID
    let timestamp: Date
}

@MainActor
final class FriendRequestService: ObservableObject {

    @Published var incomingRequests: [FriendRequest] = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let localBuddyService: LocalBuddyService
    private let currentUserID: String // remoteID of logged-in user

    init(currentUserID: String, localBuddyService: LocalBuddyService) {
        self.currentUserID = currentUserID
        self.localBuddyService = localBuddyService

        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listen for incoming friend requests
    private func startListening() {
        listener = db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: currentUserID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("❌ Firestore error:", error?.localizedDescription ?? "")
                    return
                }

                self.incomingRequests = documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                }
            }
    }

    // MARK: - Send a friend request
    func sendRequest(to buddy: LocalBuddy) {
        guard let toID = buddy.remoteID else {
            print("❌ Cannot send request — buddy has no remoteID")
            return
        }

        let request = FriendRequest(
            fromUserID: currentUserID,
            toUserID: toID,
            timestamp: Date()
        )

        do {
            try db.collection("friendRequests").addDocument(from: request)
        } catch {
            print("❌ Failed to send friend request:", error)
        }
    }

    // MARK: - Accept a friend request
    func acceptRequest(_ request: FriendRequest) async {
        // 1️⃣ Add buddy doc for the current user
        let newBuddy = LocalBuddy(displayName: "Friend Name", remoteID: request.fromUserID)
        localBuddyService.addBuddy(newBuddy)

        // 2️⃣ Add buddy doc for the sender
        // (Optional: only if sender also needs this buddy in their list)
        // You can call localBuddyService.addBuddy() for sender if needed

        // 3️⃣ Delete the friend request doc
        guard let requestID = request.id else { return }
        db.collection("friendRequests").document(requestID).delete { error in
            if let error = error {
                print("❌ Failed to delete friend request:", error)
            }
        }
    }

    // MARK: - Reject a friend request
    func rejectRequest(_ request: FriendRequest) {
        guard let requestID = request.id else { return }
        db.collection("friendRequests").document(requestID).delete { error in
            if let error = error {
                print("❌ Failed to delete friend request:", error)
            }
        }
    }
}
