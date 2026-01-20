import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var challengesService: ChallengeService
    @ObservedObject var buddyService: LocalBuddyService
    @Environment(\.dismiss) private var dismiss
    @State private var logoutError: String?

    
    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeaderCard
                focusStatusCard
                statsCard
                achievementsCard

                // MARK: - Logout button
                Button(role: .destructive) {
                    do {
                        try Auth.auth().signOut()
                        dismiss() // go back to login
                    } catch {
                        logoutError = error.localizedDescription
                    }
                }
                label: {
                    Label("Logout", systemImage: "arrow.backward.square")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .foregroundColor(.red)
                .padding(.top, 20)

                // Optional: show error
                if let error = logoutError {
                    Text("Logout failed: \(error)")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            
            .padding()
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        
        
    }

    // MARK: - Cards

    private var profileHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 64, height: 64)

                Text(initials)
                    .font(.title2.weight(.bold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName.isEmpty ? "Set your name" : displayName)
                    .font(.title3.weight(.semibold))

                Text("Building better screen habits with your buddies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("\(buddyService.buddies.count) buddy\(buddyService.buddies.count == 1 ? "" : "ies")",
                          systemImage: "person.2.fill")
                        .font(.caption)
                    Label("\(activeChallengeCount) active challenge\(activeChallengeCount == 1 ? "" : "s")",
                          systemImage: "flag.checkered")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var focusStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Focus & blocking", systemImage: "lock.app.fill")
                    .font(.headline)
                Spacer()
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(screenTime.activeMode == .idle ? .gray.opacity(0.4) : .green)
            }

            Text(focusHeadline)
                .font(.subheadline.weight(.semibold))

            Text(focusDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stats")
                .font(.headline)

            HStack {
                statColumn(
                    title: "Total focus",
                    value: "\(totalFocusMinutes) min"
                )

                Spacer()

                statColumn(
                    title: "Challenges joined",
                    value: "\(joinedChallengeCount)"
                )

                Spacer()

                statColumn(
                    title: "Buddies",
                    value: "\(buddyService.buddies.count)"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Achievements")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
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
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func achievementRow(title: String, unlocked: Bool, note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: unlocked ? "checkmark.seal.fill" : "seal")
                .foregroundColor(unlocked ? .green : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Derived values

    private var initials: String {
        let comps = displayName.split(separator: " ")
        if let first = comps.first, let char = first.first {
            return String(char).uppercased()
        }
        return "U"
    }

    private var totalFocusMinutes: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.reduce(0) { sum, challenge in
            sum + (challenge.scores[id] ?? 0)
        }
    }

    private var joinedChallengeCount: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.filter {
            $0.participantIDs.contains(id)
        }.count
    }

    private var activeChallengeCount: Int {
        let id = challengesService.localUserID
        let now = Date()
        return challengesService.challenges.filter {
            $0.participantIDs.contains(id) && now >= $0.startDate && now <= $0.endDate
        }.count
    }

    private var focusHeadline: String {
        if screenTime.focusState.isActive {
            if let s = screenTime.focusState.secondsRemaining {
                return "Focus active — \(max(1, s / 60)) min left"
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
            return "Not focusing right now"
        case .focus:
            // handled above
            return "Focus session"
        }
    }

    private var focusDetail: String {
        if screenTime.focusState.isActive {
            return "Stay in focus to build streaks and climb the leaderboard with your buddies."
        }

        switch screenTime.activeMode {
        case .baseline:
            return "Your most distracting apps are blocked by default. You can adjust this from the Home tab."
        case .panic:
            return "You recently hit the panic button to keep yourself safe from distractions."
        case .essentialsOnly:
            return "Only essential apps are allowed. Great for exam prep and deep work."
        case .idle:
            return "Start a focus session from the Home tab to protect your attention."
        case .focus:
            return ""
        }
    }
}

#Preview {
    let screenTime = ScreenTimeManager()
    let challenges = ChallengeService()
    let buddies = LocalBuddyService()
    buddies.addBuddy(LocalBuddy(remoteID: "remote1",     // buddy doc ID
                                buddyUserID: "buddyID",               // friend's auth UID
                                )) 

    return NavigationStack {
        ProfileView(challengesService: challenges, buddyService: buddies)
    }
    .environmentObject(screenTime)
}
