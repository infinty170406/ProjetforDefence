import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// NotificationService handles FCM registration, permissions, and message handling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  /// High importance channel for Android (required for banners/heads-up)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important alerts like SOS.', // description
    importance: Importance.high,
  );

  /// Initialize notifications and request permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Request permissions (especially for Android 13+ and iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('PUSH_NOTIF: User granted permission');
    } else {
      debugPrint('PUSH_NOTIF: User declined or has not accepted permission');
    }

    // 2. Initialize local notifications for foreground support
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(defaultActionName: 'Open');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('PUSH_NOTIF: Foreground notification clicked: ${details.payload}');
      },
    );

    // 3. Create the channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Handle background messaging
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Handle foreground messaging
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('PUSH_NOTIF: Received message in foreground: ${message.notification?.title}');
      
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If we're in the foreground, we manually show the notification
      if (notification != null && android != null && !kIsWeb) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: android.smallIcon ?? 'ic_launcher',

              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
      }
    });

    // 6. Handle notification tap when app is in background or closed
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('PUSH_NOTIF: Notification clicked from background!');
      // Navigation logic could go here
    });

    // 7. Initial token sync
    await syncToken();

    // 8. Listen for token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      FirestoreService().updateFcmToken(newToken);
    });

    _initialized = true;
  }

  /// Synchronizes the current device token with Firestore.
  Future<void> syncToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token == null) return;
      
      debugPrint('PUSH_NOTIF: Device Token: $token');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pairing = await StorageService().getChildPairing();
      
      if (pairing['mode'] == 'child' && 
          pairing['parentId'] != null && 
          pairing['childId'] != null) {
        // Child device: sync to children collection
        await FirestoreService().updateChildFcmToken(
          pairing['parentId']!,
          pairing['childId']!,
          token,
        );
      } else if (!user.isAnonymous) {
        // Parent device: sync to parents collection
        await FirestoreService().updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('PUSH_NOTIF: Error syncing token: $e');
    }
  }
}

/// Global handler for background messages (MUST be a top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PUSH_NOTIF: Handling background message: ${message.messageId}');
}

