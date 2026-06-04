import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyUserName = 'user_name';
  static const String _keyToken = 'access_token';
  static const String _keyUserEmail = 'user_email';
  static const String _keyPrivacyAccepted = 'privacy_accepted';
  static const String _keyPlanSelected = 'plan_selected';
  static const String _keyOtpConfigured = 'otp_configured';
  static const String _keyChildId = 'child_id';
  static const String _keyParentId = 'parent_id';
  static const String _keyDeviceMode = 'device_mode'; // 'parent' or 'child'

  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> saveUserInfo(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
  }

  Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyUserName),
      'email': prefs.getString(_keyUserEmail),
    };
  }

  Future<void> savePrivacyAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivacyAccepted, value);
  }

  Future<bool> getPrivacyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivacyAccepted) ?? false;
  }

  Future<void> savePlanSelected(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPlanSelected, value);
  }

  Future<bool> getPlanSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPlanSelected) ?? false;
  }

  Future<void> saveOtpConfigured(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOtpConfigured, value);
  }

  Future<bool> getOtpConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOtpConfigured) ?? false;
  }

  Future<void> saveChildPairing(String parentId, String childId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyParentId, parentId);
    await prefs.setString(_keyChildId, childId);
    await prefs.setString(_keyDeviceMode, 'child');
  }

  Future<Map<String, String?>> getChildPairing() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'parentId': prefs.getString(_keyParentId),
      'childId': prefs.getString(_keyChildId),
      'mode': prefs.getString(_keyDeviceMode),
    };
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final privacyAccepted = prefs.getBool(_keyPrivacyAccepted) ?? false;
    await prefs.clear();
    await prefs.setBool(_keyPrivacyAccepted, privacyAccepted);
  }
}
