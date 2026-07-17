import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'alert_service.dart';

/// Sends an SOS through the authenticated backend alert endpoint.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  final Battery _battery = Battery();
  bool _isSending = false;

  Future<bool> sendSos() async {
    if (_isSending) return false;
    _isSending = true;

    try {
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
      } catch (error) {
        debugPrint('SosService: Location unavailable: $error');
      }

      var batteryLevel = -1;
      try {
        batteryLevel = await _battery.batteryLevel;
      } catch (error) {
        debugPrint('SosService: Battery level unavailable: $error');
      }

      return AlertService().sendAlert(
        type: AlertType.sos,
        detail: "Demande d'aide d'urgence (SOS)",
        cooldownKey: 'sos',
        extra: {
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'battery': batteryLevel,
        },
      );
    } finally {
      _isSending = false;
    }
  }

  bool get isSending => _isSending;
}
