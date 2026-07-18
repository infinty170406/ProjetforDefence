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

  static const _pairingTokenAlphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';

  String _newPairingToken() {
    final random = Random.secure();
    return List.generate(
      48,
      (_) =>
          _pairingTokenAlphabet[random.nextInt(_pairingTokenAlphabet.length)],
    ).join();
  }

  /// Source de vérité Firestore pour la liste des enfants.
  Stream<List<Map<String, dynamic>>> watchChildren() {
    return _childrenCol
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...(doc.data() as Map<String, dynamic>),
                  'id': doc.id,
                })
            .toList());
  }

  Future<int> getChildrenCount() => _childrenCol.count().get().then(
        (snapshot) => snapshot.count ?? 0,
      );

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

  Future<Map<String, dynamic>> createChild({
    required String displayName,
    required int age,
    bool isMinor = true,
    String? avatar,
    String? relation,
  }) async {
    final docRef = _childrenCol.doc();
    final randomToken = _newPairingToken();

    String? familyId;
    try {
      final parentSnap = await _parentDoc.get();
      if (parentSnap.exists) {
        final parentData = parentSnap.data() as Map<String, dynamic>?;
        familyId = parentData?['familyId'] as String?;
      }
    } catch (e) {
      if (kDebugMode) print('ChildRepository: fetch familyId error: $e');
    }

    final data = {
      'id': docRef.id,
      'displayName': displayName,
      'age': age,
      'isMinor': isMinor,
      'ageGroup': isMinor ? 'MINOR' : 'ADULT',
      'parentId': _uid,
      if (familyId != null) 'familyId': familyId,
      'deviceStatus': AppConstants.statusOffline,
      'createdAt': FieldValue.serverTimestamp(),
      'isLinked': false,
      'invitationToken': randomToken,
      'invitationExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 48)),
      ),
      if (avatar != null) 'avatar': avatar,
      if (relation != null) 'relation': relation,
    };

    await docRef.set(data);
    await _initDefaultRules(docRef, isMinor);
    await _ensureChildStructure(docRef.id);

    if (familyId != null) {
      try {
        await _db.collection('families').doc(familyId).update({
          'children': FieldValue.arrayUnion([docRef.id]),
        });
      } catch (e) {
        if (kDebugMode) {
          print('ChildRepository: update family children error: $e');
        }
      }
    }

    return {...data, 'id': docRef.id};
  }

  Future<void> _initDefaultRules(
      DocumentReference childDoc, bool isMinor) async {
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
      'rulesConfigured': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureChildStructure(String childId) async {
    final batch = _db.batch();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final childDoc = _childrenCol.doc(childId);

    // Initialisation des hubs d'alertes
    batch.set(childDoc.collection('alerts').doc('usage'),
        {'initialized': true, 'type': 'usage_hub'}, SetOptions(merge: true));
    batch.set(childDoc.collection('alerts').doc('notifications'),
        {'initialized': true, 'type': 'notif_hub'}, SetOptions(merge: true));

    // Structure des statistiques
    batch.set(
        childDoc
            .collection('alerts')
            .doc('usage')
            .collection('apps')
            .doc(today),
        {
          'lastInit': FieldValue.serverTimestamp(),
          'childId': childId,
          'date': today,
        },
        SetOptions(merge: true));

    // Inventaire
    batch.set(childDoc.collection('inventory').doc('summary'),
        {'initialized': true}, SetOptions(merge: true));

    await batch.commit();
  }

  Future<Map<String, dynamic>> regeneratePairingInvitation(
    String childId,
  ) async {
    final childRef = _childrenCol.doc(childId);
    final token = _newPairingToken();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 48)),
    );

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(childRef);
      if (!snapshot.exists) {
        throw StateError('Child profile not found.');
      }

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data?['isLinked'] == true) {
        throw StateError('This child device is already paired.');
      }

      transaction.update(childRef, {
        'invitationToken': token,
        'invitationExpiresAt': expiresAt,
        'pairingLinkUpdatedAt': FieldValue.serverTimestamp(),
      });
    });

    return {
      'invitationToken': token,
      'invitationExpiresAt': expiresAt,
    };
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
    return _childrenCol.doc(childId).snapshots().map(
          (snapshot) =>
              (snapshot.data() as Map<String, dynamic>?)?['deviceStatus']
                  as String? ??
              AppConstants.statusOffline,
        );
  }
}
