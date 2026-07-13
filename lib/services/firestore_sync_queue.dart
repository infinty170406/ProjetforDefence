import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service gérant la persistance locale, le regroupement (batching 250ms),
/// et la synchronisation avec retry et exponential backoff vers Firestore.
class FirestoreSyncQueue {
  static final FirestoreSyncQueue _instance = FirestoreSyncQueue._internal();
  factory FirestoreSyncQueue() => _instance;
  FirestoreSyncQueue._internal();

  final List<Map<String, dynamic>> _queue = [];
  bool _isSyncing = false;
  Timer? _batchTimer;
  int _retryDelaySeconds = 5;
  static const int _maxRetryDelaySeconds = 60;
  static const String _prefsKey = 'guardian_pending_firestore_ops';

  Future<void> initialize() async {
    await _loadFromPrefs();
    _scheduleSync(delayMs: 1000); // Premier essai de synchronisation après démarrage
  }

  Future<void> queueAdd(String collectionPath, Map<String, dynamic> data) async {
    _queue.add({
      'type': 'add',
      'path': collectionPath,
      'data': _serialize(data),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveToPrefs();
    _scheduleSync();
  }

  Future<void> queueSet(String docPath, Map<String, dynamic> data, {bool merge = true}) async {
    _queue.add({
      'type': 'set',
      'path': docPath,
      'data': _serialize(data),
      'merge': merge,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _saveToPrefs();
    _scheduleSync();
  }

  void _scheduleSync({int delayMs = 250}) {
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(milliseconds: delayMs), () {
      _processQueue();
    });
  }

  Future<void> _processQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    _isSyncing = true;

    // Prendre une copie de la file d'attente à traiter pour cette tentative
    final List<Map<String, dynamic>> batchOps = List.from(_queue);
    debugPrint('FirestoreSyncQueue: Tentative de synchronisation de ${batchOps.length} opérations...');

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (final op in batchOps) {
        final String type = op['type'];
        final String path = op['path'];
        final Map<String, dynamic> rawData = Map<String, dynamic>.from(op['data']);
        final Map<String, dynamic> data = Map<String, dynamic>.from(_deserialize(rawData));

        if (type == 'add') {
          final colRef = firestore.collection(path);
          final docRef = colRef.doc();
          batch.set(docRef, data);
        } else if (type == 'set') {
          final docRef = firestore.doc(path);
          final bool merge = op['merge'] ?? true;
          batch.set(docRef, data, SetOptions(merge: merge));
        }
      }

      await batch.commit();
      debugPrint('FirestoreSyncQueue: ${batchOps.length} opérations synchronisées avec succès.');

      // Supprimer les éléments traités avec succès
      _queue.removeRange(0, batchOps.length);
      await _saveToPrefs();
      
      _retryDelaySeconds = 5; // Reset du délai de retry
      _isSyncing = false;

      // Si de nouveaux éléments ont été ajoutés pendant la synchronisation, planifier à nouveau
      if (_queue.isNotEmpty) {
        _scheduleSync();
      }
    } catch (e) {
      debugPrint('FirestoreSyncQueue: Échec de la synchronisation: $e. Prochain essai dans $_retryDelaySeconds secondes...');
      _isSyncing = false;
      
      // Exponential backoff
      _scheduleSync(delayMs: _retryDelaySeconds * 1000);
      _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(5, _maxRetryDelaySeconds);
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_queue));
    } catch (e) {
      debugPrint('FirestoreSyncQueue: Erreur lors de la sauvegarde de la file: $e');
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _queue.clear();
        for (final item in decoded) {
          _queue.add(Map<String, dynamic>.from(item));
        }
        debugPrint('FirestoreSyncQueue: Chargement de ${_queue.length} opérations en attente.');
      }
    } catch (e) {
      debugPrint('FirestoreSyncQueue: Erreur lors du chargement de la file: $e');
    }
  }

  static dynamic _serialize(dynamic val) {
    if (val is Map) {
      return val.map((k, v) => MapEntry(k.toString(), _serialize(v)));
    } else if (val is List) {
      return val.map((v) => _serialize(v)).toList();
    } else if (val is FieldValue) {
      final str = val.toString();
      if (str.contains('serverTimestamp')) {
        return {'__type': 'timestamp'};
      }
      if (str.contains('increment')) {
        final match = RegExp(r'increment,\s*(-?\d+)').firstMatch(str);
        final incVal = int.tryParse(match?.group(1) ?? '1') ?? 1;
        return {'__type': 'increment', 'value': incVal};
      }
    }
    return val;
  }

  static dynamic _deserialize(dynamic val) {
    if (val is Map) {
      if (val['__type'] == 'timestamp') {
        return FieldValue.serverTimestamp();
      }
      if (val['__type'] == 'increment') {
        return FieldValue.increment(val['value'] ?? 1);
      }
      return val.map((k, v) => MapEntry(k.toString(), _deserialize(v)));
    } else if (val is List) {
      return val.map((v) => _deserialize(v)).toList();
    }
    return val;
  }
}
