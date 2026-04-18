import SwiftUI
import FirebaseCore
import UserNotifications

enum BuddyLockNotificationRoute {
    static let appGroup = "group.com.example.BuddyLock"
    static let unlockRequested = "BuddyLock_Shield_UnlockRequested"
    static let unlockRequestedAt = "BuddyLock_Shield_UnlockRequestedAt"
    static let notificationIdentifier = "BuddyLock_Shield_UnlockRequested_Notification"
    static let destinationKey = "buddylockDestination"
    static let shieldUnlockDestination = "shieldUnlock"
}

extension Notification.Name {
    static let buddyLockShieldUnlockRequested = Notification.Name("BuddyLockShieldUnlockRequested")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      FirebaseApp.configure()

      let notificationCenter = UNUserNotificationCenter.current()
      notificationCenter.delegate = self

      notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          if let error {
              print("Notification authorization failed: \(error)")
          }
      }
      
    return true
  }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard isShieldUnlockNotification(response.notification.request) else { return }
        markPendingShieldUnlockRequest()
        center.removeDeliveredNotifications(withIdentifiers: [BuddyLockNotificationRoute.notificationIdentifier])
    }

    private func isShieldUnlockNotification(_ request: UNNotificationRequest) -> Bool {
        if request.identifier == BuddyLockNotificationRoute.notificationIdentifier {
            return true
        }

        let destination = request.content.userInfo[BuddyLockNotificationRoute.destinationKey] as? String
        return destination == BuddyLockNotificationRoute.shieldUnlockDestination
    }

    private func markPendingShieldUnlockRequest() {
        guard let defaults = UserDefaults(suiteName: BuddyLockNotificationRoute.appGroup) else { return }

        defaults.set(true, forKey: BuddyLockNotificationRoute.unlockRequested)
        defaults.set(Date().timeIntervalSince1970, forKey: BuddyLockNotificationRoute.unlockRequestedAt)

        NotificationCenter.default.post(name: .buddyLockShieldUnlockRequested, object: nil)
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
