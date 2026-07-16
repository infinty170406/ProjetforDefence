import 'package:cloud_firestore/cloud_firestore.dart';

class ChildRules {
  final List<String> blockedApps;
  final List<String> blockedWebsites;
  final int dailyLimitMinutes;
  final String? allowedTimeStart;
  final String? allowedTimeEnd;
  final bool blockSocialMedia;
  final bool blockGaming;
  final bool blockAdultContent;
  final bool blockViolence;
  final bool blockDrugs;
  final bool blockSexualPredators;
  final bool blockAnxietyDepression;
  final bool blockSelfHarm;
  final bool blockCyberbullying;
  final bool blockMatureContent;
  final bool blockEatingDisorders;
  final bool monitorAccountActivity;
  final bool locationAlerts;
  final List<String> customKeywords;
  final List<String> customCategories;
  final String mode;
  final String? geminiApiKey;
  final List<String> monitoredNotificationPackages;
  final String? parentId;
  final String? childDeviceUid;
  final String? blockReason;
  final DateTime? updatedAt;
  final bool rulesConfigured;

  ChildRules({
    this.blockedApps = const [],
    this.blockedWebsites = const [],
    this.dailyLimitMinutes = 0,
    this.allowedTimeStart,
    this.allowedTimeEnd,
    this.blockSocialMedia = false,
    this.blockGaming = false,
    this.blockAdultContent = true,
    this.blockViolence = true,
    this.blockDrugs = true,
    this.blockSexualPredators = true,
    this.blockAnxietyDepression = false,
    this.blockSelfHarm = true,
    this.blockCyberbullying = true,
    this.blockMatureContent = false,
    this.blockEatingDisorders = false,
    this.monitorAccountActivity = true,
    this.locationAlerts = true,
    this.customKeywords = const [],
    this.customCategories = const [],
    this.mode = 'CUSTOM',
    this.parentId,
    this.childDeviceUid,
    this.blockReason,
    this.updatedAt,
    this.rulesConfigured = false,
    this.geminiApiKey,
    this.monitoredNotificationPackages = const [],
  }) {
    // Validation
    if (dailyLimitMinutes < 0) {
      throw ArgumentError('dailyLimitMinutes cannot be negative');
    }
  }

  factory ChildRules.fromJson(Map<String, dynamic> json) {
    return ChildRules(
      blockedApps: List<String>.from(json['blockedApps'] ?? []),
      blockedWebsites: List<String>.from(json['blockedWebsites'] ?? []),
      dailyLimitMinutes: json['dailyLimitMinutes'] ?? 0,
      allowedTimeStart: json['allowedTimeStart'],
      allowedTimeEnd: json['allowedTimeEnd'],
      blockSocialMedia: json['blockSocialMedia'] ?? false,
      blockGaming: json['blockGaming'] ?? false,
      blockAdultContent: json['blockAdultContent'] ?? true,
      blockViolence: json['blockViolence'] ?? true,
      blockDrugs: json['blockDrugs'] ?? true,
      blockSexualPredators: json['blockSexualPredators'] ?? true,
      blockAnxietyDepression: json['blockAnxietyDepression'] ?? false,
      blockSelfHarm: json['blockSelfHarm'] ?? true,
      blockCyberbullying: json['blockCyberbullying'] ?? true,
      blockMatureContent: json['blockMatureContent'] ?? false,
      blockEatingDisorders: json['blockEatingDisorders'] ?? false,
      monitorAccountActivity: json['monitorAccountActivity'] ?? true,
      locationAlerts: json['locationAlerts'] ?? true,
      customKeywords: List<String>.from(json['customKeywords'] ?? []),
      customCategories: List<String>.from(json['customCategories'] ?? []),
      mode: json['mode'] ?? 'CUSTOM',
      parentId: json['parentId'],
      childDeviceUid: json['childDeviceUid'],
      blockReason: json['block_reason'],
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] as Timestamp).toDate() 
          : null,
      rulesConfigured: json['rulesConfigured'] ?? false,
      geminiApiKey: json['geminiApiKey'] ?? json['gemini_api_key'],
      monitoredNotificationPackages: List<String>.from(
          json['monitoredNotificationPackages'] ?? json['monitored_notification_packages'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      'mode': mode,
      if (parentId != null) 'parentId': parentId,
      if (childDeviceUid != null) 'childDeviceUid': childDeviceUid,
      if (blockReason != null) 'block_reason': blockReason,
      'updatedAt': FieldValue.serverTimestamp(),
      'rulesConfigured': rulesConfigured,
      if (geminiApiKey != null) 'geminiApiKey': geminiApiKey,
      if (geminiApiKey != null) 'gemini_api_key': geminiApiKey,
      'monitoredNotificationPackages': monitoredNotificationPackages,
      'monitored_notification_packages': monitoredNotificationPackages,
    };
  }

  ChildRules copyWith({
    List<String>? blockedApps,
    List<String>? blockedWebsites,
    int? dailyLimitMinutes,
    String? allowedTimeStart,
    String? allowedTimeEnd,
    bool? blockSocialMedia,
    bool? blockGaming,
    bool? blockAdultContent,
    bool? blockViolence,
    bool? blockDrugs,
    bool? blockSexualPredators,
    bool? blockAnxietyDepression,
    bool? blockSelfHarm,
    bool? blockCyberbullying,
    bool? blockMatureContent,
    bool? blockEatingDisorders,
    bool? monitorAccountActivity,
    bool? locationAlerts,
    List<String>? customKeywords,
    List<String>? customCategories,
    String? mode,
    String? parentId,
    String? childDeviceUid,
    String? blockReason,
    bool? rulesConfigured,
    String? geminiApiKey,
    List<String>? monitoredNotificationPackages,
  }) {
    return ChildRules(
      blockedApps: blockedApps ?? this.blockedApps,
      blockedWebsites: blockedWebsites ?? this.blockedWebsites,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      allowedTimeStart: allowedTimeStart ?? this.allowedTimeStart,
      allowedTimeEnd: allowedTimeEnd ?? this.allowedTimeEnd,
      blockSocialMedia: blockSocialMedia ?? this.blockSocialMedia,
      blockGaming: blockGaming ?? this.blockGaming,
      blockAdultContent: blockAdultContent ?? this.blockAdultContent,
      blockViolence: blockViolence ?? this.blockViolence,
      blockDrugs: blockDrugs ?? this.blockDrugs,
      blockSexualPredators: blockSexualPredators ?? this.blockSexualPredators,
      blockAnxietyDepression: blockAnxietyDepression ?? this.blockAnxietyDepression,
      blockSelfHarm: blockSelfHarm ?? this.blockSelfHarm,
      blockCyberbullying: blockCyberbullying ?? this.blockCyberbullying,
      blockMatureContent: blockMatureContent ?? this.blockMatureContent,
      blockEatingDisorders: blockEatingDisorders ?? this.blockEatingDisorders,
      monitorAccountActivity: monitorAccountActivity ?? this.monitorAccountActivity,
      locationAlerts: locationAlerts ?? this.locationAlerts,
      customKeywords: customKeywords ?? this.customKeywords,
      customCategories: customCategories ?? this.customCategories,
      mode: mode ?? this.mode,
      parentId: parentId ?? this.parentId,
      childDeviceUid: childDeviceUid ?? this.childDeviceUid,
      blockReason: blockReason ?? this.blockReason,
      rulesConfigured: rulesConfigured ?? this.rulesConfigured,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      monitoredNotificationPackages: monitoredNotificationPackages ?? this.monitoredNotificationPackages,
    );
  }
}
