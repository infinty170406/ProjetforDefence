// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:the_guardian/core/services/open_router_service.dart';

void main() {
  test('Test OpenRouterService with new key', () async {
    final service = OpenRouterService();
    print('Sending message to OpenRouter...');
    final response = await service.sendMessage('Bonjour, ceci est un test. Réponds simplement "Test réussi" si tu me recois.');
    print('Response: $response');
    expect(response.isNotEmpty, true);
    expect(response.contains('❌'), false); // Assuming ❌ is used for errors as in the service
  });
}
