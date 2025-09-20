import Foundation

// MARK: - Buddy Model (local-only)
struct LocalBuddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
}

// MARK: - Local Buddy Service
@MainActor
final class LocalBuddyService: ObservableObject {
    @Published private(set) var buddies: [LocalBuddy] = []
    private let key = "BuddyLock.local.buddies"

    init() {
        load()
    }

    func addBuddy(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        buddies.append(LocalBuddy(displayName: trimmed))
        save()
    }

    func removeBuddy(_ buddy: LocalBuddy) {
        buddies.removeAll { $0.id == buddy.id }
        save()
    }

    // MARK: - Persistence
    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode([LocalBuddy].self, from: data) {
                buddies = decoded
            } else {
                buddies = []
            }
        } else {
            buddies = []
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(buddies) {
            d.set(data, forKey: key)
        }
    }
}
