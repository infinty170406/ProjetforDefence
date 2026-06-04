import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/alert_model.dart';
import '../models/app_state_manager.dart';
import '../services/api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;

  StompClient? _client;
  bool _isConnected = false;

  WebSocketService._internal();

  void connect(String token, String parentId, AppStateManager stateManager) {
    if (_isConnected) return;

    _client = StompClient(
      config: StompConfig(
        url: ApiConfig.wsUrl,
        onConnect: (frame) => _onConnect(frame, parentId, stateManager),
        onWebSocketError: (dynamic error) => debugPrint('STOMP WS Error: $error'),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onDisconnect: (frame) {
           _isConnected = false;
           debugPrint('STOMP Disconnected');
        },
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame, String parentId, AppStateManager stateManager) {
    _isConnected = true;
    debugPrint('STOMP Connected to ${ApiConfig.wsUrl}');

    _client!.subscribe(
      destination: '/topic/alerts/$parentId',
      callback: (frame) {
        if (frame.body != null) {
          final data = jsonDecode(frame.body!);
          final alert = AlertModel.fromJson(data);
          stateManager.addAlert(alert);
        }
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _isConnected = false;
  }
}
