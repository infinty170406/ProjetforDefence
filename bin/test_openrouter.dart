// ignore_for_file: avoid_print
import 'dart:io';
import 'package:the_guardian/core/services/open_router_service.dart';

void main() async {
  final service = OpenRouterService();
  print('Testing OpenRouterService...');
  try {
    final response = await service.sendMessage('Bonjour, es-tu là ?');
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
