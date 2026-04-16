import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 1. Initialise Firebase before anything else.
    FirebaseApp.configure()

    // 2. Register Flutter plugins.
    GeneratedPluginRegistrant.register(with: self)

    // 3. Request notification authorisation and register for remote notifications.
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )
    application.registerForRemoteNotifications()

    // 4. Set FCM delegate so the SDK can vend the FCM token.
    Messaging.messaging().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── APNs token → FCM ────────────────────────────────────────────────────────
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
  }
}

// ── FCM token refresh ─────────────────────────────────────────────────────────
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📲 FCM Token (iOS): \(fcmToken ?? "nil")")
    // The Flutter side (NotificationService) will also receive this via
    // FirebaseMessaging.instance.onTokenRefresh – no extra work needed here.
  }
}

// ── Show notifications while the app is in the foreground ────────────────────
extension AppDelegate: UNUserNotificationCenterDelegate {
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner + play sound even while the app is open.
    completionHandler([.banner, .badge, .sound])
  }
}
