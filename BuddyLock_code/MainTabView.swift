import SwiftUI
import FirebaseAuth

#if canImport(FamilyControls)
import FamilyControls
#endif

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
    @State private var showingOnboarding = false
    @State private var showingAskBuddyFromHome = false

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
                        requestService: requestService,
                        challengesService: challengesService,
                        onOpenBuddies: {
                            selectedTab = 3
                        },
                        onAskForUnlock: {
                            showingAskBuddyFromHome = true
                        },
                        onOpenChallenges: {
                            selectedTab = 1
                        },
                        onCreateChallenge: {
                            presentCreateDestination(.challenge)
                        }
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

                // 4) BUDDIES TAB
                NavigationStack {
                    BuddiesHubView(
                        buddyService: buddyService,
                        friendRequestService: friendRequestService,
                        requestService: requestService
                    )
                }
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Buddies")
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
                        presentCreateDestination(destination)
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
        .sheet(isPresented: $showingAskBuddyFromHome) {
            NavigationStack {
                AskBuddyView(
                    buddyService: buddyService,
                    requestService: requestService
                )
                .environmentObject(screenTime)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    !showingOnboarding &&
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
            refreshOnboardingPresentation()
            consumePendingShieldUnlockRequest()
            consumeApprovedOutgoingRequests()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await screenTime.refreshAuthorizationState()
                }
                refreshOnboardingPresentation()
                consumePendingShieldUnlockRequest()
                consumeApprovedOutgoingRequests()
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView(
                buddyCount: buddyService.buddies.count,
                hasBlockedSelection: !screenTime.selectionSummary.isEmpty,
                onFinish: { destination in
                    markOnboardingComplete()
                    showingOnboarding = false
                    if let destination {
                        selectedTab = destination
                    }
                }
            )
            .environmentObject(screenTime)
        }
        .onReceive(requestService.$outgoing) { _ in
            consumeApprovedOutgoingRequests()
        }
        .onReceive(NotificationCenter.default.publisher(for: .buddyLockShieldUnlockRequested)) { _ in
            consumePendingShieldUnlockRequest()
        }
        .onReceive(buddyService.$buddies) { _ in
            refreshOnboardingPresentation()
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

    private func presentCreateDestination(_ destination: CreateDestination) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            showCreateMenu = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            activeCreateDestination = destination
        }
    }

    private func refreshOnboardingPresentation() {
        showingOnboarding = shouldPresentOnboarding
    }

    private var shouldPresentOnboarding: Bool {
        guard Auth.auth().currentUser != nil else { return false }
        return !isOnboardingComplete
    }

    private var isOnboardingComplete: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompletionKey)
    }

    private var onboardingCompletionKey: String {
        "BuddyLock.onboardingCompleted.\(Auth.auth().currentUser?.uid ?? "anonymous")"
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: onboardingCompletionKey)
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

private enum OnboardingFinishDestination {
    case home
    case buddies

