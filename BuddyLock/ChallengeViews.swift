import SwiftUI

// MARK: - List scopes (Friends vs Global)

private enum ChallengeListScope: String, CaseIterable, Identifiable {
    case friends
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: return "Friends"
        case .global:  return "Global"
        }
    }
}

// MARK: - Main list view

struct ChallengeListView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @State private var scope: ChallengeListScope = .friends

    private var friendChallenges: [Challenge] {
        challenges.challenges
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Challenge scope", selection: $scope) {
                ForEach(ChallengeListScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            List {
                switch scope {
                case .friends:
                    friendChallengesSection
                case .global:
                    globalChallengesSection
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Challenges")
    }

    // MARK: - Sections

    private var friendChallengesSection: some View {
        Section {
            if friendChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No challenges yet")
                        .font(.headline)
                    Text("Once you create a challenge, it’ll show up here so you can track progress against your buddies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(friendChallenges) { ch in
                    NavigationLink {
                        ChallengeDetailView(
                            challenge: ch,
                            challenges: challenges,
                            buddies: buddies
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ch.title.isEmpty ? defaultTitle(for: ch) : ch.title)
                                .font(.headline)

                            Text(rowSubtitle(for: ch))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    idx.map { friendChallenges[$0] }.forEach(challenges.removeChallenge)
                }
            }
        } header: {
            Text("Friend challenges")
        }
    }

    private var globalChallengesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("App-wide challenges")
                    .font(.headline)

                Text("This is where global challenges will appear once they’re available. You’ll be able to join app-wide events and earn in-game rewards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Featured challenge", systemImage: "sparkles")
                    Label("Joinable challenges", systemImage: "person.3.sequence")
                    Label("Your active global challenges", systemImage: "clock.arrow.circlepath")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Global challenges")
        } footer: {
            Text("Hook this section up to your backend or mock data when you’re ready. The layout is designed to be easy to plug into real data later.")
                .font(.footnote)
        }
    }

    // MARK: - Helpers

    private func defaultTitle(for challenge: Challenge) -> String {
        switch challenge.type {
        case .duel:
            return "Duel"
        case .group:
            return "Group challenge"
        }
    }

    private func rowSubtitle(for challenge: Challenge) -> String {
        let typeText: String = {
            switch challenge.type {
            case .duel:  return "Duel"
            case .group: return "Group"
            }
        }()

        let endText = challenge.endDate.formatted(date: .abbreviated, time: .omitted)

        if let target = challenge.targetDescription,
           !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(typeText) • \(target) • Ends \(endText)"
        } else {
            return "\(typeText) • Ends \(endText)"
        }
    }
}

// MARK: - Creation view (used from the + tab)

private enum ChallengeFormat: String, CaseIterable, Identifiable {
    case duel
    case group

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duel:  return "Duel"
        case .group: return "Group Challenge"
        }
    }
}

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

// MARK: - Detail view

struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @State private var addMinutesFor: UUID?
    @State private var minutesToAdd: Int = 10

    var body: some View {
        List {
            Section("Info") {
                Text(typeDescription(for: challenge.type))
                Text("Starts \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))")
                Text("Ends \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")

                if let desc = challenge.targetDescription,
                   !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Target: \(desc)")
                }
            }

            Section("Scoreboard") {
                ForEach(sortedParticipants(), id: \.0) { pid, score in
                    HStack {
                        Text(nameFor(pid))
                        Spacer()
                        Text("\(score) min")
                            .monospacedDigit()
                    }
                }
            }

            Section("Manual adjust (for testing)") {
                Picker("Participant", selection: $addMinutesFor) {
                    Text("Select…").tag(Optional<UUID>.none)
                    ForEach(challenge.participantIDs, id: \.self) { pid in
                        Text(nameFor(pid)).tag(Optional(pid))
                    }
                }
                Stepper("Minutes: \(minutesToAdd)", value: $minutesToAdd, in: 1...180)
                Button("Add minutes") {
                    if let pid = addMinutesFor {
                        challenges.addManualMinutes(
                            to: challenge.id,
                            participantID: pid,
                            minutes: minutesToAdd
                        )
                    }
                }
                .disabled(addMinutesFor == nil)
            }
        }
        .navigationTitle(challenge.title)
    }

    private func sortedParticipants() -> [(UUID, Int)] {
        challenge.scores.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return nameFor(lhs.key) < nameFor(rhs.key)
            }
            return lhs.value > rhs.value
        }
    }

    private func nameFor(_ pid: UUID) -> String {
        if pid == challenges.localUserID {
            return "You"
        }
        return buddies.buddies.first(where: { $0.id == pid })?.displayName ?? "Unknown"
    }

    private func typeDescription(for type: ChallengeType) -> String {
        switch type {
        case .duel:  return "Duel"
        case .group: return "Group challenge"
        }
    }
}

// MARK: - Preview

@MainActor
struct ChallengeListView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let s = LocalBuddyService()
        if s.buddies.isEmpty {
            s.addBuddy(name: "Alex")
            s.addBuddy(name: "Jordan")
            s.addBuddy(name: "Sam")
        }
        return s
    }()

    static var previewChallengeService: ChallengeService = {
        let s = ChallengeService()
        // Just for Xcode canvas; does not affect real users.
        if s.challenges.isEmpty {
            let buddies = previewBuddyService.buddies
            if let first = buddies.first {
                s.createDuel(with: first, title: "Example duel", days: 7)
            }
            if buddies.count >= 2 {
                s.createGroup(
                    with: Array(buddies.prefix(2)),
                    title: "Example group",
                    days: 3
                )
            }
        }
        return s
    }()

    static var previews: some View {
        NavigationStack {
            ChallengeListView(
                challenges: previewChallengeService,
                buddies: previewBuddyService
            )
        }
    }
}
