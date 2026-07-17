import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pont MethodChannel vers le code natif Android (MainActivity).
class NativeBridgeService {
  static const MethodChannel _channel =
      MethodChannel('com.guardian.native/control');

  /// Met à jour la liste des applications bloquées côté natif.
  static Future<void> updateBlockedAppsList(List<String> packageNames) async {
    try {
      await _channel.invokeMethod('updateBlockedAppsList', {
        'apps': packageNames,
      });
    } on PlatformException catch (e) {
      debugPrint(
        'NativeBridgeService: updateBlockedAppsList error: ${e.message}',
      );
    }
  }

  /// Met à jour les domaines/URLs bloqués pour le filtrage web natif.
  static Future<void> updateBlockedWebsites(List<String> websites) async {
    try {
      await _channel.invokeMethod('updateBlockedWebsites', {
        'websites': websites,
      });
    } on PlatformException catch (e) {
      debugPrint(
        'NativeBridgeService: updateBlockedWebsites error: ${e.message}',
      );
    }
  }

  /// Met à jour les mots-clés personnalisés surveillés par l'AccessibilityService.
  static Future<void> updateCustomKeywords(List<String> keywords) async {
    try {
      await _channel.invokeMethod('updateCustomKeywords', {
        'keywords': keywords,
      });
    } on PlatformException catch (e) {
      debugPrint(
        'NativeBridgeService: updateCustomKeywords error: ${e.message}',
      );
    }
  }

  /// Met à jour l'état de verrouillage global de l'appareil.
  static Future<void> updateDeviceLock(bool locked) async {
    try {
      await _channel.invokeMethod('updateDeviceLock', {
        'locked': locked,
      });
    } on PlatformException catch (e) {
      debugPrint(
        'NativeBridgeService: updateDeviceLock error: ${e.message}',
      );
    }
  }

  /// Démarre le ForegroundService natif (survie en arrière-plan).
  static Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      debugPrint(
        'NativeBridgeService: startForegroundService error: ${e.message}',
      );
    }
  }

  /// Vérifie si Accessibilité et Device Admin sont accordés.
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod('checkPermissions');
      if (result != null) {
        return result.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('NativeBridgeService: checkPermissions error: ${e.message}');
    }
    return {'accessibility': false, 'deviceAdmin': false};
  }

  /// Ouvre l'écran système pour activer Device Admin.
  static Future<void> requestDeviceAdmin() async {
    try {
      await _channel.invokeMethod('requestDeviceAdmin');
    } on PlatformException catch (e) {
      debugPrint('NativeBridgeService: requestDeviceAdmin error: ${e.message}');
    }
  }
}
