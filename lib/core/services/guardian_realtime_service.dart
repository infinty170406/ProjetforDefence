import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/app_state_manager.dart';
import '../models/alert_model.dart';
import '../constants/app_constants.dart';

class GuardianRealtimeService {
  static final GuardianRealtimeService _instance =
      GuardianRealtimeService._internal();
  factory GuardianRealtimeService() => _instance;
  GuardianRealtimeService._internal();

  bool _isInitialized = false;
  AppStateManager? _stateManager;
  StreamSubscription? _childrenListSubscription;
  final Map<String, Map<String, StreamSubscription>> _childSubscriptions = {};
  final Map<String, Set<String>> _seenAlertIds = {};

  void initialize(AppStateManager stateManager) {
    if (_isInitialized) {
      if (kDebugMode) print('REALTIME_LOG: Already initialized, skipping.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (kDebugMode)
        print('REALTIME_LOG: No authenticated user yet — deferring init.');
      FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((u) => u != null && !u.isAnonymous)
          .then((_) {
        if (!_isInitialized) initialize(stateManager);
      }).catchError((_) {});
      return;
    }

    _stateManager = stateManager;
    _startChildrenListListener();
    _isInitialized = true;
    if (kDebugMode)
      print('REALTIME_LOG: Initialized for parent uid=${user.uid}.');
  }

  void _startChildrenListListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final childrenCol = FirebaseFirestore.instance
        .collection('parents')
        .doc(user.uid)
        .collection('children');

    _childrenListSubscription?.cancel();

    _childrenListSubscription = _listenResilient<QuerySnapshot>(
      () => childrenCol.orderBy('createdAt', descending: false).snapshots(),
      (snap) {
        final List<Map<String, dynamic>> children = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        final childIds = children.map((c) => c['id'] as String).toSet();

        // Clean up subscriptions for deleted children
        final activeKeys = _childSubscriptions.keys.toList();
        for (final id in activeKeys) {
          if (!childIds.contains(id)) {
            _cancelChildSubscriptions(id);
          }
        }

        // Initialize subscriptions for new children
        for (final child in children) {
          final id = child['id'] as String;
          if (!_childSubscriptions.containsKey(id)) {
            _startChildSubscriptions(id);
          }
        }
      },
      'children_list',
    );
  }

  void _startChildSubscriptions(String childId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    final uid = user.uid;

    if (_childSubscriptions.containsKey(childId)) {
      if (kDebugMode)
        print(
            'REALTIME_LOG: Subscriptions for $childId already exist. Skipping.');
      return;
    }

    final subs = <String, StreamSubscription>{};

    // L'UI lit directement les flux Firestore via les repositories. Ce service
    // conserve uniquement l'abonnement nécessaire aux alertes système.
    subs['alerts'] = _listenResilient<QuerySnapshot>(
      () => FirebaseFirestore.instance
          .collection(
              'parents/$uid/children/$childId/alerts/notifications/items')
          .snapshots(),
      (snap) {
        final list = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        list.sort((a, b) {
          final tA = a['timestamp'];
          final tB = b['timestamp'];
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          if (tA is Timestamp && tB is Timestamp) {
            return tB.compareTo(tA);
          }
          return tB.toString().compareTo(tA.toString());
        });
        final trimmedList = list.take(50).toList();

        final previousAlertIds = _seenAlertIds[childId] ?? {};
        final newAlertIds = <String>{};

        for (final data in trimmedList) {
          final id = data['id'] as String;
          newAlertIds.add(id);

          if (!previousAlertIds.contains(id)) {
            if (data['read'] == false) {
              final severityStr =
                  (data['severity'] as String?)?.toUpperCase() ??
                      AppConstants.severityInfo;
              const visibleSeverities = {
                AppConstants.severityCritical,
                AppConstants.severityHigh,
                'MEDIUM'
              };
              if (visibleSeverities.contains(severityStr)) {
                final alert = AlertModel(
                  id: id,
                  title: data['title'] ?? 'Guardian Alert',
                  description: data['description'] ??
                      data['message'] ??
                      'Un événement nécessite votre attention.',
                  timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  severity: _parseSeverity(severityStr),
                  type: data['type'] ?? 'OTHER',
                  childId: childId,
                );
                _stateManager?.addAlert(alert);
              }
            }
          }
        }
        _seenAlertIds[childId] = newAlertIds;
      },
      'child_${childId}_alerts',
    );

    _childSubscriptions[childId] = subs;
  }

  void _cancelChildSubscriptions(String childId) {
    final subs = _childSubscriptions.remove(childId);
    if (subs != null) {
      for (final sub in subs.values) {
        sub.cancel();
      }
    }
    _seenAlertIds.remove(childId);
  }

  StreamSubscription<T> _listenResilient<T>(
    Stream<T> Function() streamFactory,
    void Function(T event) onData,
    String description,
  ) {
    late StreamSubscription<T> sub;
    bool isCancelled = false;

    void connect() {
      if (isCancelled) return;
      if (kDebugMode) print('REALTIME_LOG: [Subscribe] $description');

      sub = streamFactory().listen(
        (event) {
          if (isCancelled) return;
          if (kDebugMode) {
            final logStr = event.toString();
            final shortLog =
                logStr.length > 100 ? '${logStr.substring(0, 100)}...' : logStr;
            print('REALTIME_LOG: [Event] $description -> $shortLog');
          }
          onData(event);
        },
        onError: (err) {
          if (isCancelled) return;
          if (kDebugMode) {
            print(
                'REALTIME_LOG: [Error] $description failed: $err. Retrying in 5 seconds...');
          }
          sub.cancel();
          Future.delayed(const Duration(seconds: 5), connect);
        },
        cancelOnError: true,
      );
    }

    connect();

    return _CustomSubscription(() {
      isCancelled = true;
      sub.cancel();
      if (kDebugMode) print('REALTIME_LOG: [Unsubscribed] $description');
    });
  }

  AlertSeverity _parseSeverity(String sev) {
    if (sev == AppConstants.severityCritical) return AlertSeverity.critical;
    if (sev == AppConstants.severityHigh || sev == AppConstants.severityWarning)
      return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  void dispose() {
    _childrenListSubscription?.cancel();
    _childrenListSubscription = null;

    final childIds = _childSubscriptions.keys.toList();
    for (final childId in childIds) {
      _cancelChildSubscriptions(childId);
    }
    _childSubscriptions.clear();
    _seenAlertIds.clear();
    _isInitialized = false;
    _stateManager = null;
    if (kDebugMode) print('REALTIME_LOG: GuardianRealtimeService disposed.');
  }
}

class _CustomSubscription<T> implements StreamSubscription<T> {
  final void Function() _onCancel;
  _CustomSubscription(this._onCancel);

  @override
  Future<void> cancel() async {
    _onCancel();
  }

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future.value(futureValue);
}
