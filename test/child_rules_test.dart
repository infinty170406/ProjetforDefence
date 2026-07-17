import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian/core/models/child_rules.dart';

void main() {
  group('ChildRules', () {
    test('rejects a negative daily limit', () {
      expect(
        () => ChildRules(dailyLimitMinutes: -1),
        throwsArgumentError,
      );
    });

    test('round-trips user-configurable fields', () {
      final rules = ChildRules(
        blockedApps: const ['com.example.game'],
        blockedWebsites: const ['example.com'],
        dailyLimitMinutes: 90,
        blockGaming: true,
        customKeywords: const ['danger'],
      );

      final restored = ChildRules.fromJson(rules.toJson());

      expect(restored.blockedApps, rules.blockedApps);
      expect(restored.blockedWebsites, rules.blockedWebsites);
      expect(restored.dailyLimitMinutes, 90);
      expect(restored.blockGaming, isTrue);
      expect(restored.customKeywords, ['danger']);
    });
  });
}
