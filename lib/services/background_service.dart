import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_service.dart';
import 'package_service.dart';

/// BackgroundService
///
/// Foreground service Android persistant.
/// Orchestre le MonitoringService (collecte + enforcement).
///
/// Canal d'événements :
///   'triggerBlock' → reçu depuis EnforcementService (via MonitoringService)
///                 → transmis à l'isolate principal Flutter
///                 → déclenche l'écran de blocage via BlockEventService
@pragma('vm:entry-point')
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> initialize() async {
    // Initialiser l'écoute des événements natifs de blocage
    BlockEventService.init();

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: [
          AndroidForegroundType.location,
          AndroidForegroundType.dataSync,
        ],
        notificationChannelId: 'guardian_foreground',
        initialNotificationTitle: 'The Guardian',
        initialNotificationContent: 'Surveillance active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Écouter les signaux de blocage émis par l'isolate background
    // et les relayer à l'isolate principal (UI) via BlockEventService
    service.on('triggerBlock').listen((data) {
      if (data != null && data.containsKey('reason')) {
        final reason = data['reason'] as String;
        // Stocker dans BlockEventService pour que l'UI puisse l'écouter
        BlockEventService._pendingReason = reason;
        BlockEventService._controller.add(reason);

        // NOUVEAU : Forcer l'app au premier plan pour afficher l'écran de blocage
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('bringToForeground');
      }
    });

    service.on('updateNativeBlockedPackages').listen((data) {
      if (data != null && data.containsKey('packages')) {
        final packages = List<String>.from(data['packages'] as List);
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('updateBlockedPackages', packages);
      }
    });

    service.on('updateNativeCustomKeywords').listen((data) {
      if (data != null && data.containsKey('keywords')) {
        final keywords = List<String>.from(data['keywords'] as List);
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('updateCustomKeywords', keywords);
      }
    });

    service.on('updateNativeVpnState').listen((data) {
      if (data != null && data.containsKey('start')) {
        final start = data['start'] as bool;
        if (start) {
          const MethodChannel('app.theguardian.child/system').invokeMethod('startVpn');
        } else {
          const MethodChannel('app.theguardian.child/system').invokeMethod('stopVpn');
        }
      }
    });

    service.on('scheduleWatchdog').listen((_) {
      const MethodChannel('app.theguardian.child/system')
          .invokeMethod('scheduleWatchdog');
    });

    service.on('triggerAppSync').listen((_) {
      debugPrint('BackgroundService: [UI] triggerAppSync event received. Running syncInstalledApps...');
      PackageService().syncInstalledApps();
    });
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('BackgroundService: [ISOLATE] onStart entry point.');
    
    int initRetries = 0;
    bool firebaseInitialized = false;

    while (!firebaseInitialized && initRetries < 5) {
      try {
        await Firebase.initializeApp();
        // BUG #5 FIX: Do NOT call signInAnonymously() here. It overwrites the device UID.
        // Firebase Auth automatically restores the previous currentUser state from secure cache.
        firebaseInitialized = true;
        debugPrint('BackgroundService: Firebase Initialized (attempt ${initRetries + 1}).');
      } catch (e) {
        initRetries++;
        debugPrint('BackgroundService: Firebase Init Error (attempt $initRetries): $e');
        await Future.delayed(Duration(seconds: initRetries * 2));
      }
    }

    if (!firebaseInitialized) {
      debugPrint('BackgroundService: CRITICAL - Failed to initialize Firebase after $initRetries attempts.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    try {
      DartPluginRegistrant.ensureInitialized();
    } catch (_) {}

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((_) => service.setAsForegroundService());
      service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
    }

    service.on('stopService').listen((_) async {
      await MonitoringService().stopMonitoring();
      service.stopSelf();
    });

    // L'app UI nous prévient quand le jumelage est fini
    service.on('onActivated').listen((_) async {
      debugPrint('BackgroundService: Recu signal onActivated.');
      
      // IMPORTANT : Recharger les préférences pour voir le nouveau child_path
      final p = await SharedPreferences.getInstance();
      await p.reload();

      try {
        debugPrint('BackgroundService: Starting monitoring after activation...');
        await MonitoringService().startMonitoring(service);
        // Force le passage en ONLINE immédiatement
        await MonitoringService().forceGoOnline();
        // Force la synchro des apps et stats
        await MonitoringService().forceSyncNow();

        // NOUVEAU : Demander à l'isolate principal de planifier le watchdog natif
        service.invoke('scheduleWatchdog');
      } catch (e) {
        debugPrint('BackgroundService: Initial monitoring failed: $e');
      }
    });

    // Écouter les événements redirigés depuis MainActivity.kt
    service.on('web_event').listen((data) {
      if (data != null) {
        MonitoringService().enforcement.handleNativeWebEvent(data);
      }
    });

    service.on('keyword_event').listen((data) {
      if (data != null) {
        MonitoringService().enforcement.handleNativeKeywordEvent(data);
      }
    });

    try {
      await MonitoringService().startMonitoring(service);
      debugPrint('BackgroundService: MonitoringService started.');

      // NOUVEAU : Demander à l'isolate principal de planifier le watchdog
      service.invoke('scheduleWatchdog');
    } catch (e) {
      debugPrint('BackgroundService: MonitoringService failed: $e');
    }

    // Heartbeat de la notification de foreground
    Timer.periodic(const Duration(seconds: 60), (_) async {
      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'The Guardian',
          content: 'Surveillance active',
        );
      }
    });
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  /// Tente de démarrer le service uniquement si les permissions sont présentes.
  /// Appelé depuis AppState une fois que l'utilisateur a tout validé.
  Future<void> startIfPermissionsGranted() async {
    // Note : On n'instancie FlutterBackgroundService que dans l'isolate principal (UI)
    final service = FlutterBackgroundService();
    if (await service.isRunning()) return;

    // Sur Android 14+, le type 'location' impose d'avoir les permissions AVANT le start
    // Note: on vérifie la localisation car c'est elle qui cause le crash FGS 'location'
    final status = await Permission.location.status;
    if (status.isGranted) {
      debugPrint('BackgroundService: Permissions granted, starting service...');
      await service.startService();
    } else {
      debugPrint('BackgroundService: Location permission missing, cannot start service yet.');
    }
  }
}

/// BlockEventService
///
/// Pont entre l'isolate background (BackgroundService) et l'isolate principal (UI).
/// Le DashboardScreen écoute [stream] et navigue vers BlockingScreen à chaque événement.
class BlockEventService {
  static final _controller = StreamController<String>.broadcast();
  static String? _pendingReason;
  static bool _isInitialized = false;

  /// Initialise l'écoute des événements natifs Android.
  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    const EventChannel('app.theguardian.child/block_events')
        .receiveBroadcastStream()
        .listen((event) {
      if (event is Map) {
        final reason = event['reason'] as String? ?? 'Accès restreint';
        _pendingReason = reason;
        _controller.add(reason);

        // Si l'alerte vient du natif, on force aussi le passage au premier plan
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('bringToForeground');
      }
    });
  }

  /// Stream des raisons de blocage — écouter depuis le widget principal.
  static Stream<String> get stream => _controller.stream;

  /// Consomme et retourne la dernière raison en attente (si présente).
  static String? consumePending() {
    final r = _pendingReason;
    _pendingReason = null;
    return r;
  }
}
