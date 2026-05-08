import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Créer le canal de notification (CRITIQUE : avant tout le reste)
    await createNotificationChannel();

    // 2. Demander les permissions (iOS + Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('NotificationService: Permissions granted.');

      // 3. Récupérer et sauvegarder le token FCM
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // 4. Rafraîchir le token si Firebase le renouvelle
      _fcm.onTokenRefresh.listen(_saveToken);

      // 5. Gérer les messages reçus en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('NotificationService: Foreground message received.');
        
        final title = message.notification?.title ?? '';
        final body = message.notification?.body ?? '';
        
        // Anti-réflexion : ne pas afficher à l'enfant ses propres alertes SOS
        // ou alertes de restriction générées par lui-même.
        if (title.contains('SOS') || 
            title.contains('Alerte') || 
            body.contains('déclenché une alerte')) {
          debugPrint('NotificationService: Ignoring self-triggered notification.');
          return;
        }

        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });
    } else {
      debugPrint('NotificationService: Permissions denied.');
    }

    debugPrint('NotificationService: Initialized.');
  }

  Future<void> createNotificationChannel() async {
    // Canal pour la notification persistante du foreground service
    const foregroundChannel = AndroidNotificationChannel(
      'guardian_foreground',
      'The Guardian Service',
      description: 'Notification de protection active',
      importance: Importance.low,
    );

    // Canal pour les alertes du parent (priorité haute)
    const alertsChannel = AndroidNotificationChannel(
      'guardian_alerts',
      'Alertes Guardian',
      description: 'Notifications importantes du parent',
      importance: Importance.max,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(foregroundChannel);
    await androidPlugin?.createNotificationChannel(alertsChannel);

    debugPrint('NotificationService: Notification channels created.');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'guardian_alerts',
      'Alertes Guardian',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'The Guardian',
      message.notification?.body,
      platformDetails,
    );
  }

  /// Sauvegarde le token FCM dans le bon chemin Firestore :
  /// parents/{parentId}/children/{childId} (cohérent avec l'activation).
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final childPath = prefs.getString('child_path');

    if (childPath == null) {
      debugPrint('NotificationService: child_path not set, cannot save FCM token.');
      return;
    }

    try {
      await _firestore.doc(childPath).update({
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint('NotificationService: FCM token saved at $childPath');
    } catch (e) {
      debugPrint('NotificationService: Error saving FCM token: $e');
    }
  }
}
