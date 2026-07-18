import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/child_enforcement_service.dart';
import '../../core/services/guardian_api.dart';
import '../../core/services/pairing_link_service.dart';

class ChildPairingScreen extends StatefulWidget {
  final String? initialCode;
  const ChildPairingScreen({super.key, this.initialCode});

  @override
  State<ChildPairingScreen> createState() => _ChildPairingScreenState();
}

class _ChildPairingScreenState extends State<ChildPairingScreen> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialToken = PairingLinkService.extractToken(widget.initialCode);
    _codeController = TextEditingController(text: initialToken ?? widget.initialCode);
    if (initialToken != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handlePairing());
    }
  }

  Future<void> _handlePairing() async {
    final code = PairingLinkService.extractToken(_codeController.text);
    if (code == null) {
      setState(() => _error =
          'Lien ou jeton invalide. Ouvrez le lien complet envoyé par le parent.');
      return;
    }

    if (_codeController.text != code) {
      _codeController.text = code;
    }

    if (!await StorageService().getPrivacyAccepted()) {
      setState(() => _error =
          'Veuillez accepter la politique de confidentialité avant d’activer la supervision.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ── Step 1: Sign in anonymously ──────────────────────────────────────
      // The child device has no parent Firebase account. We sign in
      // anonymously so Firestore rules (request.auth != null) are satisfied.
      UserCredential? anonCred;
      if (FirebaseAuth.instance.currentUser == null) {
        anonCred = await FirebaseAuth.instance.signInAnonymously();
      }
      if (anonCred?.user == null && FirebaseAuth.instance.currentUser == null) {
        throw StateError('Anonymous authentication failed.');
      }

      // ── Step 2: consume the one-time token server-side ───────────────────
      final result = await GuardianApi.post(
        '/api/v1/device/pair',
        body: {'token': code},
      );
      final parentId = result['parentId'] as String?;
      final childId = result['childId'] as String?;
      if (parentId == null || childId == null) {
        throw StateError('Invalid pairing response.');
      }

      // ── Step 4: Save pairing locally ─────────────────────────────────────
      await StorageService().saveChildPairing(parentId, childId);
      await ChildEnforcementService().start();

      if (mounted) {
        context.go('/child/dashboard',
            extra: {'id': childId, 'parentId': parentId});
      }
    } on GuardianApiException catch (error) {
      final message = switch (error.statusCode) {
        400 => 'Le jeton d’appairage est mal formé.',
        404 => 'Ce lien est invalide ou ne correspond à aucun enfant.',
        410 => 'Ce lien a expiré. Générez un nouveau lien depuis l’app parent.',
        412 => 'Ce lien a déjà été utilisé ou l’appareil est déjà associé.',
        401 => 'L’authentification de l’appareil enfant a échoué.',
        _ => error.message,
      };
      if (mounted) setState(() => _error = message);
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            'Connexion impossible. Vérifiez Internet puis réessayez.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Pair Device',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Open the secure pairing link sent by the parent.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 48),
                  GlassCard(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        TextField(
                          controller: _codeController,
                          maxLength: 256,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Pairing token',
                            hintStyle: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.1)),
                            border: InputBorder.none,
                          ),
                          onChanged: (value) {
                            final token = PairingLinkService.extractToken(value);
                            if (token != null && _error != null) {
                              setState(() => _error = null);
                            }
                          },
                        ),
                        if (_error != null) ...[
                          SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: 32),
                        CustomButton(
                          text: _isLoading ? 'Connecting...' : 'Link My Device',
                          onPressed: _isLoading ? null : _handlePairing,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
