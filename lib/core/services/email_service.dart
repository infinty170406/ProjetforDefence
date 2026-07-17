import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  Future<void> sendOtpEmail(String targetEmail, String code) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendOtpEmail');
      await callable.call(<String, dynamic>{
        'targetEmail': targetEmail,
        'code': code,
      });
      debugPrint('EmailService: OTP relay accepted by Cloud Functions.');
    } catch (e) {
      debugPrint('EmailService: Error sending OTP via EmailJS: $e');
      rethrow;
    }
  }
}
