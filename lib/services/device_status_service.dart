import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';

/// DeviceStatusService
///
/// Responsable de maintenir le champ [deviceStatus] ("ONLINE" / "OFFLINE")
/// et [lastActive] du document enfant dans Firestore.
///
/// Cycle de vie :
///   - Appeler [goOnline] au démarrage du foreground service.
///   - Un heartbeat Firestore est envoyé toutes les 2 minutes.
///   - Appeler [goOffline] à l'arrêt du service.
class DeviceStatusService {
  static final DeviceStatusService _instance = DeviceStatusService._internal();
  factory DeviceStatusService() => _instance;
  DeviceStatusService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  Timer? _heartbeatTimer;
  bool _isOnline = false;

  static const Duration _heartbeatInterval = Duration(minutes: 2);

  /// Passe le device en ONLINE et démarre le heartbeat.
  Future<void> goOnline() async {
    _isOnline = true;
    await _updateStatus('ONLINE');
    _startHeartbeat();
    debugPrint('DeviceStatusService: ✅ ONLINE');
  }

  /// Passe le device en OFFLINE et arrête le heartbeat.
  Future<void> goOffline() async {
    _isOnline = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _updateStatus('OFFLINE');
    debugPrint('DeviceStatusService: 🔴 OFFLINE');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (_isOnline) {
        await _updateStatus('ONLINE');
        debugPrint('DeviceStatusService: Heartbeat sent.');
      }
    });
  }

  Future<void> _updateStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // IMPORTANT : recharger les données depuis le disque
    final childPath = prefs.getString('child_path');
    if (childPath == null) {
      debugPrint('DeviceStatusService: ⚠️ Cannot update status: child_path is NULL in SharedPreferences.');
      return;
    }

    try {
      final batteryLevel = await _battery.batteryLevel;
      final batteryState = await _battery.batteryState;
      final isCharging   = batteryState == BatteryState.charging || batteryState == BatteryState.full;

      await _firestore.doc(childPath).update({
        'deviceStatus': status,
        'lastHeartbeat': FieldValue.serverTimestamp(), // Aligné avec les règles Firestore
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
      });
    } catch (e) {
      debugPrint('DeviceStatusService: Error updating status: $e');
    }
  }
}
