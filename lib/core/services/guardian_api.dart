import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class GuardianApiException implements Exception {
  GuardianApiException({
    required this.message,
    required this.statusCode,
    this.code,
  });

  final String message;
  final int statusCode;
  final String? code;

  @override
  String toString() => message;
}

class GuardianApi {
  static const String baseUrl = String.fromEnvironment(
    'GUARDIAN_API_BASE_URL',
    defaultValue: 'https://guardian-secure-api.onrender.com',
  );

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw GuardianApiException(
        message: 'Utilisateur non authentifié.',
        statusCode: 401,
        code: 'unauthenticated',
      );
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw GuardianApiException(
        message: 'Token Firebase indisponible.',
        statusCode: 401,
        code: 'missing-token',
      );
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(const Duration(seconds: 45));

    Map<String, dynamic> data = <String, dynamic>{};

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GuardianApiException(
        message: data['error']?.toString() ??
            data['message']?.toString() ??
            'Erreur HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
        code: data['code']?.toString(),
      );
    }

    return data;
  }
}
