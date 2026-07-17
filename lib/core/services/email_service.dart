import 'package:flutter/foundation.dart';
import 'guardian_api.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  Future<void> sendOtpEmail(String targetEmail, String code) async {
    try {
      await GuardianApi.post(
        '/api/v1/auth/otp/send',
        body: <String, dynamic>{
          'targetEmail': targetEmail,
          'code': code,
        },
      );
      debugPrint('EmailService: OTP relay accepted by Render API.');
    } catch (e) {
      debugPrint('EmailService: Error sending OTP via Render: $e');
      rethrow;
    }
  }
}
