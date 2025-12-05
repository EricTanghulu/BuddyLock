import SwiftUI

// MARK: - Create formats (Duel vs Group)

private enum ChallengeFormat: String, CaseIterable, Identifiable {
    case duel
    case group

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duel:  return "Duel with a buddy"
        case .group: return "Group with multiple buddies"
        }
    }
}

// MARK: - Creation view (used from the + tab)

struct ChallengeCreateView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @Environment(\.dismiss) private var dismiss

    @State private var format: ChallengeFormat = .duel
    @State private var name: String = ""
    @State private var days: Int = 7
    @State private var targetDescription: String = ""

    @State private var selectedBuddyID: UUID?
    @State private var selectedGroupBuddyIDs: Set<UUID> = []

    var body: some View {
        Form {
            // Basic info about the challenge
            Section("Basics") {
                TextField("Name (optional)", text: $name)

                Stepper("Duration: \(days) day(s)", value: $days, in: 1...30)

                TextField("Apps or category (optional)", text: $targetDescription)
                    .textInputAutocapitalization(.sentences)

                Text("Later you can replace this with a real picker for apps or app groups. For now it’s just a description field.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Format (duel vs group)
            Section("Format") {
                Picker("Format", selection: $format) {
                    ForEach(ChallengeFormat.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }

            // Participants
            if format == .duel {
                duelSection
            } else {
                groupSection
            }
        }
        .navigationTitle("New Challenge")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { createChallenge() }
                    .disabled(isCreateDisabled)
            }
        }
    }

    // MARK: - Sections

    private var duelSection: some View {
        Section("Pick a buddy") {
            if buddies.buddies.isEmpty {
                Text("You don’t have any buddies yet. Add at least one buddy to start a duel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Buddy", selection: $selectedBuddyID) {
                    Text("Select…").tag(Optional<UUID>.none)
                    ForEach(buddies.buddies) { b in
                        Text(b.displayName).tag(Optional(b.id))
                    }
                }
            }
        }
    }

    private var groupSection: some View {
        Section("Pick group members") {
            if buddies.buddies.isEmpty {
                Text("You don’t have any buddies yet. Add a few buddies to start a group challenge.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddies.buddies) { b in
                    Toggle(b.displayName, isOn: Binding(
                        get: { selectedGroupBuddyIDs.contains(b.id) },
                        set: { newValue in
                            if newValue {
                                selectedGroupBuddyIDs.insert(b.id)
                            } else {
                                selectedGroupBuddyIDs.remove(b.id)
                            }
                        }
                    ))
                }

                Text("You’re included in every group challenge automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Creation

    private var isCreateDisabled: Bool {
        switch format {
        case .duel:
            return selectedBuddyID == nil
        case .group:
            return selectedGroupBuddyIDs.isEmpty
        }
    }

    private func createChallenge() {
        let title = name.isEmpty
            ? (format == .duel ? "Duel" : "Group challenge")
            : name

        let trimmedDescription = targetDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionOrNil = trimmedDescription.isEmpty ? nil : trimmedDescription

        switch format {
        case .duel:
            if let id = selectedBuddyID,
               let buddy = buddies.buddies.first(where: { $0.id == id }) {
                challenges.createDuel(
                    with: buddy,
                    title: title,
                    days: days,
                    targetDescription: descriptionOrNil
                )
            }

        case .group:
            let groupBuddies = buddies.buddies.filter { selectedGroupBuddyIDs.contains($0.id) }
            guard !groupBuddies.isEmpty else { return }
            challenges.createGroup(
                with: groupBuddies,
                title: title,
                days: days,
                targetDescription: descriptionOrNil
            )
        }

        dismiss()
    }
}

// MARK: - Preview

@MainActor
struct ChallengeCreateView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let s = LocalBuddyService()
        if s.buddies.isEmpty {
            s.addBuddy(name: "Alex")
            s.addBuddy(name: "Jordan")
        }
        return s
    }()

    static var previewChallengeService: ChallengeService = {
        ChallengeService()
    }()

    static var previews: some View {
        NavigationStack {
            ChallengeCreateView(
                challenges: previewChallengeService,
                buddies: previewBuddyService
            )
        }
    }
}
