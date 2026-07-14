import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'alert_service.dart';

/// GuardianHealthMonitor
///
/// Surveille en continu l'intégrité de la protection (toutes les 60 secondes).
/// Détecte si des autorisations critiques ont été révoquées par l'enfant :
///   1. Service d'accessibilité (Accessibility Service)
///   2. Affichage par-dessus les autres applications (Overlay / Draw over other apps)
///   3. Optimisation de la batterie (Battery Optimization ignored)
///   4. Administrateur de l'appareil (Device Administrator)
///
/// Si l'un de ces statuts passe de true à false (révocation), une alerte
/// Firestore "INTEGRITY_FAILURE" est immédiatement générée et stockée pour notifier le parent.
class GuardianHealthMonitor {
  static final GuardianHealthMonitor _instance = GuardianHealthMonitor._internal();
  factory GuardianHealthMonitor() => _instance;
  GuardianHealthMonitor._internal();

  static const _methodChannel = MethodChannel('app.theguardian.child/system');
  final AlertService _alertService = AlertService();

  Timer? _monitorTimer;
  bool _isRunning = false;

  // Stocker l'état précédent pour ne notifier que lors d'une transition true -> false (révocation)
  bool _lastAccessibility = true;
  bool _lastOverlay = true;
  bool _lastBattery = true;
  bool _lastAdmin = true;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    
    debugPrint('GuardianHealthMonitor: Starting periodic health check (every 60s)...');
    // Premier check rapide après 10s pour laisser l'app s'initialiser
    Timer(const Duration(seconds: 10), () async {
      if (_isRunning) {
        await checkIntegrity();
        _monitorTimer = Timer.periodic(const Duration(seconds: 60), (_) => checkIntegrity());
      }
    });
  }

  Future<void> stop() async {
    _isRunning = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('GuardianHealthMonitor: Stopped.');
  }

  Future<void> checkIntegrity() async {
    if (!Platform.isAndroid) return;
    try {
      final bool isAccessibilityActive = await _methodChannel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      final bool isOverlayActive = await _methodChannel.invokeMethod<bool>('hasOverlayPermission') ?? false;
      final bool isBatteryIgnored = await _methodChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      final bool isAdminActive = await _methodChannel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;

      debugPrint('GuardianHealthMonitor: Status - Accessibility: $isAccessibilityActive, Overlay: $isOverlayActive, Battery: $isBatteryIgnored, Admin: $isAdminActive');

      // 1. Désactivation de l'Accessibilité
      if (_lastAccessibility && !isAccessibilityActive) {
        debugPrint('GuardianHealthMonitor: ⚠️ Accessibility service was deactivated!');
        await _alertService.sendAlert(
          type: AlertType.integrityFailure,
          cooldownKey: 'accessibility_deactivated',
          detail: 'Le service d\'accessibilité Guardian a été désactivé par l\'enfant.',
        );
      }
      _lastAccessibility = isAccessibilityActive;

      // 2. Révocation de l'affichage par-dessus d'autres apps (Overlay)
      if (_lastOverlay && !isOverlayActive) {
        debugPrint('GuardianHealthMonitor: ⚠️ Draw Overlay permission was revoked!');
        await _alertService.sendAlert(
          type: AlertType.integrityFailure,
          cooldownKey: 'overlay_revoked',
          detail: 'L\'autorisation d\'affichage par-dessus les autres applications a été révoquée par l\'enfant.',
        );
      }
      _lastOverlay = isOverlayActive;

      // 3. Réactivation des optimisations de batterie
      if (_lastBattery && !isBatteryIgnored) {
        debugPrint('GuardianHealthMonitor: ⚠️ Battery optimizations were re-enabled!');
        await _alertService.sendAlert(
          type: AlertType.integrityFailure,
          cooldownKey: 'battery_optimized',
          detail: 'L\'optimisation de la batterie a été réactivée pour l\'application Guardian, risquant de l\'arrêter.',
        );
      }
      _lastBattery = isBatteryIgnored;

      // 4. Révocation des droits d'Administrateur
      if (_lastAdmin && !isAdminActive) {
        debugPrint('GuardianHealthMonitor: ⚠️ Device Administrator permission was revoked!');
        await _alertService.sendAlert(
          type: AlertType.integrityFailure,
          cooldownKey: 'admin_revoked',
          detail: 'Les droits d\'administrateur de l\'appareil ont été révoqués pour l\'application Guardian.',
        );
      }
      _lastAdmin = isAdminActive;

    } catch (e, s) {
      debugPrint('GuardianHealthMonitor: Error checking integrity: $e\n$s');
    }
  }
}
