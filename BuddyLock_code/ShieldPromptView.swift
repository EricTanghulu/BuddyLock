import SwiftUI

struct ShieldPromptView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService
    @ObservedObject var challengesService: ChallengeService

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @State private var showingAskBuddy = false
    @State private var selfUnlockMinutes: Int = 10
    @State private var showingSelfUnlockAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                modeExplanationCard
                actionsCard
                progressSummaryCard
            }
            .padding()
        }
        .navigationTitle("Blocked right now")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAskBuddy) {
            NavigationStack {
                AskBuddyView(
                    buddyService: buddyService,
                    requestService: requestService
                )
                .environmentObject(screenTime)
            }
        }
        .alert("Self-unlock?", isPresented: $showingSelfUnlockAlert) {
            Button("Cancel", role: .cancel) {}

            Button("I accept", role: .destructive) {
                screenTime.grantTemporaryException(minutes: selfUnlockMinutes)
            }
        } message: {
            Text("Your buddies may see that you self-unlocked. Try to keep this for emergencies only.")
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hey \(displayName.isEmpty ? "there" : displayName),")
                .font(.title.bold())

            Text("BuddyLock is blocking distractions right now to protect your goals.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeExplanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current mode")
                .font(.headline)

            HStack(spacing: 8) {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(screenTime.activeMode == .idle ? .gray.opacity(0.4) : .green)

                Text(modeTitle)
                    .font(.subheadline.weight(.semibold))
            }

            Text(modeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need access?")
                .font(.headline)

            Button {
                showingAskBuddy = true
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask a buddy first")
                            .font(.subheadline.weight(.semibold))
                        Text("Send an unlock request so a buddy can approve it.")
                            .font(.caption)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Self-unlock (emergency)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if canSelfUnlock {
                        Text("Available")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("Locked")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text("You’ll only see this as a backup once you’ve built some focus time. Your buddies may see when you use it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(
                    "\(selfUnlockMinutes) minute\(selfUnlockMinutes == 1 ? "" : "s")",
                    value: $selfUnlockMinutes,
                    in: 5...30,
                    step: 5
                )
                .disabled(!canSelfUnlock)

                Button {
                    if canSelfUnlock {
                        showingSelfUnlockAlert = true
                    }
                } label: {
                    Text("I really need access")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canSelfUnlock)
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var progressSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your progress")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(totalFocusMinutes)")
                        .font(.title2.weight(.bold))
                    Text("Total focus minutes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(activeChallengeCount)")
                        .font(.title2.weight(.bold))
                    Text("Active challenges")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(buddyService.buddies.count)")
                        .font(.title2.weight(.bold))
                    Text("Buddies")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Derived values

    private var totalFocusMinutes: Int {
        let id = challengesService.localUserID
        return challengesService.challenges.reduce(0) { sum, challenge in
            sum + (challenge.scores[id] ?? 0)
        }
    }

    private var activeChallengeCount: Int {
        let id = challengesService.localUserID
        let now = Date()
        return challengesService.challenges.filter {
            $0.participantIDs.contains(id) && now >= $0.startDate && now <= $0.endDate
        }.count
    }

    /// Simple gating rule: allow self-unlock only after 60 total focus minutes.
    private var canSelfUnlock: Bool {
        totalFocusMinutes >= 60
    }

    private var modeTitle: String {
        switch screenTime.activeMode {
        case .idle:           return "No active mode"
        case .baseline:       return "Baseline blocking"
        case .focus:          return "Focus session"
        case .panic:          return "Panic block"
        case .essentialsOnly: return "Study Only mode"
        }
    }

    private var modeDescription: String {
        switch screenTime.activeMode {
        case .idle:
            return "Nothing is actively blocking you right now. You can still start a focus session or Study Only mode from the Home tab."
        case .baseline:
            return "Your baseline block is on. Your most distracting apps and sites are blocked by default to protect your attention."
        case .focus:
            return "You’re in a focus session. Stay off distractions until the timer ends to keep your streaks and challenge progress."
        case .panic:
            return "You hit the panic button to protect yourself from temptation for a short burst. Great move to stay on track."
        case .essentialsOnly:
            return "Study Only mode is active, which blocks everything except essential apps. Perfect for exams and deep work."
        }
    }
}

// MARK: - Preview
import FirebaseAuth

#Preview {
    // Mock services for preview
    let screenTime = ScreenTimeManager()
    screenTime.activeMode = .essentialsOnly  // Pretend we're in Study Only mode

    let buddyService = LocalBuddyService()
    buddyService.addBuddy(LocalBuddy(remoteID: "remote1",     // buddy doc ID
                                     buddyUserID: "buddyID"               // friend's auth UID
                                     , displayName: "Buddy"))

    let requestService = UnlockRequestService()

    let challengesService = ChallengeService()
    // If you have APIs to add mock challenges, you could do it here,
    // but even empty this will still render fine.

    return NavigationStack {
        ShieldPromptView(
            buddyService: buddyService,
            requestService: requestService,
            challengesService: challengesService
        )
        .environmentObject(screenTime)
    }
}
