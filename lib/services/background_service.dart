import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_service.dart';
import 'package_service.dart';
import 'firestore_sync_queue.dart';

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
        final package = data['package'] as String? ?? '';
        final details = BlockDetails(package: package, reason: reason);
        // Stocker dans BlockEventService pour que l'UI puisse l'écouter
        BlockEventService._pendingBlock = details;
        BlockEventService._controller.add(details);

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

    service.on('updateNativeBlockedWebsites').listen((data) {
      if (data != null && data.containsKey('websites')) {
        final websites = List<String>.from(data['websites'] as List);
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('updateBlockedWebsites', websites);
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

    // Re-register every plugin in this background isolate so that
    // shared_preferences / firebase / etc. work here. The
    // flutter_background_service_android plugin intentionally throws from its
    // registerWith() when called outside the main isolate. Flutter's generated
    // registrant catches that and prints a misleading "may not function as
    // expected" warning via print(). We only use [ServiceInstance] in this
    // isolate, so the warning is harmless — swallow just that line while
    // forwarding everything else.
    try {
      runZoned(
        () => DartPluginRegistrant.ensureInitialized(),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            if (line.contains('flutter_background_service_android') &&
                line.contains('threw an error')) {
              return;
            }
            parent.print(zone, line);
          },
        ),
      );
    } catch (_) {}

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((_) => service.setAsForegroundService());
      service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
    }

    service.on('stopService').listen((_) async {
      try {
        await MonitoringService().stopMonitoring();
      } finally {
        service.stopSelf();
      }
    });

    // L'app UI nous prévient quand le jumelage est fini
    service.on('onActivated').listen((_) async {
      debugPrint('BackgroundService: Recu signal onActivated.');
      
      // IMPORTANT : Recharger les préférences pour voir le nouveau child_path
      final p = await SharedPreferences.getInstance();
      await p.reload();

      try {
        debugPrint('BackgroundService: Stopping existing monitoring if running...');
        await MonitoringService().stopMonitoring();
        
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

    service.on('foreground_event').listen((data) {
      if (data != null) {
        MonitoringService().enforcement.handleNativeForegroundEvent(data);
      }
    });

    try {
      await FirestoreSyncQueue().initialize();
      await MonitoringService().startMonitoring(service);
      debugPrint('BackgroundService: MonitoringService started.');

      // NOUVEAU : Demander à l'isolate principal de planifier le watchdog
      service.invoke('scheduleWatchdog');
    } catch (e) {
      debugPrint('BackgroundService: MonitoringService failed: $e');
    }

    // Heartbeat de la notification de foreground + écriture du heartbeat pour le watchdog
    Timer.periodic(const Duration(seconds: 60), (_) async {
      // FIX BUG #6 : écrire le timestamp pour que GuardianWorker sache que le service est vivant
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'guardian_service_heartbeat',
        DateTime.now().millisecondsSinceEpoch,
      );

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

    // Sur Android 14+, le type 'location' impose d'avoir les permissions AVANT le start.
    // Cependant, nous DEVONS démarrer l'enforcement même sans localisation.
    // L'idéal est de reconfigurer dynamiquement le service, mais pour garantir
    // la sécurité, on démarre le service de toute façon (il plantera si la config
    // location est stricte sur A14, mais FlutterBackgroundService gère ça partiellement).
    final status = await Permission.location.status;
    if (!status.isGranted) {
      debugPrint('BackgroundService: Location permission missing, but starting service anyway for enforcement.');
      // Option: Reconfigurer sans location
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          foregroundServiceTypes: [AndroidForegroundType.dataSync], // Uniquement dataSync
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
    }
    await service.startService();
  }
}

class BlockDetails {
  final String package;
  final String reason;

  BlockDetails({required this.package, required this.reason});
}

/// BlockEventService
///
/// Pont entre l'isolate background (BackgroundService) et l'isolate principal (UI).
/// Le DashboardScreen écoute [stream] et navigue vers BlockingScreen à chaque événement.
class BlockEventService {
  static final _controller = StreamController<BlockDetails>.broadcast();
  static BlockDetails? _pendingBlock;
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
        final package = event['package'] as String? ?? '';
        final details = BlockDetails(package: package, reason: reason);
        _pendingBlock = details;
        _controller.add(details);

        // Si l'alerte vient du natif, on force aussi le passage au premier plan
        const MethodChannel('app.theguardian.child/system')
            .invokeMethod('bringToForeground');
      }
    });
  }

  /// Stream des détails de blocage — écouter depuis le widget principal.
  static Stream<BlockDetails> get stream => _controller.stream;

  /// Consomme et retourne la dernière raison en attente (si présente).
  /// Vérifie aussi dans SharedPreferences au cas où l'EventChannel
  /// n'était pas encore prêt quand le blocage est arrivé.
  static Future<BlockDetails?> consumePendingAsync() async {
    if (_pendingBlock != null) {
      final r = _pendingBlock;
      _pendingBlock = null;
      return r;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final reason = prefs.getString('flutter.guardian_pending_block');
      final package = prefs.getString('flutter.guardian_pending_package') ?? '';
      if (reason != null) {
        await prefs.remove('flutter.guardian_pending_block');
        await prefs.remove('flutter.guardian_pending_package');
        return BlockDetails(package: package, reason: reason);
      }
    } catch (_) {}
    return null;
  }

  /// Version synchrone conservée pour compatibilité.
  static BlockDetails? consumePending() {
    final r = _pendingBlock;
    _pendingBlock = null;
    return r;
  }
}
