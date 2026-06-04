import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChildMonitorService {
  static final ChildMonitorService _instance = ChildMonitorService._internal();
  factory ChildMonitorService() => _instance;
  ChildMonitorService._internal();

  final _db = FirebaseFirestore.instance;

  /// Returns the parentId from Firebase Auth when available (parent app),
  /// or null when the user is not authenticated (child app).
  String? get _authParentId => FirebaseAuth.instance.currentUser?.uid;

  /// Resolves the Firestore path for a child document.
  /// [parentId] takes priority over the authenticated user's UID,
  /// which allows child devices (not Firebase-authenticated) to read data.
  String _childPath(String childId, {String? parentId}) {
    final pid = parentId ?? _authParentId;
    // If pid is still null (first async frame on child device before init
    // completes), return an unreachable path so streams simply emit nothing.
    if (pid == null) return 'parents/_pending_/children/$childId';
    return 'parents/$pid/children/$childId';
  }

  // ── Device status ─────────────────────────────────────────────────────────

  Stream<String> watchDeviceStatus(String childId, {String? parentId}) => _db
      .doc(_childPath(childId, parentId: parentId))
      .snapshots()
      .map((s) => (s.data()?['deviceStatus'] as String?) ?? 'OFFLINE');

  // ── GPS Location ──────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchLocation(String childId, {String? parentId}) => _db
      .doc('${_childPath(childId, parentId: parentId)}/location/current')
      .snapshots()
      .map((s) => s.data());

  // ── Alerts ────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchAlerts(String childId, {String? parentId}) => _db
      .collection('${_childPath(childId, parentId: parentId)}/alerts/notifications/items')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => q.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList());

  // ── Usage stats ───────────────────────────────────────────────────────────
  
  String _statsAppsPath(String childId, {String? parentId}) => '${_childPath(childId, parentId: parentId)}/alerts/usage/apps';
  String _statsWebPath(String childId, {String? parentId}) => '${_childPath(childId, parentId: parentId)}/alerts/usage/websites';

  Future<Map<String, dynamic>?> getTodayStats(String childId, {String? parentId}) async {
    final today = _dateStr(DateTime.now());
    final appSnap = await _db.doc('${_statsAppsPath(childId, parentId: parentId)}/$today').get();
    final webSnap = await _db.doc('${_statsWebPath(childId, parentId: parentId)}/$today').get();
    
    final appData = appSnap.data() ?? {};
    final webData = webSnap.data() ?? {};

    final appUsed = (appData['usedMinutes'] ?? appData['totalMinutes'] ?? 0) as int;
    final webUsed = (webData['usedMinutes'] ?? webData['totalMinutes'] ?? 0) as int;

    return {
      'totalMinutes': appUsed + webUsed,
      'usedMinutes': appUsed + webUsed,
      'apps': appData['apps'] ?? {},
      'websites': webData['websites'] ?? {},
    };
  }

  Future<List<Map<String, dynamic>>> getWeekStats(String childId, {String? parentId}) async {
    final appSnap = await _db
        .collection(_statsAppsPath(childId, parentId: parentId))
        .orderBy(FieldPath.documentId, descending: true)
        .limit(7)
        .get();
    
    final stats = appSnap.docs.map((d) {
      final data = d.data();
      data['date'] = d.id;
      return data;
    }).toList();
    return stats;
  }

  Future<List<Map<String, dynamic>>> getMonthStats(String childId, {String? parentId}) async {
    final appSnap = await _db
        .collection(_statsAppsPath(childId, parentId: parentId))
        .orderBy(FieldPath.documentId, descending: true)
        .limit(30)
        .get();
    
    final stats = appSnap.docs.map((d) {
      final data = d.data();
      data['date'] = d.id;
      return data;
    }).toList();
    return stats;
  }

  // ── App inventory ─────────────────────────────────────────────────────────

  Future<List<String>> getInstalledApps(String childId, {String? parentId}) async {
    final snap =
        await _db.doc('${_childPath(childId, parentId: parentId)}/inventory/apps').get();
    return List<String>.from(snap.data()?['installedPackages'] ?? []);
  }

  Future<Map<String, dynamic>?> getAppDetails(String childId, String packageName, {String? parentId}) async {
    final snap = await _db
        .doc('${_childPath(childId, parentId: parentId)}/inventory/apps/details/$packageName')
        .get();
    return snap.data();
  }

  // ── Rules & Geofences ───────────────────────────────────────────────────

  Stream<Map<String, dynamic>> watchRules(String childId, {String? parentId}) => _db
      .doc('${_childPath(childId, parentId: parentId)}/rules/active')
      .snapshots()
      .map((s) => s.data() ?? {});

  Stream<List<Map<String, dynamic>>> watchGeofences(String childId, {String? parentId}) {
    final pid = parentId ?? _authParentId;
    if (pid == null) return Stream.value([]);
    return _db
        .collection('parents/$pid/geofences')
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Web & Paginated History ──────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchWebHistory(String childId, {String? parentId}) => _db
      .collection('${_childPath(childId, parentId: parentId)}/inventory/websites/history')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  Future<QuerySnapshot<Map<String, dynamic>>> getAlertsPaginated(
    String childId, {
    String? parentId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('${_childPath(childId, parentId: parentId)}/alerts/notifications/items')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return await query.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getWebHistoryPaginated(
    String childId, {
    String? parentId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('${_childPath(childId, parentId: parentId)}/inventory/websites/history')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return await query.get();
  }

  Stream<Map<String, dynamic>?> watchSingleChild(String childId, {String? parentId}) => _db
      .doc(_childPath(childId, parentId: parentId))
      .snapshots()
      .map((s) => s.data());

  Future<List<Map<String, dynamic>>> getGeofences({String? parentId}) async {
    final pid = parentId ?? _authParentId;
    if (pid == null) return [];
    final snap = await _db.collection('parents').doc(pid).collection('geofences').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> markAllAlertsRead(String childId, {String? parentId}) async {
    final col = _db.collection('${_childPath(childId, parentId: parentId)}/alerts/notifications/items');
    final snap = await col.where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> handleAlertInteraction({
    required String childId,
    required String alertId,
    required String action,
    required String actionType,
    required String actionValue,
    String? parentId,
  }) async {
    final path = _childPath(childId, parentId: parentId);
    final alertRef = _db.doc('$path/alerts/notifications/items/$alertId');

    await alertRef.update({
      'parentAction': action,
      'processedAt': FieldValue.serverTimestamp(),
      'read': true,
    });

    if (action == 'ALLOW') {
      final rulesRef = _db.doc('$path/rules/active');

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

  // ── Helpers ───────────────────────────────────────────────────────────────

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
