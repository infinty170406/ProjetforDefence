import 'dart:async';
import 'dart:convert';
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
  static const _webEventChannel = EventChannel(
    'app.theguardian.child/web_events',
  );
  static const _keywordEventChannel = EventChannel(
    'app.theguardian.child/keyword_events',
  );

  // ── Packages par catégorie ───────────────────────────────────────────────
  static const socialMedia = {
    'com.zhiliaoapp.musically',
    'com.tiktok',
    'com.instagram.android',
    'com.snapchat.android',
    'com.twitter.android',
    'com.facebook.katana',
    'com.facebook.lite',
    'com.pinterest',
    'com.reddit.frontpage',
  };
  static const gaming = {
    'com.roblox.client',
    'com.epicgames.fortnite',
    'com.mojang.minecraftpe',
    'com.supercell.clashofclans',
    'com.supercell.brawlstars',
    'com.king.candycrushsaga',
    'com.gameloft.android.ANMP.GloftA9HM',
  };
  static const _socialMedia = socialMedia;
  static const _gaming = gaming;

  // ── Filtres de contenu (mots-clés) ───────────────────────────────────────
  static const _adultKeywords = {
    'porn',
    'sex',
    'xhamster',
    'xvideos',
    'pornhub',
    'adult',
    'hentai',
    'brazzers',
  };
  static const _violenceKeywords = {
    'violence',
    'gore',
    'suicide',
    'death',
    'blood',
    'killing',
    'murder',
    'stab',
    'gun',
    'shooting',
  };
  static const _gamblingKeywords = {
    'gambling',
    'casino',
    'bet',
    'poker',
    'slots',
    'lottery',
    'roulette',
    'blackjack',
    'betting',
  };
  static const _drugsKeywords = {
    'drugs',
    'cocaine',
    'heroin',
    'meth',
    'weed',
    'cannabis',
    'fentanyl',
    'pill',
    'ecstasy',
    'overdose',
  };
  static const _predatorsKeywords = {
    'omegle',
    'chatroulette',
    'dating',
    'tinder',
    'bumble',
    'grindr',
    'meetup',
    'strangers',
  };
  static const _selfHarmKeywords = {
    'cut',
    'harm',
    'suicide',
    'kill myself',
    'cutting',
    'self-harm',
    'razor',
    'bleeding',
  };
  static const _bullyingKeywords = {
    'ugly',
    'fat',
    'loser',
    'kill yourself',
    'stupid',
    'hate you',
    'freak',
  };
  static const _eatingKeywords = {
    'pro-ana',
    'anorexia',
    'bulimia',
    'thinspo',
    'weight loss',
    'diet pill',
    'laxative',
  };

  Timer? _checkTimer;
  bool _isRunning = false;
  bool _isChecking = false;
  String? _lastPackage;
  String? _lastUrl;
  String? _lastReportedUrl;
  DateTime? _lastScreenTimeReport;
  DateTime? _lastUiUpdate;
  StreamSubscription? _webSubscription;
  StreamSubscription? _keywordSubscription;
  int _lastReportedMinutes = 0;

  // ── Throttling d'alertes ─────────────────────────────────────────────────
  DateTime? _lastOutsideHoursAlert;
  DateTime? _lastTimeLimitAlert;
  // final Map<String, DateTime> _lastAppLimitAlerts = {}; // Unused
  
  // Anti-drain : Compteurs pour les vérifications lourdes
  int _ticksSinceLastFullSync = 0;
  static const int fullSyncIntervalTicks = 1; // Toutes les 60 secondes
  String? _currentForegroundPackage;

  // Instance du service de background (pour communication inter-isolate)
  ServiceInstance? _backgroundService;

  // Callback vers BackgroundService pour déclencher l'écran de blocage côté Flutter
  void Function(String reason)? onBlockRequired;

  // ── Démarrage / arrêt ────────────────────────────────────────────────────

  Future<void> start({
    required void Function(String reason) onBlock,
    ServiceInstance? service,
  }) async {
    debugPrint('EnforcementService: start() called.');
    if (_isRunning) return;
    _isRunning = true;
    onBlockRequired = onBlock;
    _backgroundService = service;

    // Démarrer l'écoute des règles (attendre le premier chargement pour éviter le "0 limit")
    debugPrint('EnforcementService: Initializing RulesService...');
    await _rulesService.start(waitForFirstLoad: true);
    _rulesService.addListener(_onRulesChanged);

    // FIX BUG #2 : Déterminer l'app au premier plan AU DÉMARRAGE via UsageStats
    // (sans ça, _currentForegroundPackage reste null jusqu'au 1er event AccessibilityService)
    if (Platform.isAndroid) {
      try {
        final now = DateTime.now();
        final recentEvents = await UsageStats.queryEvents(
          now.subtract(const Duration(seconds: 30)),
          now,
        );
        // eventType '1' = MOVE_TO_FOREGROUND
        final foregroundEvents =
            recentEvents.where((e) => e.eventType == '1').toList();
        if (foregroundEvents.isNotEmpty) {
          final lastPkg = foregroundEvents.last.packageName;
          if (lastPkg != null && !_isSystemApp(lastPkg)) {
            _currentForegroundPackage = lastPkg;
            debugPrint(
              'EnforcementService: Initial foreground package detected: $lastPkg',
            );
          }
        }
      } catch (e) {
        debugPrint('EnforcementService: Initial foreground detection error: $e');
      }

      // FIX BUG #5 (fallback) : lire un pending block stocké par MainActivity
      // si le SHOW_BLOCK intent est arrivé avant que Flutter soit prêt
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final pending = prefs.getString('guardian_pending_block');
        if (pending != null && pending.isNotEmpty) {
          await prefs.remove('guardian_pending_block');
          debugPrint('EnforcementService: Consuming pending block: $pending');
          onBlockRequired?.call(pending);
        }
      } catch (e) {
        debugPrint('EnforcementService: Pending block read error: $e');
      }
    }

    // Appliquer les règles initiales à l'AccessibilityService
    _onRulesChanged(_rulesService.current);

    // Boucle de vérification toutes les 60 secondes (optimisation batterie)
    _checkTimer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());

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
    updateNativeBlockedPackages(blocked);
    updateNativeCustomKeywords(rules.customKeywords);
    updateNativeBlockedWebsites(rules.blockedWebsites);

    // Le VPN est désactivé au profit de l'Accessibilité
    /*
    final needsVpn =
        rules.blockedWebsites.isNotEmpty ||
        rules.blockAdultContent ||
        rules.blockViolence ||
        rules.blockGambling;
    _updateNativeVpnState(needsVpn);
    */

    debugPrint(
      'EnforcementService: Rules updated. ${blocked.length} apps blocked. '
      'Limit: ${rules.dailyLimitMinutes} min. '
      'Hours: ${rules.allowedTimeStart}-${rules.allowedTimeEnd}',
    );

    // Déclencher une vérification immédiate sans attendre le prochain tick
    _tick();
  }

  /*
  Future<void> _updateNativeVpnState(bool start) async {
    if (!Platform.isAndroid) return;

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeVpnState', {'start': start});
      return;
    }

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
  */

  Future<void> updateNativeBlockedPackages(Set<String> packages) async {
    if (!Platform.isAndroid) return;
    final packageList = packages.toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guardian_blocked_packages_json', jsonEncode(packageList));
      debugPrint('EnforcementService: Wrote blocked packages to SharedPreferences');
    } catch (e) {
      debugPrint('EnforcementService: Failed to write blocked packages to SharedPreferences: $e');
    }

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeBlockedPackages', {
        'packages': packageList,
      });
    }

    try {
      await _methodChannel.invokeMethod('updateBlockedPackages', packageList);
      debugPrint('EnforcementService: Direct update of native blocked packages succeeded: ${packageList.length}');
    } catch (e) {
      debugPrint('EnforcementService: Direct update of native blocked packages error (non-fatal): $e');
    }
  }

  Future<void> updateNativeCustomKeywords(Set<String> keywords) async {
    if (!Platform.isAndroid) return;
    final keywordList = keywords.toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guardian_custom_keywords_json', jsonEncode(keywordList));
      debugPrint('EnforcementService: Wrote custom keywords to SharedPreferences');
    } catch (e) {
      debugPrint('EnforcementService: Failed to write custom keywords to SharedPreferences: $e');
    }

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeCustomKeywords', {
        'keywords': keywordList,
      });
    }

    try {
      await _methodChannel.invokeMethod('updateCustomKeywords', keywordList);
      debugPrint('EnforcementService: Direct update of native custom keywords succeeded: ${keywordList.length}');
    } catch (e) {
      debugPrint('EnforcementService: Direct update of native custom keywords error (non-fatal): $e');
    }
  }

  Future<void> updateNativeBlockedWebsites(Set<String> websites) async {
    if (!Platform.isAndroid) return;
    final websiteList = websites.toList();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guardian_blocked_websites_json', jsonEncode(websiteList));
      debugPrint('EnforcementService: Wrote blocked websites to SharedPreferences');
    } catch (e) {
      debugPrint('EnforcementService: Failed to write blocked websites to SharedPreferences: $e');
    }

    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeBlockedWebsites', {
        'websites': websiteList,
      });
    }

    try {
      await _methodChannel.invokeMethod('updateBlockedWebsites', websiteList);
      debugPrint('EnforcementService: Direct update of native blocked websites succeeded: ${websiteList.length}');
    } catch (e) {
      debugPrint('EnforcementService: Direct update of native blocked websites error (non-fatal): $e');
    }
  }

  String _getAppName(String package) {
    final Map<String, String> names = {
      'com.zhiliaoapp.musically': 'TikTok',
      'com.tiktok': 'TikTok',
      'com.instagram.android': 'Instagram',
      'com.snapchat.android': 'Snapchat',
      'com.twitter.android': 'Twitter/X',
      'com.facebook.katana': 'Facebook',
      'com.facebook.lite': 'Facebook Lite',
      'com.pinterest': 'Pinterest',
      'com.reddit.frontpage': 'Reddit',
      'com.roblox.client': 'Roblox',
      'com.epicgames.fortnite': 'Fortnite',
      'com.mojang.minecraftpe': 'Minecraft',
      'com.supercell.clashofclans': 'Clash of Clans',
      'com.supercell.brawlstars': 'Brawl Stars',
      'com.king.candycrushsaga': 'Candy Crush',
      'com.gameloft.android.ANMP.GloftA9HM': 'Asphalt 9',
      'com.google.android.youtube': 'YouTube',
      'com.netflix.mediaclient': 'Netflix',
      'com.spotify.music': 'Spotify',
      'com.android.chrome': 'Google Chrome',
      'org.mozilla.firefox': 'Firefox',
      'com.sec.android.app.sbrowser': 'Samsung Internet',
      'com.microsoft.emmx': 'Microsoft Edge',
    };

    if (names.containsKey(package)) {
      return names[package]!;
    }

    final last = package.split('.').last;
    if (last.isNotEmpty) {
      return last[0].toUpperCase() + last.substring(1);
    }
    return package;
  }

  String? _extractSearchQuery(String url) {
    try {
      String cleanUrl = url;
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://' + cleanUrl;
      }
      final uri = Uri.parse(cleanUrl);
      final keys = ['q', 'query', 'text', 'p', 'wd', 'search'];
      for (final key in keys) {
        if (uri.queryParameters.containsKey(key)) {
          final q = uri.queryParameters[key];
          if (q != null && q.isNotEmpty) {
            return Uri.decodeComponent(q).replaceAll('+', ' ');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Tick de vérification (toutes les 15s) ────────────────────────────────

  Future<void> _tick() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      debugPrint('EnforcementService: _tick() executing...');
      if (!Platform.isAndroid) return;

      // FIX BUG #1 + #3 : drainer la queue d'événements écrite par GuardianAccessibilityService
      // directement dans FlutterSharedPreferences (indépendant du cycle de vie de MainActivity)
      await _drainEventQueue();

      final rules = _rulesService.current;
      final now = DateTime.now();

      // Déterminer l'app au premier plan
      final frontPackage = await _getForegroundPackage();
      final bool isActivelyTrying = frontPackage != null && !_isSystemApp(frontPackage);

      // Compteurs pour les vérifications lourdes (toutes les 60s)
      _ticksSinceLastFullSync++;
      bool isFullSyncTick = _ticksSinceLastFullSync >= fullSyncIntervalTicks;
      
      int usedMinutes = await _getTodayUsedMinutes();
      _lastReportedMinutes = usedMinutes;
      
      debugPrint('EnforcementService: Tick - Front: $frontPackage, isActivelyTrying: $isActivelyTrying, Used: $usedMinutes min');
      
      if (isFullSyncTick || _lastScreenTimeReport == null) {
        _ticksSinceLastFullSync = 0;
        
        // Mettre à jour l'UI (Dashboard)
        _backgroundService?.invoke('screenTimeUpdate', {'minutes': usedMinutes});
        
        // Reporter à Firestore toutes les 2 minutes
        if (_lastScreenTimeReport == null || now.difference(_lastScreenTimeReport!) >= const Duration(minutes: 2)) {
          await _reportScreenTime(usedMinutes);
          _lastScreenTimeReport = now;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // IMPORTANT: Obligatoire pour voir les changements de l'autre isolate
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      // Déterminer les restrictions dynamiques
      final bool isOutsideHours = _isOutsideAllowedHours(rules);
      final bool isDailyLimitReached = rules.dailyLimitMinutes > 0 && usedMinutes >= rules.dailyLimitMinutes;

      // Base des packages bloqués configurée par le parent
      final baseBlocked = rules.effectiveBlockedPackages(
        socialMediaPackages: _socialMedia,
        gamingPackages: _gaming,
      );

      final activeBlocked = Set<String>.from(baseBlocked);
      String? blockReason;

      // 1. Plage horaire (Prioritaire)
      if (isOutsideHours) {
        debugPrint('EnforcementService: BLOCK -> Outside allowed hours');
        final start = rules.allowedTimeStart ?? '';
        final end = rules.allowedTimeEnd ?? '';
        blockReason = 'Utilisation hors heures autorisées ($start – $end).';

        if (onboardingComplete && isActivelyTrying) {
          if (_lastOutsideHoursAlert == null ||
              now.difference(_lastOutsideHoursAlert!).inMinutes >= 10) {
            _lastOutsideHoursAlert = now;
            await _alertService.sendAlert(
              type: AlertType.outsideHours,
              detail:
                  'Alerte d\'activité : Votre enfant a tenté d\'utiliser son téléphone en dehors des heures autorisées (de $start à $end).',
            );
          }
        }

        if (frontPackage != null && frontPackage != 'app.theguardian.child' && !_isSystemApp(frontPackage)) {
          activeBlocked.add(frontPackage);
        }
      }
      // 2. Limite journalière globale
      else if (isDailyLimitReached) {
        debugPrint('EnforcementService: BLOCK -> Daily limit reached');
        blockReason = 'Temps d\'écran journalier écoulé.';

        if (onboardingComplete && isActivelyTrying) {
          if (_lastTimeLimitAlert == null ||
              now.difference(_lastTimeLimitAlert!).inMinutes >= 10) {
            _lastTimeLimitAlert = now;
            await _alertService.sendAlert(
              type: AlertType.timeLimit,
              detail:
                  'Alerte de limite : Votre enfant a tenté d\'utiliser son téléphone alors que sa limite de temps d\'écran journalière (${rules.dailyLimitMinutes} minutes) est déjà épuisée.',
            );
          }
        }

        if (frontPackage != null && frontPackage != 'app.theguardian.child' && !_isSystemApp(frontPackage)) {
          activeBlocked.add(frontPackage);
        }
      }
      // 3. Limite d'application individuelle
      else if (frontPackage != null) {
        final appLimit = rules.appTimeLimits[frontPackage];
        if (appLimit != null && appLimit > 0) {
          final appUsedMinutes = await _getAppUsedMinutes(frontPackage);
          if (appUsedMinutes >= appLimit) {
            blockReason = 'Limite de temps pour cette application atteinte.';
            activeBlocked.add(frontPackage);

            if (onboardingComplete) {
              await _alertService.sendAlert(
                type: AlertType.appTimeLimit,
                detail:
                    'Alerte de temps : Votre enfant a essayé d\'ouvrir l\'application ${_getAppName(frontPackage)}, mais sa limite d\'utilisation pour cette application ($appLimit minutes) est atteinte.',
              );
            }
          }
        }
      }

      // 4. Bloqué individuellement ou par catégorie
      if (blockReason == null && frontPackage != null && baseBlocked.contains(frontPackage)) {
        debugPrint('EnforcementService: BLOCK -> App is in blocked list: $frontPackage');
        blockReason = 'Cette application est bloquée par vos parents.';

        if (onboardingComplete && frontPackage != _lastPackage) {
          _lastPackage = frontPackage;
          await _alertService.sendAlert(
            type: AlertType.blockedApp,
            detail:
                'Alerte de sécurité : Votre enfant a tenté d\'ouvrir l\'application ${_getAppName(frontPackage)}, qui fait partie des applications que vous avez bloquées.',
          );
        }
      } else if (frontPackage != null && !baseBlocked.contains(frontPackage)) {
        _lastPackage = null;
      }

      // Écrire les motifs de blocage dans SharedPreferences pour que le natif et l'UI les lisent
      if (blockReason != null && frontPackage != null) {
        await prefs.setString('guardian_block_reason', blockReason);
        await prefs.setString('guardian_block_reason_$frontPackage', blockReason);
        onBlockRequired?.call(blockReason);
      } else if (frontPackage != null) {
        await prefs.remove('guardian_block_reason_$frontPackage');
      }

      // Mettre à jour la liste des packages bloqués
      await updateNativeBlockedPackages(activeBlocked);
    } catch (e, stack) {
      debugPrint('EnforcementService: Error in _tick: $e\n$stack');
    } finally {
      _isChecking = false;
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

  void handleNativeForegroundEvent(Map<dynamic, dynamic> data) {
    final pkg = data['package'] as String?;
    if (pkg != null && pkg.isNotEmpty && !_isSystemApp(pkg)) {
      if (_currentForegroundPackage != pkg) {
        _currentForegroundPackage = pkg;
        debugPrint('EnforcementService: Foreground package updated: $pkg');
        if (!_isChecking) {
          Future.microtask(_tick);
        }
      }
    }
  }

  /// FIX BUG #1 + #3 + Race Conditions: Draine la queue d'événements
  /// écrite par GuardianAccessibilityService sous forme de clés distinctes.
  Future<void> _drainEventQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      // Filtrer les clés qui correspondent aux événements individuels
      final keys = prefs.getKeys().where((k) => k.startsWith('guardian_event_') && k != 'guardian_event_queue').toList();
      
      // Compatibilité descendante (nettoyer l'ancienne clé de queue si elle existe encore)
      if (prefs.containsKey('guardian_event_queue')) {
        await prefs.remove('guardian_event_queue');
      }

      if (keys.isEmpty) return;

      debugPrint('EnforcementService: Draining ${keys.length} queued events.');

      // Trier par ordre alphabétique (qui contient le timestamp grâce à notre format de clé)
      keys.sort();

      for (final key in keys) {
        final jsonStr = prefs.getString(key);
        if (jsonStr != null && jsonStr.isNotEmpty) {
           try {
             final event = Map<dynamic, dynamic>.from(jsonDecode(jsonStr));
             final action = event['action'] as String?;
             switch (action) {
               case 'web_event':
                 handleNativeWebEvent(event);
                 break;
               case 'keyword_event':
                 handleNativeKeywordEvent(event);
                 break;
               case 'foreground_event':
                 handleNativeForegroundEvent(event);
                 break;
             }
           } catch(e) {
             debugPrint('EnforcementService: Error parsing event $key: $e');
           }
        }
        // Supprimer la clé après traitement (safe vis-à-vis des race conditions)
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('EnforcementService: _drainEventQueue error: $e');
    }
  }

  // ── Web Filtering ────────────────────────────────────────────────────────

  void _onUrlDetected(Map<dynamic, dynamic> event) {
    if (!_isRunning) return;
    final url = (event['url'] as String? ?? '').toLowerCase();
    final pkg = (event['package'] as String? ?? '');
    String? searchQuery = event['searchQuery'] as String?;
    final rules = _rulesService.current;

    if (url.isEmpty) return;

    // 1. Extraire la requête de recherche si absente
    if (searchQuery == null || searchQuery.isEmpty) {
      searchQuery = _extractSearchQuery(url);
    }

    // Historique (Supporte maintenant les URLs "nues" sans http)
    if (url != _lastReportedUrl) {
      _lastReportedUrl = url;
      _reportUrlHistory(url, pkg, searchQuery: searchQuery);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // 2. Détecter si la recherche porte sur des catégories restreintes
      bool shouldBlock = false;
      String category = '';

      if (rules.blockAdultContent && _matchesKeywords(searchQuery, _adultKeywords)) {
        shouldBlock = true; category = 'Contenu Adulte';
      } else if (rules.blockViolence && _matchesKeywords(searchQuery, _violenceKeywords)) {
        shouldBlock = true; category = 'Violence';
      } else if (rules.blockGambling && _matchesKeywords(searchQuery, _gamblingKeywords)) {
        shouldBlock = true; category = 'Jeux d\'argent';
      } else if (rules.blockDrugs && _matchesKeywords(searchQuery, _drugsKeywords)) {
        shouldBlock = true; category = 'Drogues';
      } else if (rules.blockSexualPredators && _matchesKeywords(searchQuery, _predatorsKeywords)) {
        shouldBlock = true; category = 'Rencontres/Prédateurs';
      } else if (rules.blockSelfHarm && _matchesKeywords(searchQuery, _selfHarmKeywords)) {
        shouldBlock = true; category = 'Auto-mutilation';
      } else if (rules.blockCyberbullying && _matchesKeywords(searchQuery, _bullyingKeywords)) {
        shouldBlock = true; category = 'Cyber-harcèlement';
      } else if (rules.blockEatingDisorders && _matchesKeywords(searchQuery, _eatingKeywords)) {
        shouldBlock = true; category = 'Troubles alimentaires';
      }

      if (shouldBlock) {
        _triggerWebSearchBlock(url, searchQuery, category);
        return;
      }
    }

    // Blocage par domaine classique
    for (final blocked in rules.blockedWebsites) {
      if (url.contains(blocked.toLowerCase())) {
        _triggerWebBlock(
          url,
          'Ce site web ($blocked) est bloqué par vos parents.',
        );
        return;
      }
    }

    // Blocage par catégorie d'URL classique
    if (rules.blockAdultContent && _matchesKeywords(url, _adultKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Contenu Adulte).',
      );
      return;
    }
    if (rules.blockViolence && _matchesKeywords(url, _violenceKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Violence).',
      );
      return;
    }
    if (rules.blockGambling && _matchesKeywords(url, _gamblingKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Jeux d\'argent).',
      );
      return;
    }
    if (rules.blockDrugs && _matchesKeywords(url, _drugsKeywords)) {
      _triggerWebBlock(url, 'Contenu bloqué par le filtre parental (Drogues).');
      return;
    }
    if (rules.blockSexualPredators &&
        _matchesKeywords(url, _predatorsKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Rencontres/Prédateurs).',
      );
      return;
    }
    if (rules.blockSelfHarm && _matchesKeywords(url, _selfHarmKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Auto-mutilation).',
      );
      return;
    }
    if (rules.blockCyberbullying && _matchesKeywords(url, _bullyingKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Cyber-harcèlement).',
      );
      return;
    }
    if (rules.blockEatingDisorders && _matchesKeywords(url, _eatingKeywords)) {
      _triggerWebBlock(
        url,
        'Contenu bloqué par le filtre parental (Troubles alimentaires).',
      );
      return;
    }
  }

  bool _matchesKeywords(String text, Set<String> keywords) {
    return keywords.any((k) => text.contains(k.toLowerCase()));
  }

  Future<void> _triggerWebSearchBlock(String url, String searchQuery, String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('onboarding_complete') ?? false)) return;

    final domain = Uri.tryParse(url)?.host ?? url;
    if (domain == _lastUrl) return;
    _lastUrl = domain;

    await _alertService.sendAlert(
      type: AlertType.blockedApp,
      detail: 'Votre enfant a cherché "$searchQuery"',
    );

    final reason = 'Recherche restreinte détectée ("$searchQuery").';
    onBlockRequired?.call(reason);
    if (_backgroundService != null) {
      _backgroundService!.invoke('triggerBlock', {'reason': reason});
    }
  }

  Future<void> _reportUrlHistory(String url, String package, {String? searchQuery}) async {
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
          domain.replaceAll('.', '_'): {
            'domain': domain,
            'lastVisit': FieldValue.serverTimestamp(),
            'visits': FieldValue.increment(1),
          },
        },
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // On garde aussi l'historique linéaire pour le parent
      await _firestore.collection('$childPath/inventory/websites/history').add({
        'url': url,
        'domain': domain,
        'package': package,
        'searchQuery': searchQuery,
        'title': searchQuery != null && searchQuery.isNotEmpty 
            ? 'Recherche : "$searchQuery"'
            : (Uri.tryParse(url)?.path != null && Uri.tryParse(url)!.path.length > 1 
                ? Uri.tryParse(url)!.path 
                : domain),
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('EnforcementService: 🌐 Web stats and history synced.');
    } catch (e) {
      debugPrint('EnforcementService: _reportUrlHistory error: $e');
    }
  }

  Future<void> _triggerWebBlock(String url, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('onboarding_complete') ?? false)) {
      debugPrint(
        'EnforcementService: Web block triggered ($url) but onboarding_complete=false. Ignoring block.',
      );
      return;
    }

    final domain = Uri.tryParse(url)?.host ?? url;
    if (domain == _lastUrl) return;
    _lastUrl = domain;

    await _alertService.sendAlert(
      type: AlertType.blockedApp,
      detail:
          'Alerte de navigation : Votre enfant a tenté de visiter le site web restreint suivant : $url',
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
    if (!(prefs.getBool('onboarding_complete') ?? false)) {
      debugPrint(
        'EnforcementService: Keyword detected but onboarding_complete=false. Ignoring.',
      );
      return;
    }

    final keyword = event['keyword'] as String? ?? '';
    final pkg = event['package'] as String? ?? '';

    if (keyword.isEmpty) return;

    await _alertService.sendAlert(
      type: AlertType.keywordDetected,
      detail:
          'Alerte de contenu : Le mot-clé sensible "$keyword" a été détecté pendant l\'utilisation de l\'application ${_getAppName(pkg)}.',
    );

    // Déclencher le blocage immédiat pour les mots-clés
    _triggerWebBlock(pkg, 'Contenu inapproprié détecté ("$keyword").');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _getForegroundPackage() async {
    // 1. Priorité à la valeur mise à jour par l'AccessibilityService
    if (_currentForegroundPackage != null &&
        _currentForegroundPackage != 'app.theguardian.child' &&
        !_isSystemApp(_currentForegroundPackage!)) {
      return _currentForegroundPackage;
    }

    // 2. Fallback : UsageStats sur les 30 dernières secondes
    // On cherche la dernière app non-système passée au premier plan
    // AVANT Guardian (qui est elle-même au premier plan pendant les vérifications)
    try {
      final now = DateTime.now();
      final events = await UsageStats.queryEvents(
        now.subtract(const Duration(seconds: 30)),
        now,
      );
      // eventType '1' = MOVE_TO_FOREGROUND
      // On prend tous les foreground events dans l'ordre inverse
      // et on retourne le premier qui n'est pas Guardian ni une app système
      final foregroundEvents = events
          .where((e) => e.eventType == '1')
          .toList()
          .reversed
          .toList();

      for (final event in foregroundEvents) {
        final pkg = event.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        if (pkg == 'app.theguardian.child') continue;
        if (_isSystemApp(pkg)) continue;
        _currentForegroundPackage = pkg;
        return pkg;
      }
    } catch (e) {
      debugPrint('EnforcementService: getForeground fallback error: $e');
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
    _lastReportedMinutes = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final childPath = prefs.getString('child_path');
      final childId = prefs.getString('child_id');
      final parentId = prefs.getString('parent_id');
      if (childPath == null || childId == null) return;

      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      final data = {
        'childId': childId,
        'parentId': parentId,
        'usedMinutes': minutes,
        'totalMinutes': minutes,
        'lastSync': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      };

      // Path principal utilisé par le Dashboard Parent
      final parentPath = '$childPath/alerts/usage/apps/$today';
      await _firestore
          .doc(parentPath)
          .set(data, SetOptions(merge: true));

      debugPrint('EnforcementService: 📤 Real-time stats synced ($minutes min)');
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

  bool _isSystemApp(String pkg) {
    // ✅ Ne jamais considérer comme système une app explicitement bloquée
    final rules = _rulesService.current;
    if (rules.blockedApps.contains(pkg)) return false;
    if (socialMedia.contains(pkg)) return false;
    if (gaming.contains(pkg)) return false;

    // Apps Google utilisateur (bloquables)
    const userGoogleApps = {
      'com.google.android.youtube',
      'com.google.android.apps.youtube.kids',
      'com.google.android.apps.maps',
      'com.google.android.gm',
      'com.google.android.googlequicksearchbox',
    };
    if (userGoogleApps.contains(pkg)) return false;

    // Apps Android utilisateur (bloquables)
    const userAndroidApps = {
      'com.android.chrome',
      'com.android.vending',
    };
    if (userAndroidApps.contains(pkg)) return false;

    // Apps MIUI utilisateur (bloquables)
    const userMiuiApps = {
      'com.miui.gallery',
      'com.miui.video',
      'com.miui.player',
      'com.miui.notes',
      'com.miui.browser',
    };
    if (userMiuiApps.contains(pkg)) return false;

    return pkg.startsWith('com.android.') ||
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
  }

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  ActiveRules get currentRules => _rulesService.current;
}
