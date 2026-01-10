import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      FirebaseApp.configure()
      if FirebaseApp.app() != nil {
              print("Firebase initialized successfully")
          } else {
              print("Firebase initialization failed")
          }
      
    return true
  }
}

@main
struct BuddyLockApp: App {
    @StateObject private var screenTime = ScreenTimeManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var auth = AuthViewModel()
   
    var body: some Scene {
        WindowGroup {
            RootView()
                    .environmentObject(screenTime)
                    .environmentObject(auth)
        }
    }
}
