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
import 'firestore_sync_queue.dart';
import '../utils/child_path_helper.dart';
import '../utils/system_app_classifier.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

enum BlockState { normal, blocking, blocked, waitingExit }

/// EnforcementService
///
/// Moteur d'application des règles parentales en temps réel.
///
/// Responsabilités :
///   1. Écouter les règles via [RulesService] (stream Firestore temps réel)
///   2. Vérifier l'app au premier plan (AccessibilityService + fallback UsageStats)
///      — tick immédiat à chaque changement de foreground, filet de sécurité toutes les 60s
///   3. Notifier Flutter quand un blocage doit s'afficher
///   4. Mettre à jour l'AccessibilityService avec les packages bloqués
///   5. Incrémenter le compteur de temps d'écran dans Firestore
///   6. Écrire les alertes (type BLOCKED_APP, TIME_LIMIT, OUTSIDE_HOURS, APP_TIME_LIMIT)
///   7. Filtrage Web & Historique via queue SharedPreferences (web_event)
class EnforcementService {
  static final EnforcementService _instance = EnforcementService._internal();
  factory EnforcementService() => _instance;
  EnforcementService._internal() {
    _initializeRules();
  }

  late final List<EnforcementRule> _evaluationRules;

  void _initializeRules() {
    _evaluationRules = [
      AllowedHoursRule(),
      DailyLimitRule(),
      AppTimeLimitRule(
        getAppUsedMinutes: _getAppUsedMinutes,
        getAppName: _getAppName,
      ),
      BlockedAppRule(
        getAppName: _getAppName,
      ),
    ];
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AlertService _alertService = AlertService();
  final RulesService _rulesService = RulesService();

  static const _methodChannel = MethodChannel('app.theguardian.child/system');

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
  Timer? _checkingTimeoutTimer;
  bool _isRunning = false;
  bool _isChecking = false;
  String? _lastUrl;
  String? _lastReportedUrl;
  DateTime? _lastScreenTimeReport;
  DateTime? _lastScreenTimeQuery;
  DateTime? _lastUiUpdate;
  int _lastReportedMinutes = 0;
  bool _initialFastTickDone = false; // Permet un tick rapide au démarrage

  // FIX boucle de blocage : ne ré-afficher l'écran de blocage Flutter que sur
  // une transition non-bloqué -> bloqué, pas à chaque tick tant que c'est bloqué.
  // Sans ça, onBlockRequired est rappelé en boucle (toutes les 60s ou à chaque
  // changement de règles) tant que frontPackage reste sur l'app bloquée, ce qui
  // empile sans fin de nouveaux BlockingScreen via pushAndRemoveUntil.
  String? _lastBlockedSignature;
  
  String? _currentForegroundPackage;

  // Instance du service de background (pour communication inter-isolate)
  ServiceInstance? _backgroundService;

  // Callback vers BackgroundService pour déclencher l'écran de blocage côté Flutter
  void Function(String reason, String package)? onBlockRequired;

  BlockState _blockState = BlockState.normal;
  String? _blockedPackageForState;
  Timer? _waitingExitTimer;

  BlockState get blockState => _blockState;

  void setBlockState(BlockState state, {String? package}) {
    debugPrint('EnforcementService: blockState transition $_blockState -> $state');
    _blockState = state;
    if (state == BlockState.waitingExit) {
      _blockedPackageForState = package;
      _waitingExitTimer?.cancel();
      _waitingExitTimer = Timer(const Duration(seconds: 3), () {
        if (_blockState == BlockState.waitingExit) {
          _blockState = BlockState.normal;
          _blockedPackageForState = null;
          debugPrint('EnforcementService: WAITING_EXIT timer finished. State returned to NORMAL.');
        }
      });
    } else if (state == BlockState.normal) {
      _blockedPackageForState = null;
      _waitingExitTimer?.cancel();
    }
  }

  Future<void> triggerImmediateDrain() async {
    debugPrint('EnforcementService: triggerImmediateDrain() called');
    await _drainEventQueue();
  }

  // ── Démarrage / arrêt ────────────────────────────────────────────────────

  Future<void> start({
    required void Function(String reason, String package) onBlock,
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
        final pendingPkg = prefs.getString('guardian_pending_package') ?? '';
        if (pending != null && pending.isNotEmpty) {
          await prefs.remove('guardian_pending_block');
          await prefs.remove('guardian_pending_package');
          debugPrint('EnforcementService: Consuming pending block: $pending for package: $pendingPkg');
          onBlockRequired?.call(pending, pendingPkg);
        }
      } catch (e) {
        debugPrint('EnforcementService: Pending block read error: $e');
      }
    }

    // Appliquer les règles initiales à l'AccessibilityService
    _onRulesChanged(_rulesService.current);

    // FIX #3 : Tick rapide (5s) au démarrage pour une réaction immédiate,
    // puis passage au tick régulier de 60 secondes.
    Timer(const Duration(seconds: 5), () async {
      if (_isRunning) {
        await _tick(forceQueryUsageStats: true);
        _initialFastTickDone = true;
        _checkTimer = Timer.periodic(const Duration(seconds: 60), (_) => _tick(forceQueryUsageStats: true));
        debugPrint('EnforcementService: Switched to 60s periodic timer.');
      }
    });

    debugPrint('EnforcementService: Started (initial fast tick in 5s).');
  }

