import Foundation
import FirebaseFirestore

// MARK: - changing to firebase buddy


struct LocalBuddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()                 // local-only
    
    // 1. This automatically grabs the Firestore Document Name (ID)
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

                        var loadedBuddies: [LocalBuddy] = []

                
        // change this later -> rn it maps the firebase buddy with weird logic but once local + firestore matches just mpa directly
                for document in snapshot.documents {
                    // 1. Get the document ID (e.g., "user_123")
                    let docID = document.documentID
                    
                    // 2. Manually create the LocalBuddy object
                    // We map docID to both remoteID and buddyUserID
                    let buddy = LocalBuddy(
                        buddyUserID: docID,
                        displayName: docID // You can force this to empty string as requested
                    )
                    
                    loadedBuddies.append(buddy)
                    print("✅ Manually loaded:", buddy.buddyUserID)
                }

                guard let self = self else { return }
                self.buddies = loadedBuddies
                print("✅ Decoded buddies:", self.buddies)
//
//                        for document in snapshot.documents {
//                            do {
//                                let buddy = try document.data(as: LocalBuddy.self)
//                                loadedBuddies.append(buddy)
//                                print("Loaded buddy:", buddy.buddyUserID, "docID:", buddy.remoteID ?? "nil")
//                            } catch {
//                                print("❌ Failed to decode buddy from document \(document.documentID):", error)
//                            }
//                        }
//                
//                        guard let self = self else { return }
//                        
//                        if let error = error {
//                            print("❌ Snapshot listener error:", error)
//                            return
//                        }
//                
//                        self.buddies = loadedBuddies
//                        print("✅ Decoded buddies:", self.buddies)
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
