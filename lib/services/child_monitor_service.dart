import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rules_service.dart';

/// ChildMonitorService (Restructured & Restricted)
///
/// Provides read-only access to parental rules and geofences for the child app.
/// Restricted: No access to alerts history or usage statistics as per user request.
class ChildMonitorService {
  static final ChildMonitorService _instance = ChildMonitorService._internal();
  factory ChildMonitorService() => _instance;
  ChildMonitorService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns the stream of active rules for the child.
  Stream<ActiveRules> watchRules() async* {
    final prefs = await SharedPreferences.getInstance();
    final childPath = prefs.getString('child_path');
    if (childPath == null) {
      yield ActiveRules.empty;
      return;
    }

    yield* _db.doc('$childPath/rules/active').snapshots().map((snap) {
      if (!snap.exists) return ActiveRules.empty;
      return ActiveRules.fromFirestore(snap.data() as Map<String, dynamic>);
    });
  }

  /// Returns the stream of geofences assigned to this child.
  /// Fetches from the parent's global geofences collection.
  Stream<List<Geofence>> watchGeofences() async* {
    final prefs = await SharedPreferences.getInstance();
    final parentId = prefs.getString('parent_id');
    final childId = prefs.getString('child_id');

    if (parentId == null || childId == null) {
      yield [];
      return;
    }

    yield* _db
        .collection('parents')
        .doc(parentId)
        .collection('geofences')
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => Geofence.fromFirestore({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }
}