    var tabIndex: Int {
        switch self {
        case .home:
            return 0
        case .buddies:
            return 3
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case profile
    case screenTime
    case buddies

    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .profile:
            return "Your Name"
        case .screenTime:
            return "Screen Time"
        case .buddies:
            return "Your Buddies"
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager

    @AppStorage("BuddyLock.displayName")
    private var storedDisplayName: String = ""

    let buddyCount: Int
    let hasBlockedSelection: Bool
    let onFinish: (Int?) -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var draftDisplayName: String = ""
    @State private var isSavingDisplayName = false
    @State private var showingBlockedAppsPicker = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader
                content
                Spacer()
                footerActions
            }
            .padding(24)
            .navigationBarBackButtonHidden(true)
            .sheet(isPresented: $showingBlockedAppsPicker) {
                #if canImport(FamilyControls)
                NavigationStack {
                    FamilyActivityPicker(selection: $screenTime.selection)
                        .navigationTitle("Choose blocked apps")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingBlockedAppsPicker = false
                                }
                            }
                        }
                }
                #else
                Text("Screen Time selection isn’t available on this device.")
                    .padding()
                #endif
            }
            .onAppear {
                draftDisplayName = storedDisplayName
            }
        }
        .interactiveDismissDisabled()
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Let’s get BuddyLock ready")
                .font(.largeTitle.bold())

            Text(step.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { current in
                    Capsule()
                        .fill(current.rawValue <= step.rawValue ? Color.accentColor : Color(.systemGray5))
                        .frame(height: 8)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .profile:
            profileStep
        case .screenTime:
            screenTimeStep
        case .buddies:
            buddiesStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingCard(
                title: "A calmer setup, fast",
                detail: "BuddyLock works best when three things are in place: your name, Screen Time access, and at least one next step toward accountability."
            )

            onboardingBullet(
                title: "Protect your attention",
                detail: "Turn on Screen Time so BuddyLock can actually block distractions."
            )
            onboardingBullet(
                title: "Make it social",
                detail: "Buddies and challenges work better when the app knows who you are."
            )
            onboardingBullet(
                title: "Start small",
                detail: "You do not need to set up every feature right now. One solid first step is enough."
            )
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingCard(
                title: "What should people call you?",
                detail: "This is what your buddies and challenge leaderboards will show."
            )

            TextField("Display name", text: $draftDisplayName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)

            Text("You can change this later in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var screenTimeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingCard(
                title: screenTime.isAuthorized ? "Screen Time is ready" : "Turn on Screen Time",
                detail: screenTime.isAuthorized
                    ? "Nice. BuddyLock can now block distractions and make unlock approvals actually matter."
                    : "This is the permission that lets BuddyLock do the real work."
            )

            if screenTime.isAuthorized {
                VStack(alignment: .leading, spacing: 12) {
                    Text(hasBlockedSelection ? screenTime.selectionSummary : "No blocked apps picked yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        showingBlockedAppsPicker = true
                    } label: {
                        Label(hasBlockedSelection ? "Edit blocked apps" : "Choose blocked apps", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    Task {
                        await screenTime.requestAuthorization()
                    }
                } label: {
                    Label("Turn on Screen Time", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var buddiesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            onboardingCard(
                title: buddyCount > 0 ? "You already have buddies in your corner" : "Next step: add a buddy",
                detail: buddyCount > 0
                    ? "You’re set up enough to start exploring. If you want, jump straight to Buddies and keep building your support system."
                    : "You don’t need to do this right now, but adding one real person makes BuddyLock feel much more useful."
            )

            onboardingBullet(
                title: "Buddies tab",
                detail: "Send a buddy request when you’re ready to add accountability."
            )
            onboardingBullet(
                title: "Home tab",
                detail: "If you’d rather start solo, pick blocked apps and run your first focus session."
            )
        }
    }

    private var footerActions: some View {
        VStack(spacing: 10) {
            switch step {
            case .welcome:
                primaryButton("Get Started") {
                    step = .profile
                }

            case .profile:
                primaryButton(isSavingDisplayName ? "Saving..." : "Continue") {
                    saveDisplayNameAndContinue()
                }
                .disabled(isSavingDisplayName || normalizedDisplayName.isEmpty)

                secondaryButton("Back") {
                    step = .welcome
                }

            case .screenTime:
                primaryButton("Continue") {
                    step = .buddies
                }
                .disabled(!screenTime.isAuthorized)

                secondaryButton("Back") {
                    step = .profile
                }

            case .buddies:
                primaryButton(buddyCount > 0 ? "Finish" : "Go to Buddies") {
                    onFinish(buddyCount > 0 ? OnboardingFinishDestination.home.tabIndex : OnboardingFinishDestination.buddies.tabIndex)
                }

                if buddyCount > 0 {
                    secondaryButton("Go to Buddies instead") {
                        onFinish(OnboardingFinishDestination.buddies.tabIndex)
                    }
                } else {
                    secondaryButton("Finish on Home instead") {
                        onFinish(OnboardingFinishDestination.home.tabIndex)
                    }
                }
            }
        }
    }

    private func onboardingCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func onboardingBullet(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private var normalizedDisplayName: String {
        draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveDisplayNameAndContinue() {
        let resolvedName = normalizedDisplayName
        guard !resolvedName.isEmpty else { return }

        isSavingDisplayName = true
        storedDisplayName = resolvedName

        Task {
            try? await UserProfileStore.updateCurrentUserDisplayName(resolvedName)
            await MainActor.run {
                isSavingDisplayName = false
                step = .screenTime
            }
        }
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
