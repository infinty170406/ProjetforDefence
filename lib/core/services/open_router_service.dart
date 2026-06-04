import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  static final OpenRouterService _instance = OpenRouterService._internal();
  factory OpenRouterService() => _instance;
  OpenRouterService._internal();

  static String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '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';
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const List<String> _models = [
    'openrouter/free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'google/gemma-3-27b-it:free',
    'mistralai/mistral-small-3.1-24b-instruct:free',
    'google/gemini-2.0-pro-exp-02-05:free',
  ];

  static const String _systemPrompt =
      "• Interpret alerts\n\n"
      "REAL CONTEXT: You receive real-time data from Firestore (usage, rules, alerts).\n"
      "NEVER invent data if it is present in the context.\n"
      "If parents ask 'What is my child doing?', use the usage and alert data to answer.";

  final List<Map<String, dynamic>> _conversationHistory = [];

  Future<http.Response> _callApi(String model) async {
    return await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
            'HTTP-Referer': 'https://theguardian.app',
            'X-Title': 'TheGuardian Parental Control',
          },
          body: jsonEncode({
            'model': model,
            'messages': _conversationHistory,
            'temperature': 0.7,
            'max_tokens': 2048, // ✅ Increased to avoid truncated responses
          }),
        )
        .timeout(const Duration(seconds: 45)); // ✅ Timeout increased as well
  }

  Future<String> sendMessage(String userMessage,
      {Map<String, dynamic>? childContext}) async {
    try {
      if (_conversationHistory.isEmpty) {
        _conversationHistory.add({'role': 'system', 'content': _systemPrompt});
      }

      String fullMessage = userMessage;
      if (childContext != null) {
        final usage = childContext['usage'] ?? {};
        final rules = childContext['rules'] ?? {};
        final alerts = (childContext['recentAlerts'] as List?) ?? [];
        
        String alertsStr = alerts.isEmpty ? "No alerts" : alerts.map((a) => "- ${a['type']}: ${a['detail']}").join("\n");
        String rulesStr = "Limit: ${rules['dailyLimitMinutes'] ?? 'Not set'} min. Range: ${rules['allowedTimeStart'] ?? 'N/A'} - ${rules['allowedTimeEnd'] ?? 'N/A'}";

        fullMessage = '[FIRESTORE REAL-TIME DATA]\n'
            'Child: ${childContext['name']} (${childContext['age']} years old)\n'
            'Today\'s usage: ${usage['usedMinutes'] ?? 0} minutes\n'
            'Rules: $rulesStr\n'
            'Device: ${childContext['deviceStatus']} (Battery: ${childContext['battery']})\n'
            'Recent alerts:\n$alertsStr\n\n'
            'Parent message: $userMessage';
      }

      _conversationHistory.add({'role': 'user', 'content': fullMessage});

      for (final model in _models) {
        try {
          debugPrint('OpenRouter: trying with $model...');
          final response = await _callApi(model);
          debugPrint('OpenRouter: status=${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final choices = data['choices'] as List?;
            if (choices == null || choices.isEmpty) continue;

            final content = choices[0]['message']?['content'];
            String aiText = '';

            if (content is String) {
              aiText = content.trim();
            } else if (content is List) {
              aiText = content
                  .where((c) => c['type'] == 'text')
                  .map((c) => c['text'].toString())
                  .join('')
                  .trim();
            } else if (content != null) {
              aiText = content.toString().trim();
            }

            // Check if response is truncated
            final finishReason = choices[0]['finish_reason'];
            if (finishReason == 'length' && aiText.isNotEmpty) {
              // Truncated response — we accept it but note it
              debugPrint(
                  'OpenRouter: ⚠️ truncated response (finish_reason=length)');
              aiText +=
                  '\n\n*[Complete response available — try again if needed]*';
            }

            if (aiText.isEmpty) {
              debugPrint('OpenRouter: empty response from $model');
              continue;
            }

            _conversationHistory.add({'role': 'assistant', 'content': aiText});
            debugPrint('OpenRouter: ✅ success with $model');
            return aiText;
          } else if (response.statusCode == 401) {
            _conversationHistory.removeLast();
            return '❌ Invalid API key. Check your OpenRouter key.';
          } else {
            debugPrint('OpenRouter: $model → ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('OpenRouter: $model → error: $e');
        }
      }

      _conversationHistory.removeLast();
      return '❌ Service temporarily unavailable. Please try again in a few moments.';
    } catch (e) {
      return '❌ Connection error: $e';
    }
  }

  Future<String> analyzeChildActivity({
    required String childName,
    required int childAge,
    required List<Map<String, dynamic>> recentAlerts,
    String? deviceStatus,
    double? batteryLevel,
  }) async {
    final alertsText = recentAlerts.isEmpty
        ? 'No recent alerts'
        : recentAlerts.map((a) => '• ${a['type']}: ${a['details']}').join('\n');

    final prompt =
        "Analyze $childName's activity ($childAge years old) and give me a full report.\n"
        "Status: ${deviceStatus ?? 'Unknown'}\n"
        "Battery: ${batteryLevel != null ? '${batteryLevel.toInt()}%' : 'Unknown'}\n"
        "Recent alerts:\n$alertsText";

    return await sendMessage(prompt);
  }

  void clearHistory() => _conversationHistory.clear();
}
