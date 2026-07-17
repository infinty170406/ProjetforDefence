import 'feature_flags.dart';

enum SubscriptionPlan {
  free,
  plus,
  premium,
  family,
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get name {
    switch (this) {
      case SubscriptionPlan.free:
        return 'free';
      case SubscriptionPlan.plus:
        return 'guardian_plus';
      case SubscriptionPlan.premium:
        return 'guardian_premium';
      case SubscriptionPlan.family:
        return 'guardian_family';
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Guardian Free';
      case SubscriptionPlan.plus:
        return 'Guardian Plus';
      case SubscriptionPlan.premium:
        return 'Guardian Premium';
      case SubscriptionPlan.family:
        return 'Guardian Family';
    }
  }
}

class PlanPermissions {
  final SubscriptionPlan plan;
  final int childrenLimit;
  final int devicesLimit;
  final int historyDaysLimit;
  final Map<String, bool> features;

  PlanPermissions({
    required this.plan,
    required this.childrenLimit,
    required this.devicesLimit,
    required this.historyDaysLimit,
    required this.features,
  });

  static final Map<SubscriptionPlan, PlanPermissions> plans = {
    SubscriptionPlan.free: PlanPermissions(
      plan: SubscriptionPlan.free,
      childrenLimit: 1,
      devicesLimit: 1,
      historyDaysLimit: 3,
      features: {
        FeatureFlags.realTimeLocation: false,
        FeatureFlags.geofencing: false,
        FeatureFlags.screenTime: true,
        FeatureFlags.appManagement: false,
        FeatureFlags.aiReports: false,
        FeatureFlags.cyberbullyingDetection: false,
        FeatureFlags.webDashboard: false,
        FeatureFlags.prioritySupport: false,
        FeatureFlags.cloudBackup: false,
        FeatureFlags.advancedAi: false,
        'familyManagement': false,
      },
    ),
    SubscriptionPlan.plus: PlanPermissions(
      plan: SubscriptionPlan.plus,
      childrenLimit: 3,
      devicesLimit: 3,
      historyDaysLimit: 30,
      features: {
        FeatureFlags.realTimeLocation: true,
        FeatureFlags.geofencing: true,
        FeatureFlags.screenTime: true,
        FeatureFlags.appManagement: true,
        FeatureFlags.aiReports: true,
        FeatureFlags.cyberbullyingDetection: false,
        FeatureFlags.webDashboard: true,
        FeatureFlags.prioritySupport: false,
        FeatureFlags.cloudBackup: false,
        FeatureFlags.advancedAi: false,
        'familyManagement': false,
      },
    ),
    SubscriptionPlan.premium: PlanPermissions(
      plan: SubscriptionPlan.premium,
      childrenLimit: 999,
      devicesLimit: 999,
      historyDaysLimit: 365,
      features: {
        FeatureFlags.realTimeLocation: true,
        FeatureFlags.geofencing: true,
        FeatureFlags.screenTime: true,
        FeatureFlags.appManagement: true,
        FeatureFlags.aiReports: true,
        FeatureFlags.cyberbullyingDetection: true,
        FeatureFlags.webDashboard: true,
        FeatureFlags.prioritySupport: true,
        FeatureFlags.cloudBackup: true,
        FeatureFlags.advancedAi: true,
        'familyManagement': false,
      },
    ),
    SubscriptionPlan.family: PlanPermissions(
      plan: SubscriptionPlan.family,
      childrenLimit: 999,
      devicesLimit: 999,
      historyDaysLimit: 365,
      features: {
        FeatureFlags.realTimeLocation: true,
        FeatureFlags.geofencing: true,
        FeatureFlags.screenTime: true,
        FeatureFlags.appManagement: true,
        FeatureFlags.aiReports: true,
        FeatureFlags.cyberbullyingDetection: true,
        FeatureFlags.webDashboard: true,
        FeatureFlags.prioritySupport: true,
        FeatureFlags.cloudBackup: true,
        FeatureFlags.advancedAi: true,
        'familyManagement': true,
      },
    ),
  };
}
