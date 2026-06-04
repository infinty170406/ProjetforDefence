// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() async {
  const apiKey = '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';
  final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  print('Testing OpenRouter connection with new key...');
  final response = await HttpClient().postUrl(url)
    ..headers.add('Authorization', 'Bearer $apiKey')
    ..headers.add('Content-Type', 'application/json')
    ..headers.add('HTTP-Referer', 'https://theguardian.app')
    ..headers.add('X-Title', 'TheGuardian Parental Control')
    ..write(jsonEncode({
      'model': 'openrouter/free',
      'messages': [{'role': 'user', 'content': 'Hello'}],
    }));
  
  final res = await response.close();
  final body = await res.transform(utf8.decoder).join();
  print('Status: ${res.statusCode}');
  print('Body: $body\n');
}
