import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RulesWriterService {
  static final RulesWriterService _instance = RulesWriterService._internal();
  factory RulesWriterService() => _instance;
  RulesWriterService._internal();

  final _db = FirebaseFirestore.instance;

  String get _parentId => FirebaseAuth.instance.currentUser!.uid;

  String _rulesPath(String childId) =>
      'parents/$_parentId/children/$childId/rules/active';

  Future<void> saveRules({
    required String childId,
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
  }) async {
    await _db.doc(_rulesPath(childId)).set({
      'blockedApps': blockedApps,
      'blockedWebsites': blockedWebsites,
      'dailyLimitMinutes': dailyLimitMinutes,
      'allowedTimeStart': allowedTimeStart,
      'allowedTimeEnd': allowedTimeEnd,
      'blockSocialMedia': blockSocialMedia,
      'blockGaming': blockGaming,
      'blockAdultContent': blockAdultContent,
      'blockViolence': blockViolence,
      'blockDrugs': blockDrugs,
      'blockSexualPredators': blockSexualPredators,
      'blockAnxietyDepression': blockAnxietyDepression,
      'blockSelfHarm': blockSelfHarm,
      'blockCyberbullying': blockCyberbullying,
      'blockMatureContent': blockMatureContent,
      'blockEatingDisorders': blockEatingDisorders,
      'monitorAccountActivity': monitorAccountActivity,
      'locationAlerts': locationAlerts,
      'customKeywords': customKeywords,
      'customCategories': customCategories,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // SYNC: Mise à jour du document principal pour que le dashboard parent voit aussi le changement
    await _db.collection('parents').doc(_parentId).collection('children').doc(childId).update({
      'dailyLimitMinutes': dailyLimitMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockApp(String childId, String pkg) =>
      _db.doc(_rulesPath(childId)).set({
        'blockedApps': FieldValue.arrayUnion([pkg]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> unblockApp(String childId, String pkg) =>
      _db.doc(_rulesPath(childId)).set({
        'blockedApps': FieldValue.arrayRemove([pkg]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setDailyLimit(String childId, int minutes) =>
      _db.doc(_rulesPath(childId)).set({
        'dailyLimitMinutes': minutes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setAllowedHours(String childId, String start, String end) =>
      _db.doc(_rulesPath(childId)).set({
        'allowedTimeStart': start,
        'allowedTimeEnd': end,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> setCategoryBlock(
    String childId, {
    bool? socialMedia,
    bool? gaming,
    bool? adultContent,
    bool? violence,
    bool? drugs,
    bool? sexualPredators,
    bool? anxietyDepression,
    bool? selfHarm,
    bool? cyberbullying,
    bool? matureContent,
    bool? eatingDisorders,
    bool? monitorAccountActivity,
    bool? locationAlerts,
    List<String>? customKeywords,
    List<String>? customCategories,
  }) =>
      _db.doc(_rulesPath(childId)).set({
        if (socialMedia != null) 'blockSocialMedia': socialMedia,
        if (gaming != null) 'blockGaming': gaming,
        if (adultContent != null) 'blockAdultContent': adultContent,
        if (violence != null) 'blockViolence': violence,
        if (drugs != null) 'blockDrugs': drugs,
        if (sexualPredators != null) 'blockSexualPredators': sexualPredators,
        if (anxietyDepression != null) 'blockAnxietyDepression': anxietyDepression,
        if (selfHarm != null) 'blockSelfHarm': selfHarm,
        if (cyberbullying != null) 'blockCyberbullying': cyberbullying,
        if (matureContent != null) 'blockMatureContent': matureContent,
        if (eatingDisorders != null) 'blockEatingDisorders': eatingDisorders,
        if (monitorAccountActivity != null) 'monitorAccountActivity': monitorAccountActivity,
        if (locationAlerts != null) 'locationAlerts': locationAlerts,
        if (customKeywords != null) 'customKeywords': customKeywords,
        if (customCategories != null) 'customCategories': customCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<Map<String, dynamic>?> watchRules(String childId) =>
      _db.doc(_rulesPath(childId)).snapshots().map((s) => s.data());
}
