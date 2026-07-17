import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StatsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache en mémoire
  final Map<String, _CachedStats> _cache = {};
  static const Duration _cacheDuration = Duration(seconds: 60);

  String? get _uid => _auth.currentUser?.uid;

  /// Récupère les statistiques d'aujourd'hui avec gestion du cache
  Future<Map<String, dynamic>> getTodayStats(String childId) async {
    if (_uid == null || childId.isEmpty) return {};

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cacheKey = '${childId}_$today';

    // Vérification du cache
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (now.difference(cached.timestamp) < _cacheDuration) {
        if (kDebugMode) {
          print('StatsRepository: Serving from cache for $childId');
        }
        return cached.data;
      }
    }

    try {
      if (kDebugMode) {
        print('StatsRepository: Fetching from Firestore for $childId');
      }

      final childDoc = _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId);
      final usageDoc = childDoc.collection('alerts').doc('usage');

      final appSnap = await usageDoc.collection('apps').doc(today).get();
      final webSnap = await usageDoc.collection('websites').doc(today).get();

      final appData = appSnap.data() ?? {};
      final webData = webSnap.data() ?? {};

      final result = {
        'totalMinutes': (appData['totalMinutes'] ?? 0) as int,
        'usedMinutes':
            (appData['usedMinutes'] ?? appData['totalMinutes'] ?? 0) as int,
        'remainingMinutes': appData['remainingMinutes'] as int?,
        'isLocked': (appData['isLocked'] ?? false) as bool,
        'apps': appData['apps'] ?? {},
        'websites': webData['websites'] ?? {},
        'lastSync': DateTime.now().toIso8601String(),
      };

      // Mise en cache
      _cache[cacheKey] = _CachedStats(data: result, timestamp: now);

      return result;
    } catch (e) {
      if (kDebugMode) print('StatsRepository error: $e');
      return {};
    }
  }

  Stream<Map<String, dynamic>> watchTodayStats(String childId) {
    if (_uid == null || childId.isEmpty) return Stream.value(const {});
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('usage')
        .collection('apps')
        .doc(today)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data() ?? const <String, dynamic>{};
      return <String, dynamic>{
        'totalMinutes': data['totalMinutes'] ?? 0,
        'usedMinutes': data['usedMinutes'] ?? data['totalMinutes'] ?? 0,
        'remainingMinutes': data['remainingMinutes'],
        'isLocked': data['isLocked'] ?? false,
        'apps': data['apps'] ?? const <String, dynamic>{},
        'lastSync': DateTime.now().toIso8601String(),
      };
    });
  }

  void clearCache() => _cache.clear();
}

class _CachedStats {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedStats({required this.data, required this.timestamp});
}
