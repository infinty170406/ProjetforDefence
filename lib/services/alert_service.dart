import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guardian_api.dart';

/// Types of alerts accepted by the shared parent backend.
enum AlertType {
  sos,
  blockedApp,
  timeLimit,
  outsideHours,
  geofenceEnter,
  geofenceExit,
  appTimeLimit,
  keywordDetected,
  notificationRisk,
  gpsDisabled,
}

extension AlertTypeExtension on AlertType {
  String get value => switch (this) {
        AlertType.sos => 'SOS',
        AlertType.blockedApp => 'BLOCKED_APP',
        AlertType.timeLimit => 'TIME_LIMIT',
        AlertType.outsideHours => 'OUTSIDE_HOURS',
        AlertType.geofenceEnter => 'GEOFENCE_ENTER',
        AlertType.geofenceExit => 'GEOFENCE_EXIT',
        AlertType.appTimeLimit => 'APP_TIME_LIMIT',
        AlertType.keywordDetected => 'KEYWORD_DETECTED',
        AlertType.notificationRisk => 'NOTIFICATION_RISK',
        AlertType.gpsDisabled => 'GPS_DISABLED',
      };

  String get genre => switch (this) {
        AlertType.sos ||
        AlertType.geofenceEnter ||
        AlertType.geofenceExit ||
        AlertType.keywordDetected ||
        AlertType.notificationRisk ||
        AlertType.gpsDisabled =>
          'security',
        _ => 'restriction',
      };
}

/// Sends alerts through the authenticated Render backend.
///
/// The child app no longer calls Firebase Functions; all alert traffic
/// goes to POST /api/v1/device/alerts on the Render API.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final Map<String, DateTime> _lastSent = {};
  final Random _random = Random.secure();
  static const _cooldown = Duration(minutes: 1);

  Future<bool> sendAlert({
    required AlertType type,
    String detail = '',
    String? cooldownKey,
    Map<String, dynamic> extra = const {},
  }) async {
    final key = cooldownKey != null && cooldownKey.isNotEmpty
        ? '${type.value}|$cooldownKey'
        : type.value;
    final last = _lastSent[key];
    if (last != null && DateTime.now().difference(last) < _cooldown) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final childId = prefs.getString('child_id');
    final parentId = prefs.getString('parent_id');
    if (childId == null || parentId == null) return false;

    final eventId = 'evt_${DateTime.now().microsecondsSinceEpoch}_'
        '${_random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0')}';
    final severity = type.genre == 'security' ? 'CRITICAL' : 'HIGH';

    try {
      await GuardianApi.post(
        '/api/v1/device/alerts',
        body: {
          'parentId': parentId,
          'childId': childId,
          'eventId': eventId,
          'type': type.value,
          'detail': detail,
          'severity': severity,
          'genre': type.genre,
          'extra': extra,
        },
      ).timeout(const Duration(seconds: 45));
      _lastSent[key] = DateTime.now();
      debugPrint('AlertService: Alert delivered through Render backend.');
      return true;
    } on GuardianApiException catch (error) {
      debugPrint('AlertService: Backend rejected alert (${error.code}).');
      return false;
    } catch (error) {
      debugPrint('AlertService: Alert delivery failed: $error');
      return false;
    }
  }
}
