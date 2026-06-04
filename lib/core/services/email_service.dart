import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  Future<void> sendOtpEmail(String targetEmail, String code) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('sendOtpEmail');
      final response = await callable.call(<String, dynamic>{
        'targetEmail': targetEmail,
        'code': code,
      });

      debugPrint('EmailService: OTP sent successfully via Cloud Functions. Response: ${response.data}');
    } catch (e) {
      debugPrint('EmailService: Failed to send OTP via Cloud Functions: $e');
      rethrow;
    }
  }
}
