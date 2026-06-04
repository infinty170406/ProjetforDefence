import 'package:flutter/material.dart';
import 'alert_model.dart';
import 'chat_message.dart';
import 'app_state.dart';
import '../services/global_monitor_service.dart';

class AppStateManager extends ChangeNotifier {
  GuardianState _state = GuardianState.unauthenticated;
  GuardianState get state => _state;

  final List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => List.unmodifiable(_alerts);

  final List<ChatMessage> _chatHistory = [];
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

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