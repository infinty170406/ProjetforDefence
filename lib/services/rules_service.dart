import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Geofence
///
/// Représente une zone de sécurité (Maison, École, etc.).
class Geofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // en mètres

  const Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory Geofence.fromFirestore(Map<String, dynamic> data) {
    return Geofence(
      id:        data['id']        as String? ?? '',
      name:      data['name']      as String? ?? 'Zone Sans Nom',
      latitude:  (data['latitude']  as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      radius:    (data['radius']    as num?)?.toDouble() ?? 100.0,
    );
  }

  @override
  String toString() => 'Geofence($name, r=$radius)';
}

/// ActiveRules
///
/// Représente l'état courant des règles configurées par le parent.
/// Tous les champs sont optionnels — une règle absente = non configurée = pas de restriction.
class ActiveRules {
  /// Apps individuellement bloquées (packages Android ex: "com.tiktok")
  final Set<String> blockedApps;

  /// Limite journalière de temps d'écran en minutes (0 = pas de limite)
  final int dailyLimitMinutes;

  /// Plage horaire autorisée — heure de début "HH:MM" (null = pas de restriction)
  final String? allowedTimeStart;

  /// Plage horaire autorisée — heure de fin "HH:MM" (null = pas de restriction)
  final String? allowedTimeEnd;

  /// Bloquer tous les packages de la catégorie réseaux sociaux
  final bool blockSocialMedia;

  /// Bloquer tous les packages de la catégorie jeux
  final bool blockGaming;

  /// [NEW] Liste des domaines web bloqués (ex: "facebook.com")
  final Set<String> blockedWebsites;

  /// [NEW] Activer le filtrage de contenu adulte (violence, contenu explicite)
  final bool blockAdultContent;

  /// [NEW] Bloquer les contenus violents
  final bool blockViolence;

  /// [NEW] Bloquer les sites de jeux d'argent/paris
  final bool blockGambling;

  /// [NEW] Mots-clés personnalisés (frappe clavier / écran)
  final Set<String> customKeywords;

  /// [NEW] Zones de sécurité GPS
  final List<Geofence> geofences;

  /// [NEW] Limites de temps par application (PackageName -> Minutes)
  final Map<String, int> appTimeLimits;

  // Content Filtering (Granular)
  final bool blockDrugs;
  final bool blockSexualPredators;
  final bool blockAnxietyDepression;
  final bool blockSelfHarm;
  final bool blockCyberbullying;
  final bool blockMatureContent;
  final bool blockEatingDisorders;
  final bool monitorAccountActivity;
  final bool locationAlerts;

  const ActiveRules({
    this.blockedApps       = const {},
    this.dailyLimitMinutes = 0,
    this.allowedTimeStart,
    this.allowedTimeEnd,
    this.blockSocialMedia  = false,
    this.blockGaming       = false,
    this.blockedWebsites   = const {},
    this.blockAdultContent = false,
    this.blockViolence     = false,
    this.blockGambling     = false,
    this.customKeywords    = const {},
    this.geofences         = const [],
    this.appTimeLimits     = const {},
    this.blockDrugs        = false,
    this.blockSexualPredators = false,
    this.blockAnxietyDepression = false,
    this.blockSelfHarm     = false,
    this.blockCyberbullying = false,
    this.blockMatureContent = false,
    this.blockEatingDisorders = false,
    this.monitorAccountActivity = false,
    this.locationAlerts    = false,
  });

  /// Règles vides = aucune restriction active
  static const empty = ActiveRules();

