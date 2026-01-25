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
        print("is my buddy service listening")
        print(currentUserID)
        listener = db.collection("users")
            .document(currentUserID)
            .collection("friends")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                            print("❌ Snapshot listener error:", error)
                            return
                        }
                
                guard let snapshot = snapshot else {
                            print("❌ Snapshot is nil")
                            return
                        }

                        print("📄 Raw snapshot documents count:", snapshot.documents.count)

                        for doc in snapshot.documents {
                            print("Document ID:", doc.documentID)
                            print("Data:", doc.data())
                        }

                        self?.buddies = snapshot.documents.compactMap {
                            try? $0.data(as: LocalBuddy.self)
                        }

                        print("✅ Decoded buddies:", self?.buddies ?? [])
                    }
    }

    // MARK: - Accept friend request → add buddy
    // Add buddy directly (from Firestore / friend requests)
    // THIS IS FOR LOCAL DATA/TESTING
    func addBuddy(_ buddy: LocalBuddy) {
        // Prevent duplicates by remoteID
        if let remoteID = buddy.remoteID,
           buddies.contains(where: { $0.remoteID == remoteID }) { return }

        buddies.append(buddy)
    }


    // MARK: - Remove buddy
    func removeBuddy(_ buddy: LocalBuddy) {
        guard let buddyID = buddy.remoteID else { return }

        db.collection("users")
                .document(currentUserID)
                .collection("friends")
                .document(buddyID)
                .delete()
        
        db.collection("users")
                .document(buddyID)
                .collection("friends")
                .document(currentUserID)
                .delete()
    }
}
