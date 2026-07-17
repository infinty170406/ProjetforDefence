import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// URL de base de l'API
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }
    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL est obligatoire pour une version de production.',
      );
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
    } catch (e) {
      // Platform might not be available on all platforms (like web)
    }
    return 'http://localhost:8080';
  }

  static String get wsUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    } else if (base.startsWith('http://')) {
      return base.replaceFirst('http://', 'ws://');
    }
    return 'wss://guardian-backend-10zk.onrender.com';
  }

  // ==================== AUTH ====================
  // login and register are now handled via Firebase Magic Link / OTP
  static const String sendOtp = '/api/v1/auth/otp/send';
  static const String verifyOtp = '/api/v1/auth/otp/verify';
  static const String createInvite = '/api/v1/family/invites';
  static const String acceptInvite = '/api/v1/family/invites/accept';
  static const String pairDevice = '/api/v1/device/pair';
  static const String reportAlert = '/api/v1/device/alerts';
  static const String updateMetadata = '/api/v1/device/metadata';
  static const String analyzeNotification = '/api/v1/device/notifications/analyze';
  static const String verifyKyc = '/api/v1/auth/kyc/verify';
  static const String billingCheckout = '/api/v1/billing/checkout';
  static const String billingCharge = '/api/v1/billing/charge';
  static String billingPaymentStatus(String reference) =>
      '/api/v1/billing/payments/$reference';

  // ==================== PARENT ====================
  static const String myChildren = '/api/v1/parents/me/children';
  static const String linkChild = '/api/v1/parents/me/children/link';

  // ==================== PARENTAL CONTROL ====================
  static String parentalProfile(String childId) =>
      '/api/v1/children/$childId/parental/profile';

  static String schedules(String childId) =>
      '/api/v1/children/$childId/parental/schedules';

  static String schedule(String childId, String scheduleId) =>
      '/api/v1/children/$childId/parental/schedules/$scheduleId';

  static String contentRule(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category';

  static String contentKeywords(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category/keywords';

  // ==================== HISTORY ====================
  static String history(String childId) => '/api/v1/children/$childId/history';

  // ==================== DEVICE ====================
  static String deviceRules(String childId) =>
      '/api/v1/device/children/$childId/rules';

  static String deviceEvents(String childId) =>
      '/api/v1/device/children/$childId/events';

  // ==================== AI ====================
  // Get your free API key from https://aistudio.google.com/
  static String geminiApiKey = '';

  // ==================== EXECUTE ====================
  static const String execute = '/api/v1/execute';
}
