import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'rules_service.dart';
import 'enforcement_service.dart';

/// ChildRulesEnforcementService
///
/// Ce service assure la synchronisation immédiate des règles entre Firestore
/// et les couches natives de l'appareil (Android/iOS).
/// Il s'exécute sur le téléphone de l'enfant.
class ChildRulesEnforcementService {
  static final ChildRulesEnforcementService _instance = ChildRulesEnforcementService._internal();
  factory ChildRulesEnforcementService() => _instance;
  ChildRulesEnforcementService._internal();

  final RulesService _rulesService = RulesService();
  static const _methodChannel = MethodChannel('app.theguardian.child/system');
  
  StreamSubscription? _rulesSubscription;
  DateTime? _lastUpdate;
  bool _isInitialized = false;

  /// Initialise le service et commence l'écoute en temps réel.
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('ChildRulesEnforcementService: Initializing...');
    
    // Démarrer RulesService s'il n'est pas déjà lancé
    await _rulesService.start();
    
    // Souscrire aux changements de règles
    _rulesService.addListener(_onRulesChanged);
    
    // Appliquer les règles actuelles immédiatement
    _applyRules(_rulesService.current);
    
    _isInitialized = true;
    debugPrint('ChildRulesEnforcementService: Initialized and listening.');
  }

  void _onRulesChanged(ActiveRules rules) {
    debugPrint('ChildRulesEnforcementService: Rules changed, applying...');
    _applyRules(rules);
  }

  /// Applique les règles aux composants natifs via MethodChannel.
  Future<void> _applyRules(ActiveRules rules) async {
    try {
      // 1. Liste des packages bloqués (individuel + catégories)
      final blockedPackages = rules.effectiveBlockedPackages(
        socialMediaPackages: EnforcementService.socialMedia,
        gamingPackages: EnforcementService.gaming,
      ).toList();

      // 2. Mots-clés personnalisés
      final customKeywords = rules.customKeywords.toList();

      // 3. État du filtrage web / VPN
      final needsVpn = rules.blockedWebsites.isNotEmpty || 
          rules.blockAdultContent || 
          rules.blockViolence || 
          rules.blockGambling;

      // Envoi groupé ou individuel au natif
      await _methodChannel.invokeMethod('updateBlockedPackages', blockedPackages);
      await _methodChannel.invokeMethod('updateCustomKeywords', customKeywords);
      
      if (needsVpn) {
        await _methodChannel.invokeMethod('startVpn');
      } else {
        await _methodChannel.invokeMethod('stopVpn');
      }

      _lastUpdate = DateTime.now();
      debugPrint('ChildRulesEnforcementService: Native rules updated at $_lastUpdate');
      debugPrint(' - Blocked apps: ${blockedPackages.length}');
      debugPrint(' - Keywords: ${customKeywords.length}');
      debugPrint(' - VPN active: $needsVpn');
      
    } catch (e) {
      debugPrint('ChildRulesEnforcementService: Error applying native rules: $e');
    }
  }

  /// Arrête l'écoute du service.
  void dispose() {
    _rulesService.removeListener(_onRulesChanged);
    debugPrint('ChildRulesEnforcementService: Disposed.');
  }

  // Helpers pour l'UI
  bool isAppBlocked(String packageName, ActiveRules rules) {
    final blocked = rules.effectiveBlockedPackages(
      socialMediaPackages: EnforcementService.socialMedia,
      gamingPackages: EnforcementService.gaming,
    );
    return blocked.contains(packageName);
  }
}
