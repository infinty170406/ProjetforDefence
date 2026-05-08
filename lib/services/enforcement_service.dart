import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'rules_service.dart';
import 'alert_service.dart';

/// EnforcementService
///
/// Moteur d'application des règles parentales en temps réel.
///
/// Responsabilités :
///   1. Écouter les règles via [RulesService] (stream Firestore temps réel)
///   2. Vérifier toutes les 5s l'app au premier plan (UsageStats) + plages horaires
///   3. Notifier Flutter via [EventChannel] quand un blocage doit s'afficher
///   4. Mettre à jour l'AccessibilityService avec les packages bloqués
///   5. Incrémenter le compteur de temps d'écran dans Firestore
///   6. Écrire les alertes (type BLOCKED_APP, TIME_LIMIT, OUTSIDE_HOURS, APP_TIME_LIMIT)
///   7. Filtrage Web & Historique via EventChannel natif
class EnforcementService {
  static final EnforcementService _instance = EnforcementService._internal();
  factory EnforcementService() => _instance;
  EnforcementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AlertService _alertService = AlertService();
  final RulesService _rulesService = RulesService();

  static const _methodChannel = MethodChannel('app.theguardian.child/system');
  static const _webEventChannel = EventChannel('app.theguardian.child/web_events');
  static const _keywordEventChannel = EventChannel('app.theguardian.child/keyword_events');

  // ── Packages par catégorie ───────────────────────────────────────────────
  static const socialMedia = {
    'com.zhiliaoapp.musically', 'com.tiktok',
    'com.instagram.android', 'com.snapchat.android',
    'com.twitter.android', 'com.facebook.katana',
    'com.facebook.lite', 'com.pinterest',
    'com.reddit.frontpage',
  };
  static const gaming = {
    'com.roblox.client', 'com.epicgames.fortnite',
    'com.mojang.minecraftpe', 'com.supercell.clashofclans',
    'com.supercell.brawlstars', 'com.king.candycrushsaga',
    'com.gameloft.android.ANMP.GloftA9HM',
  };
  static const _socialMedia = socialMedia;
  static const _gaming = gaming;

  // ── Filtres de contenu (mots-clés) ───────────────────────────────────────
  static const _adultKeywords = {'porn', 'sex', 'xhamster', 'xvideos', 'pornhub', 'adult'};
  static const _violenceKeywords = {'violence', 'gore', 'suicide', 'death', 'blood', 'killing'};
  static const _gamblingKeywords = {'gambling', 'casino', 'bet', 'poker', 'slots', 'lottery'};

  Timer? _checkTimer;
  bool _isRunning = false;
  String? _lastPackage;
  String? _lastUrl;
  String? _lastReportedUrl;
  DateTime? _lastScreenTimeReport;
  DateTime? _lastUiUpdate;
  StreamSubscription? _webSubscription;
  StreamSubscription? _keywordSubscription;

  // Instance du service de background (pour communication inter-isolate)
  ServiceInstance? _backgroundService;

  // Callback vers BackgroundService pour déclencher l'écran de blocage côté Flutter
  void Function(String reason)? onBlockRequired;

  // ── Démarrage / arrêt ────────────────────────────────────────────────────

  Future<void> start({
    required void Function(String reason) onBlock,
    ServiceInstance? service,
  }) async {
    if (_isRunning) return;
    _isRunning = true;
    onBlockRequired = onBlock;
    _backgroundService = service;

    // Démarrer l'écoute des règles
    await _rulesService.start();
    _rulesService.addListener(_onRulesChanged);

    // Note : On n'écoute plus les EventChannels ici car ils ne fonctionnent pas
    // dans un isolate de background. Les événements sont maintenant reçus
    // via BackgroundService (web_event / keyword_event).

    // Appliquer les règles initiales à l'AccessibilityService
    _onRulesChanged(_rulesService.current);

    // Boucle de vérification toutes les secondes pour plus de réactivité
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    debugPrint('EnforcementService: Started.');
  }

  Future<void> stop() async {
    _checkTimer?.cancel();
    _checkTimer = null;
    await _webSubscription?.cancel();
    _webSubscription = null;
    await _keywordSubscription?.cancel();
    _keywordSubscription = null;
    _rulesService.removeListener(_onRulesChanged);
    await _rulesService.stop();
    _isRunning = false;
    debugPrint('EnforcementService: Stopped.');
  }

