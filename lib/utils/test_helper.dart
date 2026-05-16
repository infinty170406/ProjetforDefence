import 'package:flutter/foundation.dart';
import '../services/monitoring_service.dart';

/// TestHelper
///
/// Utility class to simulate events that would normally come from the native side.
/// Use this to test the enforcement and history logic in a controlled way.
class TestHelper {
  /// Simulates a web navigation event.
  static void simulateWebEvent(String url, {String package = 'com.android.chrome'}) {
    debugPrint('TestHelper: Simulating web event for URL: $url');
    MonitoringService().enforcement.handleNativeWebEvent({
      'url': url,
      'package': package,
    });
  }

  /// Simulates a keyword detection event.
  static void simulateKeywordEvent(String keyword, {String package = 'com.whatsapp'}) {
    debugPrint('TestHelper: Simulating keyword event: $keyword');
    MonitoringService().enforcement.handleNativeKeywordEvent({
      'keyword': keyword,
      'package': package,
    });
  }

  /// Runs a suite of tests to verify filtering logic.
  static Future<void> runDiagnosticSuite() async {
    debugPrint('--- STARTING DIAGNOSTIC SUITE ---');
    
    // 1. Test History Reporting
    simulateWebEvent('https://www.google.com');
    
    // 2. Test Domain Blocking
    simulateWebEvent('https://www.facebook.com');
    
    // 3. Test Category Blocking (Adult)
    simulateWebEvent('https://www.pornhub.com');
    
    // 4. Test Keyword Detection
    simulateKeywordEvent('porn');
    
    debugPrint('--- DIAGNOSTIC SUITE COMPLETED ---');
    debugPrint('Check Firestore logs to verify that alerts and history were recorded.');
  }
}
