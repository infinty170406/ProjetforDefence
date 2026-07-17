import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'guardian_api.dart';
import '../models/child_profile.dart';
import '../models/link_activation.dart';
import '../utils/pairing_token.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _childIdKey = 'child_id';
  static const String _parentIdKey = 'parent_id';
  static const String _childPathKey = 'child_path';
  static const String _deviceUidKey = 'device_uid';
  static const String _migratedKey = 'storage_migrated';
  static final RegExp _identifierPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _cachedChildId;
  String? _cachedParentId;
  String? _cachedChildPath;
  String? _cachedDeviceUid;

  Future<LinkActivation> activateDevice(String rawLink) async {
    final token = extractPairingToken(rawLink);
    if (token == null) {
      return const LinkActivation(status: LinkStatus.invalid);
    }

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      if (connectivityResults.contains(ConnectivityResult.none)) {
        return const LinkActivation(
          status: LinkStatus.networkError,
          errorMessage: 'Aucune connexion Internet disponible.',
        );
      }

      final user = await _ensureAnonymousUser();
      final activation = await GuardianApi.post(
        '/api/v1/device/pair',
        body: {'token': token},
      ).timeout(const Duration(seconds: 45));
      final childId = activation['childId'] as String?;
      final parentId = activation['parentId'] as String?;
      if (!_isValidIdentifier(childId) || !_isValidIdentifier(parentId)) {
        return const LinkActivation(status: LinkStatus.invalid);
      }

      final childPath = 'parents/$parentId/children/$childId';
      await _persistPairing(
        childId: childId!,
        parentId: parentId!,
        childPath: childPath,
        deviceUid: user.uid,
      );

      debugPrint('AuthService: Device pairing completed.');
      return LinkActivation(
        status: LinkStatus.success,
        childId: childId,
        parentId: parentId,
      );
    } on GuardianApiException catch (error) {
      debugPrint('AuthService: Pairing backend error (${error.code}).');
      if (error.statusCode == 400) {
        return const LinkActivation(status: LinkStatus.invalid);
      }
      if (error.statusCode == 404 ||
          error.statusCode == 410 ||
          error.statusCode == 412 ||
          error.statusCode == 403) {
        return const LinkActivation(status: LinkStatus.expired);
      }
      return const LinkActivation(
        status: LinkStatus.networkError,
        errorMessage: 'Le service de jumelage est indisponible.',
      );
    } on TimeoutException {
      return const LinkActivation(
        status: LinkStatus.networkError,
        errorMessage: 'Le serveur ne répond pas. Vérifiez la connexion.',
      );
    } on FirebaseAuthException catch (error) {
      debugPrint('AuthService: Anonymous authentication failed (${error.code}).');
      return const LinkActivation(
        status: LinkStatus.networkError,
        errorMessage: 'Impossible d’authentifier cet appareil.',
      );
    } catch (error) {
      debugPrint('AuthService: Pairing failed: $error');
      return const LinkActivation(
        status: LinkStatus.networkError,
        errorMessage: 'Une erreur est survenue pendant le jumelage.',
      );
    }
  }

  Future<User> _ensureAnonymousUser() async {
    var user = _auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await _auth.signOut();
      user = null;
    }
    user ??= (await _auth.signInAnonymously().timeout(
      const Duration(seconds: 20),
    ))
        .user;
    if (user == null || !user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'anonymous-auth-failed',
        message: 'Anonymous child authentication failed.',
      );
    }
    return user;
  }

  Future<void> _persistPairing({
    required String childId,
    required String parentId,
    required String childPath,
    required String deviceUid,
  }) async {
    _cachedChildId = childId;
    _cachedParentId = parentId;
    _cachedChildPath = childPath;
    _cachedDeviceUid = deviceUid;

    await Future.wait([
      _secureStorage.write(key: _childIdKey, value: childId),
      _secureStorage.write(key: _parentIdKey, value: parentId),
      _secureStorage.write(key: _childPathKey, value: childPath),
      _secureStorage.write(key: _deviceUidKey, value: deviceUid),
    ]);

    // Les services Android et l'isolate de fond doivent pouvoir lire ces
    // identifiants. Ils ne constituent pas un secret d'autorisation : les
    // règles Firebase vérifient toujours l'UID authentifié childDeviceUid.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_childIdKey, childId);
    await prefs.setString(_parentIdKey, parentId);
    await prefs.setString(_childPathKey, childPath);
    await prefs.setString(_deviceUidKey, deviceUid);
    await prefs.setBool(_migratedKey, true);
  }

  Future<bool> isDeviceActivated() async {
    await _hydratePairing();
    if (!_isValidIdentifier(_cachedChildId) ||
        !_isValidIdentifier(_cachedParentId) ||
        !_isValidIdentifier(_cachedDeviceUid)) {
      return false;
    }

    final expectedPath =
        'parents/$_cachedParentId/children/$_cachedChildId';
    if (_cachedChildPath != expectedPath) {
      _cachedChildPath = expectedPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_childPathKey, expectedPath);
      await _secureStorage.write(key: _childPathKey, value: expectedPath);
    }

    User? user = _auth.currentUser;
    user ??= await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        );

    return user != null &&
        user.isAnonymous &&
        user.uid == _cachedDeviceUid;
  }

  Future<void> _hydratePairing() async {
    if (_cachedChildId != null &&
        _cachedParentId != null &&
        _cachedDeviceUid != null) {
      return;
    }

    try {
      _cachedChildId = await _secureStorage.read(key: _childIdKey);
      _cachedParentId = await _secureStorage.read(key: _parentIdKey);
      _cachedChildPath = await _secureStorage.read(key: _childPathKey);
      _cachedDeviceUid = await _secureStorage.read(key: _deviceUidKey);
    } catch (error) {
      debugPrint('AuthService: Secure storage read failed: $error');
    }

    if (_cachedChildId != null &&
        _cachedParentId != null &&
        _cachedDeviceUid != null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final childId = prefs.getString(_childIdKey);
    final parentId = prefs.getString(_parentIdKey);
    final deviceUid = prefs.getString(_deviceUidKey);
    if (childId == null || parentId == null || deviceUid == null) return;

    final childPath = 'parents/$parentId/children/$childId';
    await _persistPairing(
      childId: childId,
      parentId: parentId,
      childPath: childPath,
      deviceUid: deviceUid,
    );
  }

  bool _isValidIdentifier(String? value) =>
      value != null && _identifierPattern.hasMatch(value);

  Future<ChildProfile?> getChildProfile() async {
    final childPath = await _getChildPath();
    if (childPath == null) return null;

    try {
      final document = await _firestore.doc(childPath).get();
      if (!document.exists) return null;
      return ChildProfile.fromFirestore(document);
    } catch (error) {
      debugPrint('AuthService: Child profile read failed: $error');
      return null;
    }
  }

  Stream<ChildProfile?> watchChildProfile() async* {
    final childPath = await _getChildPath();
    if (childPath == null) {
      yield null;
      return;
    }
    yield* _firestore.doc(childPath).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return ChildProfile.fromFirestore(snapshot);
    });
  }

  Future<String?> _getChildPath() async {
    await _hydratePairing();
    if (!_isValidIdentifier(_cachedChildId) ||
        !_isValidIdentifier(_cachedParentId)) {
      return null;
    }
    return 'parents/$_cachedParentId/children/$_cachedChildId';
  }

  Future<String?> getChildId() async {
    await _hydratePairing();
    return _cachedChildId;
  }

  Future<String?> getParentId() async {
    await _hydratePairing();
    return _cachedParentId;
  }

  Future<void> logout() async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (error) {
      debugPrint('AuthService: Background service stop failed: $error');
    }

    _cachedChildId = null;
    _cachedParentId = null;
    _cachedChildPath = null;
    _cachedDeviceUid = null;

    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    for (final key in <String>{
      _childIdKey,
      _parentIdKey,
      _childPathKey,
      _deviceUidKey,
      _migratedKey,
      'onboarding_complete',
      'cached_rules',
      'monitored_notification_packages',
      'guardian_monitor_account_activity',
      'guardian_location_alerts',
      'gemini_api_key',
      'guardian_pending_firestore_ops',
    }) {
      await prefs.remove(key);
    }
    for (final key in prefs.getKeys().where(
          (key) => key.startsWith('guardian_alert_'),
        )) {
      await prefs.remove(key);
    }

    await _auth.signOut();
    debugPrint('AuthService: Local child session cleared.');
  }
}
