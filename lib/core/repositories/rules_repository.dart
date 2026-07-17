import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/child_rules.dart';

class RulesRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference _rulesDoc(String childId) {
    if (_uid == null) throw Exception('User not authenticated');
    return _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('rules')
        .doc('active');
  }

  /// Source de vérité Firestore pour les règles de l'enfant.
  Stream<ChildRules> watchRules(String childId) {
    return _rulesDoc(childId).snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>?;
      return ChildRules.fromJson(data ?? const {});
    });
  }

  /// Sauvegarde les règles avec validation
  Future<void> saveRules(String childId, ChildRules rules) async {
    // La validation est faite dans le constructeur de ChildRules
    final data = rules.copyWith(rulesConfigured: true).toJson();
    // NOTE: childDeviceUid n'est PAS défini ici — il est défini une seule fois
    // lors de l'appairage (child_pairing_screen) avec l'UID Auth anonyme
    // de l'appareil enfant. Le parent ne le connaît pas et ne doit jamais l'écraser.
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['parentId'] = _uid;
    await _rulesDoc(childId).set(data, SetOptions(merge: true));

    // Synchronisation de la limite journalière sur le document enfant pour un accès rapide
    await _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .update({
      'dailyLimitMinutes': rules.dailyLimitMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bloquer/Débloquer une application spécifique
  Future<void> toggleAppBlock(
      String childId, String packageName, bool block) async {
    await _rulesDoc(childId).set({
      'blockedApps': block
          ? FieldValue.arrayUnion([packageName])
          : FieldValue.arrayRemove([packageName]),
      'rulesConfigured': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Bloquer/Débloquer un site web spécifique
  Future<void> toggleWebsiteBlock(
      String childId, String domain, bool block) async {
    await _rulesDoc(childId).set({
      'blockedWebsites': block
          ? FieldValue.arrayUnion([domain])
          : FieldValue.arrayRemove([domain]),
      'rulesConfigured': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Récupère l'inventaire des applications installées
  Stream<List<String>> watchInstalledApps(String childId) {
    if (_uid == null) throw Exception('User not authenticated');
    return _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('inventory')
        .doc('apps')
        .snapshots()
        .map((snapshot) => List<String>.from(
            snapshot.data()?['installedPackages'] as List? ?? const []));
  }

  Future<void> updateDailyLimit(String childId, int limit) async {
    await _rulesDoc(childId).set({
      'dailyLimitMinutes': limit,
      'rulesConfigured': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Sync to child doc
    await _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .update({
      'dailyLimitMinutes': limit,
    });
  }

  Future<ChildRules> getRules(String childId) async {
    final snap = await _rulesDoc(childId).get();
    if (!snap.exists) return ChildRules();
    return ChildRules.fromJson(snap.data() as Map<String, dynamic>);
  }

  Stream<List<String>> blockedAppsStream(String childId) {
    return watchRules(childId).map((rules) => rules.blockedApps);
  }

  Future<void> updateBlockedApps(
      String childId, List<String> blockedApps) async {
    await _rulesDoc(childId).set({
      'blockedApps': blockedApps,
      'rulesConfigured': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
