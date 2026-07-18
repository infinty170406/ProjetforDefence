import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    test('copyWith updates individual fields correctly', () {
      final rules = ChildRules(
        blockedApps: const ['com.example.game'],
        dailyLimitMinutes: 90,
      );

      final updated = rules.copyWith(
        blockedApps: const ['com.example.game2'],
        blockedWebsites: const ['example.com'],
        dailyLimitMinutes: 120,
        allowedTimeStart: '08:00',
        allowedTimeEnd: '20:00',
        blockSocialMedia: true,
        blockGaming: true,
        blockAdultContent: false,
        blockViolence: false,
        blockDrugs: false,
        blockSexualPredators: false,
        blockAnxietyDepression: true,
        blockSelfHarm: false,
        blockCyberbullying: false,
        blockMatureContent: true,
        blockEatingDisorders: true,
        monitorAccountActivity: false,
        locationAlerts: false,
        customKeywords: const ['safety'],
        customCategories: const ['games'],
        mode: 'STRICT',
        parentId: 'parent123',
        childDeviceUid: 'device456',
        blockReason: 'time limit reached',
        rulesConfigured: true,
        geminiApiKey: 'api_key_123',
        monitoredNotificationPackages: const ['pkg.name'],
      );

      expect(updated.blockedApps, ['com.example.game2']);
      expect(updated.blockedWebsites, ['example.com']);
      expect(updated.dailyLimitMinutes, 120);
      expect(updated.allowedTimeStart, '08:00');
      expect(updated.allowedTimeEnd, '20:00');
      expect(updated.blockSocialMedia, isTrue);
      expect(updated.blockGaming, isTrue);
      expect(updated.blockAdultContent, isFalse);
      expect(updated.blockViolence, isFalse);
      expect(updated.blockDrugs, isFalse);
      expect(updated.blockSexualPredators, isFalse);
      expect(updated.blockAnxietyDepression, isTrue);
      expect(updated.blockSelfHarm, isFalse);
      expect(updated.blockCyberbullying, isFalse);
      expect(updated.blockMatureContent, isTrue);
      expect(updated.blockEatingDisorders, isTrue);
      expect(updated.monitorAccountActivity, isFalse);
      expect(updated.locationAlerts, isFalse);
      expect(updated.customKeywords, ['safety']);
      expect(updated.customCategories, ['games']);
      expect(updated.mode, 'STRICT');
      expect(updated.parentId, 'parent123');
      expect(updated.childDeviceUid, 'device456');
      expect(updated.blockReason, 'time limit reached');
      expect(updated.rulesConfigured, isTrue);
      expect(updated.geminiApiKey, 'api_key_123');
      expect(updated.monitoredNotificationPackages, ['pkg.name']);
    });

    test('fromJson parses updatedAt from Timestamp or DateTime', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);

      final rulesFromTimestamp = ChildRules.fromJson({
        'updatedAt': timestamp,
      });
      final rulesFromDateTime = ChildRules.fromJson({
        'updatedAt': now,
      });
      final rulesNull = ChildRules.fromJson({
        'updatedAt': null,
      });

      expect(rulesFromTimestamp.updatedAt, now);
      expect(rulesFromDateTime.updatedAt, now);
      expect(rulesNull.updatedAt, isNull);
    });
  });
}

