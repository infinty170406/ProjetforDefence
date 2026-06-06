import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import 'auth_service.dart';
import '../models/link_activation.dart';
import '../screens/auth/connecting_screen.dart';
import '../screens/auth/invalid_link_screen.dart';
import '../screens/auth/expired_link_screen.dart';

/// LinkHandlerService
///
/// Intercepte les deep links de jumelage (guardian:// et https://the-guardian.app/pair/…)
/// et orchestre le processus d'activation.
class LinkHandlerService {
  static final LinkHandlerService _instance = LinkHandlerService._internal();
  factory LinkHandlerService() => _instance;
  LinkHandlerService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  final _authService = AuthService();

  String? _pendingLink;

  void initialize() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('LinkHandler: Incoming deep link: $uri');
      _handleLink(uri.toString());
    }, onError: (err) {
      debugPrint('LinkHandler: Stream error: $err');
    });

    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        debugPrint('LinkHandler: Initial link (cold start): $uri');
        await Future.delayed(const Duration(milliseconds: 500));
        _handleLink(uri.toString());
      }
    } catch (e) {
      debugPrint('LinkHandler: Failed to get initial link: $e');
    }
  }

  void processPendingLink() {
    if (_pendingLink != null) {
      final link = _pendingLink!;
      _pendingLink = null;
      _handleLink(link);
    }
  }

  void _handleLink(String link) async {
    if (await _authService.isDeviceActivated()) {
      debugPrint('LinkHandler: Device already activated, ignoring link.');
      return;
    }

    final context = navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      debugPrint('LinkHandler: Context not ready or not mounted, storing link for later.');
      _pendingLink = link;
      return;
    }

    // Afficher un indicateur de chargement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Pairing device...'),
          ],
        ),
        duration: Duration(seconds: 20),
        backgroundColor: Colors.blueAccent,
      ),
    );

    final result = await _authService.activateDevice(link);
    
    // Vérifier si le widget est toujours présent
    final currentContext = navigatorKey.currentContext;
    if (currentContext == null || !currentContext.mounted) {
      debugPrint('LinkHandler: Context lost after activation.');
      return;
    }

    // Cacher le snackbar de chargement
    ScaffoldMessenger.of(currentContext).hideCurrentSnackBar();

    switch (result.status) {
      case LinkStatus.success:
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
            content: Text('✅ Device paired successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          currentContext,
          MaterialPageRoute(builder: (_) => const ConnectingScreen()),
          (route) => false,
        );
        break;

      case LinkStatus.invalid:
        Navigator.push(
          currentContext,
          MaterialPageRoute(
            builder: (_) => InvalidLinkScreen(status: result.status),
          ),
        );
        break;

      case LinkStatus.expired:
        Navigator.push(
          currentContext,
          MaterialPageRoute(builder: (_) => const ExpiredLinkScreen()),
        );
        break;

      case LinkStatus.networkError:
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Network error during activation.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () => _handleLink(link),
            ),
          ),
        );
        break;
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
