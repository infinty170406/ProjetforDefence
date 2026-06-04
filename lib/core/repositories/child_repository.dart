import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ChildRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference get _parentDoc {
    if (_uid == null) throw Exception('User not authenticated');
    return _db.collection('parents').doc(_uid);
  }

  CollectionReference get _childrenCol => _parentDoc.collection('children');

  /// Récupère la liste des enfants en temps réel
  Stream<List<Map<String, dynamic>>> watchChildren() {
    if (_uid == null) return Stream.value([]);
    return _childrenCol
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Récupère l'historique d'un enfant
  Future<List<Map<String, dynamic>>> getHistory(String childId) async {
    try {
      final snap = await _childrenCol
          .doc(childId)
          .collection('history')
          .orderBy('occurredAt', descending: true)
          .limit(20)
          .get();

      return snap.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      if (kDebugMode) print('ChildRepository: getHistory error: $e');
      return [];
    }
  }

  /// Crée un nouvel enfant avec une structure par défaut
  Future<Map<String, dynamic>> createChild({
    required String displayName,
    required int age,
    bool isMinor = true,
  }) async {
    final docRef = _childrenCol.doc();
    final randomToken = (100000 + Random().nextInt(900000)).toString(); // 6 digits

    final data = {
      'id': docRef.id,
      'displayName': displayName,
      'age': age,
      'isMinor': isMinor,
      'ageGroup': isMinor ? 'MINOR' : 'ADULT',
      'parentId': _uid,
      'deviceStatus': AppConstants.statusOffline,
      'createdAt': FieldValue.serverTimestamp(),
      'isLinked': false,
      'invitationToken': randomToken,
    };

    await docRef.set(data);
    await _initDefaultRules(docRef, isMinor);
    await _ensureChildStructure(docRef.id);

    return {...data, 'id': docRef.id};
  }

  Future<void> _initDefaultRules(DocumentReference childDoc, bool isMinor) async {
    await childDoc.collection('rules').doc('active').set({
      'blockedApps': [],
      'dailyLimitMinutes': isMinor ? 120 : 0,
      'allowedTimeStart': isMinor ? '07:00' : null,
      'allowedTimeEnd': isMinor ? '21:00' : null,
      'blockSocialMedia': isMinor,
      'blockGaming': isMinor,
      'blockAdultContent': true,
      'blockViolence': true,
      'blockDrugs': true,
      'blockSexualPredators': true,
      'blockAnxietyDepression': isMinor,
      'blockSelfHarm': true,
      'blockCyberbullying': true,
      'blockMatureContent': isMinor,
      'blockEatingDisorders': isMinor,
      'monitorAccountActivity': true,
      'locationAlerts': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureChildStructure(String childId) async {
    final batch = _db.batch();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final childDoc = _childrenCol.doc(childId);

    // Initialisation des hubs d'alertes
    batch.set(childDoc.collection('alerts').doc('usage'), {'initialized': true, 'type': 'usage_hub'}, SetOptions(merge: true));
    batch.set(childDoc.collection('alerts').doc('notifications'), {'initialized': true, 'type': 'notif_hub'}, SetOptions(merge: true));

    // Structure des statistiques
    batch.set(childDoc.collection('alerts').doc('usage').collection('apps').doc(today), {
      'lastInit': FieldValue.serverTimestamp(),
      'childId': childId,
      'date': today,
    }, SetOptions(merge: true));

    // Inventaire
    batch.set(childDoc.collection('inventory').doc('summary'), {'initialized': true}, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> deleteChild(String childId) async {
    await _childrenCol.doc(childId).delete();
  }

  Future<void> linkChild(String childId) async {
    await _childrenCol.doc(childId).update({
      'isLinked': true,
      'linkedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<String> watchDeviceStatus(String childId) {
    if (_uid == null || childId.isEmpty) return Stream.value(AppConstants.statusOffline);
    return _childrenCol.doc(childId).snapshots().map((snap) {
      final data = snap.data() as Map<String, dynamic>?;
      return (data?['deviceStatus'] as String?) ?? AppConstants.statusOffline;
    });
  }
}
