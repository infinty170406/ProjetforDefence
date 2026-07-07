import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/child_rules.dart';
import 'storage_service.dart';
import '../../services/native_bridge_service.dart';

/// Écoute les règles Firestore en temps réel sur l'appareil enfant
/// et les propage vers le natif (AccessibilityService).
class ChildEnforcementService {
  static final ChildEnforcementService _instance =
      ChildEnforcementService._internal();
  factory ChildEnforcementService() => _instance;
  ChildEnforcementService._internal();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rulesSub;
  bool _running = false;

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

    final pairing = await StorageService().getChildPairing();
    if (pairing['mode'] != 'child') return;

    final parentId = pairing['parentId'];
    final childId = pairing['childId'];
    if (parentId == null || childId == null) {
      debugPrint('ChildEnforcementService: pairing incomplet — arrêt.');
      return;
    }

    _running = true;
    debugPrint(
      'ChildEnforcementService: démarrage pour parent=$parentId child=$childId',
    );

    await NativeBridgeService.startForegroundService();

    final rulesRef = FirebaseFirestore.instance
        .doc('parents/$parentId/children/$childId/rules/active');

    // Sync immédiate avant le premier snapshot.
    try {
      final snap = await rulesRef.get();
      if (snap.exists) {
        await _applyRules(ChildRules.fromJson(snap.data()!));
      }
    } catch (e) {
      debugPrint('ChildEnforcementService: lecture initiale échouée: $e');
    }

    _rulesSub = rulesRef.snapshots().listen(
      (snap) async {
        if (!snap.exists || snap.data() == null) return;
        try {
          await _applyRules(ChildRules.fromJson(snap.data()!));
        } catch (e) {
          debugPrint('ChildEnforcementService: apply rules error: $e');
        }
      },
      onError: (e) {
        debugPrint('ChildEnforcementService: stream error: $e');
      },
    );
  }

  Future<void> stop() async {
    await _rulesSub?.cancel();
    _rulesSub = null;
    _running = false;
    debugPrint('ChildEnforcementService: arrêté.');
  }

  Future<void> _applyRules(ChildRules rules) async {
    final apps = _effectiveBlockedApps(rules);
    await NativeBridgeService.updateBlockedAppsList(apps);
    await NativeBridgeService.updateBlockedWebsites(rules.blockedWebsites);
    await NativeBridgeService.updateCustomKeywords(rules.customKeywords);
    debugPrint(
      'ChildEnforcementService: sync natif — '
      '${apps.length} apps, ${rules.blockedWebsites.length} sites, '
      '${rules.customKeywords.length} mots-clés',
    );
  }

  List<String> _effectiveBlockedApps(ChildRules rules) {
    final result = <String>{...rules.blockedApps};
    if (rules.blockSocialMedia) result.addAll(_socialMediaPackages);
    if (rules.blockGaming) result.addAll(_gamingPackages);
    return result.toList();
  }
}
