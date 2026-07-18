import '../services/api_config.dart';
import '../services/api_service.dart';

/// Payment requests are authenticated calls to our backend; no provider key is
/// present in Flutter.
class SharePayService {
  static final SharePayService _instance = SharePayService._internal();
  factory SharePayService() => _instance;
  SharePayService._internal();

  Future<Map<String, dynamic>?> createCheckout({
    required int amount,
    required String currency,
    String? description,
    String? successUrl,
    String? cancelUrl,
    String? merchantReference,
  }) =>
      ApiService().post(ApiConfig.billingCheckoutUrl, {
        'plan': _planForAmount(amount),
        'cycle': _cycleForAmount(amount),
      });

  Future<Map<String, dynamic>?> createCharge({
    required int amount,
    required String currency,
    required String paymentMethod,
    required String payerAccount,
    String? payerName,
    String? payerEmail,
    String? merchantReference,
    String? description,
    String? idempotencyKey,
  }) =>
      ApiService().post(ApiConfig.billingChargeUrl, {
        'plan': _planForAmount(amount),
        'cycle': _cycleForAmount(amount),
        'paymentMethod': paymentMethod,
        'payerAccount': payerAccount,
      });

  Future<Map<String, dynamic>?> getPayInStatus(String reference) =>
      ApiService().get(ApiConfig.billingPaymentStatusUrl(reference));

  Future<Map<String, dynamic>?> createTransfer({
    required int amount,
    required String currency,
    required String paymentMethod,
    required String beneficiaryAccount,
    required String beneficiaryName,
    String? beneficiaryEmail,
    String? merchantReference,
    String? description,
  }) =>
      throw UnsupportedError(
          'Les virements ne sont pas disponibles dans l’application.');

  Future<Map<String, dynamic>?> getPayOutStatus(String reference) =>
      throw UnsupportedError(
          'Les virements ne sont pas disponibles dans l’application.');

  String _planForAmount(int amount) => switch (amount) {
        1950 || 18000 => 'guardian_plus',
        3250 || 30000 => 'guardian_premium',
        4500 || 42000 => 'guardian_family',
        _ => throw ArgumentError('Montant d’abonnement invalide.'),
      };

  String _cycleForAmount(int amount) => switch (amount) {
        18000 || 30000 || 42000 => 'annual',
        _ => 'monthly',
      };
}
