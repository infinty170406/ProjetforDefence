import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    this.blockDrugs        = true,
    this.blockSexualPredators = true,
    this.blockAnxietyDepression = false,
    this.blockSelfHarm     = true,
    this.blockCyberbullying = true,
    this.blockMatureContent = false,
    this.blockEatingDisorders = false,
    this.monitorAccountActivity = true,
    this.locationAlerts    = true,
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
        blockAdultContent: data['blockAdultContent'] as bool? ?? false,
        blockViolence:     data['blockViolence']     as bool? ?? false,
        blockGambling:     data['blockGambling']     as bool? ?? false,
        customKeywords:    keys.map((e) => e.toString()).toSet(),
        geofences:         geos.map((e) => Geofence.fromFirestore(e)).toList(),
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

  StreamSubscription<QuerySnapshot>? _subscription;
  StreamSubscription<QuerySnapshot>? _geofencesSub;
  StreamSubscription<User?>? _authSub;
  ActiveRules _current = ActiveRules.empty;
  bool _isStarting = false;
  int _retryCount = 0;

  // Callbacks enregistrés par les consommateurs
  final List<void Function(ActiveRules)> _listeners = [];

  ActiveRules get current => _current;

  static const String _cacheKey = 'cached_rules';

  /// Démarre l'écoute temps réel du document rules/active.
  /// Idempotent — appels multiples sont ignorés.
  Future<void> start({bool waitForFirstLoad = false}) async {
    if (_subscription != null) return;
    if (_isStarting) return;
    _isStarting = true;

    Completer<void>? firstLoadCompleter;
    if (waitForFirstLoad) {
      firstLoadCompleter = Completer<void>();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // IMPORTANT: Obligatoire pour voir les changements faits par l'autre isolate
      
      debugPrint('RulesService: Starting... (waitForFirstLoad=$waitForFirstLoad)');
      
      // 1. Charger les règles depuis le cache local (offline-first)
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson != null) {
        try {
          _current = ActiveRules.fromFirestore(json.decode(cachedJson));
          debugPrint('RulesService: Loaded from local cache.');
          _notifyListeners();
          // Si on a du cache, on considère que c'est un "premier chargement" suffisant
          firstLoadCompleter?.complete();
          firstLoadCompleter = null; 
        } catch (e) {
          debugPrint('RulesService: Cache decode error: $e');
        }
      }

      final childDeviceUid = prefs.getString('device_uid') ?? FirebaseAuth.instance.currentUser?.uid;
      debugPrint('RulesService: Resolved childDeviceUid = $childDeviceUid');

      if (childDeviceUid == null) {
        debugPrint('RulesService: ⚠️ childDeviceUid not set — cannot start rules listener.');
        _isStarting = false;
        if (firstLoadCompleter != null && !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
        return;
      }

      // Écouter Firestore via collectionGroup
      _listenToFirestore(childDeviceUid, firstLoadCompleter: firstLoadCompleter);

      // 2. Écouter aussi les Geofences
      _checkAndStartGeofences(prefs);
      
      if (firstLoadCompleter != null) {
        await firstLoadCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => debugPrint('RulesService: Timeout waiting for first load'),
        );
      }
    } finally {
      _isStarting = false;
    }
  }

  void _checkAndStartGeofences(SharedPreferences prefs) {
    if (_geofencesSub != null) return;

    final parentId = prefs.getString('parent_id');
    final childId  = prefs.getString('child_id');

    debugPrint('RulesService: Checking for geofences sub (parent=$parentId, child=$childId)');

    if (parentId == null || childId == null) {
      debugPrint('RulesService: ⚠️ Cannot start Geofences sub — missing parent_id or child_id');
      return;
    }

    // Guard: attendre que Firebase Auth soit restauré avant de lire Firestore,
    // sinon request.auth est null → PERMISSION_DENIED sur la collection géofences.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('RulesService: Auth ready (${user.uid}), starting geofences listener.');
      _listenToGeofences(parentId, childId);
    } else {
      debugPrint('RulesService: Auth not ready — waiting for authStateChanges to start geofences.');
      _authSub?.cancel();
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u != null && _geofencesSub == null) {
          debugPrint('RulesService: Auth restored (${u.uid}), starting geofences listener.');
          _listenToGeofences(parentId, childId);
          _authSub?.cancel();
          _authSub = null;
        }
      });
    }
  }

  void _listenToFirestore(String childDeviceUid, {Completer<void>? firstLoadCompleter}) {
    _subscription?.cancel();
    _subscription = _firestore
        .collectionGroup('rules')
        .where('childDeviceUid', isEqualTo: childDeviceUid)
        .snapshots()
        .listen(
      (snap) async {
        _retryCount = 0; // Reset retry on success
        
        if (snap.docs.isEmpty) {
          debugPrint('RulesService: ❌ Rules document DOES NOT EXIST or no rules found for childDeviceUid: $childDeviceUid');
          _current = ActiveRules.empty;
        } else {
          final data = snap.docs.first.data();
          debugPrint('RulesService: 📄 Raw data received for rules: $data');
          
          try {
            final newRules = ActiveRules.fromFirestore(data);
            
            // FUSION : Si le document rules/active ne contient pas de geofences
            // (ce qui est normal si elles sont gérées en sous-collection),
            // on préserve celles que nous avons déjà reçues via _listenToGeofences.
            final hasGeofencesInDoc = data['geofences'] != null && (data['geofences'] as List).isNotEmpty;
            
            if (!hasGeofencesInDoc && _current.geofences.isNotEmpty) {
              debugPrint('RulesService: 🛡️ Preserving ${_current.geofences.length} existing geofences from sub-collection.');
              _current = newRules.copyWith(geofences: _current.geofences);
            } else {
              _current = newRules;
            }
            
            // Sauvegarder dans le cache local
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_cacheKey, json.encode(_current.toMap()));
          } catch (e) {
            debugPrint('RulesService: ❌ Parsing failed. Retaining current rules. Error: $e');
            // On ne remplace pas _current, ce qui préserve les règles existantes ou le cache chargé au démarrage.
          }
        }

        debugPrint('RulesService: ✅ Rules updated → $_current');
        _notifyListeners();
        
        if (firstLoadCompleter != null && !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
      },
      onError: (e) {
        debugPrint('RulesService: Firestore error: $e');
        if (e is FirebaseException && e.code == 'permission-denied') {
          debugPrint('RulesService: FirebaseException [permission-denied] - Cannot read rules. Check Firebase Security Rules.');
        }
        if (firstLoadCompleter != null && !firstLoadCompleter.isCompleted) {
          firstLoadCompleter.complete();
        }
        _handleRetry(childDeviceUid);
      },
    );
  }

  void _listenToGeofences(String parentId, String childId) {
    _geofencesSub?.cancel();
    _geofencesSub = _firestore
        .collection('parents')
        .doc(parentId)
        .collection('geofences')
        .where('childId', isEqualTo: childId)
        .snapshots()
        .listen((snap) {
      final geos = snap.docs
          .map((doc) => Geofence.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
      
      _current = _current.copyWith(geofences: geos);
      debugPrint('RulesService: Geofences updated → ${geos.length} zones');
      _notifyListeners();
    });
  }

  void _handleRetry(String childDeviceUid) {
    _retryCount++;
    final delay = Duration(seconds: (_retryCount * 5).clamp(5, 60));
    debugPrint('RulesService: Retrying in ${delay.inSeconds}s (attempt $_retryCount)...');
    
    Timer(delay, () => _listenToFirestore(childDeviceUid));
  }

  void _notifyListeners() {
    for (final cb in List.of(_listeners)) {
      cb(_current);
    }
  }

  /// Arrête l'écoute et réinitialise les règles.
  Future<void> stop() async {
    await _subscription?.cancel();
    await _geofencesSub?.cancel();
    await _authSub?.cancel();
    _subscription = null;
    _geofencesSub = null;
    _authSub = null;
    _current = ActiveRules.empty;
    debugPrint('RulesService: Stopped.');
  }

  /// Enregistre un callback appelé à chaque mise à jour des règles.
  void addListener(void Function(ActiveRules) callback) {
    _listeners.add(callback);
  }

  void removeListener(void Function(ActiveRules) callback) {
    _listeners.remove(callback);
  }
}
