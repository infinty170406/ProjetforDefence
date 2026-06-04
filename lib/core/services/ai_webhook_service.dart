import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AiWebhookService {
  static final AiWebhookService _instance = AiWebhookService._internal();
  factory AiWebhookService() => _instance;
  AiWebhookService._internal();

  final Dio _dio = Dio();
  static const String _webhookUrl = 'http://192.168.1.215:5678/webhook/guardian-chat';

  Future<String> sendMessage(
    String message, {
    required String parentId,
    required String childId,
    Map<String, dynamic>? childContext,
  }) async {
    try {
      final response = await _dio.post(
        _webhookUrl,
        data: {
          'sessionId': 'session_${parentId}_$childId',
          'parentId': parentId,
          'childId': childId,
          'message': message,
          'context': childContext ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Assume the webhook returns the response in an 'output' or 'response' field
        // or directly as text. Adjust based on n8n format.
        final data = response.data;
        if (data is String) return data;
        if (data is Map) {
          return data['output'] ?? data['response'] ?? data['text'] ?? 'Empty response from server';
        }
        return data.toString();
      } else {
        return 'AI Server Error (${response.statusCode})';
      }
    } catch (e) {
      debugPrint('AiWebhookService: Webhook call error: $e');
      return 'Sorry, I cannot answer right now. Is the local AI turned on?';
    }
  }
}
