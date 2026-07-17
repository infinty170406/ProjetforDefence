import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_rules.dart';
import 'storage_service.dart';
import '../../services/native_bridge_service.dart';

/// Écoute les règles et statistiques Firestore en temps réel sur l'appareil enfant,
/// applique le verrouillage de l'appareil (limite de temps/plage horaire/verrou parent),
/// et maintient le heartbeat en ligne.
class ChildEnforcementService {
  static final ChildEnforcementService _instance =
      ChildEnforcementService._internal();
  factory ChildEnforcementService() => _instance;
  ChildEnforcementService._internal() {
    StorageService.onClearAll = () async {
      await stop();
    };
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rulesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statsSub;
  Timer? _enforcementTimer;

  bool _running = false;
  ChildRules? _cachedRules;
  Map<String, dynamic>? _cachedStats;
  String? _currentStatsDate;

  static const _socialMediaPackages = {
    'com.zhiliaoapp.musically',
    'com.tiktok',
    'com.instagram.android',
    'com.snapchat.android',
    'com.twitter.android',
    'com.facebook.katana',
    'com.facebook.lite',
  };

  static const _gamingPackages = {
    'com.roblox.client',
    'com.epicgames.fortnite',
    'com.mojang.minecraftpe',
    'com.supercell.clashofclans',
    'com.supercell.brawlstars',
    'com.king.candycrushsaga',
  };

  bool get isRunning => _running;

  /// Démarre l'écoute des règles si cet appareil est en mode enfant.
  Future<void> start() async {
    if (_running) return;
    if (!await StorageService().getPrivacyAccepted()) {
      debugPrint(
          'ChildEnforcementService: consentement confidentialité absent — arrêt.');
      return;
    }
    _running = true;

    final pairing = await StorageService().getChildPairing();
    if (pairing['mode'] != 'child') {
      _running = false;
      return;
    }

    final parentId = pairing['parentId'];
    final childId = pairing['childId'];
    if (parentId == null || childId == null) {
      debugPrint('ChildEnforcementService: pairing incomplet — arrêt.');
      _running = false;
      return;
    }

    debugPrint(
      'ChildEnforcementService: démarrage pour parent=$parentId child=$childId',
    );

    await NativeBridgeService.startForegroundService();

    final rulesRef = FirebaseFirestore.instance
        .doc('parents/$parentId/children/$childId/rules/active');

    // Sync immédiate des règles avant le premier snapshot.
    try {
      final snap = await rulesRef.get();
      if (snap.exists && snap.data() != null) {
        _cachedRules = ChildRules.fromJson(snap.data()!);
      }
    } catch (e) {
      debugPrint(
          'ChildEnforcementService: lecture initiale des règles échouée: $e');
    }

    // Démarrer l'écoute des stats du jour
    final today = _dateStr(DateTime.now());
    _startStatsListener(parentId, childId, today);

    // Initialiser/propager les règles
    await _evaluateAndApply();

    // Écouter les changements de règles
    _rulesSub = rulesRef.snapshots().listen(
      (snap) async {
        if (!snap.exists || snap.data() == null) return;
        try {
          _cachedRules = ChildRules.fromJson(snap.data()!);
          await _evaluateAndApply();
        } catch (e) {
          debugPrint('ChildEnforcementService: rules stream apply error: $e');
        }
      },
      onError: (e) {
        debugPrint('ChildEnforcementService: rules stream error: $e');
      },
    );

    // Démarrer le timer périodique (toutes les 30s) pour :
    // 1. Envoyer le heartbeat
    // 2. Réévaluer le verrouillage (changement d'heure/limite)
    // 3. Vérifier le changement de jour pour les stats d'usage
    _enforcementTimer?.cancel();
    _enforcementTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_running) return;

      // 1. Update Heartbeat & Status
      final childDocRef =
          FirebaseFirestore.instance.doc('parents/$parentId/children/$childId');
      try {
        await childDocRef.update({
          'lastHeartbeat': FieldValue.serverTimestamp(),
          'deviceStatus': 'ONLINE',
        });
      } catch (e) {
        debugPrint('ChildEnforcementService: Failed to update heartbeat: $e');
      }

      // 2. Check date change
      final currentDate = _dateStr(DateTime.now());
      if (_currentStatsDate != currentDate) {
        _startStatsListener(parentId, childId, currentDate);
      }

      // 3. Evaluate & apply limits/schedule
      await _evaluateAndApply();
    });
  }

  Future<void> stop() async {
    _enforcementTimer?.cancel();
    _enforcementTimer = null;
    await _rulesSub?.cancel();
    _rulesSub = null;
    await _statsSub?.cancel();
    _statsSub = null;
    _running = false;
    _cachedRules = null;
    _cachedStats = null;
    _currentStatsDate = null;
    debugPrint('ChildEnforcementService: arrêté.');
  }

  void _startStatsListener(String parentId, String childId, String date) {
    _statsSub?.cancel();
    _currentStatsDate = date;

    final statsRef = FirebaseFirestore.instance
        .doc('parents/$parentId/children/$childId/alerts/usage/apps/$date');

    _statsSub = statsRef.snapshots().listen(
      (snap) async {
        _cachedStats = snap.data();
        await _evaluateAndApply();
      },
      onError: (e) {
        debugPrint('ChildEnforcementService: stats stream error: $e');
      },
    );
  }

  Future<void> _evaluateAndApply() async {
    if (_cachedRules == null) return;

    final rules = _cachedRules!;
    final stats = _cachedStats ?? {};

    // 1. Vérification du verrou manuel parent
    final bool parentLocked = stats['isLocked'] == true;

    // 2. Vérification de la limite d'utilisation quotidienne (Screen Time)
    final usedMinutes =
        (stats['usedMinutes'] ?? stats['totalMinutes'] ?? 0) as num;
    final dailyLimit = rules.dailyLimitMinutes;
    final bool limitReached = dailyLimit > 0 && usedMinutes >= dailyLimit;

    // 3. Vérification de la plage horaire autorisée
    final bool outsideHours =
        _isOutsideAllowedHours(rules.allowedTimeStart, rules.allowedTimeEnd);

    // Le verrou s'applique si l'une des 3 conditions est vraie
    final bool shouldLock = parentLocked || limitReached || outsideHours;

    if (kDebugMode) {
      print(
          'ChildEnforcementService: Evaluate — parentLocked=$parentLocked, limitReached=$limitReached, outsideHours=$outsideHours -> shouldLock=$shouldLock');
    }

    // Appliquer l'état de verrouillage au code natif
    await NativeBridgeService.updateDeviceLock(shouldLock);

    // Propager les autres listes restrictives
    final apps = _effectiveBlockedApps(rules);
    await NativeBridgeService.updateBlockedAppsList(apps);
    await NativeBridgeService.updateBlockedWebsites(rules.blockedWebsites);
    await NativeBridgeService.updateCustomKeywords(rules.customKeywords);
  }

  bool _isOutsideAllowedHours(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return false; // Pas de restriction d'horaire définie
    }
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final startParts = start.split(':');
      final endParts = end.split(':');

      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (startMinutes <= endMinutes) {
        // Cas standard : ex. 08:00 à 21:00
        return currentMinutes < startMinutes || currentMinutes > endMinutes;
      } else {
        // Cas nuit : ex. 21:00 à 07:00 le lendemain
        return currentMinutes < startMinutes && currentMinutes > endMinutes;
      }
    } catch (e) {
      debugPrint('ChildEnforcementService: Error parsing schedule times: $e');
      return false;
    }
  }

  List<String> _effectiveBlockedApps(ChildRules rules) {
    final result = <String>{...rules.blockedApps};
    if (rules.blockSocialMedia) result.addAll(_socialMediaPackages);
    if (rules.blockGaming) result.addAll(_gamingPackages);
    return result.toList();
  }

  String _dateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
