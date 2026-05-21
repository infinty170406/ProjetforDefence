import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package_service.dart'; // Unused in background isolate
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
    // Déclencher la synchronisation complète des applications et icônes installées sur le main isolate
    service.invoke('triggerAppSync');

    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      await _syncUsageStats();
      await _syncBrowserHistory();
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

      debugPrint('MonitoringService: 📤 Stats synced to parent path: $parentPath');
      debugPrint('MonitoringService: ✅ Stats synced — $totalMinutes min, ${filtered.length} apps.');
    } catch (e) {
      debugPrint('MonitoringService: _syncUsageStats error: $e');
    }
  }

  bool _isSystemApp(String pkg) =>
      pkg.startsWith('com.android.') ||
      pkg.startsWith('com.google.android.') ||
      pkg.startsWith('com.miui.') ||
      pkg.startsWith('com.xiaomi.') ||
      pkg.startsWith('com.qualcomm.') ||
      pkg.startsWith('com.mediatek.') ||
      pkg.startsWith('com.samsung.') ||
      pkg.startsWith('com.huawei.') ||
      pkg.startsWith('com.oppo.') ||
      pkg.startsWith('com.vivo.') ||
      pkg.startsWith('com.oneplus.') ||
      pkg.startsWith('com.coloros.') ||
      pkg.startsWith('com.heytap.') ||
      pkg.startsWith('com.bbk.') ||
      // Specific system packages often showing as "Home", "Android", "Chat"
      pkg == 'android' ||
      pkg == 'com.miui.home' ||
      pkg == 'com.miui.securitycenter' ||
      pkg == 'com.miui.msa.global' ||
      pkg == 'com.miui.bugreport' ||
      pkg == 'com.miui.daemon' ||
      pkg == 'com.miui.analytics' ||
      pkg == 'com.xiaomi.market' ||
      pkg == 'com.xiaomi.simactivate.service' ||
      pkg == 'com.lbe.security.miui' ||
      pkg == 'app.theguardian.child';

  static const _browserPackages = {
    'com.android.chrome',
    'org.mozilla.firefox',
    'com.opera.browser',
    'com.brave.browser',
    'com.microsoft.emmx',
    'com.UCMobile.intl',
  };

  /// Syncs browser history by reading recent UsageEvents for known browser apps.
  /// This bypasses the EventChannel limitation in background isolates.
  Future<void> _syncBrowserHistory() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final childPath = prefs.getString('child_path');
    if (childPath == null) return;

    try {
      final now = DateTime.now();
      final since = now.subtract(const Duration(minutes: 3));
      final events = await UsageStats.queryEvents(since, now);

      final Set<String> reportedDomains = {};
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      for (final event in events.reversed) {
        final pkg = event.packageName ?? '';
        if (!_browserPackages.contains(pkg)) continue;
        // Event type 1 = MOVE_TO_FOREGROUND (user switched to browser)
        if (event.eventType != '1') continue;

        // We can't get the URL directly, but we can record browser usage
        // by package to at least provide some history signal.
        if (reportedDomains.contains(pkg)) continue;
        reportedDomains.add(pkg);

        final browserName = pkg.split('.').last;
        final domain = '$browserName.browser.session';

        // Write to linear history collection
        await _firestore.collection('$childPath/inventory/websites/history').add({
          'url': 'browser://$pkg',
          'domain': domain,
          'package': pkg,
          'title': _browserFriendlyName(pkg),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Write to aggregated websites stats
        final webStatsPath = '$childPath/alerts/usage/websites/$today';
        await _firestore.doc(webStatsPath).set({
          'websites': {
            domain.replaceAll('.', '_'): {
              'domain': domain,
              'lastVisit': FieldValue.serverTimestamp(),
              'visits': FieldValue.increment(1),
            },
          },
          'lastSync': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('MonitoringService: 🌐 Browser usage detected: $pkg');
      }
    } catch (e) {
      debugPrint('MonitoringService: _syncBrowserHistory error: $e');
    }
  }

  String _browserFriendlyName(String pkg) {
    const names = {
      'com.android.chrome': 'Google Chrome',
      'org.mozilla.firefox': 'Firefox',
      'com.opera.browser': 'Opera',
      'com.brave.browser': 'Brave',
      'com.microsoft.emmx': 'Microsoft Edge',
      'com.UCMobile.intl': 'UC Browser',
    };
    return names[pkg] ?? pkg.split('.').last;
  }

  Future<void> forceSyncNow() => _syncUsageStats();

  /// Force le statut ONLINE (utile après jumelage)
  Future<void> forceGoOnline() async {
    await _deviceStatusService.goOnline();
  }

  EnforcementService get enforcement => _enforcementService;
}
