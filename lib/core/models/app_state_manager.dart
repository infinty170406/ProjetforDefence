import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alert_model.dart';
import 'chat_message.dart';
import 'app_state.dart';
import '../services/global_monitor_service.dart';

class AppStateManager extends ChangeNotifier {
  GuardianState _state = GuardianState.unauthenticated;
  GuardianState get state => _state;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  final List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => List.unmodifiable(_alerts);

  final List<ChatMessage> _chatHistory = [];
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  AppStateManager() {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('theme_mode') ?? 'system';
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('AppStateManager: Error loading theme: $e');
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

  void updateState(GuardianState newState) {
    if (_state == newState) return;
    
    _state = newState;
    if (newState == GuardianState.authenticated) {
      GlobalMonitorService().initialize(this);
    } else if (newState == GuardianState.unauthenticated) {
      GlobalMonitorService().dispose();
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
    GlobalMonitorService().dispose();
    super.dispose();
  }
}