import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/link_activation.dart';
import '../models/child_profile.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String baseUrl = 'https://api.the-guardian.app/v1';
  static const String _childIdKey = 'child_id';
  static const String _parentIdKey = 'parent_id';
  static const String _childPathKey = 'child_path';
  static const String _deviceUidKey = 'device_uid';
  static const String _migratedKey = 'storage_migrated';

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedChildId;
  String? _cachedParentId;
  String? _cachedChildPath;

  String? _extractToken(String rawLink) {
    final trimmed = rawLink.trim();

    if (trimmed.startsWith('http') || trimmed.startsWith('guardian://')) {
      try {
        final uri = Uri.parse(trimmed);

        final childId = uri.queryParameters['childId'];
        if (childId != null && childId.isNotEmpty) return childId;

        final token = uri.queryParameters['token'] ?? uri.queryParameters['code'];
        if (token != null && token.isNotEmpty) return token;

        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          final last = segments.last;
          if (last.isNotEmpty && last != 'pair') return last;
        }
      } catch (e) {
        debugPrint('AuthService: Error parsing link: $e');
      }
      return null;
    }

    if (!trimmed.contains('/') && !trimmed.contains(' ') && trimmed.isNotEmpty) {
      return trimmed;
    }

    return null;
  }

  Future<LinkActivation> activateDevice(String rawLink) async {
    debugPrint('AuthService: Activating device with link: $rawLink');

    final token = _extractToken(rawLink);
    if (token == null || token.isEmpty) {
      debugPrint('AuthService: Could not extract token from link');
      return const LinkActivation(status: LinkStatus.invalid);
    }

    debugPrint('AuthService: Extracted token: $token');

    try {
      // 1. Check Connectivity
      final connectivityResultList = await Connectivity().checkConnectivity();
      if (connectivityResultList.contains(ConnectivityResult.none)) {
        debugPrint('AuthService: ❌ No internet connection');
        return const LinkActivation(
          status: LinkStatus.networkError,
          errorMessage: 'No internet connection available.',
        );
      }

      // 1b. Authentification anonyme
      debugPrint('AuthService: Starting anonymous auth...');
      
      // Petite pause pour stabiliser la connexion sur certains appareils (Xiaomi)
      await Future.delayed(const Duration(seconds: 1));

      final userCredential = await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 20), onTimeout: () {
        throw TimeoutException('Authentication timeout. Please check your connection.');
      });

      final uid = userCredential.user!.uid;
      debugPrint('AuthService: Anonymous auth successful, UID: $uid');

      // 2. Recherche du document enfant
      QuerySnapshot? query;
      try {
        debugPrint('AuthService: Searching collectionGroup "children" where id == $token');
        query = await _firestore
            .collectionGroup('children')
            .where('id', isEqualTo: token)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('AuthService: ⚠️ Query by id failed (possibly permission-denied): $e');
      }

      if (query == null || query.docs.isEmpty) {
        try {
          debugPrint('AuthService: Trying by "invitationToken"...');
          query = await _firestore
              .collectionGroup('children')
              .where('invitationToken', isEqualTo: token)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          debugPrint('AuthService: ❌ Query by invitationToken failed: $e');
        }
      }

      if (query == null || query.docs.isEmpty) {
        debugPrint('AuthService: ❌ No document found for token: $token');
        return const LinkActivation(status: LinkStatus.invalid);
      }

      final childDoc = query.docs.first;
      final childRef = childDoc.reference;
      final childData = childDoc.data() as Map<String, dynamic>;
      debugPrint('AuthService: Document found at path: ${childRef.path}');

      // 3. Log du statut actuel pour debug
      final isAlreadyLinked = childData['isLinked'] == true;
      final existingDeviceUid = childData['deviceUid'] as String?;
      if (isAlreadyLinked && existingDeviceUid != null) {
        debugPrint('AuthService: Link already used (existingDeviceUid: $existingDeviceUid). Re-linking with UID: $uid');
      } else {
        debugPrint('AuthService: First-time linking.');
      }

      // 4. Transaction : on met toujours à jour deviceUid avec le nouvel UID
      // On respecte les règles Firestore qui autorisent la modif de ces 3 clés uniquement.
      bool isValid = false;
      try {
        debugPrint('AuthService: Starting linking transaction for UID: $uid');
        await _firestore.runTransaction((transaction) async {
          final snap = await transaction.get(childRef);
          if (!snap.exists) {
            debugPrint('AuthService: ❌ Document disappeared during transaction.');
            return;
          }

          // On vérifie qu'on n'envoie que les clés autorisées par les règles Firestore
          final Map<String, dynamic> updateData = {
            'isLinked': true,
            'childDeviceUid': uid, // Doit correspondre au champ attendu par les règles Firestore
          };

          transaction.update(childRef, updateData);
          isValid = true;
        }).timeout(const Duration(seconds: 20));

        debugPrint('AuthService: ✅ Transaction complete.');
      } catch (e) {
        debugPrint('AuthService: ❌ Transaction failed: $e');
        if (e is FirebaseException) {
          debugPrint('AuthService: Firebase Error [${e.code}]: ${e.message}');
        }
        rethrow;
      }

      if (!isValid) {
        return const LinkActivation(status: LinkStatus.expired);
      }

      // 5. Persister les données localement
      final childId = childDoc.id;
      final parentId = childData['parentId'] as String? ?? '';
      final childPath = childRef.path;

      _cachedChildId = childId;
      _cachedParentId = parentId;
      _cachedChildPath = childPath;

      // 5. Persister les données de manière sécurisée
      await _secureStorage.write(key: _childIdKey, value: childId);
      await _secureStorage.write(key: _parentIdKey, value: parentId);
      await _secureStorage.write(key: _childPathKey, value: childPath);
      await _secureStorage.write(key: _deviceUidKey, value: uid);

      // Persister aussi dans SharedPreferences pour les services d'arrière-plan
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_childIdKey, childId);
      await prefs.setString(_parentIdKey, parentId);
      await prefs.setString(_childPathKey, childPath);
      await prefs.setString(_deviceUidKey, uid);
      await prefs.setBool(_migratedKey, true);

      debugPrint('AuthService: ✅ Activation successful — Child: $childId, Parent: $parentId');

      return LinkActivation(
        status: LinkStatus.success,
        childId: childId,
        parentId: parentId,
      );
    } catch (e) {
      debugPrint('AuthService: activation error: $e');
      String msg = 'An error occurred during activation.';
      
      if (e is FirebaseException) {
        debugPrint('AuthService: Firebase Detailed Error Code: ${e.code}');
        if (e.code == 'operation-not-allowed') {
          msg = 'Anonymous authentication is not enabled in Firebase.';
        } else if (e.code == 'permission-denied') {
          msg = 'Access denied by security rules. Please check if the device is already linked or if rules are correct.';
        } else if (e.code == 'failed-precondition') {
          msg = 'A Firestore index is required for this operation. Please check the Firebase console logs.';
        } else {
          msg = 'Firebase Error (${e.code}): ${e.message}';
        }
      } else if (e is TimeoutException) {
        msg = 'The server is not responding. Please check your connection.';
      }

      return LinkActivation(
        status: LinkStatus.networkError,
        errorMessage: msg,
      );
    }
  }

  Future<bool> isDeviceActivated() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('AuthService: isDeviceActivated - Current Firebase UID: ${user?.uid}');
    
    if (_cachedChildId != null) return true;

    // Tentative de lecture depuis le stockage sécurisé
    final secureChildId = await _secureStorage.read(key: _childIdKey);
    if (secureChildId != null) {
      _cachedChildId = secureChildId;
      _cachedParentId = await _secureStorage.read(key: _parentIdKey);
      _cachedChildPath = await _secureStorage.read(key: _childPathKey);
      return true;
    }

    // Migration depuis SharedPreferences si nécessaire
    final prefs = await SharedPreferences.getInstance();
    final hasOldData = prefs.containsKey(_childIdKey);
    
    if (hasOldData) {
      debugPrint('AuthService: Migrating data to secure storage...');
      final cid = prefs.getString(_childIdKey);
      final pid = prefs.getString(_parentIdKey);
      final path = prefs.getString(_childPathKey);
      final uid = prefs.getString(_deviceUidKey);

      if (cid != null) await _secureStorage.write(key: _childIdKey, value: cid);
      if (pid != null) await _secureStorage.write(key: _parentIdKey, value: pid);
      if (path != null) await _secureStorage.write(key: _childPathKey, value: path);
      if (uid != null) await _secureStorage.write(key: _deviceUidKey, value: uid);

      // Nettoyer SharedPreferences pour la sécurité
      // On conserve TOUTES les clés car le background isolate (RulesService, EnforcementService) en a besoin
      // await prefs.remove(_childIdKey);
      // await prefs.remove(_parentIdKey);
      // await prefs.remove(_childPathKey);
      // await prefs.remove(_deviceUidKey); 
      await prefs.setBool(_migratedKey, true);

      _cachedChildId = cid;
      _cachedParentId = pid;
      _cachedChildPath = path;
      return true;
    }

    return false;
  }

  Future<ChildProfile?> getChildProfile() async {
    final childPath = await _getChildPath();
    if (childPath == null) return null;

    try {
      final doc = await _firestore.doc(childPath).get();
      if (!doc.exists) return null;
      return ChildProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('AuthService: getChildProfile error: $e');
      return null;
    }
  }

  Stream<ChildProfile?> watchChildProfile() async* {
    final childPath = await _getChildPath();
    if (childPath == null) {
      yield null;
      return;
    }
    yield* _firestore.doc(childPath).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ChildProfile.fromFirestore(snap);
    });
  }

  Future<String?> _getChildPath() async {
    if (_cachedChildPath != null) return _cachedChildPath;
    _cachedChildPath = await _secureStorage.read(key: _childPathKey);
    return _cachedChildPath;
  }

  Future<String?> getChildId() async {
    if (_cachedChildId != null) return _cachedChildId;
    _cachedChildId = await _secureStorage.read(key: _childIdKey);
    return _cachedChildId;
  }

  Future<String?> getParentId() async {
    if (_cachedParentId != null) return _cachedParentId;
    _cachedParentId = await _secureStorage.read(key: _parentIdKey);
    return _cachedParentId;
  }

  Future<void> logout() async {
    _cachedChildId = null;
    _cachedParentId = null;
    _cachedChildPath = null;

    await _secureStorage.deleteAll();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migratedKey);

    await FirebaseAuth.instance.signOut();
  }
}