  // ── Réaction aux changements de règles ───────────────────────────────────
  void _onRulesChanged(ActiveRules rules) {
    final blocked = rules.effectiveBlockedPackages(
      socialMediaPackages: _socialMedia,
      gamingPackages: _gaming,
    );
    _updateNativeBlockedPackages(blocked);
    _updateNativeCustomKeywords(rules.customKeywords);

    final needsVpn = rules.blockedWebsites.isNotEmpty || 
        rules.blockAdultContent || 
        rules.blockViolence || 
        rules.blockGambling;
    _updateNativeVpnState(needsVpn);

    debugPrint('EnforcementService: Rules updated. ${blocked.length} apps blocked. VPN needed: $needsVpn');
    
    // Déclencher une vérification immédiate sans attendre le prochain tick
    _tick();
  }

  Future<void> _updateNativeVpnState(bool start) async {
    if (!Platform.isAndroid) return;
    try {
      if (start) {
        await _methodChannel.invokeMethod('startVpn');
      } else {
        await _methodChannel.invokeMethod('stopVpn');
      }
    } catch (e) {
      debugPrint('EnforcementService: VPN update error: $e');
    }
  }

  Future<void> _updateNativeBlockedPackages(Set<String> packages) async {
    if (!Platform.isAndroid) return;
    final packageList = packages.toList();

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeBlockedPackages', {'packages': packageList});
      return;
    }

