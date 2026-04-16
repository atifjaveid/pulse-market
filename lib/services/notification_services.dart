// lib/services/notification_services.dart

// Handles all three FCM message states:
//   • Foreground  – app is open
//   • Background  – app is open but not in focus (tap resumes it)
//   • Terminated  – app was fully closed (tap cold-starts it)

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Top-level background handler (must be a top-level function) ───────────────
// Called by FCM when the app is in the background / terminated.
// Keep this lightweight – it runs in a separate isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // For data-only messages the system won't show a heads-up notification
  // automatically, so we show one via flutter_local_notifications.
  final localNotifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    ),
  );
  _showLocalNotification(message, localNotifications);
}

// ── Shared plugin instance used in the foreground ─────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Android notification channel for price / FCM alerts ───────────────────────
const AndroidNotificationChannel _priceAlertChannel = AndroidNotificationChannel(
  'price_alerts',
  'Price Alerts',
  description: 'Notifications for price targets and market alerts.',
  importance: Importance.high,
);

// ── Navigation key – set this on your MaterialApp so the service can push
//    routes without a BuildContext. ─────────────────────────────────────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ── Initialize ──────────────────────────────────────────────────────────────
  static Future<void> initialize() async {
    // 1. Request permission (iOS shows a system dialog; Android 13+ too).
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('📋 FCM permission: \${settings.authorizationStatus}');

    // 2. Register the background handler (must be called before any other
    //    onMessage listeners).
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Set up flutter_local_notifications so we can show heads-up banners
    //    while the app is in the foreground.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      // Called when the user taps a local notification while the app is open.
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // 4. Create the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_priceAlertChannel);

    // 5. On iOS, tell FCM to deliver foreground notifications as banners too.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. Listen for messages while the app is in the foreground.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // 7. Listen for notification taps when the app is in the background
    //    (but still running – e.g. minimised).
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // 8. Check whether the app was opened from a terminated state via a
    //    notification tap.
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App opened from terminated state');
      // Delay navigation slightly so the widget tree is ready.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationNavigation(initialMessage),
      );
    }

    // 9. Log and store the device token; refresh when it rotates.
    final token = await _fcm.getToken();
    _onNewToken(token);
    _fcm.onTokenRefresh.listen(_onNewToken);
  }

  // ── Public helpers ──────────────────────────────────────────────────────────

  /// Returns the current FCM registration token.
  static Future<String?> getToken() => _fcm.getToken();

  /// Subscribe to a topic (e.g. 'market_updates').
  static Future<void> subscribeToTopic(String topic) =>
      _fcm.subscribeToTopic(topic);

  /// Unsubscribe from a topic.
  static Future<void> unsubscribeFromTopic(String topic) =>
      _fcm.unsubscribeFromTopic(topic);

  // ── Private handlers ────────────────────────────────────────────────────────

  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground FCM: \${message.notification?.title}');
    // FCM does NOT show a heads-up banner automatically when the app is open,
    // so we display one via flutter_local_notifications.
    _showLocalNotification(message, _localNotifications);
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('👆 Notification tapped (background): \${message.messageId}');
    _handleNotificationNavigation(message);
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: \${response.payload}');
    // payload is the screen hint we stored when showing the notification.
    final screen = response.payload;
    if (screen == null) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    navigator.pushNamed('/$screen');
  }

  static void _onNewToken(String? token) {
    if (token == null) return;
    debugPrint('📲 FCM Token: \$token');
    // TODO: send `token` to your backend so it can address push messages
    // to this device.  Example:
    //   await MyBackendApi.registerDeviceToken(token);
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  /// Routes the user to the correct screen based on the `data` payload.
  ///
  /// Expected payload shape (sent from your backend / Firebase console):
  /// {
  ///   "screen": "alerts" | "markets" | "home",
  ///   "symbol": "BTC"     // optional – reserved for future deep-linking
  /// }
  static void _handleNotificationNavigation(RemoteMessage message) {
    final screen = message.data['screen'] as String?;
    final navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;

    switch (screen) {
      case 'alerts':
        navigator.pushNamed('/alerts');
        break;
      case 'markets':
        navigator.pushNamed('/markets');
        break;
      case 'home':
      default:
        break;
    }
  }
}

// ── Helper: show a local heads-up notification ─────────────────────────────────
void _showLocalNotification(
  RemoteMessage message,
  FlutterLocalNotificationsPlugin plugin,
) {
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] ?? 'Pulse Market';
  final body = notification?.body ?? message.data['body'] ?? '';

  // If there's no notification object and no title/body in data, don't show anything.
  if (notification == null && message.data['title'] == null && message.data['body'] == null) {
    return;
  }

  plugin.show(
    (notification?.hashCode ?? message.hashCode) & 0x7FFFFFFF,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _priceAlertChannel.id,
        _priceAlertChannel.name,
        channelDescription: _priceAlertChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        // icon: '@mipmap/ic_launcher' is invalid here and causes an exception.
        // It automatically uses the default icon from InitializationSettings.
        tag: message.messageId,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data['screen'],
  );
}
