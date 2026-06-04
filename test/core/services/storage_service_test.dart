import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_guardian/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService storageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
    });

    test('saveOtpConfigured and getOtpConfigured', () async {
      expect(await storageService.getOtpConfigured(), false);
      await storageService.saveOtpConfigured(true);
      expect(await storageService.getOtpConfigured(), true);
    });

    test('savePlanSelected and getPlanSelected', () async {
      expect(await storageService.getPlanSelected(), false);
      await storageService.savePlanSelected(true);
      expect(await storageService.getPlanSelected(), true);
    });
  });
}
