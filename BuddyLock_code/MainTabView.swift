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

    @StateObject private var buddyService: LocalBuddyService
    @StateObject private var friendRequestService: FriendRequestService
    @StateObject private var requestService = LocalUnlockRequestService()
    @StateObject private var challengesService = ChallengeService()

    
    // For handling the middle "+" behavior
    @State private var selectedTab: Int = 0
    @State private var lastNonCreateTab: Int = 0

    // Our custom pop-up existence
    @State private var showCreateMenu: Bool = false

    // The currently active full-screen destination (New Challenge / New Moment)
    @State private var activeCreateDestination: CreateDestination?

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
                        challengesService: challengesService,
                        leaderboardEntries: [],
                        socialPosts: [],
                        stories: []
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
            .onChange(of: selectedTab) { newValue in
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

#Preview {
    MainTabView()
        .environmentObject(ScreenTimeManager())
}
