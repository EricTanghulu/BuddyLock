import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager

    @ObservedObject var challengesService: ChallengeService
    @ObservedObject var buddyService: LocalBuddyService

    @State private var logoutError: String?

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    private var recentActivity: [ChallengeActivityItem] {
        Array(challengesService.activity.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeroCard
                focusSnapshotCard
                progressSection
                momentumSection
                achievementsCard

                if !recentActivity.isEmpty {
                    recentActivitySection
                }

                accountSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView(buddyService: buddyService)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
    }

    private var profileHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.16))
                        .frame(width: 72, height: 72)

                    Text(initials)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(resolvedDisplayName)
                        .font(.title2.weight(.bold))

                    Text(profileSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        statChip(
                            title: "\(buddyService.buddies.count) \(buddyLabel(for: buddyService.buddies.count))",
                            systemImage: "person.2.fill"
                        )
                        statChip(
                            title: "\(activeChallengeCount) active",
                            systemImage: "flag.checkered"
                        )
                    }
                }

                Spacer()
            }

            Text(profileSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .profileCardBackground(tint: Color.orange.opacity(0.16))
    }

    private var focusSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Focus Snapshot", systemImage: "lock.fill")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(focusStatusTint)
                    .frame(width: 10, height: 10)
            }

            Text(focusHeadline)
                .font(.title3.weight(.bold))

            Text(focusDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let secondary = focusSecondaryLine {
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .profileCardBackground()
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.title3.weight(.bold))

            HStack(spacing: 12) {
                metricCard(
                    title: "Total Focus",
                    value: "\(totalFocusMinutes)m",
                    subtitle: "Logged through challenges",
                    tint: .green
                )
                metricCard(
                    title: "Joined",
                    value: "\(joinedChallengeCount)",
                    subtitle: "Challenges so far",
                    tint: .blue
                )
            }

            HStack(spacing: 12) {
                metricCard(
                    title: "Wins",
                    value: "\(completedChallengeWins)",
                    subtitle: "Finished in first place",
                    tint: .orange
                )
                metricCard(
                    title: "Active",
                    value: "\(activeChallengeCount)",
                    subtitle: "Still in motion",
                    tint: .purple
                )
            }
        }
    }

    private func metricCard(
        title: String,
        value: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileCardBackground()
    }

    private var momentumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Momentum")
                .font(.title3.weight(.bold))

            VStack(alignment: .leading, spacing: 10) {
                momentumRow(
                    title: activeChallengeCount > 0 ? "You’re in \(activeChallengeCount) live challenge\(activeChallengeCount == 1 ? "" : "s")." : "No active challenges right now.",
                    detail: activeChallengeCount > 0
                        ? "Keep logging focus to protect your spot on the leaderboard."
                        : "Start a fresh challenge from Create when you want a little extra accountability.",
                    tint: .blue
                )

                momentumRow(
                    title: completedChallengeWins > 0
                        ? "You’ve won \(completedChallengeWins) completed challenge\(completedChallengeWins == 1 ? "" : "s")."
                        : "Your first challenge win is still up for grabs.",
                    detail: completedChallengeWins > 0
                        ? "That’s a strong signal that the social side of the app is working for you."
                        : "A quick duel is probably the easiest place to get momentum.",
                    tint: .orange
                )
            }
        }
    }

    private func momentumRow(title: String, detail: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.subheadline.weight(.semibold))
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
        .profileCardBackground()
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                achievementRow(
                    title: "First buddy",
                    unlocked: buddyService.buddies.count >= 1,
                    note: "Add at least one buddy."
                )
                achievementRow(
                    title: "First challenge",
                    unlocked: joinedChallengeCount >= 1,
                    note: "Join or create a challenge."
                )
                achievementRow(
                    title: "1 hour focused",
                    unlocked: totalFocusMinutes >= 60,
                    note: "Reach 60 minutes of focus across challenges."
                )
            }
        }
        .profileCardBackground()
    }

    private func achievementRow(title: String, unlocked: Bool, note: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(unlocked ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Challenge Activity")
                .font(.title3.weight(.bold))

            VStack(spacing: 10) {
                ForEach(recentActivity) { item in
                    recentActivityRow(for: item)
                }
            }
        }
    }

    private func recentActivityRow(for item: ChallengeActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: activityIcon(for: item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(activityTint(for: item))
                .frame(width: 34, height: 34)
                .background(activityTint(for: item).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(activityTitle(for: item))
                    .font(.subheadline.weight(.semibold))
                Text(item.challengeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relativeDateString(from: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .profileCardBackground()
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.title3.weight(.bold))

            Button(role: .destructive) {
                signOut()
            } label: {
                Label("Sign Out", systemImage: "arrow.backward.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let logoutError {
                Text("Logout failed: \(logoutError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .profileCardBackground()
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            logoutError = error.localizedDescription
        }
    }

    private var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Set your name" : trimmed
    }

    private var initials: String {
        let comps = resolvedDisplayName.split(separator: " ")
        if let first = comps.first, let char = first.first {
            return String(char).uppercased()
        }
        return "U"
    }

    private var profileSubtitle: String {
        if buddyService.buddies.isEmpty {
            return "Start small, then bring your people in."
        }

        return "Building better screen habits with your buddies."
    }

    private var profileSummary: String {
        if activeChallengeCount > 0 {
            return "You’ve got live accountability in motion right now. Keep your focus sessions steady and the rest of the tab should start trending up."
        }

        if totalFocusMinutes > 0 {
            return "You’ve already logged real focus time. Now the goal is turning that into a routine that feels repeatable."
        }

        return "This tab should become your personal checkpoint for focus, social accountability, and momentum over time."
    }

    private func statChip(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }

    private func buddyLabel(for count: Int) -> String {
        count == 1 ? "buddy" : "buddies"
    }

    private var totalFocusMinutes: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.reduce(0) { sum, challenge in
            sum + (challenge.scores[id] ?? 0)
        }
    }

    private var joinedChallengeCount: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.filter { $0.participantIDs.contains(id) }.count
    }

    private var activeChallengeCount: Int {
        let id = challengesService.localUserID
        let now = Date()
        return challengesService.challenges.filter {
            $0.participantIDs.contains(id) && now >= $0.startDate && now <= $0.endDate
        }.count
    }

    private var completedChallengeWins: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.filter { challenge in
            challenge.phase() == .completed &&
            leadingParticipant(for: challenge)?.0 == id &&
            (leadingParticipant(for: challenge)?.1 ?? 0) > 0
        }.count
    }

    private func leadingParticipant(for challenge: Challenge) -> (UUID, Int)? {
        challenge.scores.max { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.uuidString > rhs.key.uuidString
            }
            return lhs.value < rhs.value
        }
    }

    private var focusHeadline: String {
        if screenTime.focusState.isActive {
            if let seconds = screenTime.focusState.secondsRemaining {
                return "Focus active for another \(max(1, seconds / 60)) min"
            }
            return "Focus session active"
        }

        switch screenTime.activeMode {
        case .baseline:
            return "Baseline blocking is on"
        case .panic:
            return "Panic block is active"
        case .essentialsOnly:
            return "Study Only mode is active"
        case .idle:
            return "Nothing is protecting your attention right now"
        case .focus:
            return "Focus session"
        }
    }

    private var focusDetail: String {
        if screenTime.focusState.isActive {
            return "Stay in focus to build streaks, finish stronger in challenges, and give your future self fewer cleanup sessions."
        }

        switch screenTime.activeMode {
        case .baseline:
            return "Your default distractions are already blocked, so the app is quietly helping even when you’re not in a formal session."
        case .panic:
            return "You used a short hard stop to protect yourself from a distraction spiral."
        case .essentialsOnly:
            return "Only your essentials are available, which is usually a strong signal you’re in serious work mode."
        case .idle:
            return "Start a focus session from Home when you want more structure."
        case .focus:
            return ""
        }
    }

    private var focusSecondaryLine: String? {
        if screenTime.isBaselineEnabled && screenTime.activeMode == .idle {
            return "Baseline blocking is still on in the background."
        }

        return nil
    }

    private var focusStatusTint: Color {
        switch screenTime.activeMode {
        case .idle:
            return screenTime.focusState.isActive ? .green : .gray.opacity(0.5)
        case .baseline:
            return .green
        case .focus:
            return .blue
        case .panic:
            return .red
        case .essentialsOnly:
            return .indigo
        }
    }

    private func activityTitle(for item: ChallengeActivityItem) -> String {
        switch item.kind {
        case .created:
            return "You started a challenge"
        case .rematchStarted:
            return "You kicked off a rematch"
        case .minutesLogged:
            return "You logged \(item.minutes ?? 0)m"
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

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension View {
    func profileCardBackground(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    let screenTime = ScreenTimeManager()
    let challenges = ChallengeService()
    let buddies = LocalBuddyService()
    if buddies.buddies.isEmpty {
        buddies.addBuddy(LocalBuddy(buddyUserID: "sam", displayName: "Sam"))
        buddies.addBuddy(LocalBuddy(buddyUserID: "jules", displayName: "Jules"))
    }

    return NavigationStack {
        ProfileView(challengesService: challenges, buddyService: buddies)
    }
    .environmentObject(screenTime)
}
