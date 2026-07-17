import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference _notificationsCol(String childId) {
    if (_uid == null) throw Exception('User not authenticated');
    return _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('notifications')
        .collection('items');
  }

  /// Source de vérité Firestore pour les alertes de l'enfant.
  Stream<List<Map<String, dynamic>>> watchAlerts(String childId) {
    return _notificationsCol(childId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...(doc.data() as Map<String, dynamic>),
                  'id': doc.id,
                })
            .toList());
  }

  /// Marquer toutes les alertes comme lues
  Future<void> markAllRead(String childId) async {
    final snap =
        await _notificationsCol(childId).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Interaction sur une alerte (ALLOW / DENY)
  Future<void> handleInteraction({
    required String childId,
    required String alertId,
    required String action,
    required String actionType,
    required String actionValue,
  }) async {
    final alertRef = _notificationsCol(childId).doc(alertId);

    await alertRef.update({
      'parentAction': action,
      'processedAt': FieldValue.serverTimestamp(),
      'read': true,
    });

    if (action == 'ALLOW') {
      final rulesRef = _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('rules')
          .doc('active');

      if (actionType == 'WEB_SEARCH') {
        await rulesRef.update({
          'allowedWebsites': FieldValue.arrayUnion([actionValue])
        });
      } else if (actionType == 'KEYWORD') {
        await rulesRef.update({
          'allowedKeywords': FieldValue.arrayUnion([actionValue])
        });
      }
    }
  }

  /// Récupère le décompte des alertes par période
  Future<Map<String, int>> getAlertCounts(String childId) async {
    if (_uid == null || childId.isEmpty) {
      return {'day': 0, 'week': 0, 'month': 0};
    }
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snap = await _notificationsCol(childId).get();
      int day = 0, week = 0, month = 0;

      for (final doc in snap.docs) {
        final ts =
            (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
        if (ts == null) continue;
        final date = ts.toDate();
        if (date.isAfter(startOfDay)) day++;
        if (date.isAfter(now.subtract(const Duration(days: 7)))) week++;
        if (date.isAfter(DateTime(now.year, now.month, 1))) month++;
      }
      return {'day': day, 'week': week, 'month': month};
    } catch (_) {
      return {'day': 0, 'week': 0, 'month': 0};
    }
  }
}
