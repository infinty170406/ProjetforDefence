import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/child_enforcement_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/api_config.dart';

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
    _codeController = TextEditingController(text: widget.initialCode);
    if (widget.initialCode != null && widget.initialCode!.length >= 32) {
      // Auto-trigger pairing if code is valid
      WidgetsBinding.instance.addPostFrameCallback((_) => _handlePairing());
    }
  }

  Future<void> _handlePairing() async {
    final code = _codeController.text.trim();
    if (code.length < 32 || code.length > 128) {
      setState(() => _error = 'Please open the complete pairing link.');
      return;
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
      final result = await ApiService().postWithAuth(
        ApiConfig.pairDevice,
        {'token': code},
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
    } catch (e) {
      setState(() => _error = 'Connection error. Please try again.');
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
                          maxLength: 128,
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
                          onChanged: (val) {
                            if (val.length == 6) {
                              FocusScope.of(context).unfocus();
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
