import SwiftUI

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
struct ChallengeDetailView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let s = LocalBuddyService()
        if s.buddies.isEmpty {
            s.addBuddy(name: "Alex")
            s.addBuddy(name: "Jordan")
        }
        return s
    }()

    static var previewChallengeService: ChallengeService = {
        let service = ChallengeService()
        if service.challenges.isEmpty {
            let buddies = previewBuddyService.buddies
            if let first = buddies.first {
                service.createDuel(with: first, title: "Example duel", days: 7)
            }
        }
        return service
    }()

    static var previews: some View {
        let service = previewChallengeService
        let challenge = service.challenges.first ?? Challenge(
            title: "Example duel",
            type: .duel,
            participantIDs: [],
            startDate: .now,
            endDate: .now,
            scores: [:],
            targetDescription: "Screen time on social apps"
        )

        return NavigationStack {
            ChallengeDetailView(
                challenge: challenge,
                challenges: service,
                buddies: previewBuddyService
            )
        }
    }
}
