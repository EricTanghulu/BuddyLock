import Foundation
import FirebaseFirestore

// MARK: - changing to firebase buddy

struct LocalBuddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()          // local identity (used by challenges)
    var displayName: String
    @DocumentID var remoteID: String?   // Firestore identity
}


// MARK: - firebase Buddy Service
import Foundation
import FirebaseFirestore

@MainActor
final class LocalBuddyService: ObservableObject {

    @Published private(set) var buddies: [LocalBuddy] = []

    private let db = Firestore.firestore()
    private let collection = "buddies"
    private var listener: ListenerRegistration?

    init() {
        startListening()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Firestore listener (syncs remote changes)
    private func startListening() {
        listener = db.collection(collection)
            .order(by: "displayName")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("❌ Firestore error:", error?.localizedDescription ?? "")
                    return
                }

                // Convert Firestore docs to LocalBuddy
                let remoteBuddies = documents.compactMap { try? $0.data(as: LocalBuddy.self) }

                // Merge remote buddies with existing local-only buddies
                self.buddies = self.merge(remoteBuddies: remoteBuddies)
            }
    }

    // MARK: - Merge remote with local
    private func merge(remoteBuddies: [LocalBuddy]) -> [LocalBuddy] {
        var combined = buddies

        for buddy in remoteBuddies {
            if let remoteID = buddy.remoteID,
               !combined.contains(where: { $0.remoteID == remoteID }) {
                combined.append(buddy)
            }
        }

        return combined
    }

    // MARK: - Add buddy by name (local-only or cloud)
//    func addBuddy(name: String) {
//        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !trimmed.isEmpty else { return }
//
//        let buddy = LocalBuddy(displayName: trimmed)
//
//        // Prevent duplicates by name
//        if buddies.contains(where: { $0.displayName == trimmed }) { return }
//
//        buddies.append(buddy)
//
//        // Save to Firestore
//        do {
//            try db.collection(collection).addDocument(from: buddy)
//        } catch {
//            print("❌ Failed to add buddy:", error)
//        }
//    }

    // MARK: - Add buddy directly (from Firestore / friend requests)
    func addBuddy(_ buddy: LocalBuddy) {
        // Prevent duplicates by remoteID
        if let remoteID = buddy.remoteID,
           buddies.contains(where: { $0.remoteID == remoteID }) { return }

        buddies.append(buddy)

        // If no remoteID, add to Firestore
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
        buddies.removeAll { $0.id == buddy.id || $0.remoteID == buddy.remoteID }

        // Delete from Firestore if remoteID exists
        if let remoteID = buddy.remoteID {
            db.collection(collection).document(remoteID).delete { error in
                if let error = error {
                    print("❌ Failed to delete buddy:", error)
                }
            }
        }
    }
}
