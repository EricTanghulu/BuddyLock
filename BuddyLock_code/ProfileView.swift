import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var challengesService: ChallengeService
    @ObservedObject var buddyService: LocalBuddyService

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeaderCard
                focusStatusCard
                challengesCard
                achievementsCard
                quickActionsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView(buddyService: buddyService)
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                }
            }
        }
    }

    // MARK: - Cards

    private var profileHeaderCard: some View {
        NavigationLink {
            EditProfileView(buddyService: buddyService)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Your Profile" : displayName)
                            .font(.title3.bold())

                        let count = buddyService.buddies.count
                        Text("\(count) \(count == 1 ? "buddy" : "buddies") connected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.vertical, 4)

                HStack(spacing: 16) {
                    statPill(title: "Buddies", value: "\(buddyService.buddies.count)")
                    statPill(title: "Challenges", value: "\(totalChallenges)")
                    statPill(title: "Active", value: "\(activeChallenges)")
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
            .shadow(radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var focusStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus").font(.headline)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: screenTime.focusState.isActive ? "lock.circle.fill" : "lock.circle")
                    .font(.system(size: 28))
                    .foregroundColor(screenTime.focusState.isActive ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(focusHeadline)
                        .font(.subheadline.bold())

                    Text(focusDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 4, x: 0, y: 2)
    }

    private var challengesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Challenges").font(.headline)

            HStack(spacing: 16) {
                statPill(title: "Total", value: "\(totalChallenges)")
                statPill(title: "Active", value: "\(activeChallenges)")
                statPill(title: "Completed", value: "\(completedChallenges)")
            }

            Text(challengeSummaryLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 4, x: 0, y: 2)
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Achievements").font(.headline)

            VStack(spacing: 6) {
                achievementRow(title: "First challenge", unlocked: totalChallenges >= 1)
                achievementRow(title: "Regular challenger", unlocked: totalChallenges >= 3)
                achievementRow(title: "Challenge finisher", unlocked: completedChallenges >= 1)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 4, x: 0, y: 2)
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick actions").font(.headline)

            NavigationLink {
                BuddyListView(service: buddyService)
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "person.2").font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage buddies")
                        Text("Add or remove friends").font(.footnote).foregroundStyle(.secondary)
                    }

                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 4, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func statPill(title: String, value: String) -> some View {
        VStack {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func achievementRow(title: String, unlocked: Bool) -> some View {
        HStack {
            Image(systemName: unlocked ? "checkmark.circle.fill" : "circle")
                .foregroundColor(unlocked ? .green : .secondary)
            Text(title)
            Spacer()
        }
        .font(.subheadline)
    }

    private var totalChallenges: Int { challengesService.challenges.count }

    private var activeChallenges: Int {
        let now = Date()
        return challengesService.challenges.filter { $0.startDate <= now && $0.endDate >= now }.count
    }

    private var completedChallenges: Int {
        let now = Date()
        return challengesService.challenges.filter { $0.endDate < now }.count
    }

    private var challengeSummaryLine: String {
        if activeChallenges > 0 {
            return "You’re currently in \(activeChallenges) active challenge\(activeChallenges == 1 ? "" : "s")."
        }
        if completedChallenges > 0 {
            return "You’ve completed \(completedChallenges) challenge\(completedChallenges == 1 ? "" : "s")."
        }
        return "You haven’t joined any challenges yet."
    }

    private var focusHeadline: String {
        if screenTime.focusState.isActive {
            if let s = screenTime.focusState.secondsRemaining {
                return "Focus active — \(max(1, s / 60)) min left"
            }
            return "Focus session active"
        }
        return "Not focusing"
    }

    private var focusDetail: String {
        screenTime.focusState.isActive
        ? "Stay in focus to reduce screen time and compete in challenges."
        : "Start a focus session from the Home tab."
    }
}

#Preview {
    let screenTime = ScreenTimeManager()
    let challenges = ChallengeService()
    let buddies = LocalBuddyService()
    buddies.addBuddy(name: "Preview Buddy")

    return NavigationStack {
        ProfileView(challengesService: challenges, buddyService: buddies)
    }
    .environmentObject(screenTime)
}
