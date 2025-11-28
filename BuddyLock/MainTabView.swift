import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager

    @StateObject private var buddyService = LocalBuddyService()
    @StateObject private var requestService = LocalUnlockRequestService()
    @StateObject private var challengesService = ChallengeService()

    var body: some View {
        TabView {
            // 1) HOME / FOCUS TAB
            NavigationStack {
                HomeView(challengesService: challengesService)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }

            // 2) CHALLENGES
            NavigationStack {
                ChallengeListView(challenges: challengesService, buddies: buddyService)
            }
            .tabItem {
                Image(systemName: "trophy.fill")
                Text("Challenges")
            }

            // 3) CREATE (+)
            CreateTabView(challenges: challengesService, buddies: buddyService)
                .tabItem {
                    Image(systemName: "plus.app.fill")
                    Text("Create")
                }

            // 4) FRIENDS
            NavigationStack {
                FriendsHubView(
                    buddyService: buddyService,
                    requestService: requestService
                )
            }
            .tabItem {
                Image(systemName: "person.2.fill")
                Text("Friends")
            }

            // 5) PROFILE
            NavigationStack {
                ProfileView(buddyService: buddyService)
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(ScreenTimeManager())
}
