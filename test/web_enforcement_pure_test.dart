import 'package:flutter_test/flutter_test.dart';

// Logic extracted from EnforcementService for pure unit testing
class EnforcementLogic {
  static bool matchesKeywords(String url, Set<String> keywords) {
    return keywords.any((k) => url.toLowerCase().contains(k.toLowerCase()));
  }

  static bool isOutsideAllowedHours(String start, String end, DateTime now) {
    final current = now.hour * 60 + now.minute;
    final s = _parseTime(start);
    final e = _parseTime(end);
    if (s == null || e == null) return false;

    if (s <= e) return current < s || current >= e;
    return current >= e && current < s;
  }

  static int? _parseTime(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

void main() {
  group('Web Enforcement Logic (Pure Unit)', () {
    test('Keyword Filtering - matches correctly', () {
      final keywords = {'porn', 'sex', 'violence'};
      
      expect(EnforcementLogic.matchesKeywords('https://pornhub.com', keywords), isTrue);
      expect(EnforcementLogic.matchesKeywords('https://google.com/search?q=violence', keywords), isTrue);
      expect(EnforcementLogic.matchesKeywords('https://education.org', keywords), isFalse);
    });

    test('Keyword Filtering - case insensitivity', () {
      final keywords = {'PORN', 'Sex'};
      expect(EnforcementLogic.matchesKeywords('https://pornhub.com', keywords), isTrue);
    });

    test('Allowed Hours - Daytime range', () {
      final start = '08:00';
      final end = '20:00';
      
      // Inside
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 10, 0)), isFalse);
      // Outside (Before)
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 7, 59)), isTrue);
      // Outside (After)
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 20, 0)), isTrue);
    });

    test('Allowed Hours - Overnight range', () {
      final start = '22:00';
      final end = '06:00';
      
      // Inside (Night)
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 23, 0)), isFalse);
      // Inside (Early morning)
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 5, 0)), isFalse);
      // Outside (Day)
      expect(EnforcementLogic.isOutsideAllowedHours(start, end, DateTime(2024, 1, 1, 12, 0)), isTrue);
    });
  });
}
