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
    let fromUsername: String?
    let fromDisplayName: String?
    let status: String   // "pending"
    let timestamp: Date

    var resolvedName: String {
        let displayName = fromDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !displayName.isEmpty {
            return displayName
        }

        let username = fromUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !username.isEmpty {
            return username
        }

        return fromUserID
    }
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
        let normalizedTargetUsername = UserProfileStore.normalizeUsername(targetID)
        guard !normalizedTargetUsername.isEmpty else {
            throw NSError(
                domain: "FriendRequest",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Enter a username first."]
            )
        }

        guard let senderProfile = try await UserProfileStore.fetchProfile(userID: currentUserID) else {
            throw NSError(
                domain: "FriendRequest",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Your profile is not ready yet. Try again in a moment."]
            )
        }

        guard let targetProfile = try await UserProfileStore.fetchProfile(username: normalizedTargetUsername) else {
            throw NSError(
                domain: "FriendRequest",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "User not found."]
            )
        }

        guard targetProfile.userID != currentUserID else {
            throw NSError(
                domain: "FriendRequest",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Cannot friend yourself."]
            )
        }

        let friendDoc = try await db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .document(targetProfile.userID)
            .getDocument()
        if friendDoc.exists {
            throw NSError(
                domain: "FriendRequest",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "You are already friends."]
            )
        }

        let requestDoc = try await db.collection("users")
            .document(targetProfile.userID)
            .collection("friendRequests")
            .document(currentUserID)
            .getDocument()
        if requestDoc.exists {
            throw NSError(
                domain: "FriendRequest",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Friend request already sent."]
            )
        }

        try await db.collection("users")
            .document(targetProfile.userID)
            .collection("friendRequests")
            .document(currentUserID)
            .setData([
                "fromUserID": currentUserID,
                "fromUsername": senderProfile.username,
                "fromDisplayName": senderProfile.displayName,
                "status": "pending",
                "timestamp": Timestamp()
            ])
    }




    // MARK: - Accept request
    func accept(_ request: FriendRequest) async throws {
        let senderID = request.fromUserID
        guard !senderID.isEmpty else { return }

        let currentUserProfile = try await UserProfileStore.fetchProfile(userID: currentUserID)
        let senderProfile = try await UserProfileStore.fetchProfile(userID: senderID)

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
            .document(request.id ?? senderID)

        batch.setData(friendPayload(from: senderProfile, fallbackName: request.resolvedName), forDocument: myFriendsRef)

        batch.setData([
            "since": Timestamp()
        ].merging(friendPayload(from: currentUserProfile), uniquingKeysWith: { _, new in new }), forDocument: senderFriendsRef)

        batch.deleteDocument(requestRef)

        try await batch.commit()

        buddyService.addBuddy(
            LocalBuddy(
                remoteID: senderID,
                buddyUserID: senderProfile?.username ?? request.fromUsername ?? senderID,
                displayName: senderProfile?.displayName ?? request.resolvedName
            )
        )
    }


    // MARK: - Reject request
    func reject(_ request: FriendRequest) async throws {
        let senderID = request.id ?? request.fromUserID
        guard !senderID.isEmpty else { return }

        try await db.collection("users")
            .document(currentUserID)
            .collection("friendRequests")
            .document(senderID)
            .delete()
    }

    private func friendPayload(from profile: RemoteUserProfile?, fallbackName: String? = nil) -> [String: Any] {
        var payload: [String: Any] = [
            "since": Timestamp()
        ]

        if let profile {
            payload["displayName"] = profile.displayName
            payload["username"] = profile.username
        } else if let fallbackName, !fallbackName.isEmpty {
            payload["displayName"] = fallbackName
        }

        return payload
    }
}