    try {
      await _methodChannel.invokeMethod('updateBlockedPackages', packageList);
    } catch (e) {
      debugPrint('EnforcementService: Native update error (non-fatal): $e');
    }
  }

  Future<void> _updateNativeCustomKeywords(Set<String> keywords) async {
    if (!Platform.isAndroid) return;
    final keywordList = keywords.toList();

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeCustomKeywords', {'keywords': keywordList});
      return;
    }

    try {
      await _methodChannel.invokeMethod('updateCustomKeywords', keywordList);
    } catch (e) {
      debugPrint('EnforcementService: Native custom keywords update error: $e');
    }
  }

  // ── Tick de vérification (toutes les 5s) ─────────────────────────────────

  Future<void> _tick() async {
    if (!Platform.isAndroid) return;
    final rules = _rulesService.current;

    // Temps d'écran utilisé
    final usedMinutes = await _getTodayUsedMinutes();
    final now = DateTime.now();

    // Mettre à jour l'UI toutes les minutes
    if (_lastUiUpdate == null || now.difference(_lastUiUpdate!) >= const Duration(minutes: 1)) {
      _backgroundService?.invoke('screenTimeUpdate', {'minutes': usedMinutes});
      _lastUiUpdate = now;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // IMPORTANT: Obligatoire pour voir les changements de l'autre isolate
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    // 1. Plage horaire
    if (_isOutsideAllowedHours(rules)) {
      final start = rules.allowedTimeStart ?? '';
      final end = rules.allowedTimeEnd ?? '';
      
      if (onboardingComplete) {
        await _alertService.sendAlert(
          type: AlertType.outsideHours,
          detail: 'Hors plage autorisée ($start – $end)',
        );
        onBlockRequired?.call('Utilisation hors heures autorisées ($start – $end).');
        return;
      }
    }

    // 2. Limite journalière globale
    if (rules.dailyLimitMinutes > 0) {
      if (usedMinutes >= rules.dailyLimitMinutes && onboardingComplete) {
        await _alertService.sendAlert(
          type: AlertType.timeLimit,
          detail: 'Limite de ${rules.dailyLimitMinutes} min atteinte',
        );
        onBlockRequired?.call('Temps d\'écran journalier écoulé.');
      }

      if (_lastScreenTimeReport == null || now.difference(_lastScreenTimeReport!) >= const Duration(minutes: 5)) {
        await _reportScreenTime(usedMinutes);
        _lastScreenTimeReport = now;
      }

      if (usedMinutes >= rules.dailyLimitMinutes) {
        return;
      }
    }

    // 3. App au premier plan
    final frontPackage = await _getForegroundPackage();
    if (frontPackage == null) return;

    // 3a. Vérifier les limites par application
    final appLimit = rules.appTimeLimits[frontPackage];
    if (appLimit != null && appLimit > 0) {
      final appUsedMinutes = await _getAppUsedMinutes(frontPackage);
      if (appUsedMinutes >= appLimit) {
      if (onboardingComplete) {
        await _alertService.sendAlert(
          type: AlertType.appTimeLimit,
          detail: 'Limite pour $frontPackage atteinte ($appLimit min)',
        );
        onBlockRequired?.call('Limite de temps pour cette application atteinte.');
        return;
      }
      }
    }

    // 3b. Vérifier si l'app est bloquée (individuellement ou catégorie)
    final blocked = rules.effectiveBlockedPackages(
      socialMediaPackages: _socialMedia,
      gamingPackages: _gaming,
    );

    if (blocked.contains(frontPackage) && frontPackage != _lastPackage) {
      _lastPackage = frontPackage;
      
      if (onboardingComplete) {
        await _alertService.sendAlert(
          type: AlertType.blockedApp,
          detail: 'App bloquée : $frontPackage',
        );
        onBlockRequired?.call('Cette application est bloquée par vos parents.');
      }
    } else if (!blocked.contains(frontPackage)) {
      _lastPackage = null;
    }
  }

  /// Appelé par BackgroundService quand il reçoit un web_event du natif
  void handleNativeWebEvent(Map<dynamic, dynamic> data) {
    _onUrlDetected(data);
  }

  /// Appelé par BackgroundService quand il reçoit un keyword_event du natif
  void handleNativeKeywordEvent(Map<dynamic, dynamic> data) {
    _onKeywordDetected(data);
  }

  // ── Web Filtering ────────────────────────────────────────────────────────

  void _onUrlDetected(Map<dynamic, dynamic> event) {
    if (!_isRunning) return;
    final url = (event['url'] as String? ?? '').toLowerCase();
    final pkg = (event['package'] as String? ?? '');
    final rules = _rulesService.current;

    if (url.isEmpty) return;

    // Historique
    if (url != _lastReportedUrl && url.startsWith('http')) {
      _lastReportedUrl = url;
      _reportUrlHistory(url, pkg);
    }

    // Blocage par domaine
    for (final blocked in rules.blockedWebsites) {
      if (url.contains(blocked.toLowerCase())) {
        _triggerWebBlock(url, 'Ce site web ($blocked) est bloqué par vos parents.');
        return;
      }
    }

    // Blocage par catégorie
    if (rules.blockAdultContent && _matchesKeywords(url, _adultKeywords)) {
      _triggerWebBlock(url, 'Contenu bloqué par le filtre parental (Contenu Adulte).');
      return;
    }
    if (rules.blockViolence && _matchesKeywords(url, _violenceKeywords)) {
      _triggerWebBlock(url, 'Contenu bloqué par le filtre parental (Violence).');
      return;
    }
    if (rules.blockGambling && _matchesKeywords(url, _gamblingKeywords)) {
      _triggerWebBlock(url, 'Contenu bloqué par le filtre parental (Jeux d\'argent).');
      return;
    }
  }

  bool _matchesKeywords(String url, Set<String> keywords) {
    return keywords.any((k) => url.contains(k));
  }

  Future<void> _reportUrlHistory(String url, String package) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childPath = prefs.getString('child_path');
      if (childPath == null) return;

      final today = _todayString();
      final domain = Uri.tryParse(url)?.host ?? url;
      if (domain.isEmpty) return;

      // Chemin EXACT attendu par le parent pour les stats web
      final webStatsPath = '$childPath/alerts/usage/websites/$today';

      await _firestore.doc(webStatsPath).set({
        'totalMinutes': 0, // Optionnel, le parent additionne
        'websites': {
          domain.replaceAll('.', '_'): { // Firestore n'aime pas les points dans les clés
            'domain': domain,
            'lastVisit': FieldValue.serverTimestamp(),
            'visits': FieldValue.increment(1),
          }
        },
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // On garde aussi l'historique linéaire pour le debug
      await _firestore.collection('$childPath/webHistory').add({
        'url': url,
        'domain': domain,
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('EnforcementService: 🌐 Web stats synced to: $webStatsPath');
    } catch (e) {
      debugPrint('EnforcementService: _reportUrlHistory error: $e');
    }
  }

  Future<void> _triggerWebBlock(String url, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('onboarding_complete') ?? false)) return;

    final domain = Uri.tryParse(url)?.host ?? url;
    if (domain == _lastUrl) return;
    _lastUrl = domain;

    await _alertService.sendAlert(
      type: AlertType.blockedApp,
      detail: 'Site bloqué : $url',
    );

    onBlockRequired?.call(reason);
    if (_backgroundService != null) {
      _backgroundService!.invoke('triggerBlock', {'reason': reason});
    }
  }

  // ── Keyword Filtering ────────────────────────────────────────────────────

  Future<void> _onKeywordDetected(Map<dynamic, dynamic> event) async {
    if (!_isRunning) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('onboarding_complete') ?? false)) return;

    final keyword = event['keyword'] as String? ?? '';
    final pkg = event['package'] as String? ?? '';

    if (keyword.isEmpty) return;

    await _alertService.sendAlert(
      type: AlertType.keywordDetected,
      detail: 'Mot-clé détecté : "$keyword" (dans $pkg)',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _getForegroundPackage() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(seconds: 4));
      final events = await UsageStats.queryEvents(start, now);
      for (final e in events.reversed) {
        if (e.eventType == '1') return e.packageName;
      }
    } catch (e) {
      debugPrint('EnforcementService: getForegroundPackage error: $e');
    }
    return null;
  }

  Future<int> _getTodayUsedMinutes() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stats = await UsageStats.queryUsageStats(startOfDay, now);
      final totalMs = stats.fold<int>(0, (sum, s) {
        final pkg = s.packageName ?? '';
        if (_isSystemApp(pkg)) return sum;
        return sum + (int.tryParse(s.totalTimeInForeground ?? '0') ?? 0);
      });
      return totalMs ~/ 60000;
    } catch (e) {
      debugPrint('EnforcementService: _getTodayUsedMinutes error: $e');
      return 0;
    }
  }

  Future<int> _getAppUsedMinutes(String packageName) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stats = await UsageStats.queryUsageStats(startOfDay, now);
      for (final s in stats) {
        if (s.packageName == packageName) {
          return (int.tryParse(s.totalTimeInForeground ?? '0') ?? 0) ~/ 60000;
        }
      }
    } catch (e) {
      debugPrint('EnforcementService: _getAppUsedMinutes error: $e');
    }
    return 0;
  }

  Future<void> _reportScreenTime(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childPath = prefs.getString('child_path');
      final childId = prefs.getString('child_id');
      final parentId = prefs.getString('parent_id');
      if (childPath == null || childId == null) return;

      final today = _todayString();
      final data = {
        'childId': childId,
        'parentId': parentId,
        'totalScreenMinutes': minutes,
        'totalMinutes': minutes,
        'lastSync': FieldValue.serverTimestamp(),
      };

      // Synchro multi-chemins
      await _firestore.doc('$childPath/alerts/usage/apps/$today').set(data, SetOptions(merge: true));
      await _firestore.doc('$childPath/usage/$today').set(data, SetOptions(merge: true));
      await _firestore.doc('usageStats/$childId-$today').set(data, SetOptions(merge: true));

      await _firestore.doc(childPath).update({
        'todayScreenMinutes': minutes,
        'lastUsageSync': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('EnforcementService: _reportScreenTime error: $e');
    }
  }

  bool _isOutsideAllowedHours(ActiveRules rules) {
    final start = rules.allowedTimeStart;
    final end = rules.allowedTimeEnd;
    if (start == null || end == null) return false;

    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final s = _parseTime(start);
    final e = _parseTime(end);
    if (s == null || e == null) return false;

    if (s <= e) return current < s || current >= e;
    return current >= e && current < s;
  }

  int? _parseTime(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  bool _isSystemApp(String pkg) =>
      pkg.startsWith('com.android.') ||
      pkg.startsWith('com.google.android.') ||
      pkg == 'android' ||
      pkg == 'app.theguardian.child';

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  ActiveRules get currentRules => _rulesService.current;
}
