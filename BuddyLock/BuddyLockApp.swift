import SwiftUI

@main
struct BuddyLockApp: App {
    @StateObject private var screenTime = ScreenTimeManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()            // 👈 NEW ROOT VIEW
                .environmentObject(screenTime)
        }
    }
}
