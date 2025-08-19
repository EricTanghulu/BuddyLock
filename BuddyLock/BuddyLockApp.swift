
import SwiftUI

@main
struct BuddyLockStarterApp: App {
    @StateObject private var screenTime = ScreenTimeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(screenTime)
        }
    }
}
