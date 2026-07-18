import '../../../core/premium/plan_permissions.dart';

class SubscriptionModel {
  final String plan; // 'free', 'guardian_plus', 'guardian_premium'
  final String status; // 'active', 'expired', 'trialing', 'cancelled'
  final String billingCycle; // 'monthly', 'biannual', 'annual', 'none'
  final DateTime startDate;
  final DateTime endDate;
  final bool trialUsed;
  final int childrenLimit;
  final int devicesLimit;
  final Map<String, bool> features;

  SubscriptionModel({
    required this.plan,
    required this.status,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    required this.trialUsed,
    required this.childrenLimit,
    required this.devicesLimit,
    required this.features,
  });

  factory SubscriptionModel.freeTrial(DateTime now) {
    return SubscriptionModel(
      plan: 'free',
      status: 'trialing',
      billingCycle: 'none',
      startDate: now,
      endDate: now.add(const Duration(days: 14)),
      trialUsed: true,
      childrenLimit: 1,
      devicesLimit: 1,
      features: PlanPermissions.plans[SubscriptionPlan.free]!.features,
    );
  }

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    final planEnum = _planFromName(map['plan']);
    return SubscriptionModel(
      plan: map['plan'] ?? 'free',
      status: map['status'] ?? 'trialing',
      billingCycle: map['billingCycle'] ?? 'none',
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'].toString())
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'].toString())
          : DateTime.now().add(const Duration(days: 14)),
      trialUsed: map['trialUsed'] ?? false,
      childrenLimit: map['childrenLimit'] ?? 1,
      devicesLimit: map['devicesLimit'] ?? 1,
      features: PlanPermissions.plans[planEnum]!.features,
    );
  }

  static SubscriptionPlan _planFromName(Object? value) {
    return switch (value) {
      'guardian_plus' => SubscriptionPlan.plus,
      'guardian_premium' => SubscriptionPlan.premium,
      'guardian_family' => SubscriptionPlan.family,
      _ => SubscriptionPlan.free,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'plan': plan,
      'status': status,
      'billingCycle': billingCycle,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'trialUsed': trialUsed,
      'childrenLimit': childrenLimit,
      'devicesLimit': devicesLimit,
      'features': features,
    };
  }

  bool get isActive => status == 'active' || status == 'trialing';
  bool get isExpired => !isActive;

  SubscriptionPlan get planEnum {
    if (plan == 'guardian_family') return SubscriptionPlan.family;
    if (plan == 'guardian_premium') return SubscriptionPlan.premium;
    if (plan == 'guardian_plus') return SubscriptionPlan.plus;
    return SubscriptionPlan.free;
  }
}
