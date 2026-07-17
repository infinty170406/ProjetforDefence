import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JSON-safe values supported by [FirestoreSyncQueue].
abstract final class FirestoreQueueValue {
  static const serverTimestamp = <String, dynamic>{
    '__guardianQueueType': 'serverTimestamp',
  };

  static Map<String, dynamic> increment(num value) => {
        '__guardianQueueType': 'increment',
        'value': value,
      };
}

/// Bounded, persistent and idempotent Firestore write queue.
class FirestoreSyncQueue {
  static final FirestoreSyncQueue _instance = FirestoreSyncQueue._internal();
  factory FirestoreSyncQueue() => _instance;
  FirestoreSyncQueue._internal();

  static const int _maxQueueLength = 1000;
  static const int _maxBatchOperations = 450;
  static const int _maxRetryDelaySeconds = 60;
  static const String _prefsKey = 'guardian_pending_firestore_ops';

  final List<Map<String, dynamic>> _queue = [];
  bool _isSyncing = false;
  Timer? _batchTimer;
  int _retryDelaySeconds = 5;

  Future<void> initialize() async {
    await _loadFromPrefs();
    _scheduleSync(delayMs: 1000);
  }

  Future<void> queueAdd(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    final documentId =
        FirebaseFirestore.instance.collection(collectionPath).doc().id;
    await _enqueue({
      'type': 'add',
      'path': collectionPath,
      'documentId': documentId,
      'data': _serialize(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> queueSet(
    String docPath,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await _enqueue({
      'type': 'set',
      'path': docPath,
      'data': _serialize(data),
      'merge': merge,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _enqueue(Map<String, dynamic> operation) async {
    _queue.add(operation);
    if (_queue.length > _maxQueueLength) {
      final overflow = _queue.length - _maxQueueLength;
      _queue.removeRange(0, overflow);
      debugPrint(
        'FirestoreSyncQueue: Dropped $overflow oldest operations to keep the queue bounded.',
      );
    }
    await _saveToPrefs();
    _scheduleSync();
  }

  void _scheduleSync({int delayMs = 250}) {
    _batchTimer?.cancel();
    _batchTimer = Timer(
      Duration(milliseconds: delayMs),
      () {
        unawaited(_processQueue());
      },
    );
  }

  Future<void> _processQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    _isSyncing = true;

    final batchOps = _queue.take(_maxBatchOperations).toList(growable: false);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final operation in batchOps) {
        final type = operation['type'] as String?;
        final path = operation['path'] as String?;
        final rawData = operation['data'];
        if (type == null || path == null || rawData is! Map) {
          throw const FormatException('Malformed queued Firestore operation.');
        }

        final data = Map<String, dynamic>.from(
          _deserialize(Map<String, dynamic>.from(rawData)) as Map,
        );

        switch (type) {
          case 'add':
            final documentId = operation['documentId'] as String?;
            if (documentId == null || documentId.isEmpty) {
              throw const FormatException('Queued add is missing documentId.');
            }
            batch.set(firestore.collection(path).doc(documentId), data);
            break;
          case 'set':
            final merge = operation['merge'] as bool? ?? true;
            batch.set(
              firestore.doc(path),
              data,
              SetOptions(merge: merge),
            );
            break;
          default:
            throw FormatException('Unsupported queued operation: $type');
        }
      }

      await batch.commit();
      _queue.removeRange(0, batchOps.length);
      await _saveToPrefs();
      _retryDelaySeconds = 5;
    } catch (error) {
      debugPrint('FirestoreSyncQueue: Sync failed: $error');
      _scheduleSync(delayMs: _retryDelaySeconds * 1000);
      _retryDelaySeconds =
          (_retryDelaySeconds * 2).clamp(5, _maxRetryDelaySeconds).toInt();
      return;
    } finally {
      _isSyncing = false;
    }

    if (_queue.isNotEmpty) _scheduleSync();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_queue));
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString == null || jsonString.isEmpty) return;

      final decoded = jsonDecode(jsonString);
      if (decoded is! List) throw const FormatException('Queue is not a list.');

      _queue
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(_isValidPersistedOperation)
              .take(_maxQueueLength),
        );
      await _saveToPrefs();
    } catch (error) {
      debugPrint('FirestoreSyncQueue: Invalid persisted queue cleared: $error');
      _queue.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    }
  }

  bool _isValidPersistedOperation(Map<String, dynamic> operation) {
    final type = operation['type'];
    if (type != 'add' && type != 'set') return false;
    if (operation['path'] is! String || operation['data'] is! Map) return false;
    if (type == 'add' && operation['documentId'] is! String) return false;
    return true;
  }

  static dynamic _serialize(dynamic value) {
    if (value is FieldValue) {
      throw ArgumentError(
        'FieldValue cannot be persisted safely. Use FirestoreQueueValue instead.',
      );
    }
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _serialize(nested)),
      );
    }
    if (value is Iterable) {
      return value.map(_serialize).toList();
    }
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value;
  }

  static dynamic _deserialize(dynamic value) {
    if (value is Map) {
      final type = value['__guardianQueueType'];
      if (type == 'serverTimestamp') return FieldValue.serverTimestamp();
      if (type == 'increment') {
        final increment = value['value'];
        if (increment is! num) {
          throw const FormatException('Invalid increment sentinel.');
        }
        return FieldValue.increment(increment);
      }
      return value.map(
        (key, nested) => MapEntry(key.toString(), _deserialize(nested)),
      );
    }
    if (value is List) return value.map(_deserialize).toList();
    return value;
  }
}
