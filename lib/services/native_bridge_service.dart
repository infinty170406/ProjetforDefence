import 'package:flutter/services.dart';

class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel('com.guardian.native/control');

  /// Met à jour la liste des applications bloquées du côté natif.
  /// Ces applications seront interceptées par le GuardianAccessibilityService.
  static Future<void> updateBlockedAppsList(List<String> packageNames) async {
    try {
      await _channel.invokeMethod('updateBlockedAppsList', {'apps': packageNames});
    } on PlatformException catch (e) {
      print("Erreur lors de la mise à jour des apps bloquées : \${e.message}");
    }
  }

  /// Démarre le ForegroundService natif pour empêcher Android de tuer l'app en arrière-plan.
  static Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      print("Erreur lors du lancement du Foreground Service : \${e.message}");
    }
  }

  /// Vérifie si les permissions (Accessibilité, Device Admin) sont accordées.
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('checkPermissions');
      if (result != null) {
        return result.cast<String, bool>();
      }
    } on PlatformException catch (e) {
      print("Erreur lors de la vérification des permissions : \${e.message}");
    }
    return {'accessibility': false, 'deviceAdmin': false};
  }

  /// Demande les droits Device Admin.
  static Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      print("Erreur lors de la demande Device Admin : \${e.message}");
    }
  }
}
