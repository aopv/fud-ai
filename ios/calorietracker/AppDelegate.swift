import UIKit
import UserNotifications

/// Minimal app delegate, attached via `@UIApplicationDelegateAdaptor`, solely to handle local
/// notifications: present the "Update Available" banner while the app is foreground (the update
/// check runs at launch) and open the App Store when it's tapped.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        QuickActionSettings.registerApplicationShortcuts()
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(QuickActionCoordinator.handle(shortcutItem))
    }

    /// Show the update banner even when the app is in the foreground; leave the scheduled reminders
    /// to their default (no foreground interruption) so this changes nothing for them.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.identifier == NotificationManager.appUpdateNotificationID {
            return [.banner, .sound, .list]
        }
        return []
    }

    /// Open the App Store listing when the update notification is tapped.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["updateURL"] as? String, let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
    }
}