  Future<void> stop() async {
    _checkTimer?.cancel();
    _checkTimer = null;
    _checkingTimeoutTimer?.cancel();
    _checkingTimeoutTimer = null;
    _rulesService.removeListener(_onRulesChanged);
    await _rulesService.stop();
    _isRunning = false;
    _isChecking = false;
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
    updateNativeCategoryFilters(rules);

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

  Future<void> updateNativeCategoryFilters(ActiveRules rules) async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guardian_block_adult', rules.blockAdultContent);
      await prefs.setBool('guardian_block_violence', rules.blockViolence);
      await prefs.setBool('guardian_block_gambling', rules.blockGambling);
      await prefs.setBool('guardian_block_drugs', rules.blockDrugs);
      await prefs.setBool('guardian_block_sexual_predators', rules.blockSexualPredators);
      await prefs.setBool('guardian_block_self_harm', rules.blockSelfHarm);
      await prefs.setBool('guardian_block_cyberbullying', rules.blockCyberbullying);
      await prefs.setBool('guardian_block_eating_disorders', rules.blockEatingDisorders);
      debugPrint('EnforcementService: Wrote category filters to SharedPreferences');
    } catch (e) {
      debugPrint('EnforcementService: Failed to write category filters to SharedPreferences: $e');
    }
  }

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

    // In the background isolate the native MethodChannel has no handler — it is
    // registered by MainActivity on the main (UI) isolate. Relay through the
    // background service so the main isolate performs the native call, then
    // return to avoid a guaranteed MissingPluginException every tick.
    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeBlockedPackages', {
        'packages': packageList,
      });
      return;
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

    // Background isolate: relay to the main isolate and return (see
    // updateNativeBlockedPackages for why the direct channel call is skipped).
    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeCustomKeywords', {
        'keywords': keywordList,
      });
      return;
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

    // Background isolate: relay to the main isolate and return (see
    // updateNativeBlockedPackages for why the direct channel call is skipped).
    if (_backgroundService != null) {
      _backgroundService!.invoke('updateNativeBlockedWebsites', {
        'websites': websiteList,
      });
      return;
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

  Future<void> _tick({bool forceQueryUsageStats = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    // FIX #4 : timeout de sécurité — si _tick() dure > 30s, libérer le verrou
    _checkingTimeoutTimer?.cancel();
    _checkingTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isChecking) {
        debugPrint('EnforcementService: ⚠️ _isChecking timeout — force releasing lock.');
        _isChecking = false;
      }
    });
    try {
      debugPrint('EnforcementService: _tick() executing... (forceQueryUsageStats: $forceQueryUsageStats)');
      if (!Platform.isAndroid) return;

      // FIX BUG #1 + #3 : drainer la queue d'événements écrite par GuardianAccessibilityService
      // directement dans FlutterSharedPreferences (indépendant du cycle de vie de MainActivity)
      await _drainEventQueue();

      final rules = _rulesService.current;
      final now = DateTime.now();

      // Déterminer l'app au premier plan
      final frontPackage = await _getForegroundPackage(forceQueryUsageStats: forceQueryUsageStats);
      
      if (_blockState == BlockState.waitingExit && frontPackage == _blockedPackageForState) {
        debugPrint('EnforcementService: Skipping block check in _tick because state is WAITING_EXIT for $frontPackage');
        _checkingTimeoutTimer?.cancel();
        _checkingTimeoutTimer = null;
        _isChecking = false;
        return;
      }
      
      final bool isActivelyTrying = frontPackage != null && !_isSystemApp(frontPackage);

      // Throttling de la vérification de temps journalier (UsageStats) à au plus une fois par 60 secondes
      final bool isTimeCheckTick = forceQueryUsageStats ||
          _lastScreenTimeQuery == null ||
          now.difference(_lastScreenTimeQuery!).inSeconds >= 60;
      
      int usedMinutes;
      if (isTimeCheckTick) {
        usedMinutes = await _getTodayUsedMinutes();
        _lastReportedMinutes = usedMinutes;
        _lastScreenTimeQuery = now;
      } else {
        usedMinutes = _lastReportedMinutes;
      }
      
      debugPrint('EnforcementService: Tick - Front: $frontPackage, isActivelyTrying: $isActivelyTrying, Used: $usedMinutes min (timeCheck: $isTimeCheckTick)');
      
      if (isTimeCheckTick) {
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
      // FIX #1 : onboarding_complete ne bloque plus le BLOCAGE des apps.
      // Il sert uniquement à décider si on envoie des alertes Firestore (pour éviter
      // de spammer des alertes pendant la phase de configuration du device).
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      // Base des packages bloqués configurée par le parent
      final baseBlocked = rules.effectiveBlockedPackages(
        socialMediaPackages: _socialMedia,
        gamingPackages: _gaming,
      );

      final activeBlocked = Set<String>.from(baseBlocked);
      String? blockReason;

      RuleEvaluationResult? winningResult;
      for (final rule in _evaluationRules) {
        final result = await rule.evaluate(
          frontPackage: frontPackage,
          rules: rules,
          usedMinutes: usedMinutes,
          now: now,
          onboardingComplete: onboardingComplete,
          isActivelyTrying: isActivelyTrying,
          baseBlockedPackages: baseBlocked,
        );
        if (result.isBlocked) {
          winningResult = result;
          break;
        }
      }

      if (winningResult != null) {
        blockReason = winningResult.blockReason;
        
        // Gérer l'envoi d'alertes s'il y a un détail d'alerte à notifier
        if (winningResult.alertDetail != null && winningResult.alertType != null) {
          await _alertService.sendAlert(
            type: winningResult.alertType!,
            cooldownKey: winningResult.cooldownKey,
            detail: winningResult.alertDetail!,
          );
        }

        if (frontPackage != null && frontPackage != 'app.theguardian.child' && !_isSystemApp(frontPackage)) {
          activeBlocked.add(frontPackage);
        }
      }

      // Écrire les motifs de blocage dans SharedPreferences pour que le natif et l'UI les lisent
      if (blockReason != null && frontPackage != null) {
        await prefs.setString('guardian_block_reason', blockReason);
        await prefs.setString('guardian_block_reason_$frontPackage', blockReason);

        // FIX boucle de blocage : signature unique de cet état de blocage
        // (app + motif). On ne notifie l'UI que si cette signature est
        // nouvelle par rapport au tick précédent — pas à chaque tick tant
        // que la même app reste bloquée au premier plan.
        final blockSignature = '$frontPackage|$blockReason';
        if (blockSignature != _lastBlockedSignature) {
          _lastBlockedSignature = blockSignature;
          if (_blockState == BlockState.normal) {
            setBlockState(BlockState.blocking, package: frontPackage);
            onBlockRequired?.call(blockReason, frontPackage ?? '');
          }
        }
      } else if (frontPackage != null) {
        await prefs.remove('guardian_block_reason_$frontPackage');
        _lastBlockedSignature = null;
        if (_blockState == BlockState.blocked || _blockState == BlockState.blocking) {
          setBlockState(BlockState.normal);
        }
      } else {
        // Aucune app au premier plan détectée (ex: retour à l'accueil) :
        // on réinitialise pour permettre un nouveau blocage à la prochaine détection.
        _lastBlockedSignature = null;
        if (_blockState == BlockState.blocked || _blockState == BlockState.blocking) {
          setBlockState(BlockState.normal);
        }
      }

      // Mettre à jour la liste des packages bloqués
      await updateNativeBlockedPackages(activeBlocked);
    } catch (e, stack) {
      debugPrint('EnforcementService: Error in _tick: $e\n$stack');
    } finally {
      _checkingTimeoutTimer?.cancel();
      _checkingTimeoutTimer = null;
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
    if (pkg == null || pkg.isEmpty) return;

    if (_blockState == BlockState.waitingExit && pkg == _blockedPackageForState) {
      debugPrint('EnforcementService: Ignoring native foreground event for $pkg because state is WAITING_EXIT');
      return;
    }

    if (pkg == 'app.theguardian.child' || _isSystemApp(pkg)) {
      // FIX boucle de blocage : un retour à l'accueil (launcher système) ou
      // sur Guardian lui-même doit LIBÉRER frontPackage, pas être ignoré.
      // L'ancien code ignorait silencieusement ces événements, ce qui
      // laissait _currentForegroundPackage figé sur la dernière app bloquée
      // indéfiniment — chaque tick redétectait alors cette app comme "au
      // premier plan" et redéclenchait le blocage en boucle, même quand
      // l'enfant était revenu sur le dashboard de Guardian.
      if (_currentForegroundPackage != null) {
        debugPrint('EnforcementService: Foreground returned to system/self ($pkg) — clearing frontPackage.');
        _currentForegroundPackage = null;
        if (!_isChecking) {
          Future.microtask(_tick);
        }
      }
      return;
    }

    if (_currentForegroundPackage != pkg) {
      _currentForegroundPackage = pkg;
      debugPrint('EnforcementService: Foreground package updated: $pkg');
      if (!_isChecking) {
        Future.microtask(_tick);
      }
    }
  }

  static Database? _eventDb;

  Future<Database> _getEventDatabase() async {
    if (_eventDb != null && _eventDb!.isOpen) return _eventDb!;
    final dbFolder = await getDatabasesPath();
    final dbPath = p.join(dbFolder, 'guardian_history.db');
    _eventDb = await openDatabase(dbPath);
    return _eventDb!;
  }

  /// Draine la queue d'événements persistante depuis SQLite/Room (et SharedPreferences en secours).
  Future<void> _drainEventQueue() async {
    try {
      // 1. Compatibilité descendante : draine d'abord SharedPreferences s'il reste des clés
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final keys = prefs.getKeys().where((k) => k.startsWith('guardian_event_') && k != 'guardian_event_queue').toList();
      if (keys.isNotEmpty) {
        debugPrint('EnforcementService: Draining ${keys.length} legacy SharedPreferences events.');
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
               debugPrint('EnforcementService: Error parsing legacy event $key: $e');
             }
          }
          await prefs.remove(key);
        }
      }

      // 2. Drainage SQLite/Room principal
      final db = await _getEventDatabase();
      
      // Vérifier si la table sync_events existe (évite les exceptions lors de la création initiale)
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sync_events'");
      if (tables.isEmpty) {
        return;
      }

      final List<Map<String, dynamic>> rows = await db.query(
        'sync_events',
        orderBy: 'id ASC',
      );

      if (rows.isEmpty) return;

      debugPrint('EnforcementService: Draining ${rows.length} Room queued events.');

      final List<int> idsToDelete = [];

      for (final row in rows) {
        final id = row['id'] as int;
        final action = row['action'] as String;
        final payloadStr = row['payload'] as String;
        
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          final event = {
            'action': action,
            ...payload,
          };
          
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
          idsToDelete.add(id);
        } catch (e) {
          debugPrint('EnforcementService: Error parsing Room event id $id: $e');
          idsToDelete.add(id); // On supprime pour éviter de bloquer la file
        }
      }

      if (idsToDelete.isNotEmpty) {
        await db.delete(
          'sync_events',
          where: 'id IN (${idsToDelete.join(',')})',
        );
        debugPrint('EnforcementService: Deleted ${idsToDelete.length} Room events.');
      }
    } catch (e) {
      debugPrint('EnforcementService: _drainEventQueue (Room) error: $e');
    }
  }

  // ── Web Filtering ────────────────────────────────────────────────────────

  void _onUrlDetected(Map<dynamic, dynamic> event) {
    if (!_isRunning) return;
    final url = (event['url'] as String? ?? '').toLowerCase();
    final pkg = (event['package'] as String? ?? '');
    String? searchQuery = event['searchQuery'] as String?;
    final String? title = event['title'] as String?;
    final String? category = event['category'] as String?;
    final String? riskLevel = event['riskLevel'] as String?;
    final bool isSiteBlocked = event['isSiteBlocked'] as bool? ?? false;
    final bool isWordBlocked = event['isWordBlocked'] as bool? ?? false;
    final String status = event['status'] as String? ?? 'Autorisé';
    final String? date = event['date'] as String?;
    final String? time = event['time'] as String?;
    final rules = _rulesService.current;

    if (url.isEmpty) return;

    // 1. Extraire la requête de recherche si absente
    if (searchQuery == null || searchQuery.isEmpty) {
      searchQuery = _extractSearchQuery(url);
    }

    // Historique
    if (url != _lastReportedUrl) {
      _lastReportedUrl = url;
      _reportUrlHistory(
        url,
        pkg,
        searchQuery: searchQuery,
        title: title,
        category: category,
        riskLevel: riskLevel,
        isSiteBlocked: isSiteBlocked,
        isWordBlocked: isWordBlocked,
        status: status,
        date: date,
        time: time,
      );
    }

    if (status == 'Bloqué') {
      final domain = Uri.tryParse(url)?.host ?? url;
      final isRealSearch = isWordBlocked && searchQuery != null && searchQuery.isNotEmpty;
      _alertService.sendAlert(
        type: AlertType.blockedApp,
        cooldownKey: isRealSearch ? 'search:$searchQuery' : 'web:$domain',
        detail: isRealSearch
            ? 'Alerte de recherche : Votre enfant a recherché "$searchQuery" (Mot ou catégorie bloqué(e)).'
            : 'Alerte de navigation : Votre enfant a tenté de visiter le site restreint $url.',
      );
      return;
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // 2. Détecter si la recherche porte sur des catégories restreintes (fallback)
      bool shouldBlock = false;
      String cat = '';

      if (rules.blockAdultContent && _matchesKeywords(searchQuery, _adultKeywords)) {
        shouldBlock = true; cat = 'Contenu Adulte';
      } else if (rules.blockViolence && _matchesKeywords(searchQuery, _violenceKeywords)) {
        shouldBlock = true; cat = 'Violence';
      } else if (rules.blockGambling && _matchesKeywords(searchQuery, _gamblingKeywords)) {
        shouldBlock = true; cat = 'Jeux d\'argent';
      } else if (rules.blockDrugs && _matchesKeywords(searchQuery, _drugsKeywords)) {
        shouldBlock = true; cat = 'Drogues';
      } else if (rules.blockSexualPredators && _matchesKeywords(searchQuery, _predatorsKeywords)) {
        shouldBlock = true; cat = 'Rencontres/Prédateurs';
      } else if (rules.blockSelfHarm && _matchesKeywords(searchQuery, _selfHarmKeywords)) {
        shouldBlock = true; cat = 'Auto-mutilation';
      } else if (rules.blockCyberbullying && _matchesKeywords(searchQuery, _bullyingKeywords)) {
        shouldBlock = true; cat = 'Cyber-harcèlement';
      } else if (rules.blockEatingDisorders && _matchesKeywords(searchQuery, _eatingKeywords)) {
        shouldBlock = true; cat = 'Troubles alimentaires';
      }

      if (shouldBlock) {
        _triggerWebSearchBlock(url, searchQuery, cat);
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
      cooldownKey: 'search:$searchQuery',
      detail: 'Votre enfant a cherché "$searchQuery"',
    );

    final reason = 'Recherche restreinte détectée ("$searchQuery").';
    final pkg = _currentForegroundPackage ?? '';
    onBlockRequired?.call(reason, pkg);
    if (_backgroundService != null) {
      _backgroundService!.invoke('triggerBlock', {'reason': reason, 'package': pkg});
    }
  }

  Future<void> _reportUrlHistory(
    String url,
    String package, {
    String? searchQuery,
    String? title,
    String? category,
    String? riskLevel,
    bool? isSiteBlocked,
    bool? isWordBlocked,
    String? status,
    String? date,
    String? time,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final childPath = await readChildPath(prefs);
      if (childPath == null) return;

      final today = _todayString();
      final domain = Uri.tryParse(url)?.host ?? url;
      if (domain.isEmpty) return;

      // Chemin EXACT attendu par le parent pour les stats web
      final webStatsPath = '$childPath/alerts/usage/websites/$today';

      await FirestoreSyncQueue().queueSet(webStatsPath, {
        'totalMinutes': 0, // Optionnel, le parent additionne
        'websites': {
          domain.replaceAll('.', '_'): {
            'domain': domain,
            'lastVisit': FieldValue.serverTimestamp(),
            'visits': FieldValue.increment(1),
          },
        },
        'lastSync': FieldValue.serverTimestamp(),
      }, merge: true);

      // On garde aussi l'historique linéaire pour le parent via FirestoreSyncQueue
      await FirestoreSyncQueue().queueAdd('$childPath/inventory/websites/history', {
        'url': url,
        'domain': domain,
        'package': package,
        'searchQuery': searchQuery,
        'title': title ?? (searchQuery != null && searchQuery.isNotEmpty 
            ? 'Recherche : "$searchQuery"'
            : (Uri.tryParse(url)?.path != null && Uri.tryParse(url)!.path.length > 1 
                ? Uri.tryParse(url)!.path 
                : domain)),
        'category': category ?? 'Aucune',
        'riskLevel': riskLevel ?? 'Faible',
        'isSiteBlocked': isSiteBlocked ?? false,
        'isWordBlocked': isWordBlocked ?? false,
        'status': status ?? 'Autorisé',
        'date': date ?? today,
        'time': time ?? '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      debugPrint('EnforcementService: 🌐 Enriched web history synced to Firestore.');
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
      cooldownKey: 'web:$domain',
      detail:
          'Alerte de navigation : Votre enfant a tenté de visiter le site web restreint suivant : $url',
    );

    final pkg = (url.contains('.') && !url.contains('/')) ? url : (_currentForegroundPackage ?? '');
    if (_blockState == BlockState.normal) {
      setBlockState(BlockState.blocking, package: pkg);
      onBlockRequired?.call(reason, pkg);
      if (_backgroundService != null) {
        _backgroundService!.invoke('triggerBlock', {'reason': reason, 'package': pkg});
      }
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
      cooldownKey: keyword,
      detail:
          'Alerte de contenu : Le mot-clé sensible "$keyword" a été détecté pendant l\'utilisation de l\'application ${_getAppName(pkg)}.',
    );

    // Déclencher le blocage immédiat pour les mots-clés
    _triggerWebBlock(pkg, 'Contenu inapproprié détecté ("$keyword").');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _getForegroundPackage({bool forceQueryUsageStats = false}) async {
    // 1. Priorité à la valeur mise à jour par l'AccessibilityService
    if (!forceQueryUsageStats && _currentForegroundPackage != null) {
      if (_currentForegroundPackage == 'app.theguardian.child' || _isSystemApp(_currentForegroundPackage!)) {
        return null;
      }
      return _currentForegroundPackage;
    }

    // 2. Fallback / Watchdog : UsageStats sur les 30 dernières secondes
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
        // FIX boucle de blocage : si l'événement le plus récent est un retour
        // à l'accueil / au launcher / à Guardian lui-même, cela signifie que
        // l'utilisateur a QUITTÉ l'app précédente. Il ne faut pas continuer à
        // chercher plus loin dans le passé (sinon on retombe sur l'ancienne
        // app, ex: WhatsApp, alors que l'enfant est en réalité revenu sur le
        // dashboard) — il faut s'arrêter et considérer qu'aucune app
        // utilisateur n'est au premier plan.
        if (pkg == 'app.theguardian.child' || _isSystemApp(pkg)) {
          _currentForegroundPackage = null;
          return null;
        }
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
      final childPath = await readChildPath(prefs);
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
      await FirestoreSyncQueue().queueSet(parentPath, data, merge: true);

      debugPrint('EnforcementService: 📤 Real-time stats enqueued ($minutes min)');
    } catch (e) {
      debugPrint('EnforcementService: _reportScreenTime error: $e');
    }
  }

  bool _isSystemApp(String pkg) => SystemAppClassifier.forEnforcement(
        pkg,
        blockedByParent: _rulesService.current.blockedApps,
        additionalUserPackages: {...socialMedia, ...gaming},
      );

  String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  ActiveRules get currentRules => _rulesService.current;
}

// ─── Rule Engine Abstract Interfaces & Rule Implementations ──────────────────

abstract class EnforcementRule {
  String get name;
  Future<RuleEvaluationResult> evaluate({
    required String? frontPackage,
    required ActiveRules rules,
    required int usedMinutes,
    required DateTime now,
    required bool onboardingComplete,
    required bool isActivelyTrying,
    required Set<String> baseBlockedPackages,
  });
}

class RuleEvaluationResult {
  final bool isBlocked;
  final String? blockReason;
  final AlertType? alertType;
  final String? cooldownKey;
  final String? alertDetail;

  RuleEvaluationResult.allow()
      : isBlocked = false,
        blockReason = null,
        alertType = null,
        cooldownKey = null,
        alertDetail = null;

  RuleEvaluationResult.block({
    required this.blockReason,
    this.alertType,
    this.cooldownKey,
    this.alertDetail,
  }) : isBlocked = true;
}

class AllowedHoursRule implements EnforcementRule {
  @override
  String get name => 'AllowedHours';

  DateTime? _lastAlert;

  @override
  Future<RuleEvaluationResult> evaluate({
    required String? frontPackage,
    required ActiveRules rules,
    required int usedMinutes,
    required DateTime now,
    required bool onboardingComplete,
    required bool isActivelyTrying,
    required Set<String> baseBlockedPackages,
  }) async {
    final bool isOutside = _isOutsideAllowedHours(rules, now);
    if (!isOutside) return RuleEvaluationResult.allow();

    final start = rules.allowedTimeStart ?? '';
    final end = rules.allowedTimeEnd ?? '';
    final reason = 'Utilisation hors heures autorisées ($start – $end).';

    String? alertDetail;
    if (onboardingComplete && isActivelyTrying) {
      if (_lastAlert == null || now.difference(_lastAlert!).inMinutes >= 10) {
        _lastAlert = now;
        alertDetail = 'Alerte d\'activité : Votre enfant a tenté d\'utiliser son téléphone en dehors des heures autorisées (de $start à $end).';
      }
    }

    return RuleEvaluationResult.block(
      blockReason: reason,
      alertType: AlertType.outsideHours,
      alertDetail: alertDetail,
    );
  }

  bool _isOutsideAllowedHours(ActiveRules rules, DateTime now) {
    final start = rules.allowedTimeStart;
    final end = rules.allowedTimeEnd;
    if (start == null || end == null) return false;

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
}

class DailyLimitRule implements EnforcementRule {
  @override
  String get name => 'DailyLimit';

  DateTime? _lastAlert;

  @override
  Future<RuleEvaluationResult> evaluate({
    required String? frontPackage,
    required ActiveRules rules,
    required int usedMinutes,
    required DateTime now,
    required bool onboardingComplete,
    required bool isActivelyTrying,
    required Set<String> baseBlockedPackages,
  }) async {
    final bool isLimitReached = rules.dailyLimitMinutes > 0 && usedMinutes >= rules.dailyLimitMinutes;
    if (!isLimitReached) return RuleEvaluationResult.allow();

    final reason = 'Temps d\'écran journalier écoulé.';

    String? alertDetail;
    if (onboardingComplete && isActivelyTrying) {
      if (_lastAlert == null || now.difference(_lastAlert!).inMinutes >= 10) {
        _lastAlert = now;
        alertDetail = 'Alerte de limite : Votre enfant a tenté d\'utiliser son téléphone alors que sa limite de temps d\'écran journalière (${rules.dailyLimitMinutes} minutes) est déjà épuisée.';
      }
    }

    return RuleEvaluationResult.block(
      blockReason: reason,
      alertType: AlertType.timeLimit,
      alertDetail: alertDetail,
    );
  }
}

class AppTimeLimitRule implements EnforcementRule {
  @override
  String get name => 'AppTimeLimit';

  final Future<int> Function(String) getAppUsedMinutes;
  final String Function(String) getAppName;

  AppTimeLimitRule({required this.getAppUsedMinutes, required this.getAppName});

  final Map<String, int> _cachedUsedMinutes = {};
  final Map<String, DateTime> _lastQueryTime = {};

  @override
  Future<RuleEvaluationResult> evaluate({
    required String? frontPackage,
    required ActiveRules rules,
    required int usedMinutes,
    required DateTime now,
    required bool onboardingComplete,
    required bool isActivelyTrying,
    required Set<String> baseBlockedPackages,
  }) async {
    if (frontPackage == null) return RuleEvaluationResult.allow();

    final appLimit = rules.appTimeLimits[frontPackage];
    if (appLimit == null || appLimit <= 0) return RuleEvaluationResult.allow();

    int appUsedMinutes;
    final lastQuery = _lastQueryTime[frontPackage];
    if (lastQuery == null || now.difference(lastQuery).inSeconds >= 60) {
      appUsedMinutes = await getAppUsedMinutes(frontPackage);
      _cachedUsedMinutes[frontPackage] = appUsedMinutes;
      _lastQueryTime[frontPackage] = now;
    } else {
      appUsedMinutes = _cachedUsedMinutes[frontPackage] ?? 0;
    }

    if (appUsedMinutes < appLimit) return RuleEvaluationResult.allow();

    final reason = 'Limite de temps pour cette application atteinte.';
    String? alertDetail;

    if (onboardingComplete) {
      alertDetail = 'Alerte de temps : Votre enfant a essayé d\'ouvrir l\'application ${getAppName(frontPackage)}, mais sa limite d\'utilisation pour cette application ($appLimit minutes) est atteinte.';
    }

    return RuleEvaluationResult.block(
      blockReason: reason,
      alertType: AlertType.appTimeLimit,
      cooldownKey: frontPackage,
      alertDetail: alertDetail,
    );
  }
}

class BlockedAppRule implements EnforcementRule {
  @override
  String get name => 'BlockedApp';

  final String Function(String) getAppName;
  String? _lastPackage;

  BlockedAppRule({required this.getAppName});

  @override
  Future<RuleEvaluationResult> evaluate({
    required String? frontPackage,
    required ActiveRules rules,
    required int usedMinutes,
    required DateTime now,
    required bool onboardingComplete,
    required bool isActivelyTrying,
    required Set<String> baseBlockedPackages,
  }) async {
    if (frontPackage == null) return RuleEvaluationResult.allow();

    final isBlocked = baseBlockedPackages.contains(frontPackage);
    if (!isBlocked) {
      _lastPackage = null;
      return RuleEvaluationResult.allow();
    }

    final reason = 'Cette application est bloquée par vos parents.';
    String? alertDetail;

    if (frontPackage != _lastPackage) {
      _lastPackage = frontPackage;
      if (onboardingComplete) {
        alertDetail = 'Alerte de sécurité : Votre enfant a tenté d\'ouvrir l\'application ${getAppName(frontPackage)}, qui fait partie des applications que vous avez bloquées.';
      }
    }

    return RuleEvaluationResult.block(
      blockReason: reason,
      alertType: AlertType.blockedApp,
      cooldownKey: frontPackage,
      alertDetail: alertDetail,
    );
  }
}