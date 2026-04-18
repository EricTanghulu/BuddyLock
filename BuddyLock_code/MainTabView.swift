import SwiftUI

// What we can create from the pop-up
enum CreateDestination: Identifiable {
    case challenge
    case moment   // combined Post + Story

    var id: String {
        switch self {
        case .challenge: return "challenge"
        case .moment:    return "moment"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var buddyService: LocalBuddyService
    @StateObject private var friendRequestService: FriendRequestService
    @StateObject private var requestService = UnlockRequestService()
    @StateObject private var challengesService = ChallengeService()

    
    // For handling the middle "+" behavior
    @State private var selectedTab: Int = 0
    @State private var lastNonCreateTab: Int = 0

    // Our custom pop-up existence
    @State private var showCreateMenu: Bool = false

    // The currently active full-screen destination (New Challenge / New Moment)
    @State private var activeCreateDestination: CreateDestination?
    @State private var showingShieldPrompt = false

    init() {
        let buddyService = LocalBuddyService()
        _buddyService = StateObject(wrappedValue: buddyService)
        _friendRequestService = StateObject(wrappedValue: FriendRequestService(buddyService: buddyService))
    }
    
    var body: some View {
        ZStack {
            // ---------- MAIN TABS ----------
            TabView(selection: $selectedTab) {

                // 1) HOME TAB
                NavigationStack {
                    HomeView(
                        buddyService: buddyService,
                        friendRequestService: friendRequestService,
                        requestService: requestService
                    )
                }
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

                // 2) CHALLENGES TAB
                NavigationStack {
                    ChallengeListView(
                        challenges: challengesService,
                        buddies: buddyService
                    )
                }
                .tabItem {
                    Image(systemName: "flag.checkered")
                    Text("Challenges")
                }
                .tag(1)

                // 3) CREATE (+) TAB
                Text("") // Placeholder; selection is intercepted
                    .tabItem {
                        Image(systemName: "plus.app.fill")
                        Text("Create")
                    }
                    .tag(2)

                // 4) FRIENDS TAB (moved from #2 → now #4)
                NavigationStack {
                    FriendsHubView(
                        buddyService: buddyService,
                        friendRequestService: friendRequestService,
                        requestService: requestService
                    )
                }
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }
                .tag(3)

                // 5) PROFILE TAB
                NavigationStack {
                    ProfileView(
                        challengesService: challengesService,
                        buddyService: buddyService
                    )
                }
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("Profile")
                }
                .tag(4)
            }
            .onChange(of: selectedTab) { _, newValue in
                if newValue == 2 {
                    // User tapped the plus tab → show our custom pop-up
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        showCreateMenu = true
                    }
                    // Snap back to the last real tab so UI doesn't "stay" on the plus tab
                    selectedTab = lastNonCreateTab
                } else {
                    lastNonCreateTab = newValue
                }
            }

            // ---------- CREATE POP-UP OVERLAY ----------
            if showCreateMenu {
                CreateTabView(
                    challenges: challengesService,
                    buddies: buddyService,
                    onSelect: { destination in
                        // Just present the sheet ON TOP of the still-open popup
                        activeCreateDestination = destination
                    },
                    onClose: {
                        // Fully close the popup (with its own animation)
                        showCreateMenu = false
                    }
                )
                .environmentObject(screenTime)
                .zIndex(1)
            }
        }
        // ---------- FULL-SCREEN DESTINATIONS ----------
        .sheet(item: $activeCreateDestination) { destination in
            NavigationStack {
                switch destination {
                case .challenge:
                    ChallengeCreateContainer(
                        challenges: challengesService,
                        buddies: buddyService
                    )

                case .moment:
                    CreateMomentView()
                }
            }
        }
        .sheet(isPresented: $showingShieldPrompt) {
            NavigationStack {
                ShieldPromptView(
                    buddyService: buddyService,
                    requestService: requestService,
                    challengesService: challengesService
                )
                .environmentObject(screenTime)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    screenTime.hasResolvedAuthorizationStatus &&
                    !screenTime.isAuthorized
                },
                set: { _ in }
            )
        ) {
            ScreenTimeRequiredView()
                .environmentObject(screenTime)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    screenTime.isAuthorized &&
                    screenTime.focusState.isActive &&
                    screenTime.exceptionEndsAt == nil
                },
                set: { _ in }
            )
        ) {
            FocusSessionLockedView()
                .environmentObject(screenTime)
        }
        .onAppear {
            Task {
                await screenTime.refreshAuthorizationState()
            }
            consumePendingShieldUnlockRequest()
            consumeApprovedOutgoingRequests()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await screenTime.refreshAuthorizationState()
                }
                consumePendingShieldUnlockRequest()
                consumeApprovedOutgoingRequests()
            }
        }
        .onReceive(requestService.$outgoing) { _ in
            consumeApprovedOutgoingRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: .buddyLockShieldUnlockRequested)) { _ in
            consumePendingShieldUnlockRequest()
        }
    }

    private func consumePendingShieldUnlockRequest() {
        let appGroup = "group.com.example.BuddyLock"
        let unlockRequestedKey = "BuddyLock_Shield_UnlockRequested"
        let unlockRequestedAtKey = "BuddyLock_Shield_UnlockRequestedAt"

        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        guard defaults.bool(forKey: unlockRequestedKey) else { return }

        defaults.removeObject(forKey: unlockRequestedKey)
        defaults.removeObject(forKey: unlockRequestedAtKey)

        if !showingShieldPrompt {
            showingShieldPrompt = true
        }
    }

    private func consumeApprovedOutgoingRequests() {
        while let approvedRequest = requestService.consumeApprovedOutgoingRequest() {
            let minutes = approvedRequest.approvedMinutes ?? approvedRequest.minutesRequested
            screenTime.grantTemporaryException(minutes: minutes)
        }
    }
}

