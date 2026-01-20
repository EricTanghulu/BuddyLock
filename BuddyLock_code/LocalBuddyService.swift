import Foundation
import FirebaseFirestore

// MARK: - changing to firebase buddy

struct LocalBuddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()                 // local-only
    @DocumentID var remoteID: String?     // buddy doc ID
    var buddyUserID: String               // friend's auth UID
    var displayName: String? = nil
}

import FirebaseAuth

@MainActor
final class LocalBuddyService: ObservableObject {

    @Published private(set) var buddies: [LocalBuddy] = []

    private let db = Firestore.firestore()
    private let collection = "friends"
    private var listener: ListenerRegistration?
    private let currentUserID: String

    init() {
        currentUserID = Auth.auth().currentUser?.uid ?? "unknown"
        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Listen to current user's buddies only
    private func startListening() {
        listener = db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .order(by: "buddyUserID")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let documents = snapshot?.documents else { return }
                self.buddies = documents.compactMap {
                    try? $0.data(as: LocalBuddy.self)
                }
            }
    }

    // MARK: - Accept friend request → add buddy
    // Add buddy directly (from Firestore / friend requests)
    func addBuddy(_ buddy: LocalBuddy) {
        // Prevent duplicates by remoteID
        if let remoteID = buddy.remoteID,
           buddies.contains(where: { $0.remoteID == remoteID }) { return }

        buddies.append(buddy)

        // If no remoteID, save to Firestore
        if buddy.remoteID == nil {
            do {
                try db.collection(collection).addDocument(from: buddy)
            } catch {
                print("❌ Failed to add buddy:", error)
            }
        }
    }


    // MARK: - Remove buddy
    func removeBuddy(_ buddy: LocalBuddy) {
        guard let remoteID = buddy.remoteID else { return }

        db.collection(collection)
            .document(remoteID)
            .delete()
    }
}
