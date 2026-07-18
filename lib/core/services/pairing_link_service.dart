import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';

/// Centralise la génération, la validation et l'ouverture des liens
/// d'appairage parent/enfant.
class PairingLinkService {
  PairingLinkService._();

  static final PairingLinkService instance = PairingLinkService._();

  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{32,128}$');

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  String? _lastDispatchedToken;
  DateTime? _lastDispatchAt;

  /// Lien HTTPS partageable. Le backend Render affiche une page de transition
  /// puis ouvre le schéma privé de l'application enfant.
  static String buildPairingLink(String token) {
    final normalized = extractToken(token);
    if (normalized == null) {
      throw ArgumentError.value(token, 'token', 'Jeton d’appairage invalide');
    }

    return Uri.parse('${ApiConfig.productionBaseUrl}/pair')
        .replace(queryParameters: {'code': normalized})
        .toString();
  }

  /// Lien applicatif utilisé par la page de transition Render.
  static String buildAppLink(String token) {
    final normalized = extractToken(token);
    if (normalized == null) {
      throw ArgumentError.value(token, 'token', 'Jeton d’appairage invalide');
    }

    return Uri(
      scheme: 'theguardian',
      host: 'pair',
      queryParameters: {'code': normalized},
    ).toString();
  }

  /// Accepte un jeton seul, un lien HTTPS complet ou un lien theguardian://.
  static String? extractToken(String? rawValue) {
    if (rawValue == null) return null;

    final raw = rawValue.trim();
    if (raw.isEmpty) return null;
    if (_tokenPattern.hasMatch(raw)) return raw;

    final uri = Uri.tryParse(raw);
    if (uri != null) {
      for (final key in const ['code', 'token', 'pairingCode']) {
        final candidate = uri.queryParameters[key]?.trim();
        if (candidate != null && _tokenPattern.hasMatch(candidate)) {
          return candidate;
        }
      }

      // Certains outils placent le lien dans le fragment après le caractère #.
      if (uri.fragment.isNotEmpty) {
        final fragmentUri = Uri.tryParse(uri.fragment);
        if (fragmentUri != null) {
          for (final key in const ['code', 'token', 'pairingCode']) {
            final candidate = fragmentUri.queryParameters[key]?.trim();
            if (candidate != null && _tokenPattern.hasMatch(candidate)) {
              return candidate;
            }
          }
        }
      }
    }

    try {
      final decoded = Uri.decodeComponent(raw);
      if (decoded != raw && _tokenPattern.hasMatch(decoded)) return decoded;
    } on FormatException {
      // La valeur n'était pas encodée : aucune action nécessaire.
    }

    return null;
  }

  static bool isValidToken(String? value) => extractToken(value) != null;

  static String formatTokenForDisplay(String token) {
    final normalized = extractToken(token);
    if (normalized == null) return token;

    final groups = <String>[];
    for (var start = 0; start < normalized.length; start += 8) {
      final end = start + 8 < normalized.length ? start + 8 : normalized.length;
      groups.add(normalized.substring(start, end));
    }
    return groups.join('\n');
  }

  /// Écoute le lien qui a lancé l'application et ceux reçus pendant qu'elle
  /// est déjà ouverte. Le callback reçoit toujours un jeton normalisé.
  Future<void> initialize(ValueChanged<String> onPairingToken) async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      _dispatch(initialUri, onPairingToken);
    } catch (error) {
      debugPrint('PAIRING_LINK: initial link error: $error');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _dispatch(uri, onPairingToken),
      onError: (Object error) {
        debugPrint('PAIRING_LINK: stream error: $error');
      },
    );
  }

  void _dispatch(Uri? uri, ValueChanged<String> onPairingToken) {
    if (uri == null) return;

    final token = extractToken(uri.toString());
    if (token == null) {
      debugPrint('PAIRING_LINK: ignored invalid URI: $uri');
      return;
    }

    final now = DateTime.now();
    final duplicate = token == _lastDispatchedToken &&
        _lastDispatchAt != null &&
        now.difference(_lastDispatchAt!) < const Duration(seconds: 2);
    if (duplicate) return;

    _lastDispatchedToken = token;
    _lastDispatchAt = now;
    debugPrint('PAIRING_LINK: valid token received from ${uri.scheme} link.');
    onPairingToken(token);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _lastDispatchedToken = null;
    _lastDispatchAt = null;
  }
}
