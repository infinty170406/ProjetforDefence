import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';

/// SosService
///
/// Déclenché par le bouton SOS depuis le dashboard de l'enfant.
/// Envoie dans Firestore :
///   - latitude / longitude (position GPS actuelle)
///   - niveau de batterie
///   - heure de l'alerte
///
/// Structure Firestore :
///   alerts/{alertId}
///     → childId    : String
///     → type       : "SOS"
///     → latitude   : double
///     → longitude  : double
///     → battery    : int (%)
///     → timestamp  : Timestamp
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  bool _isSending = false;

  /// Envoie une alerte SOS.
  /// Retourne `true` si l'envoi a réussi, `false` sinon.
  Future<bool> sendSos() async {
    if (_isSending) return false;
    _isSending = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final childId = prefs.getString('child_id');
      final parentId = prefs.getString('parent_id');
      final childPath = prefs.getString('child_path');
      if (childId == null || childPath == null || parentId == null) {
        debugPrint('SosService: child_id, parent_id or child_path not found.');
        return false;
      }

      // Récupérer la position GPS
      double? latitude;
      double? longitude;
      try {
        final permission = await geo.Geolocator.checkPermission();
        if (permission != geo.LocationPermission.denied &&
            permission != geo.LocationPermission.deniedForever) {
          final position = await geo.Geolocator.getCurrentPosition(
            desiredAccuracy: geo.LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        debugPrint('SosService: GPS error (non-fatal): $e');
      }

      // Niveau de batterie
      int batteryLevel = -1;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (e) {
        debugPrint('SosService: Battery error (non-fatal): $e');
      }

      const detail = "Demande d'aide d'urgence (SOS)";
      final alertData = {
        'childId':     childId,
        'type':        'SOS',
        'title':       '🆘 Alerte SOS !',
        'description': detail,
        'severity':    'CRITICAL',
        'status':      'unread',
        'genre':       'security',
        'read':        false,
        'timestamp':   FieldValue.serverTimestamp(),
        'latitude':    latitude,
        'longitude':   longitude,
        'battery':     batteryLevel,
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

      // 3. Mise à jour du document enfant avec la dernière alerte SOS
      await _firestore.doc(childPath).update({
        'lastSosTimestamp': FieldValue.serverTimestamp(),
        if (latitude != null) 'lastLatitude': latitude,
        if (longitude != null) 'lastLongitude': longitude,
      });

      debugPrint('SosService: ✅ SOS sent — battery: $batteryLevel%, '
          'lat: ${latitude?.toStringAsFixed(5)}, lng: ${longitude?.toStringAsFixed(5)}');
      return true;
    } catch (e) {
      debugPrint('SosService: Error sending SOS: $e');
      return false;
    } finally {
      _isSending = false;
    }
  }

  bool get isSending => _isSending;
}
