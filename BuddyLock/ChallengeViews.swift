
import SwiftUI

struct ChallengeListView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: BuddyService

    @State private var showCreate = false

    var body: some View {
        List {
            Section {
                if challenges.challenges.isEmpty {
                    Text("No challenges yet. Create a head‑to‑head or group challenge to get started.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(challenges.challenges) { ch in
                        NavigationLink {
                            ChallengeDetailView(challenge: ch, challenges: challenges, buddies: buddies)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ch.title).bold()
                                Text("\(ch.type.label) • Ends \(ch.endDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        idx.map { challenges.challenges[$0] }.forEach(challenges.removeChallenge)
                    }
                }
            }
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Label("New", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            ChallengeCreateView(challenges: challenges, buddies: buddies)
        }
    }
}

struct ChallengeCreateView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: BuddyService

    @Environment(\.dismiss) private var dismiss
    @State private var type: ChallengeType = .headToHead
    @State private var title: String = ""
    @State private var days: Int = 7

    // selections
    @State private var selectedBuddyForH2H: UUID?
    @State private var selectedGroupBuddyIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    Picker("Type", selection: $type) {
                        ForEach(ChallengeType.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    TextField("Title (optional)", text: $title)
                    Stepper("Duration: \(days) day(s)", value: $days, in: 1...30)
                }

                if type == .headToHead {
                    Section("Pick a buddy") {
                        if buddies.buddies.isEmpty {
                            Text("You have no buddies yet. Add one first.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Buddy", selection: $selectedBuddyForH2H) {
                                ForEach(buddies.buddies) { b in
                                    Text(b.displayName).tag(Optional(b.id))
                                }
                            }
                        }
                    }
                } else {
                    Section("Pick group members") {
                        if buddies.buddies.isEmpty {
                            Text("You have no buddies yet. Add a few first.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(buddies.buddies) { b in
                                Toggle(b.displayName, isOn: Binding(
                                    get: { selectedGroupBuddyIDs.contains(b.id) },
                                    set: { newVal in
                                        if newVal { selectedGroupBuddyIDs.insert(b.id) }
                                        else { selectedGroupBuddyIDs.remove(b.id) }
                                    }
                                ))
                            }
                            Text("You are included automatically.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Challenge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let t = title.isEmpty ? (type == .headToHead ? "Head-to-Head" : "Group Challenge") : title
                        if type == .headToHead, let id = selectedBuddyForH2H, let buddy = buddies.buddies.first(where: { $0.id == id }) {
                            challenges.createHeadToHead(with: buddy, title: t, days: days)
                            dismiss()
                        } else if type == .group {
                            let groupBuddies = buddies.buddies.filter { selectedGroupBuddyIDs.contains($0.id) }
                            guard !groupBuddies.isEmpty else { return }
                            challenges.createGroup(with: groupBuddies, title: t, days: days)
                            dismiss()
                        }
                    }
                    .disabled((type == .headToHead && selectedBuddyForH2H == nil) ||
                              (type == .group && selectedGroupBuddyIDs.isEmpty))
                }
            }
        }
    }
}

struct ChallengeDetailView: View {
    let challenge: Challenge
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: BuddyService

    @State private var addMinutesFor: UUID?
    @State private var minutesToAdd: Int = 5

    var body: some View {
        List {
            Section("Standings") {
                ForEach(sortedParticipants(), id: \.0) { pid, minutes in
                    HStack {
                        Text(nameFor(pid))
                        Spacer()
                        Text("\(minutes) min").monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Add 5 min") { addMinutes(pid: pid, minutes: 5) }
                        Button("Add 10 min") { addMinutes(pid: pid, minutes: 10) }
                    }
                }
                Text("Challenge ends \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Manual Log") {
                Picker("Participant", selection: $addMinutesFor) {
                    ForEach(challenge.participantIDs, id: \.self) { pid in
                        Text(nameFor(pid)).tag(Optional(pid))
                    }
                }
                Stepper("Minutes: \(minutesToAdd)", value: $minutesToAdd, in: 1...180)
                Button("Add Minutes") {
                    if let pid = addMinutesFor {
                        challenges.addManualMinutes(to: challenge.id, participantID: pid, minutes: minutesToAdd)
                    }
                }.disabled(addMinutesFor == nil)
            }
        }
        .navigationTitle(challenge.title)
    }

    private func sortedParticipants() -> [(UUID, Int)] {
        let dict = challenge.scores
        return dict.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return nameFor(lhs.key) < nameFor(rhs.key)
            }
            return lhs.value > rhs.value
        }
    }

    private func nameFor(_ pid: UUID) -> String {
        if pid == challenges.localUserID { return "You" }
        return buddies.buddies.first(where: { $0.id == pid })?.displayName ?? "Unknown"
    }

    private func addMinutes(pid: UUID, minutes: Int) {
        challenges.addManualMinutes(to: challenge.id, participantID: pid, minutes: minutes)
    }
}
