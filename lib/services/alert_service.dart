import 'firestore_sync_queue.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/child_path_helper.dart';

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
/// Écrit les alertes dans la collection Firestore lue par l'app parent /
/// GuardianAgent :
///   {childPath}/alerts/notifications/items/{alertId}
///     → childId      : String
///     → type         : "SOS" | "BLOCKED_APP" | "TIME_LIMIT" | "OUTSIDE_HOURS" | ...
///     → description  : String  (lu par AlertModel parent)
///     → detail       : String  (lu par GuardianAgent)
///     → severity     : "CRITICAL" | "HIGH"
///     → timestamp    : Timestamp
///     → createdAt    : Timestamp (ordre du stream agent côté parent)
///     → ai_processed : bool (drapeau de traitement par GuardianAgent)
///
/// Anti-spam : même type + même sujet (app, mot-clé…) = max 1 envoi par minute.
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
    String? cooldownKey,
  }) async {
    // Anti-spam : par type seul si pas de sujet, sinon par type + sujet
    final key = cooldownKey != null && cooldownKey.isNotEmpty
        ? '${type.value}|$cooldownKey'
        : type.value;
    final last = _lastSent[key];
    if (last != null && DateTime.now().difference(last) < _cooldown) return;
    _lastSent[key] = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final childPath = await readChildPath(prefs);
    final childId   = prefs.getString('child_id');
    final parentId  = prefs.getString('parent_id');
    if (childPath == null || childId == null || parentId == null) return;

    try {
      // security = CRITICAL (SOS, géofences, mots-clés)
      // restriction = HIGH (app bloquée, limite atteinte, hors horaire)
      // → Les deux niveaux sont désormais visibles dans l'overlay parent.
      final severity = type.genre == 'security' ? 'CRITICAL' : 'HIGH';

      final alertData = {
        'childId':      childId,
        'type':         type.value,
        'title':        type.title,
        // GuardianAgent (app parent) lit le champ 'detail' ; l'AlertModel parent
        // lit 'description'. On écrit les deux pour rester compatible (§6.2).
        'description':  detail,
        'detail':       detail,
        'severity':     severity,
        'status':       'unread',
        'genre':        type.genre,
        'read':         false,
        // FirestoreService.watchAlerts() (app parent) ordonne par 'createdAt',
        // alors que l'app enfant écrivait seulement 'timestamp' (Piège 2).
        // On écrit les deux pour que le stream de l'agent fonctionne.
        'timestamp':    FieldValue.serverTimestamp(),
        'createdAt':    FieldValue.serverTimestamp(),
        // Drapeau consommé par GuardianAgentService.start() côté parent :
        // l'agent filtre where('ai_processed', isEqualTo: false), traite
        // l'alerte, puis le passe à true (Piège 4). Sans ce champ, l'agent
        // re-traiterait toutes les alertes historiques à chaque démarrage.
        'ai_processed': false,
      };

      // 1. Écriture sur le chemin unique lu par le parent via FirestoreSyncQueue
      final deepPath = '$childPath/alerts/notifications/items';
      
      await FirestoreSyncQueue().queueAdd(deepPath, {...alertData, 'message': detail});

      debugPrint('AlertService: ✅ Enqueued [${type.value}] — $detail (single-path sync)');
    } catch (e) {
      debugPrint('AlertService: Error: $e');
    }
  }
}