  factory ActiveRules.fromFirestore(Map<String, dynamic> data) {
    try {
      final apps = data['blockedApps'] as List<dynamic>? ?? [];
      final webs = data['blockedWebsites'] as List<dynamic>? ?? [];
      final keys = data['customKeywords'] as List<dynamic>? ?? [];
      final geos = data['geofences']   as List<dynamic>? ?? [];
      final limits = data['appTimeLimits'] as Map<String, dynamic>? ?? {};
      
      return ActiveRules(
        blockedApps:       apps.map((e) => e.toString()).toSet(),
        dailyLimitMinutes: (data['dailyLimitMinutes'] as num?)?.toInt() ?? 0,
        allowedTimeStart:  data['allowedTimeStart']  as String?,
        allowedTimeEnd:    data['allowedTimeEnd']    as String?,
        blockSocialMedia:  data['blockSocialMedia']  as bool? ?? false,
        blockGaming:       data['blockGaming']       as bool? ?? false,
        blockedWebsites:   webs.map((e) => e.toString()).toSet(),
        blockAdultContent: data['blockAdultContent'] as bool? ?? true,
        blockViolence:     data['blockViolence']     as bool? ?? true,
        blockGambling:     data['blockGambling']     as bool? ?? false,
        customKeywords:    keys.map((e) => e.toString()).toSet(),
        geofences: geos
            .whereType<Map>()
            .map((e) => Geofence.fromFirestore(Map<String, dynamic>.from(e)))
            .toList(),
        appTimeLimits:     limits.map((k, v) => MapEntry(k, (v as num).toInt())),
        blockDrugs:        data['blockDrugs']        as bool? ?? true,
        blockSexualPredators: data['blockSexualPredators'] as bool? ?? true,
        blockAnxietyDepression: data['blockAnxietyDepression'] as bool? ?? false,
        blockSelfHarm:     data['blockSelfHarm']     as bool? ?? true,
        blockCyberbullying: data['blockCyberbullying'] as bool? ?? true,
        blockMatureContent: data['blockMatureContent'] as bool? ?? false,
        blockEatingDisorders: data['blockEatingDisorders'] as bool? ?? false,
        monitorAccountActivity: data['monitorAccountActivity'] as bool? ?? true,
        locationAlerts:    data['locationAlerts']    as bool? ?? true,
      );
    } catch (e, stack) {
      debugPrint('ActiveRules: Error parsing rules data: $e');
      debugPrint('ActiveRules: Stack trace: $stack');
      // On lance l'erreur au lieu de renvoyer empty pour que RulesService préserve le cache.
      throw FormatException('Failed to parse ActiveRules: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'blockedApps':       blockedApps.toList(),
      'dailyLimitMinutes': dailyLimitMinutes,
      'allowedTimeStart':  allowedTimeStart,
      'allowedTimeEnd':    allowedTimeEnd,
      'blockSocialMedia':  blockSocialMedia,
      'blockGaming':       blockGaming,
      'blockedWebsites':   blockedWebsites.toList(),
      'blockAdultContent': blockAdultContent,
      'blockViolence':     blockViolence,
      'blockGambling':     blockGambling,
      'customKeywords':    customKeywords.toList(),
      'geofences':         geofences.map((g) => {
        'id': g.id,
        'name': g.name,
        'latitude': g.latitude,
        'longitude': g.longitude,
        'radius': g.radius,
      }).toList(),
      'appTimeLimits':     appTimeLimits,
      'blockDrugs':        blockDrugs,
      'blockSexualPredators': blockSexualPredators,
      'blockAnxietyDepression': blockAnxietyDepression,
      'blockSelfHarm':     blockSelfHarm,
      'blockCyberbullying': blockCyberbullying,
      'blockMatureContent': blockMatureContent,
      'blockEatingDisorders': blockEatingDisorders,
      'monitorAccountActivity': monitorAccountActivity,
      'locationAlerts':    locationAlerts,
    };
  }

  /// Retourne l'ensemble complet des packages effectivement bloqués
  /// (règles individuelles + catégories).
  Set<String> effectiveBlockedPackages({
    required Set<String> socialMediaPackages,
    required Set<String> gamingPackages,
  }) {
    final result = <String>{...blockedApps};
    if (blockSocialMedia) result.addAll(socialMediaPackages);
    if (blockGaming)      result.addAll(gamingPackages);
    return result;
  }

  bool get hasAnyRule =>
      blockedApps.isNotEmpty ||
      dailyLimitMinutes > 0  ||
      allowedTimeStart != null ||
      blockSocialMedia ||
      blockGaming ||
      blockedWebsites.isNotEmpty ||
      blockAdultContent ||
      blockViolence ||
      blockGambling ||
      blockDrugs ||
      blockSexualPredators ||
      blockAnxietyDepression ||
      blockSelfHarm ||
      blockCyberbullying ||
      blockMatureContent ||
      blockEatingDisorders ||
      appTimeLimits.isNotEmpty ||
      customKeywords.isNotEmpty ||
      geofences.isNotEmpty;

  ActiveRules copyWith({
    Set<String>? blockedApps,
    int? dailyLimitMinutes,
    String? allowedTimeStart,
    String? allowedTimeEnd,
    bool? blockSocialMedia,
    bool? blockGaming,
    Set<String>? blockedWebsites,
    bool? blockAdultContent,
    bool? blockViolence,
    bool? blockGambling,
    Set<String>? customKeywords,
    List<Geofence>? geofences,
    Map<String, int>? appTimeLimits,
    bool? blockDrugs,
    bool? blockSexualPredators,
    bool? blockAnxietyDepression,
    bool? blockSelfHarm,
    bool? blockCyberbullying,
    bool? blockMatureContent,
    bool? blockEatingDisorders,
    bool? monitorAccountActivity,
    bool? locationAlerts,
  }) {
    return ActiveRules(
      blockedApps:       blockedApps ?? this.blockedApps,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      allowedTimeStart:  allowedTimeStart ?? this.allowedTimeStart,
      allowedTimeEnd:    allowedTimeEnd ?? this.allowedTimeEnd,
      blockSocialMedia:  blockSocialMedia ?? this.blockSocialMedia,
      blockGaming:       blockGaming ?? this.blockGaming,
      blockedWebsites:   blockedWebsites ?? this.blockedWebsites,
      blockAdultContent: blockAdultContent ?? this.blockAdultContent,
      blockViolence:     blockViolence ?? this.blockViolence,
      blockGambling:     blockGambling ?? this.blockGambling,
      customKeywords:    customKeywords ?? this.customKeywords,
      geofences:         geofences ?? this.geofences,
      appTimeLimits:     appTimeLimits ?? this.appTimeLimits,
      blockDrugs:        blockDrugs ?? this.blockDrugs,
      blockSexualPredators: blockSexualPredators ?? this.blockSexualPredators,
      blockAnxietyDepression: blockAnxietyDepression ?? this.blockAnxietyDepression,
      blockSelfHarm:     blockSelfHarm ?? this.blockSelfHarm,
      blockCyberbullying: blockCyberbullying ?? this.blockCyberbullying,
      blockMatureContent: blockMatureContent ?? this.blockMatureContent,
      blockEatingDisorders: blockEatingDisorders ?? this.blockEatingDisorders,
      monitorAccountActivity: monitorAccountActivity ?? this.monitorAccountActivity,
      locationAlerts:    locationAlerts ?? this.locationAlerts,
    );
  }

  @override
  String toString() =>
      'ActiveRules(apps=${blockedApps.length}, limit=$dailyLimitMinutes, '
      'hours=$allowedTimeStart-$allowedTimeEnd, '
      'social=$blockSocialMedia, gaming=$blockGaming, '
      'websites=${blockedWebsites.length}, adult=$blockAdultContent, '
      'keywords=${customKeywords.length}, '
      'geos=${geofences.length})';
}

/// RulesService
///
/// Écoute en **temps réel** le document Firestore `{childPath}/rules/active`.
/// Chaque modification faite par le parent est reçue instantanément et
/// propagée à tous les listeners (EnforcementService, AppState, UI).
///
/// Pattern : stream + callback pour permettre une utilisation depuis
/// l'isolate background du foreground service.
class RulesService {
  static final RulesService _instance = RulesService._internal();
  factory RulesService() => _instance;
  RulesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _retryTimer;
  ActiveRules _current = ActiveRules.empty;
  bool _isStarting = false;
  int _retryCount = 0;

