import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_state_manager.dart';
import '../models/alert_model.dart';
import '../constants/app_constants.dart';

class GlobalMonitorService {
  static final GlobalMonitorService _instance = GlobalMonitorService._internal();
  factory GlobalMonitorService() => _instance;
  GlobalMonitorService._internal();

  final _db = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _childSubscriptions = {};
  AppStateManager? _stateManager;
  StreamSubscription? _childrenListSubscription;
  bool _isInitialized = false;

  void initialize(AppStateManager stateManager) {
    if (_isInitialized) {
      if (kDebugMode) print('GLOBAL_MONITOR: Already initialized, skipping.');
      return;
    }

    // Guard: do not start Firestore listeners before authentication.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (kDebugMode) print('GLOBAL_MONITOR: No authenticated user yet — deferring init.');
      // Retry once Auth state settles.
      FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null && !u.isAnonymous).then((_) {
        if (!_isInitialized) initialize(stateManager);
      }).catchError((_) {});
      return;
    }

    _stateManager = stateManager;
    _startChildrenListListener();
    _isInitialized = true;
    if (kDebugMode) print('GLOBAL_MONITOR: Initialized for uid=${user.uid}.');
  }

  void _startChildrenListListener() {
    final user = FirebaseAuth.instance.currentUser;
    // Skip for anonymous users (child devices)
    if (user == null || user.isAnonymous) return;

    final childrenCol = _db.collection('parents').doc(user.uid).collection('children');

    _childrenListSubscription?.cancel();
    _childrenListSubscription = childrenCol.snapshots().listen((snap) {
      final childIds = snap.docs.map((d) => d.id).toSet();

      // Cancel subscriptions for children no longer present
      _childSubscriptions.removeWhere((id, sub) {
        if (!childIds.contains(id)) {
          sub.cancel();
          return true;
        }
        return false;
      });

      // Add subscriptions for new children
      for (final id in childIds) {
        if (!_childSubscriptions.containsKey(id)) {
          _startChildAlertListener(id);
        }
      }
    }, onError: (e) {
      if (kDebugMode) print('GLOBAL_MONITOR: List listener error: $e');
    });
  }

  void _startChildAlertListener(String childId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final alertsCol = _db
        .collection('parents')
        .doc(user.uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('notifications')
        .collection('items');

    final sub = alertsCol
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final severityStr = (data['severity'] as String?)?.toUpperCase() ?? AppConstants.severityInfo;

          // Show overlay for CRITICAL, HIGH and MEDIUM (covers BLOCKED_APP, TIME_LIMIT, OUTSIDE_HOURS).
          const _visibleSeverities = {AppConstants.severityCritical, AppConstants.severityHigh, 'MEDIUM'};
          if (_visibleSeverities.contains(severityStr)) {
            final alert = AlertModel(
              id: change.doc.id,
              title: data['title'] ?? 'Guardian Alert',
              description: data['description'] ?? data['message'] ?? 'Un événement nécessite votre attention.',
              timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              severity: _parseSeverity(severityStr),
              type: data['type'] ?? 'OTHER',
              childId: childId,
            );

            _stateManager?.addAlert(alert);
            if (kDebugMode) print('GLOBAL_MONITOR: Alert received for $childId (severity=$severityStr)');
          }
        }
      }
    }, onError: (e) {
      if (kDebugMode) print('GLOBAL_MONITOR: Child listener error ($childId): $e');
    });

    _childSubscriptions[childId] = sub;
  }

  AlertSeverity _parseSeverity(String sev) {
    if (sev == AppConstants.severityCritical) return AlertSeverity.critical;
    if (sev == AppConstants.severityHigh || sev == AppConstants.severityWarning) return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  void dispose() {
    _childrenListSubscription?.cancel();
    _childrenListSubscription = null;
    for (var sub in _childSubscriptions.values) {
      sub.cancel();
    }
    _childSubscriptions.clear();
    _isInitialized = false;
    _stateManager = null;
    if (kDebugMode) print('GLOBAL_MONITOR: Disposed.');
  }
}

