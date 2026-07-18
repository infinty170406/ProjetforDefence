import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian/core/premium/feature_flags.dart';
import 'package:the_guardian/core/premium/plan_permissions.dart';

void main() {
  group('PlanPermissions', () {
    test('free plan keeps premium location disabled', () {
      final permissions = PlanPermissions.plans[SubscriptionPlan.free]!;
      expect(permissions.childrenLimit, 1);
      expect(permissions.features[FeatureFlags.realTimeLocation], isFalse);
    });

    test('premium plan grants AI reports', () {
      final permissions = PlanPermissions.plans[SubscriptionPlan.premium]!;
      expect(permissions.features[FeatureFlags.aiReports], isTrue);
    });

    test('plus plan configures limits correctly', () {
      final permissions = PlanPermissions.plans[SubscriptionPlan.plus]!;
      expect(permissions.childrenLimit, 3);
      expect(permissions.devicesLimit, 3);
      expect(permissions.historyDaysLimit, 30);
      expect(permissions.features[FeatureFlags.realTimeLocation], isTrue);
    });

    test('family plan configures limits correctly', () {
      final permissions = PlanPermissions.plans[SubscriptionPlan.family]!;
      expect(permissions.childrenLimit, 999);
      expect(permissions.devicesLimit, 999);
      expect(permissions.features['familyManagement'], isTrue);
    });

    test('SubscriptionPlanExtension name returns correct string', () {
      expect(SubscriptionPlan.free.name, 'free');
      expect(SubscriptionPlan.plus.name, 'guardian_plus');
      expect(SubscriptionPlan.premium.name, 'guardian_premium');
      expect(SubscriptionPlan.family.name, 'guardian_family');
    });

    test('SubscriptionPlanExtension displayName returns correct string', () {
      expect(SubscriptionPlan.free.displayName, 'Guardian Free');
      expect(SubscriptionPlan.plus.displayName, 'Guardian Plus');
      expect(SubscriptionPlan.premium.displayName, 'Guardian Premium');
      expect(SubscriptionPlan.family.displayName, 'Guardian Family');
    });
  });
}

