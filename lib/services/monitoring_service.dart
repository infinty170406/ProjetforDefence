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
      onBlock: (reason) {
        // Transmettre le signal de blocage à l'isolate principal Flutter
        service.invoke('triggerBlock', {'reason': reason});
      },
      service: service,
    );
    
    // ── B. Démarrer le suivi GPS et Geofencing ───────────────────────────
    await LocationService().startTracking();

    // ── B. Démarrer la collecte des stats (boucle 15min) ─────────────────
    await _syncUsageStats();
    PackageService().syncInstalledApps();

    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      await _syncUsageStats();
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
    await prefs.reload();
    final childPath = prefs.getString('child_path');
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
        return ms > 0 && !_isSystemApp(pkg);
      }).toList()
        ..sort((a, b) {
          final aMs = int.tryParse(a.totalTimeInForeground ?? '0') ?? 0;
          final bMs = int.tryParse(b.totalTimeInForeground ?? '0') ?? 0;
          return bMs.compareTo(aMs);
        });

      final totalMs      = filtered.fold<int>(0, (s, e) =>
          s + (int.tryParse(e.totalTimeInForeground ?? '0') ?? 0));
      final totalMinutes = totalMs ~/ 60000;

      final Map<String, dynamic> appsData = {};
      for (final s in filtered.take(20)) {
        final pkg     = s.packageName ?? '';
        final minutes = (int.tryParse(s.totalTimeInForeground ?? '0') ?? 0) ~/ 60000;
        appsData[pkg] = {
          'totalMinutes': minutes,
          'category':     _catStr(_classify(pkg)),
          'lastUpdate':   FieldValue.serverTimestamp(),
        };
      }

      final usageDoc = {
        'childId':            childId,
        'parentId':           parentId,
        'date':               today,
        'usedMinutes':        totalMinutes, // Requis par le parent
        'totalMinutes':       totalMinutes,
        'apps':               appsData,
        'lastSync':           FieldValue.serverTimestamp(),
      };

      // Emplacement EXACT attendu par l'application parente
      final parentPath = '$childPath/alerts/usage/apps/$today';
      await _firestore.doc(parentPath).set(usageDoc, SetOptions(merge: true));

      // Synchro vers les autres chemins pour sécurité
      await _firestore.doc('$childPath/usage/$today').set(usageDoc, SetOptions(merge: true));
      await _firestore.doc('usageStats/$childId-$today').set(usageDoc, SetOptions(merge: true));

      debugPrint('MonitoringService: 📤 Stats synced to parent path: $parentPath');

      // Résumé sur le document enfant
      await _firestore.doc(childPath).update({
        'todayScreenMinutes': totalMinutes,
        'lastUsageSync':      FieldValue.serverTimestamp(),
      });

      debugPrint('MonitoringService: ✅ Stats synced — $totalMinutes min, ${filtered.length} apps.');
    } catch (e) {
      debugPrint('MonitoringService: _syncUsageStats error: $e');
    }
  }

  bool _isSystemApp(String pkg) =>
      pkg.startsWith('com.android.') ||
      pkg.startsWith('com.google.android.') ||
      pkg == 'android' ||
      pkg == 'app.theguardian.child';

  Future<void> forceSyncNow() => _syncUsageStats();

  /// Force le statut ONLINE (utile après jumelage)
  Future<void> forceGoOnline() async {
    await _deviceStatusService.goOnline();
  }

  EnforcementService get enforcement => _enforcementService;
}
