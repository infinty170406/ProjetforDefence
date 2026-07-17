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
  });
}