// Wrapper that adds a back button which dismisses the sheet
// (and therefore reveals the popup already sitting underneath)
private struct ChallengeCreateContainer: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    var body: some View {
        ChallengeCreateView(
            challenges: challenges,
            buddies: buddies
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("Create")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScreenTimeRequiredView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var isRequestingAuthorization = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "hand.raised.app.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("Turn on Screen Time")
                        .font(.largeTitle.bold())

                    Text("BuddyLock needs Screen Time access before it can block distracting apps, start focus sessions, or make buddy unlocks work the right way.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    requirementRow(
                        title: "Block apps when you focus",
                        detail: "Your sessions only work if BuddyLock can actually shield the apps you picked."
                    )

                    requirementRow(
                        title: "Use panic block and longer locks",
                        detail: "Quick blocks and longer lock-ins both depend on the same permission."
                    )

                    requirementRow(
                        title: "Make buddy unlocks mean something",
                        detail: "Unlock approvals only matter if Screen Time is active first."
                    )
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        requestAuthorization()
                    } label: {
                        HStack {
                            if isRequestingAuthorization {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "hand.raised.fill")
                            }

                            Text(isRequestingAuthorization ? "Checking access..." : "Turn on Screen Time")
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingAuthorization)

                    Text("You’ll come right back into BuddyLock as soon as access is enabled.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)
            .navigationBarBackButtonHidden(true)
        }
        .interactiveDismissDisabled()
    }

    private func requestAuthorization() {
        guard !isRequestingAuthorization else { return }

        isRequestingAuthorization = true
        Task {
            await screenTime.requestAuthorization()
            await MainActor.run {
                isRequestingAuthorization = false
            }
        }
    }

    private func requirementRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FocusSessionLockedView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @AppStorage("BuddyLock.loseFocusMinutes")
    private var loseFocusMinutes: Int = 5
    @State private var showingLoseFocusConfirmation = false
    @State private var showingEndFocusConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    Text(screenTime.focusState.phase == .warmUp ? "Get ready" : "Focus mode")
                        .font(.largeTitle.bold())

                    Text(timerText)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                }

                VStack(spacing: 12) {
                    Button {
                        showingLoseFocusConfirmation = true
                    } label: {
                        Text("Lose focus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showingEndFocusConfirmation = true
                    } label: {
                        Text("End focus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .navigationBarBackButtonHidden(true)
        }
        .interactiveDismissDisabled()
        .alert("Lose focus?", isPresented: $showingLoseFocusConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Lose focus") {
                screenTime.pauseFocusSession(for: loseFocusMinutes)
            }
        } message: {
            Text("This pauses your timer and unblocks your selected apps for \(loseFocusMinutes) minute\(loseFocusMinutes == 1 ? "" : "s").")
        }
        .alert("End focus?", isPresented: $showingEndFocusConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End focus", role: .destructive) {
                Task {
                    await screenTime.endFocusSession(completed: false)
                }
            }
        } message: {
            Text("This ends the focus session right now.")
        }
    }

    private var timerText: String {
        let seconds = screenTime.focusState.secondsRemaining ?? 0
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }
}

#Preview {
    MainTabView()
        .environmentObject(ScreenTimeManager())
}
