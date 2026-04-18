import SwiftUI

private enum ChallengeListScope: String, CaseIterable, Identifiable {
    case friends
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends:
            return "Friends"
        case .global:
            return "Global"
        }
    }
}

struct ChallengeListView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @State private var scope: ChallengeListScope = .friends

    private var friendChallenges: [Challenge] {
        challenges.challenges.sorted { lhs, rhs in
            if lhs.phase() == rhs.phase() {
                return lhs.endDate < rhs.endDate
            }
            return phaseSortOrder(lhs.phase()) < phaseSortOrder(rhs.phase())
        }
    }

    private var activeChallenges: [Challenge] {
        friendChallenges.filter { $0.phase() == .active }
    }

    private var upcomingChallenges: [Challenge] {
        friendChallenges.filter { $0.phase() == .upcoming }
    }

    private var completedChallenges: [Challenge] {
        friendChallenges.filter { $0.phase() == .completed }
    }

    private var recentCompletedChallenges: [Challenge] {
        Array(
            completedChallenges
                .sorted { $0.endDate > $1.endDate }
                .prefix(3)
        )
    }

    private var recentActivity: [ChallengeActivityItem] {
        Array(challenges.activity.prefix(6))
    }

    private var totalLoggedMinutes: Int {
        friendChallenges.reduce(0) { partialResult, challenge in
            partialResult + (challenge.scores[challenges.localUserID] ?? 0)
        }
    }

    private var leadingCount: Int {
        activeChallenges.filter(isCurrentUserLeading).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scopePicker

                switch scope {
                case .friends:
                    friendsOverview
                case .global:
                    globalOverview
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.large)
    }

    private var scopePicker: some View {
        Picker("Challenge scope", selection: $scope) {
            ForEach(ChallengeListScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var friendsOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerCard
            summaryCards

            if friendChallenges.isEmpty {
                emptyStateCard
            } else {
                if !recentActivity.isEmpty {
                    activitySection
                }

                if !recentCompletedChallenges.isEmpty {
                    recentlyFinishedSection
                }

                if !activeChallenges.isEmpty {
                    challengeSection(
                        title: "Active Now",
                        subtitle: leadingCount > 0
                            ? "You’re leading \(leadingCount) active challenge\(leadingCount == 1 ? "" : "s")."
                            : "The challenges that still need your focus."
                    ) {
                        ForEach(activeChallenges) { challenge in
                            challengeCard(for: challenge)
                        }
                    }
                }

                if !upcomingChallenges.isEmpty {
                    challengeSection(
                        title: "Starting Soon",
                        subtitle: "Challenges that are lined up next."
                    ) {
                        ForEach(upcomingChallenges) { challenge in
                            challengeCard(for: challenge)
                        }
                    }
                }

                if !completedChallenges.isEmpty {
                    challengeSection(
                        title: "Completed",
                        subtitle: "Look back at the finished runs and the final scores."
                    ) {
                        ForEach(completedChallenges) { challenge in
                            challengeCard(for: challenge)
                        }
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        challengeSection(
            title: "Activity",
            subtitle: "A quick read on what’s moving without opening every challenge."
        ) {
            ForEach(recentActivity) { item in
                activityRow(for: item)
            }
        }
    }

    private var globalOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Global challenges are coming")
                    .font(.title3.weight(.bold))
                Text("The tab is ready for friend-based accountability now. Later, this space can expand into app-wide events, featured seasons, and community leaderboards without changing the overall flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .challengeCardBackground(tint: Color.indigo.opacity(0.18))

            VStack(alignment: .leading, spacing: 12) {
                globalFeatureRow(
                    title: "Featured events",
                    detail: "Short themed challenges you can join with one tap.",
                    systemImage: "sparkles",
                    tint: .orange
                )
                globalFeatureRow(
                    title: "Joinable seasons",
                    detail: "Longer competitions with milestones and rewards.",
                    systemImage: "flag.2.crossed.fill",
                    tint: .blue
                )
                globalFeatureRow(
                    title: "Community standings",
                    detail: "See how your focus stacks up once backend support is in place.",
                    systemImage: "chart.bar.fill",
                    tint: .green
                )
            }
            .challengeCardBackground()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make focus social")
                .font(.title2.weight(.bold))

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .challengeCardBackground(tint: Color.orange.opacity(0.18))
    }

    private var headerSubtitle: String {
        if friendChallenges.isEmpty {
            return "Challenge one buddy or a small group so the app feels less like a rule and more like a team effort."
        }

        if activeChallenges.isEmpty {
            return "You’ve wrapped your recent challenges. Start another one while the momentum is still warm."
        }

        return "Check the live standings, log a little more focus, and keep your people in the loop without digging around."
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Active",
                value: "\(activeChallenges.count)",
                tint: .blue
            )
            summaryCard(
                title: "Completed",
                value: "\(completedChallenges.count)",
                tint: .green
            )
            summaryCard(
                title: "Your Minutes",
                value: "\(totalLoggedMinutes)",
                tint: .orange
            )
        }
    }

    private func summaryCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            Text(value)
                .font(.title3.weight(.bold))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "flag.slash.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("No challenges yet")
                .font(.headline)

            Text("Start with a quick duel against one buddy or set up a small group challenge so everyone can see the same scoreboard.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Use the Create tab to start your first challenge.")
                .font(.subheadline.weight(.semibold))
        }
        .challengeCardBackground()
    }

    private var recentlyFinishedSection: some View {
        challengeSection(
            title: "Recently Finished",
            subtitle: "Re-run a challenge that worked well without rebuilding it from scratch."
        ) {
            ForEach(recentCompletedChallenges) { challenge in
                recentlyFinishedCard(for: challenge)
            }
        }
    }

    private func challengeSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                content()
            }
        }
    }

    private func challengeCard(for challenge: Challenge) -> some View {
        NavigationLink {
            ChallengeDetailView(
                challengeID: challenge.id,
                challenges: challenges,
                buddies: buddies
            )
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(challenge.resolvedTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(challengeSubtitle(for: challenge))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    challengePhaseBadge(for: challenge)
                }

                if let target = challenge.trimmedTargetDescription {
                    Text(target)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 10) {
                    labelChip(
                        title: "\(challenge.participantCount) people",
                        systemImage: "person.2.fill"
                    )
                    labelChip(
                        title: scoreSummary(for: challenge),
                        systemImage: "chart.bar.fill"
                    )
                }

                Text(footerSummary(for: challenge))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .challengeCardBackground()
        }
        .buttonStyle(.plain)
    }

    private func recentlyFinishedCard(for challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.resolvedTitle)
                        .font(.headline)
                    Text("Ended \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                challengePhaseBadge(for: challenge)
            }

            Text(rematchSummary(for: challenge))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                NavigationLink {
                    ChallengeDetailView(
                        challengeID: challenge.id,
                        challenges: challenges,
                        buddies: buddies
                    )
                } label: {
                    Text("View results")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    challenges.createRematch(from: challenge)
                } label: {
                    Label("Rematch", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .challengeCardBackground()
    }

    private func activityRow(for item: ChallengeActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activityIcon(for: item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activityTint(for: item))
                .frame(width: 34, height: 34)
                .background(activityTint(for: item).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(activityTitle(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.challengeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relativeDateString(from: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .challengeCardBackground()
    }

    private func challengeSubtitle(for challenge: Challenge) -> String {
        let typeLabel = challenge.type == .duel ? "Duel" : "Group"

        switch challenge.phase() {
        case .active:
            return "\(typeLabel) • \(timeRemainingText(for: challenge))"
        case .upcoming:
            return "\(typeLabel) • Starts \(challenge.startDate.formatted(date: .abbreviated, time: .omitted))"
        case .completed:
            return "\(typeLabel) • Ended \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    private func footerSummary(for challenge: Challenge) -> String {
        if isCurrentUserLeading(challenge) {
            return "You’re currently setting the pace."
        }

        guard let leader = leadingParticipant(for: challenge) else {
            return "No focus logged yet."
        }

        let name = leader.0 == challenges.localUserID ? "You" : buddies.displayName(for: leader.0)
        return "\(name) is leading with \(leader.1) minute\(leader.1 == 1 ? "" : "s")."
    }

    private func rematchSummary(for challenge: Challenge) -> String {
        guard let leader = leadingParticipant(for: challenge), leader.1 > 0 else {
            return "Run it back with the same people and reset the scoreboard."
        }

        let winner = leader.0 == challenges.localUserID ? "You" : buddies.displayName(for: leader.0)
        return "\(winner) won the last round with \(leader.1)m. Start the same challenge again in one tap."
    }

    private func activityTitle(for item: ChallengeActivityItem) -> String {
        let actor = displayName(for: item.participantID)

        switch item.kind {
        case .created:
            return "\(actor) started a challenge"
        case .rematchStarted:
            return "\(actor) kicked off a rematch"
        case .minutesLogged:
            let minutes = item.minutes ?? 0
            return "\(actor) logged \(minutes)m"
        }
    }

    private func activityIcon(for item: ChallengeActivityItem) -> String {
        switch item.kind {
        case .created:
            return "flag.fill"
        case .rematchStarted:
            return "arrow.clockwise"
        case .minutesLogged:
            return "timer"
        }
    }

    private func activityTint(for item: ChallengeActivityItem) -> Color {
        switch item.kind {
        case .created:
            return .orange
        case .rematchStarted:
            return .blue
        case .minutesLogged:
            return .green
        }
    }

    private func displayName(for participantID: UUID?) -> String {
        guard let participantID else { return "Someone" }
        return participantID == challenges.localUserID ? "You" : buddies.displayName(for: participantID)
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func scoreSummary(for challenge: Challenge) -> String {
        let yourMinutes = challenge.scores[challenges.localUserID] ?? 0
        return "You: \(yourMinutes)m"
    }

    private func isCurrentUserLeading(_ challenge: Challenge) -> Bool {
        guard let leader = leadingParticipant(for: challenge) else { return false }
        let yourMinutes = challenge.scores[challenges.localUserID] ?? 0
        return leader.1 > 0 && yourMinutes == leader.1
    }

    private func leadingParticipant(for challenge: Challenge) -> (UUID, Int)? {
        challenge.scores.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.uuidString > rhs.key.uuidString
            }
            return lhs.value < rhs.value
        }
    }

    private func timeRemainingText(for challenge: Challenge) -> String {
        let remaining = max(challenge.endDate.timeIntervalSinceNow, 0)
        let days = Int(remaining / 86_400)

        if days >= 1 {
            return "\(days)d left"
        }

        let hours = max(Int(remaining / 3_600), 1)
        return "\(hours)h left"
    }

    private func challengePhaseBadge(for challenge: Challenge) -> some View {
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
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func labelChip(title: String, systemImage: String) -> some View {
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

    private func globalFeatureRow(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func phaseSortOrder(_ phase: ChallengePhase) -> Int {
        switch phase {
        case .active:
            return 0
        case .upcoming:
            return 1
        case .completed:
            return 2
        }
    }
}

private extension View {
    func challengeCardBackground(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@MainActor
struct ChallengeListView_Previews: PreviewProvider {
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
                service.createDuel(with: first, title: "Weekend reset", days: 7, targetDescription: "Social apps")
            }
            if buddies.count >= 2 {
                service.createGroup(
                    with: Array(buddies.prefix(2)),
                    title: "Study sprint",
                    days: 5,
                    targetDescription: "Stay off distractions after 8 PM"
                )
            }
        }
        return service
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
