class PlayStoreService {
  static final PlayStoreService _instance = PlayStoreService._internal();
  factory PlayStoreService() => _instance;
  PlayStoreService._internal();

  Future<bool> buyPlan(String planId) async {
    // Simulate Google Play Billing dialog loading
    await Future.delayed(const Duration(seconds: 1));
    // Simulate successful payment validation
    return true;
  }
}
