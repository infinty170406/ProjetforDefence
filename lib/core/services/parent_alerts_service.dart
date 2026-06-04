import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

class ParentAlertsService {
  static final ParentAlertsService _instance = ParentAlertsService._internal();
  factory ParentAlertsService() => _instance;
  ParentAlertsService._internal();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _notificationsCol(String childId) =>
      _db.collection('parents').doc(FirestoreService().uid).collection('children').doc(childId).collection('alerts').doc('notifications').collection('items');

  Future<void> markAsRead(String childId, String alertId) => 
      _notificationsCol(childId)
          .doc(alertId)
          .update({'read': true, 'readAt': FieldValue.serverTimestamp()});

  Future<void> markAllAsRead(String childId) async {
    final snap = await _notificationsCol(childId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference,
          {'read': true, 'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  Stream<int> watchUnreadCount(String childId) {
    if (childId.isEmpty) return Stream.value(0);
    return _notificationsCol(childId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((q) => q.docs.length);
  }
}
