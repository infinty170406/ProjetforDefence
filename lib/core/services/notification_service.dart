import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// NotificationService handles FCM registration, permissions, topic filtering,
/// and foreground/background message display.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── SharedPreferences key → FCM topic name ──────────────────────────────
  static const Map<String, String> _topicKeys = {
    'settings_sos_notif': 'sos_alerts',
    'settings_geofence_notif': 'geofence_alerts',
    'settings_offline_notif': 'offline_alerts',
    'settings_reports_notif': 'weekly_reports',
  };

  // FCM data.category value → SharedPreferences key
  static const Map<String, String> _categoryToKey = {
    'sos': 'settings_sos_notif',
    'geofence': 'settings_geofence_notif',
    'offline': 'settings_offline_notif',
    'report': 'settings_reports_notif',
  };

  // ── Android high-importance channel ─────────────────────────────────────
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important alerts like SOS.',
    importance: Importance.high,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Request permissions (Android 13+ / iOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('PUSH_NOTIF: Permission accordée');
    } else {
      debugPrint('PUSH_NOTIF: Permission refusée ou en attente');
    }

    // 2. Initialize local notifications
    const initAndroid = AndroidInitializationSettings('ic_launcher');
    const initDarwin = DarwinInitializationSettings();
    const initLinux = LinuxInitializationSettings(defaultActionName: 'Open');

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: initAndroid,
        iOS: initDarwin,
        linux: initLinux,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse r) =>
          debugPrint('PUSH_NOTIF: Clicked: ${r.payload}'),
    );

    // 3. Create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. Foreground handler with category-level filtering
    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint('PUSH_NOTIF: Foreground → ${msg.notification?.title}');

      final category = msg.data['category'] as String?;
      if (category != null && !await _isCategoryEnabled(category)) {
        debugPrint('PUSH_NOTIF: Supprimée — catégorie "$category" désactivée.');
        return;
      }

      final notification = msg.notification;
      final android = msg.notification?.android;
      if (notification != null && android != null && !kIsWeb) {
        await _localNotifications.show(
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
          payload: msg.data.toString(),
        );
      }
    });

    // 6. Tap from background
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('PUSH_NOTIF: Notification ouverte depuis l\'arrière-plan!');
    });

    // 7. Token sync + topic sync
    await syncToken();
    await _syncTopicsFromPreferences();

    // 8. Token refresh
    _fcm.onTokenRefresh.listen(FirestoreService().updateFcmToken);

    _initialized = true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM Topic management
  // ─────────────────────────────────────────────────────────────────────────

  /// Lit les SharedPreferences et (dés)abonne les topics FCM en conséquence.
  Future<void> _syncTopicsFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in _topicKeys.entries) {
        final enabled = prefs.getBool(entry.key) ?? true;
        await _setTopicSubscription(entry.value, enabled);
      }
      debugPrint('PUSH_NOTIF: Topics FCM synchronisés.');
    } catch (e) {
      debugPrint('PUSH_NOTIF: Erreur sync topics: $e');
    }
  }

  /// Appelé depuis la page Paramètres quand le parent bascule une notification.
  Future<void> updateNotificationPreference(
      String prefKey, bool enabled) async {
    final topic = _topicKeys[prefKey];
    if (topic == null) return;
    await _setTopicSubscription(topic, enabled);
    debugPrint(
        'PUSH_NOTIF: Topic "$topic" → ${enabled ? "abonné" : "désabonné"}');
  }

  Future<void> _setTopicSubscription(String topic, bool subscribe) async {
    try {
      if (subscribe) {
        await _fcm.subscribeToTopic(topic);
      } else {
        await _fcm.unsubscribeFromTopic(topic);
      }
    } catch (e) {
      debugPrint('PUSH_NOTIF: Erreur topic "$topic": $e');
    }
  }

  /// Vérifie si une catégorie de notification est activée par le parent.
  Future<bool> _isCategoryEnabled(String category) async {
    final key = _categoryToKey[category];
    if (key == null) return true; // Catégorie inconnue → autorisée par défaut
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Token management
  // ─────────────────────────────────────────────────────────────────────────

  /// Synchronise le token FCM de l'appareil avec Firestore.
  Future<void> syncToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      debugPrint('PUSH_NOTIF: Token = $token');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pairing = await StorageService().getChildPairing();

      if (pairing['mode'] == 'child' &&
          pairing['parentId'] != null &&
          pairing['childId'] != null) {
        await FirestoreService().updateChildFcmToken(
          pairing['parentId']!,
          pairing['childId']!,
          token,
        );
      } else if (!user.isAnonymous) {
        await FirestoreService().updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('PUSH_NOTIF: Erreur sync token: $e');
    }
  }
}

/// Handler de fond (doit être une fonction top-level).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PUSH_NOTIF: Message en arrière-plan: ${message.messageId}');
}
