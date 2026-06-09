import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/storage_service.dart';

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
    if (widget.initialCode != null && widget.initialCode!.length == 6) {
      // Auto-trigger pairing if code is valid
      WidgetsBinding.instance.addPostFrameCallback((_) => _handlePairing());
    }
  }

  Future<void> _handlePairing() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      // ── Step 1: Sign in anonymously ──────────────────────────────────────
      // The child device has no parent Firebase account. We sign in
      // anonymously so Firestore rules (request.auth != null) are satisfied.
      UserCredential? anonCred;
      if (FirebaseAuth.instance.currentUser == null) {
        anonCred = await FirebaseAuth.instance.signInAnonymously();
      }
      final childDeviceUid =
          anonCred?.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;

      // ── Step 2: Find the child document by invitationToken ───────────────
      final query = await db
          .collectionGroup('children')
          .where('invitationToken', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => _error = 'Invalid or expired code');
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final childId = doc.id;
      final parentId = data['parentId'] as String?;

      if (parentId == null) {
        setState(() => _error = 'Internal error: parent link missing');
        return;
      }

      // ── Step 3: Mark as linked and store childDeviceUid ──────────────────
      // childDeviceUid allows the Firestore rules to identify this device
      // for future authenticated reads without requiring the parent account.
      await doc.reference.update({
        'isLinked': true,
        'deviceStatus': 'ONLINE',
        'lastHeartbeat': FieldValue.serverTimestamp(),
        if (childDeviceUid != null) 'childDeviceUid': childDeviceUid,
      });

      // ── Step 4: Save pairing locally ─────────────────────────────────────
      await StorageService().saveChildPairing(parentId, childId);

      if (mounted) {
        // Pass full data + id so ChildDashboardScreen can resolve childId.
        context.go('/child/dashboard', extra: {...data, 'id': childId});
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
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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
                    'Enter the 6-digit code displayed on your parent\'s dashboard.',
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
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
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
                            style: TextStyle(color: Colors.redAccent, fontSize: 13),
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
