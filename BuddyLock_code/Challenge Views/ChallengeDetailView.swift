import SwiftUI

struct ChallengeDetailView: View {
    let challengeID: UUID

    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @State private var addMinutesFor: UUID?
    @State private var minutesToAdd: Int = 10

    private var challenge: Challenge? {
        challenges.challenges.first(where: { $0.id == challengeID })
    }

    var body: some View {
        Group {
            if let challenge {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard(for: challenge)
                        quickActionsCard(for: challenge)
                        scoreboardSection(for: challenge)
                        detailsCard(for: challenge)
                        manualAdjustCard(for: challenge)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(challenge.resolvedTitle)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Challenge not found",
                    systemImage: "flag.slash",
                    description: Text("This challenge may have been removed.")
                )
            }
        }
    }

    private func heroCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.resolvedTitle)
                        .font(.title2.weight(.bold))
                    Text(heroSubtitle(for: challenge))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                phaseBadge(for: challenge)
            }

            if let target = challenge.trimmedTargetDescription {
                Text(target)
                    .font(.headline)
            }

            HStack(spacing: 10) {
                infoChip(title: "\(challenge.participantCount) people", systemImage: "person.2.fill")
                infoChip(title: "\(challenge.durationInDays()) day\(challenge.durationInDays() == 1 ? "" : "s")", systemImage: "calendar")
                infoChip(title: challenge.type.label, systemImage: "flag.2.crossed")
            }

            Text(leaderSummary(for: challenge))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .detailCardBackground(tint: Color.orange.opacity(0.16))
    }

    private func quickActionsCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            if challenge.phase() == .active {
                Text("Log a little focus without leaving the scoreboard.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    quickLogButton(challengeID: challenge.id, minutes: 15)
                    quickLogButton(challengeID: challenge.id, minutes: 30)
                    quickLogButton(challengeID: challenge.id, minutes: 45)
                }
            } else {
                Text("This challenge isn’t active right now, so the quick log buttons are paused.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .detailCardBackground()
    }

    private func quickLogButton(challengeID: UUID, minutes: Int) -> some View {
        Button {
            challenges.addManualMinutes(
                to: challengeID,
                participantID: challenges.localUserID,
                minutes: minutes
            )
        } label: {
            Text("+\(minutes)m")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func scoreboardSection(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scoreboard")
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                ForEach(Array(sortedParticipants(for: challenge).enumerated()), id: \.element.0) { index, entry in
                    scoreboardRow(
                        rank: index + 1,
                        participantID: entry.0,
                        score: entry.1,
                        maxScore: max(topScore(for: challenge), 1)
                    )
                }
            }
        }
    }

    private func scoreboardRow(rank: Int, participantID: UUID, score: Int, maxScore: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rank == 1 ? Color.yellow.opacity(0.24) : Color(.tertiarySystemBackground))
                        .frame(width: 34, height: 34)
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(rank == 1 ? .yellow : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName(for: participantID))
                        .font(.headline)
                    Text(participantSubtitle(for: participantID, score: score, maxScore: maxScore))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(score)m")
                    .font(.headline.monospacedDigit())
            }

            GeometryReader { proxy in
                let fullWidth = max(proxy.size.width, 1)
                let progress = CGFloat(score) / CGFloat(maxScore)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemBackground))
                    Capsule()
                        .fill(rank == 1 ? Color.yellow : Color.accentColor)
                        .frame(width: max(fullWidth * progress, score > 0 ? 12 : 0))
                }
            }
            .frame(height: 10)
        }
        .detailCardBackground()
    }

    private func detailsCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Details")
                .font(.headline)

            detailRow(
                title: "Starts",
                value: challenge.startDate.formatted(date: .abbreviated, time: .omitted)
            )
            detailRow(
                title: "Ends",
                value: challenge.endDate.formatted(date: .abbreviated, time: .omitted)
            )
            detailRow(
                title: "Format",
                value: challenge.type.label
            )
            detailRow(
                title: "Duration",
                value: "\(challenge.durationInDays()) day\(challenge.durationInDays() == 1 ? "" : "s")"
            )
        }
        .detailCardBackground()
    }

    private func manualAdjustCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust Scores")
                .font(.headline)

            Text("Keep this lightweight for now: use it to correct totals while the challenge system is still local-first.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Participant", selection: $addMinutesFor) {
                Text("Select a person").tag(Optional<UUID>.none)
                ForEach(challenge.participantIDs, id: \.self) { participantID in
                    Text(displayName(for: participantID)).tag(Optional(participantID))
                }
            }
            .pickerStyle(.menu)

            Stepper("Minutes: \(minutesToAdd)", value: $minutesToAdd, in: 1...180)

            Button {
                if let participantID = addMinutesFor {
                    challenges.addManualMinutes(
                        to: challenge.id,
                        participantID: participantID,
                        minutes: minutesToAdd
                    )
                }
            } label: {
                Text("Apply adjustment")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(addMinutesFor == nil)
        }
        .detailCardBackground()
    }

    private func heroSubtitle(for challenge: Challenge) -> String {
        switch challenge.phase() {
        case .active:
            return timeRemainingText(for: challenge)
        case .upcoming:
            return "Starts \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))"
        case .completed:
            return "Finished \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func leaderSummary(for challenge: Challenge) -> String {
        guard let leader = sortedParticipants(for: challenge).first else {
            return "No one has logged any focus yet."
        }

        if leader.1 == 0 {
            return "No focus logged yet. Be the first one to set the pace."
        }

        let leaderName = displayName(for: leader.0)
        let yourScore = challenge.scores[challenges.localUserID] ?? 0

        if leader.0 == challenges.localUserID {
            return "You’re in front with \(leader.1) minute\(leader.1 == 1 ? "" : "s")."
        }

        let gap = max(leader.1 - yourScore, 0)
        return "\(leaderName) is leading with \(leader.1) minute\(leader.1 == 1 ? "" : "s"). You’re \(gap)m back."
    }

    private func participantSubtitle(for participantID: UUID, score: Int, maxScore: Int) -> String {
        if participantID == challenges.localUserID {
            return score == maxScore && score > 0 ? "You’re tied for the lead." : "Your current total."
        }

        if score == maxScore && score > 0 {
            return "Currently setting the pace."
        }

        return "Still in the mix."
    }

    private func displayName(for participantID: UUID) -> String {
        if participantID == challenges.localUserID {
            return "You"
        }

        return buddies.displayName(for: participantID)
    }

    private func sortedParticipants(for challenge: Challenge) -> [(UUID, Int)] {
        challenge.scores.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return displayName(for: lhs.key) < displayName(for: rhs.key)
            }
            return lhs.value > rhs.value
        }
    }

    private func topScore(for challenge: Challenge) -> Int {
        sortedParticipants(for: challenge).first?.1 ?? 0
    }

    private func timeRemainingText(for challenge: Challenge) -> String {
        let remaining = max(challenge.endDate.timeIntervalSinceNow, 0)
        let days = Int(remaining / 86_400)

        if days >= 1 {
            return "\(days) day\(days == 1 ? "" : "s") left"
        }

        let hours = max(Int(remaining / 3_600), 1)
        return "\(hours) hour\(hours == 1 ? "" : "s") left"
    }

    private func phaseBadge(for challenge: Challenge) -> some View {
        let title: String
        let tint: Color

        switch challenge.phase() {
        case .active:
            title = "Active"
            tint = .blue
        case .upcoming:
            title = "Soon"
            tint = .orange
        case .completed:
            title = "Done"
            tint = .green
        }

        return Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func infoChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private extension View {
    func detailCardBackground(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@MainActor
struct ChallengeDetailView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let service = LocalBuddyService()
        if service.buddies.isEmpty {
            service.addBuddy(LocalBuddy(buddyUserID: "sam", displayName: "Sam"))
            service.addBuddy(LocalBuddy(buddyUserID: "jules", displayName: "Jules"))
        }
        return service
    }()

    static var previewChallengeService: ChallengeService = {
        let service = ChallengeService()
        if service.challenges.isEmpty {
            let buddies = previewBuddyService.buddies
            if let first = buddies.first {
                service.createDuel(
                    with: first,
                    title: "Example duel",
                    days: 7,
                    targetDescription: "Stay off short-form video after class"
                )
            }
        }
        return service
    }()

    static var previews: some View {
        let service = previewChallengeService
        let challengeID = service.challenges.first?.id ?? UUID()

        return NavigationStack {
            ChallengeDetailView(
                challengeID: challengeID,
                challenges: service,
                buddies: previewBuddyService
            )
        }
    }
}
