import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_guardian_child/utils/child_path_helper.dart';

void main() {
  group('Child path persistence', () {
    test('normalizes a stored child path', () async {
      SharedPreferences.setMockInitialValues({
        'child_path': 'parents/p1/children/c1/',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(await readChildPath(prefs), 'parents/p1/children/c1');
    });

    test('rejects an empty child path', () {
      expect(normalizeChildPath('   '), isNull);
    });
  });
}
