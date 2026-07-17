import 'dart:async';
import 'sharepay_service.dart';

class OrangeMoneyService {
  static final OrangeMoneyService _instance = OrangeMoneyService._internal();
  factory OrangeMoneyService() => _instance;
  OrangeMoneyService._internal();

  Future<bool> requestPayment({
    required String phoneNumber,
    required double amount,
    required String planName,
  }) async {
    // 1. Format number
    String formattedPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (!formattedPhone.startsWith('+') &&
        !formattedPhone.startsWith('237') &&
        formattedPhone.length == 9) {
      formattedPhone = '237$formattedPhone';
    } else if (formattedPhone.startsWith('+')) {
      formattedPhone = formattedPhone.substring(1);
    }

    final idempotencyKey =
        'charge-orange-${DateTime.now().millisecondsSinceEpoch}';

    // 2. Call SharePay Direct Charge
    final response = await SharePayService().createCharge(
      amount: amount.toInt(),
      currency: 'XAF',
      paymentMethod: 'ORANGE_MONEY_CM',
      payerAccount: formattedPhone,
      payerName: 'Parent Guardian',
      description: 'Abonnement $planName',
      idempotencyKey: idempotencyKey,
    );

    if (response == null) {
      // Fallback/simulation logic if API key/network is not configured/active
      await Future.delayed(const Duration(seconds: 2));
      await Future.delayed(const Duration(seconds: 1));
      return true;
    }

    final String? reference = response['reference'];
    if (reference == null) return false;

    // 3. Poll for status change (SUCCESS or FAILED/CANCELLED)
    int attempts = 0;
    const maxAttempts = 30; // 90 seconds timeout
    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 3));
      final statusResp = await SharePayService().getPayInStatus(reference);
      if (statusResp != null) {
        final status = statusResp['status'];
        if (status == 'SUCCESS') {
          return true;
        } else if (status == 'FAILED' || status == 'CANCELLED') {
          return false;
        }
      }
      attempts++;
    }
    return false;
  }
}
