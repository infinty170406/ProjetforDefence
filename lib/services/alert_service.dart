import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Types d'alertes générées par l'app enfant.
enum AlertType {
  sos,           // Bouton SOS pressé par l'enfant
  blockedApp,    // App bloquée détectée au premier plan
  timeLimit,     // Limite journalière de temps d'écran atteinte
  outsideHours,  // Utilisation hors plage horaire autorisée
  geofenceEnter, // Entrée dans zone de sécurité
  geofenceExit,  // Sortie de zone de sécurité
  appTimeLimit,  // Limite par application atteinte
  keywordDetected, // Mot-clé personnalisé détecté
}

extension AlertTypeExtension on AlertType {
  String get value {
    switch (this) {
      case AlertType.sos:           return 'SOS';
      case AlertType.blockedApp:    return 'BLOCKED_APP';
      case AlertType.timeLimit:     return 'TIME_LIMIT';
      case AlertType.outsideHours:  return 'OUTSIDE_HOURS';
      case AlertType.geofenceEnter: return 'GEOFENCE_ENTER';
      case AlertType.geofenceExit:  return 'GEOFENCE_EXIT';
      case AlertType.appTimeLimit:  return 'APP_TIME_LIMIT';
      case AlertType.keywordDetected: return 'KEYWORD_DETECTED';
    }
  }

  String get genre {
    switch (this) {
      case AlertType.sos:
      case AlertType.geofenceEnter:
      case AlertType.geofenceExit:
      case AlertType.keywordDetected:
        return 'security';
      case AlertType.blockedApp:
      case AlertType.timeLimit:
      case AlertType.outsideHours:
      case AlertType.appTimeLimit:
        return 'restriction';
    }
  }

  String get title {
    switch (this) {
      case AlertType.sos:           return 'Alerte SOS';
      case AlertType.blockedApp:    return 'Application bloquée';
      case AlertType.timeLimit:     return 'Limite globale atteinte';
      case AlertType.outsideHours:  return 'Hors plage horaire';
      case AlertType.geofenceEnter: return 'Entrée en zone';
      case AlertType.geofenceExit:  return 'Sortie de zone';
      case AlertType.appTimeLimit:  return 'Limite d\'app atteinte';
      case AlertType.keywordDetected: return 'Mot-clé détecté';
    }
  }
}

/// AlertService
///
/// Écrit les alertes dans la collection Firestore [alerts].
/// Structure :
///   alerts/{alertId}
///     → childId   : String
///     → type      : "SOS" | "BLOCKED_APP" | "TIME_LIMIT" | "OUTSIDE_HOURS"
///     → detail    : String
///     → timestamp : Timestamp
///
/// Anti-spam : même type d'alerte = max 1 envoi par minute.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, DateTime> _lastSent = {};
  static const _cooldown = Duration(minutes: 1);

  Future<void> sendAlert({
    required AlertType type,
    String detail = '',
  }) async {
    // Anti-spam
    final key = type.value;
    final last = _lastSent[key];
    if (last != null && DateTime.now().difference(last) < _cooldown) return;
    _lastSent[key] = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final childPath = prefs.getString('child_path');
    final childId   = prefs.getString('child_id');
    final parentId  = prefs.getString('parent_id');
    if (childPath == null || childId == null || parentId == null) return;

    try {
      final severity = type.genre == 'security' ? 'HIGH' : 'MEDIUM';

      final alertData = {
        'childId':     childId,
        'type':        type.value,
        'title':       type.title,
        'description': detail,
        'severity':    severity,
        'status':      'unread',
        'genre':       type.genre,
        'read':        false,
        'timestamp':   FieldValue.serverTimestamp(),
      };

      // 1. Écriture dans l'historique local de l'enfant (2 formats)
      final deepPath = '$childPath/alerts/notifications/items';
      final flatPath = '$childPath/alerts';
      
      await _firestore.collection(deepPath).add({...alertData, 'message': detail});
      await _firestore.collection(flatPath).add({...alertData, 'message': detail});

      // 2. Écriture dans la collection racine /alerts (pour le parent)
      if (parentId.isNotEmpty) {
        await _firestore.collection('alerts').add({
          ...alertData,
          'parentId': parentId,
          'childPath': childPath,
          'message': detail,
        });
      }

      debugPrint('AlertService: ✅ [${type.value}] — $detail (multi-path sync)');
    } catch (e) {
      debugPrint('AlertService: Error: $e');
    }
  }
}
