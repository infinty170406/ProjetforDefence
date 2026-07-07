import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../api_config.dart';

/// GeminiService
///
/// Client bas niveau de l'API Google Gemini (Generative Language API).
/// C'est le « cerveau » brut utilisé par [GuardianAgentService].
///
/// Deux modes d'appel :
///   • [generateText]  → réponse en texte libre (chat, analyses rédigées)
///   • [generateJson]  → réponse JSON stricte (analyses structurées, recommandations)
///
/// La clé API est lue dans cet ordre de priorité :
///   1. variable d'environnement `GEMINI_API_KEY` (fichier .env)
///   2. fallback historique `ApiConfig.geminiApiKey`
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  /// Clé API Gemini. À définir dans le fichier `.env` (GEMINI_API_KEY=...).
  static String get _apiKey {
    final fromEnv = dotenv.env['GEMINI_API_KEY'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    return ApiConfig.geminiApiKey;
  }

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Liste de modèles essayés successivement (du plus récent/rapide au fallback).
  /// Si un modèle est indisponible, on bascule automatiquement sur le suivant.
  static const List<String> _models = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];

  /// Appel HTTP unitaire vers un modèle donné.
  Future<http.Response> _call(String model, Map<String, dynamic> body) {
    final uri = Uri.parse('$_baseUrl/$model:generateContent');
    return http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
  }

  /// Construit le corps de requête Gemini commun aux deux modes.
  ///
  /// [history] : historique conversationnel facultatif au format
  ///   `[{'role': 'user'|'model', 'text': '...'}]`.
  /// [jsonMode] : force une sortie strictement JSON (responseMimeType).
  Map<String, dynamic> _buildBody({
    required String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
    double temperature = 0.7,
    bool jsonMode = false,
  }) {
    final contents = <Map<String, dynamic>>[];

    // Historique conversationnel (chat multi-tours)
    if (history != null) {
      for (final m in history) {
        contents.add({
          'role': m['role'] == 'model' ? 'model' : 'user',
          'parts': [
            {'text': m['text'] ?? ''}
          ],
        });
      }
    }

    // Message courant
    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ],
    });

    return {
      if (systemPrompt != null)
        'system_instruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': 2048,
        if (jsonMode) 'responseMimeType': 'application/json',
      },
    };
  }

  /// Extrait le texte de la première réponse renvoyée par Gemini.
  String? _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;
      final buffer = StringBuffer();
      for (final p in parts) {
        final t = p['text'];
        if (t is String) buffer.write(t);
      }
      final text = buffer.toString().trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('GeminiService: _extractText error: $e');
      return null;
    }
  }

  /// Génère une réponse en texte libre.
  ///
  /// Essaie chaque modèle de [_models] jusqu'à obtenir une réponse valide.
  /// Lève une [Exception] si tous les modèles échouent.
  Future<String> generateText(
    String prompt, {
    String? systemPrompt,
    List<Map<String, String>>? history,
    double temperature = 0.7,
  }) async {
    final body = _buildBody(
      prompt: prompt,
      systemPrompt: systemPrompt,
      history: history,
      temperature: temperature,
    );

    Object? lastError;
    for (final model in _models) {
      try {
        debugPrint('GeminiService: trying $model ...');
        final res = await _call(model, body);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final text = _extractText(data);
          if (text != null) {
            debugPrint('GeminiService: ✅ success with $model');
            return text;
          }
          debugPrint('GeminiService: empty response from $model');
        } else if (res.statusCode == 400 || res.statusCode == 403) {
          // Clé invalide ou requête refusée : inutile d'essayer les autres modèles.
          debugPrint('GeminiService: ${res.statusCode} → ${res.body}');
          throw Exception('Clé Gemini invalide ou accès refusé (${res.statusCode}).');
        } else {
          debugPrint('GeminiService: $model → HTTP ${res.statusCode}');
          lastError = Exception('HTTP ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('GeminiService: $model → error: $e');
        lastError = e;
      }
    }
    throw Exception('Gemini indisponible: ${lastError ?? 'aucun modèle disponible'}');
  }

  /// Génère une réponse JSON et la parse en [Map].
  ///
  /// Le prompt doit décrire le schéma JSON attendu. En cas d'échec de parsing,
  /// retourne `null` (l'appelant doit prévoir un fallback heuristique).
  Future<Map<String, dynamic>?> generateJson(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.4,
  }) async {
    final body = _buildBody(
      prompt: prompt,
      systemPrompt: systemPrompt,
      temperature: temperature,
      jsonMode: true,
    );

    for (final model in _models) {
      try {
        final res = await _call(model, body);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final text = _extractText(data);
          if (text == null) continue;
          return _safeParseJson(text);
        } else if (res.statusCode == 400 || res.statusCode == 403) {
          throw Exception('Clé Gemini invalide ou accès refusé (${res.statusCode}).');
        }
      } catch (e) {
        debugPrint('GeminiService: generateJson $model → error: $e');
      }
    }
    return null;
  }

  /// Parse JSON de manière tolérante (retire un éventuel bloc ```json ... ```).
  Map<String, dynamic>? _safeParseJson(String text) {
    try {
      var clean = text.trim();
      if (clean.startsWith('```')) {
        clean = clean.replaceAll(RegExp(r'^```[a-zA-Z]*'), '').replaceAll('```', '').trim();
      }
      final decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'items': decoded};
      return null;
    } catch (e) {
      debugPrint('GeminiService: _safeParseJson error: $e');
      return null;
    }
  }
}
