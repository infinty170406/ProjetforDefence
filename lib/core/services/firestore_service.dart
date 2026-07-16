import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'email_service.dart';
import '../repositories/child_repository.dart';
import '../repositories/rules_repository.dart';
import '../repositories/alert_repository.dart';
import '../repositories/stats_repository.dart';
import '../models/child_rules.dart';
import '../constants/app_constants.dart';

/// FirestoreService acts as a facade delegating to specialized repositories.
/// [DEPRECATED] Use individual repositories directly for new code.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final _childRepo = ChildRepository();
  final _rulesRepo = RulesRepository();
  final _alertRepo = AlertRepository();
  final _statsRepo = StatsRepository();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    // Anonymous users are child devices — they must not access parent data.
    if (user.isAnonymous) throw Exception('Anonymous user — no parent profile');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _parentDoc =>
      _db.collection('parents').doc(uid);

  // ── Parent Profile ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final snap = await _parentDoc.get();
      if (snap.exists) {
        return snap.data() as Map<String, dynamic>;
      }
      return await _createProfile();
    } catch (e) {
      if (kDebugMode) print('FirestoreService: getMyProfile error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _createProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    final data = {
      'uid': uid,
      'name': user?.displayName ?? '',
      'email': user?.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'kycStatus': AppConstants.kycPending,
    };
    await _parentDoc.set(data, SetOptions(merge: true));
    return data;
  }

  Future<void> updateLastActive() async {
    try {
      // Skip on child devices: they sign in anonymously and have no parent profile.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      await _parentDoc.set({
        'last_active': FieldValue.serverTimestamp(),
        'app_status': 'Active',
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) print('FirestoreService: Heartbeat error: $e');
    }
  }

  // ── OTP (MFA) ────────────────────────────────────────────────────────────

  Future<void> sendOtpCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) throw Exception('User has no email');

    final code = (100000 + Random().nextInt(900000)).toString();

    await _parentDoc.collection('verification').doc('otp').set({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
      'email': user.email,
    });

    try {
      await EmailService().sendOtpEmail(user.email!, code);
    } catch (e) {
      throw Exception('Failed to send email: $e');
    }
  }

  Future<bool> verifyOtpCode(String code) async {
    final snap = await _parentDoc.collection('verification').doc('otp').get();
    if (!snap.exists) return false;

    final data = snap.data()!;
    final storedCode = data['code'] as String;
    final expiresAt = data['expiresAt'] as Timestamp;

    if (DateTime.now().isAfter(expiresAt.toDate())) {
      throw Exception('Code expired');
    }

    if (storedCode == code) {
      await _parentDoc.update({
        'otpVerified': true,
        'otpVerifiedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }

  // ── Delegation to Repositories ───────────────────────────────────────────

  // Children
  Future<List<Map<String, dynamic>>> getMyChildren() async {
    final snapshot = await _db.collection('parents').doc(uid).collection('children').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<Map<String, dynamic>> createChild({required String displayName, required int age, bool isMinor = true}) =>
      _childRepo.createChild(displayName: displayName, age: age, isMinor: isMinor);

  Stream<List<Map<String, dynamic>>> childrenStream() => _childRepo.watchChildren();

  Future<void> deleteChild(String childId) => _childRepo.deleteChild(childId);

  Future<void> linkChild(String childId) => _childRepo.linkChild(childId);

  Stream<String> watchDeviceStatus(String childId) => _childRepo.watchDeviceStatus(childId);

  // Rules
  Future<void> saveRules(String childId, {
    List<String> blockedApps = const [],
    List<String> blockedWebsites = const [],
    int dailyLimitMinutes = 0,
    String? allowedTimeStart,
    String? allowedTimeEnd,
    bool blockSocialMedia = false,
    bool blockGaming = false,
    bool blockAdultContent = true,
    bool blockViolence = true,
    bool blockDrugs = true,
    bool blockSexualPredators = true,
    bool blockAnxietyDepression = false,
    bool blockSelfHarm = true,
    bool blockCyberbullying = true,
    bool blockMatureContent = false,
    bool blockEatingDisorders = false,
    bool monitorAccountActivity = true,
    bool locationAlerts = true,
    List<String> customKeywords = const [],
    List<String> customCategories = const [],
    String mode = 'CUSTOM',
    String? blockReason,
    String? geminiApiKey,
    List<String> monitoredNotificationPackages = const [],
  }) async {
    final rules = ChildRules(
      blockedApps: blockedApps,
      blockedWebsites: blockedWebsites,
      dailyLimitMinutes: dailyLimitMinutes,
      allowedTimeStart: allowedTimeStart,
      allowedTimeEnd: allowedTimeEnd,
      blockSocialMedia: blockSocialMedia,
      blockGaming: blockGaming,
      blockAdultContent: blockAdultContent,
      blockViolence: blockViolence,
      blockDrugs: blockDrugs,
      blockSexualPredators: blockSexualPredators,
      blockAnxietyDepression: blockAnxietyDepression,
      blockSelfHarm: blockSelfHarm,
      blockCyberbullying: blockCyberbullying,
      blockMatureContent: blockMatureContent,
      blockEatingDisorders: blockEatingDisorders,
      monitorAccountActivity: monitorAccountActivity,
      locationAlerts: locationAlerts,
      customKeywords: customKeywords,
      customCategories: customCategories,
      mode: mode,
      blockReason: blockReason,
      geminiApiKey: geminiApiKey,
      monitoredNotificationPackages: monitoredNotificationPackages,
    );
    await _rulesRepo.saveRules(childId, rules);
  }

  Stream<Map<String, dynamic>?> watchRules(String childId) =>
      _rulesRepo.watchRules(childId).map((rules) => rules.toJson());

  Stream<List<String>> appInventoryStream(String childId) => _rulesRepo.watchInstalledApps(childId);

  // Stats
  Future<Map<String, dynamic>> getTodayStats(String childId) => _statsRepo.getTodayStats(childId);

  Future<Map<String, dynamic>> getUsageStats(String childId) => _statsRepo.getTodayStats(childId);

  // Alerts
  Stream<List<Map<String, dynamic>>> watchAlerts(String childId) => _alertRepo.watchAlerts(childId);

  Future<void> markAllAlertsRead(String childId) => _alertRepo.markAllRead(childId);

  Future<void> handleAlertInteraction({
    required String childId,
    required String alertId,
    required String action,
    required String actionType,
    required String actionValue,
  }) => _alertRepo.handleInteraction(
    childId: childId,
    alertId: alertId,
    action: action,
    actionType: actionType,
    actionValue: actionValue,
  );

  Future<void> ensureProfileExists(String name, String email) async {
    final snap = await _parentDoc.get();
    if (!snap.exists) {
      await _parentDoc.set({
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'kycStatus': AppConstants.kycPending,
      }, SetOptions(merge: true));
    }
  }

  Future<void> updateKycStatus(String status) async {
    await _parentDoc.update({'kycStatus': status});
  }

  Future<Map<String, dynamic>> updateChild(String childId, {required String displayName, required int age}) async {
    final data = {
      'displayName': displayName,
      'age': age,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('parents').doc(uid).collection('children').doc(childId).update(data);
    return data;
  }

  Future<Map<String, dynamic>> getParentalProfile(String childId) async {
    final snap = await _db.collection('parents').doc(uid).collection('children').doc(childId).get();
    return snap.data() ?? {};
  }

  Future<void> updateParentalProfile(String childId, Map<String, dynamic> data) async {
    await _db.collection('parents').doc(uid).collection('children').doc(childId).update(data);
  }

  Future<void> createSchedule(String childId, Map<String, dynamic> data) async {
    // Legacy support: mapping to rules/active for now or a dedicated subcollection
    await _db.collection('parents').doc(uid).collection('children').doc(childId)
        .collection('rules').doc('schedule').set(data, SetOptions(merge: true));
  }

  Future<void> updateContentRule(String childId, String category, Map<String, dynamic> data) async {
    await _db.collection('parents').doc(uid).collection('children').doc(childId)
        .collection('rules').doc('active').set({
      'contentRules': {category: data}
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>> createGeofence(Map<String, dynamic> data, {String? childId}) async {
    final doc = await _parentDoc.collection('geofences').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      if (childId != null) 'childId': childId,
    });
    return {...data, 'id': doc.id};
  }

  Future<void> deleteGeofence(String id) async {
    await _parentDoc.collection('geofences').doc(id).delete();
  }

  Future<void> updateFcmToken(String? token) async {
    if (token == null) return;
    await _parentDoc.update({'fcmToken': token});
  }

  Future<void> updateChildFcmToken(String parentId, String childId, String token) async {
    await _db.collection('parents').doc(parentId).collection('children').doc(childId).update({
      'fcmToken': token,
      'lastTokenSync': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDailyLimit(String childId, int limit) => _rulesRepo.updateDailyLimit(childId, limit);

  Future<Map<String, dynamic>> getRules(String childId) async {
    final rules = await _rulesRepo.getRules(childId);
    return rules.toJson();
  }

  Stream<Map<String, dynamic>> rulesStream(String childId) => watchRules(childId).map((e) => e ?? {});

  Stream<List<String>> blockedAppsStream(String childId) => _rulesRepo.blockedAppsStream(childId);

  Future<void> updateBlockedApps(String childId, List<String> blockedApps) => _rulesRepo.updateBlockedApps(childId, blockedApps);

  Future<List<Map<String, dynamic>>> getHistory(String childId) => _childRepo.getHistory(childId);

  Future<List<Map<String, dynamic>>> getGeofences() async {
    final snap = await _parentDoc.collection('geofences').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> watchGeofences(String childId) {
    return _parentDoc
        .collection('geofences')
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<Map<String, dynamic>> getUsageStatsSingle(String childId) => _statsRepo.getTodayStats(childId);

  Stream<Map<String, dynamic>> usageStatsStream(String childId) => 
      _db.collection('parents').doc(uid).collection('children').doc(childId)
          .collection('alerts').doc('usage').collection('apps')
          .doc(DateTime.now().toIso8601String().split('T')[0])
          .snapshots().map((s) => s.data() ?? {});

  Stream<List<Map<String, dynamic>>> watchWebHistory(String childId) => 
      _db.collection('parents').doc(uid).collection('children').doc(childId)
          .collection('inventory').doc('websites').collection('history')
          .orderBy('timestamp', descending: true).limit(50)
          .snapshots()
          .map((s) => s.docs
              .map((d) => {'id': d.id, ...d.data()})
              .where((item) => !_isGenericBrowserSession(item))
              .toList());

  Future<void> toggleWebsiteBlock(String childId, String domain, bool block) =>
      _rulesRepo.toggleWebsiteBlock(childId, domain, block);

  Stream<Map<String, dynamic>?> appDetailsStream(String childId, String packageName) {
    if (childId.isEmpty || packageName.isEmpty) return Stream.value(null);
    return _db.collection('parents').doc(uid).collection('children').doc(childId)
        .collection('inventory').doc('apps').collection('details').doc(packageName)
        .snapshots().map((snap) => snap.data());
  }

  Future<List<Map<String, dynamic>>> getRecentAlerts(String childId) async {
    final snap = await _db
        .collection('parents').doc(uid)
        .collection('children').doc(childId)
        .collection('alerts').doc('notifications').collection('items')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getAlertsPaginated(String childId, {int limit = 20, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = _db
        .collection('parents').doc(uid)
        .collection('children').doc(childId)
        .collection('alerts').doc('notifications').collection('items')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return await query.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getWebHistoryPaginated(String childId, {int limit = 20, DocumentSnapshot? startAfter}) async {
    Query<Map<String, dynamic>> query = _db.collection('parents').doc(uid).collection('children').doc(childId)
        .collection('inventory').doc('websites').collection('history')
        .orderBy('timestamp', descending: true).limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return await query.get();
  }

  bool _isGenericBrowserSession(Map<String, dynamic> item) {
    final url = item['url'] as String? ?? '';
    return url.startsWith('browser://');
  }

  Future<List<Map<String, dynamic>>> getWeekStats(String childId) async {
    final List<Map<String, dynamic>> week = [];
    final now = DateTime.now();
    final demoValues = [45.0, 70.0, 30.0, 110.0, 50.0, 85.0, 60.0];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      week.add({
        'date': date.toIso8601String().split('T')[0],
        'totalMinutes': demoValues[6 - i],
      });
    }
    return week;
  }
}