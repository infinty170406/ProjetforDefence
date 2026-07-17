import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package_service.dart';
import 'device_status_service.dart';
import 'enforcement_service.dart';
import 'location_service.dart';
import '../utils/child_path_helper.dart';
import '../utils/system_app_classifier.dart';

/// Catégories d'applications.
enum AppCategory { socialMedia, gaming, education, browser, messaging, other }

/// MonitoringService
///
/// Coordonne deux responsabilités complémentaires :
///
///   A. COLLECTE  — Statistiques d'usage (UsageStatsManager) → Firestore
///      Fréquence : toutes les 15 minutes + au démarrage.
///
///   B. ENFORCEMENT — via [EnforcementService]
///      Boucle de vérification toutes les 5s :
///        • Blocage des apps individuelles et par catégorie
///        • Limite journalière de temps d'écran
///        • Plages horaires autorisées
///      Chaque règle enfreinte déclenche :
///        • Un événement 'triggerBlock' → BackgroundService → Flutter
///        • Une alerte Firestore (AlertService)
class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceStatusService _deviceStatusService = DeviceStatusService();
  final EnforcementService _enforcementService = EnforcementService();

  Timer? _syncTimer;
  bool _isMonitoring = false;
  DateTime? _lastAppSync;

  // ── Classification ────────────────────────────────────────────────────────

  static const Map<String, AppCategory> _knownPackages = {
    'com.zhiliaoapp.musically': AppCategory.socialMedia,
    'com.tiktok': AppCategory.socialMedia,
    'com.instagram.android': AppCategory.socialMedia,
    'com.snapchat.android': AppCategory.socialMedia,
    'com.twitter.android': AppCategory.socialMedia,
    'com.facebook.katana': AppCategory.socialMedia,
    'com.facebook.lite': AppCategory.socialMedia,
    'com.pinterest': AppCategory.socialMedia,
    'com.reddit.frontpage': AppCategory.socialMedia,
    'com.roblox.client': AppCategory.gaming,
    'com.epicgames.fortnite': AppCategory.gaming,
    'com.mojang.minecraftpe': AppCategory.gaming,
    'com.supercell.clashofclans': AppCategory.gaming,
    'com.supercell.brawlstars': AppCategory.gaming,
    'com.king.candycrushsaga': AppCategory.gaming,
    'com.duolingo': AppCategory.education,
    'com.khanacademy.android': AppCategory.education,
    'com.quizlet.quizletapp': AppCategory.education,
    'com.android.chrome': AppCategory.browser,
    'org.mozilla.firefox': AppCategory.browser,
    'com.opera.browser': AppCategory.browser,
    'com.whatsapp': AppCategory.messaging,
    'com.facebook.orca': AppCategory.messaging,
    'org.telegram.messenger': AppCategory.messaging,
    'com.discord': AppCategory.messaging,
  };

  static AppCategory _classify(String pkg) =>
      _knownPackages[pkg] ?? AppCategory.other;

  static String _catStr(AppCategory c) {
    switch (c) {
      case AppCategory.socialMedia: return 'social_media';
      case AppCategory.gaming:      return 'gaming';
      case AppCategory.education:   return 'education';
      case AppCategory.browser:     return 'browser';
      case AppCategory.messaging:   return 'messaging';
      case AppCategory.other:       return 'other';
    }
  }

  // ── Démarrage / arrêt ─────────────────────────────────────────────────────

  Future<void> startMonitoring(ServiceInstance service) async {
    if (_isMonitoring) return;

    if (Platform.isAndroid) {
      try {
        final granted = await UsageStats.checkUsagePermission() ?? false;
        if (!granted) {
          debugPrint('MonitoringService: PACKAGE_USAGE_STATS not granted.');
        }
      } catch (e) {
        debugPrint('MonitoringService: Permission check error: $e');
      }
    }

    _isMonitoring = true;
    await _deviceStatusService.goOnline();

    // ── A. Démarrer l'enforcement (règles Firestore + boucle 5s) ─────────
    await _enforcementService.start(
      onBlock: (reason, package) {
        // Transmettre le signal de blocage à l'isolate principal Flutter
        service.invoke('triggerBlock', {'reason': reason, 'package': package});
      },
      service: service,
    );
    
    // ── B. Démarrer le suivi GPS et Geofencing ───────────────────────────
    await LocationService().startTracking();

    // ── B. Démarrer la collecte des stats (boucle 15min) ─────────────────
    await _syncUsageStats();
    
    // Synchronisation complète des applications et icônes installées directement depuis le background
    try {
      await PackageService().syncInstalledApps();
      _lastAppSync = DateTime.now();
    } catch (e) {
      debugPrint('MonitoringService: Background app sync error: $e');
    }
    
    service.invoke('triggerAppSync');
 
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await _syncUsageStats();

      // Synchronisation périodique des applications (toutes les 6 heures)
      final now = DateTime.now();
      if (_lastAppSync == null || now.difference(_lastAppSync!) > const Duration(hours: 6)) {
        try {
          debugPrint('MonitoringService: Running periodic app sync...');
          await PackageService().syncInstalledApps();
          _lastAppSync = now;
        } catch (e) {
          debugPrint('MonitoringService: Periodic background app sync error: $e');
        }
      }
    });

    debugPrint('MonitoringService: Started (enforcement + collection).');
  }

  Future<void> stopMonitoring() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    await _enforcementService.stop();
    await LocationService().stopTracking();
    _isMonitoring = false;
    await _deviceStatusService.goOffline();
    debugPrint('MonitoringService: Stopped.');
  }

  // ── Collecte stats d'usage → Firestore ───────────────────────────────────

  Future<void> _syncUsageStats() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final childPath = await readChildPath(prefs);
    final childId   = prefs.getString('child_id');
    final parentId  = prefs.getString('parent_id');
    if (childPath == null || childId == null || parentId == null) return;

    try {
      final now        = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final today      = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

      final stats = await UsageStats.queryUsageStats(startOfDay, now);
      if (stats.isEmpty) return;

      final filtered = stats.where((s) {
        final pkg = s.packageName ?? '';
        final ms  = int.tryParse(s.totalTimeInForeground ?? '0') ?? 0;
        // BUG FIX #5 : Ne pas exclure com.google.android.youtube / com.android.chrome
        // si le parent les a bloqués. Les stats doivent refléter l'usage réel.
        // On garde seulement l'exclusion des paquets génériques Android/constructeur.
        return ms > 0 && !SystemAppClassifier.forUsageStats(pkg);
      }).toList()
        ..sort((a, b) {
          final aMs = int.tryParse(a.totalTimeInForeground ?? '0') ?? 0;
          final bMs = int.tryParse(b.totalTimeInForeground ?? '0') ?? 0;
          return bMs.compareTo(aMs);
        });

      final totalMs      = filtered.fold<int>(0, (s, e) =>
          s + (int.tryParse(e.totalTimeInForeground ?? '0') ?? 0));
      final totalMinutes = totalMs ~/ 60000;

      // Les métriques détaillées restent imbriquées dans `apps`, seul
      // champ enrichi autorisé par les règles Firestore du parent.
      final Map<String, dynamic> appsData = {};
      for (final s in filtered.take(20)) {
        final pkg     = s.packageName ?? '';
        if (pkg.isEmpty) continue;
        final minutes = (int.tryParse(s.totalTimeInForeground ?? '0') ?? 0) ~/ 60000;
        
        // Lire le label et l'icône depuis les détails déjà syncés par PackageService
        String? appLabel;
        String? iconBase64;
        try {
          final detailSnap = await _firestore
              .doc('$childPath/inventory/apps/details/$pkg')
              .get();
          if (detailSnap.exists) {
            appLabel = detailSnap.data()?['appName'] as String? ??
                       detailSnap.data()?['label'] as String? ??
                       detailSnap.data()?['name'] as String?;
            iconBase64 = detailSnap.data()?['iconBase64'] as String? ??
                         detailSnap.data()?['icon'] as String?;
          }
        } catch (_) {}

        appsData[pkg] = {
          'minutes':      minutes,
          'category':     _catStr(_classify(pkg)),
          'lastUpdate':   FieldValue.serverTimestamp(),
          if (appLabel != null) 'label': appLabel,
          if (appLabel != null) 'name': appLabel,
          if (appLabel != null) 'appName': appLabel,
          if (iconBase64 != null) 'iconBase64': iconBase64,
          if (iconBase64 != null) 'icon': iconBase64,
        };
      }

      final usageDoc = {
        'childId':            childId,
        'date':               today,
        'usedMinutes':        totalMinutes, // Requis par le parent
        'totalMinutes':       totalMinutes,
        'apps':               appsData,
        'lastSync':           FieldValue.serverTimestamp(),
      };

      // Emplacement EXACT attendu par l'application parente
      final parentPath = '$childPath/alerts/usage/apps/$today';
      await _firestore.doc(parentPath).set(usageDoc, SetOptions(merge: true));

      debugPrint('MonitoringService: 📤 Stats synced to parent path: $parentPath');
      debugPrint('MonitoringService: ✅ Stats synced — $totalMinutes min, ${filtered.length} apps.');
    } catch (e) {
      debugPrint('MonitoringService: _syncUsageStats error: $e');
    }
  }



  Future<void> forceSyncNow() => _syncUsageStats();

  /// Force le statut ONLINE (utile après jumelage)
  Future<void> forceGoOnline() async {
    await _deviceStatusService.goOnline();
  }

  EnforcementService get enforcement => _enforcementService;
}
