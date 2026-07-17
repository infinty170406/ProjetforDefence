import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'alert_model.dart';
import 'chat_message.dart';
import 'app_state.dart';
import '../services/guardian_realtime_service.dart';
import '../services/ai/guardian_agent_service.dart';

class AppStateManager extends ChangeNotifier {
  GuardianState _state = GuardianState.unauthenticated;
  GuardianState get state => _state;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  String _language = 'Français';
  String get language => _language;

  String _timezone = 'GMT+1 (Paris)';
  String get timezone => _timezone;

  bool _isAppLocked = false;
  bool get isAppLocked => _isAppLocked;

  final List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => List.unmodifiable(_alerts);

  final List<ChatMessage> _chatHistory = [];
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  AppStateManager() {
    _loadSettings();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && !user.isAnonymous) {
        updateState(GuardianState.authenticated);
      } else {
        updateState(GuardianState.unauthenticated);
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme
      final themeStr = prefs.getString('theme_mode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );

      // Load language
      _language = prefs.getString('settings_language') ?? 'Français';

      // Load timezone
      _timezone = prefs.getString('settings_timezone') ?? 'GMT+1 (Paris)';

      notifyListeners();
    } catch (e) {
      debugPrint('AppStateManager: Error loading settings: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (e) {
      debugPrint('AppStateManager: Error saving theme: $e');
    }
  }

  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_language', lang);
    } catch (e) {
      debugPrint('AppStateManager: Error saving language: $e');
    }
  }

  Future<void> setTimezone(String zone) async {
    if (_timezone == zone) return;
    _timezone = zone;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('settings_timezone', zone);
    } catch (e) {
      debugPrint('AppStateManager: Error saving timezone: $e');
    }
  }

  void setAppLocked(bool locked) {
    if (_isAppLocked == locked) return;
    _isAppLocked = locked;
    notifyListeners();
  }

  Future<void> _checkAppLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appLockEnabled = prefs.getBool('settings_app_lock') ?? false;
      if (appLockEnabled) {
        _isAppLocked = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppStateManager: Error checking app lock: $e');
    }
  }

  void updateState(GuardianState newState) {
    if (_state == newState) return;

    _state = newState;
    if (newState == GuardianState.authenticated) {
      GuardianRealtimeService().initialize(this);
      // Démarre l'agent IA (surveillance + enrichissement des alertes en continu).
      GuardianAgentService().start();
      _checkAppLock();
    } else if (newState == GuardianState.unauthenticated) {
      GuardianRealtimeService().dispose();
      GuardianAgentService().stop();
      _isAppLocked = false;
      _alerts.clear();
      _chatHistory.clear();
    }
    notifyListeners();
  }

  void addAlert(AlertModel alert) {
    _alerts.insert(0, alert);
    notifyListeners();
  }

  void addChatMessage(ChatMessage message) {
    _chatHistory.add(message);
    notifyListeners();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  void clearChatHistory() {
    _chatHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    GuardianRealtimeService().dispose();
    GuardianAgentService().stop();
    super.dispose();
  }
}
