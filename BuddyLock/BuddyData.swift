
import Foundation

// Simple Buddy model (no roles)
struct Buddy: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
}

// Holds buddies and persistence
@MainActor
final class BuddyService: ObservableObject {
    @Published private(set) var buddies: [Buddy] = []
    private let key = "BuddyLock.buddies.simple"

    init() {
        load()
        // Seed with a sample buddy if empty (optional)
        if buddies.isEmpty {
            buddies = []
            save()
        }
        
    }

    func addBuddy(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        buddies.append(Buddy(displayName: trimmed))
        save()
    }

    func removeBuddy(_ buddy: Buddy) {
        buddies.removeAll { $0.id == buddy.id }
        save()
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Buddy].self, from: data) {
            buddies = decoded
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(buddies) {
            d.set(data, forKey: key)
        }
    }
}