  final List<void Function(ActiveRules)> _listeners = [];

  ActiveRules get current => _current;

  static const String _cacheKey = 'cached_rules';
  static const String _monitoredPackagesKey =
      'monitored_notification_packages';
  static const String _monitorAccountActivityKey =
      'guardian_monitor_account_activity';
  static const String _locationAlertsKey = 'guardian_location_alerts';

  /// Starts the only Firestore listener authorized by the parent backend:
  /// `parents/{parentId}/children/{childId}/rules/active`.
  ///
  /// The previous collection-group fallback could not satisfy the parent's
  /// security rules and could also select another child's rules document.
  Future<void> start({bool waitForFirstLoad = false}) async {
    if (_subscription != null || _isStarting) return;
    _isStarting = true;

    Completer<void>? firstLoadCompleter =
        waitForFirstLoad ? Completer<void>() : null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        try {
          _current = ActiveRules.fromFirestore(
            Map<String, dynamic>.from(json.decode(cachedJson) as Map),
          );
          _notifyListeners();
          if (firstLoadCompleter != null &&
              !firstLoadCompleter.isCompleted) {
            firstLoadCompleter.complete();
          }
        } catch (e) {
          debugPrint('RulesService: Invalid local rules cache: $e');
        }
      }

      final parentId = prefs.getString('parent_id');
      final childId = prefs.getString('child_id');
      if (parentId == null || childId == null) {
        debugPrint('RulesService: Pairing identifiers are missing.');
        if (firstLoadCompleter != null &&
            !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
        return;
      }

      _listenToFirestoreDirect(
        parentId,
        childId,
        firstLoadCompleter: firstLoadCompleter,
      );

      if (firstLoadCompleter != null) {
        await firstLoadCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              debugPrint('RulesService: Initial rules load timed out.'),
        );
      }
    } finally {
      _isStarting = false;
    }
  }

  void _listenToFirestoreDirect(
    String parentId,
    String childId, {
    Completer<void>? firstLoadCompleter,
  }) {
    _subscription?.cancel();
    _retryTimer?.cancel();

    final docRef = _firestore.doc(
      'parents/$parentId/children/$childId/rules/active',
    );

    _subscription = docRef.snapshots().listen(
      (snapshot) async {
        _retryCount = 0;
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          _current = ActiveRules.empty;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_cacheKey);
          await prefs.remove(_monitoredPackagesKey);
          await prefs.setBool(_monitorAccountActivityKey, false);
          await prefs.setBool(_locationAlertsKey, false);
          await prefs.remove('gemini_api_key');
          await prefs.remove('flutter.gemini_api_key');
        } else {
          try {
            final parsed = ActiveRules.fromFirestore(data);
            _current = parsed;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, json.encode(parsed.toMap()));
            await prefs.setBool(
              _monitorAccountActivityKey,
              parsed.monitorAccountActivity,
            );
            await prefs.setBool(_locationAlertsKey, parsed.locationAlerts);

            final packages = data['monitoredNotificationPackages'] ??
                data['monitored_notification_packages'];
            if (packages is List) {
              await prefs.setString(
                _monitoredPackagesKey,
                json.encode(packages.map((e) => e.toString()).toList()),
              );
            } else {
              await prefs.remove(_monitoredPackagesKey);
            }

            // Provider API keys are intentionally never copied to the device.
            await prefs.remove('gemini_api_key');
            await prefs.remove('flutter.gemini_api_key');
          } catch (e) {
            debugPrint(
              'RulesService: Invalid rules payload; keeping last valid rules: $e',
            );
          }
        }

        _notifyListeners();
        if (firstLoadCompleter != null &&
            !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
      },
      onError: (Object error) {
        debugPrint('RulesService: Rules listener failed: $error');
        if (firstLoadCompleter != null &&
            !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
        _scheduleRetry(parentId, childId);
      },
    );
  }

  void _scheduleRetry(String parentId, String childId) {
    _retryTimer?.cancel();
    _retryCount += 1;
    final seconds = (_retryCount * 5).clamp(5, 60).toInt();
    _retryTimer = Timer(
      Duration(seconds: seconds),
      () => _listenToFirestoreDirect(parentId, childId),
    );
  }

  void _notifyListeners() {
    for (final callback in List<void Function(ActiveRules)>.of(_listeners)) {
      callback(_current);
    }
  }

  Future<void> stop() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _current = ActiveRules.empty;
    _retryCount = 0;
    debugPrint('RulesService: Stopped.');
  }

  void addListener(void Function(ActiveRules) callback) {
    if (!_listeners.contains(callback)) _listeners.add(callback);
  }

  void removeListener(void Function(ActiveRules) callback) {
    _listeners.remove(callback);
  }
}
