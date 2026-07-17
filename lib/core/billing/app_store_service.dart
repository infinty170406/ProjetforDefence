class AppStoreService {
  static final AppStoreService _instance = AppStoreService._internal();
  factory AppStoreService() => _instance;
  AppStoreService._internal();

  Future<bool> purchasePlan(String productID) async {
    // Simulate StoreKit sheet loading
    await Future.delayed(const Duration(seconds: 1));
    // Simulate FaceID/TouchID confirmation and verification
    return true;
  }
}
