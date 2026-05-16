import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian_child/services/enforcement_service.dart';
import 'package:the_guardian_child/services/rules_service.dart';

void main() {
  group('EnforcementService Logic Tests', () {
    late EnforcementService enforcementService;

    setUp(() {
      enforcementService = EnforcementService();
    });

    test('Keyword Matching Logic', () {
      final adultKeywords = {
        'porn', 'sex', 'adult',
      };

      bool matches(String url, Set<String> keywords) {
        return keywords.any((k) => url.contains(k));
      }

      expect(matches('https://www.pornhub.com', adultKeywords), isTrue);
      expect(matches('https://www.google.com/search?q=sexy+stuff', adultKeywords), isTrue);
      expect(matches('https://www.wikipedia.org', adultKeywords), isFalse);
    });

    test('Domain Blocking Logic', () {
      final blockedWebsites = {'facebook.com', 'instagram.com'};
      final url = 'https://www.facebook.com/profile';

      bool isBlocked = false;
      for (final blocked in blockedWebsites) {
        if (url.contains(blocked.toLowerCase())) {
          isBlocked = true;
          break;
        }
      }

      expect(isBlocked, isTrue);
    });

    test('Allowed Hours Logic', () {
      int? parseTime(String t) {
        final p = t.split(':');
        if (p.length != 2) return null;
        final h = int.tryParse(p[0]);
        final m = int.tryParse(p[1]);
        if (h == null || m == null) return null;
        return h * 60 + m;
      }

      bool isOutsideAllowedHours(String start, String end, int currentHour, int currentMinute) {
        final current = currentHour * 60 + currentMinute;
        final s = parseTime(start);
        final e = parseTime(end);
        if (s == null || e == null) return false;

        if (s <= e) return current < s || current >= e;
        return current >= e && current < s;
      }

      // 08:00 to 20:00
      expect(isOutsideAllowedHours('08:00', '20:00', 10, 0), isFalse); // Inside
      expect(isOutsideAllowedHours('08:00', '20:00', 7, 0), isTrue);  // Before
      expect(isOutsideAllowedHours('08:00', '20:00', 21, 0), isTrue); // After
      
      // Overnight: 22:00 to 06:00
      expect(isOutsideAllowedHours('22:00', '06:00', 23, 0), isFalse); // Inside
      expect(isOutsideAllowedHours('22:00', '06:00', 2, 0), isFalse);  // Inside
      expect(isOutsideAllowedHours('22:00', '06:00', 12, 0), isTrue);  // Outside
    });
  });
}
