import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class InstallLinkGenerationScreen extends StatefulWidget {
  final dynamic child;
  const InstallLinkGenerationScreen({super.key, this.child});

  @override
  State<InstallLinkGenerationScreen> createState() =>
      _InstallLinkGenerationScreenState();
}

class _InstallLinkGenerationScreenState
    extends State<InstallLinkGenerationScreen> {
  bool _generating = false;
  String? _generatedLink;
  String? _token;


  Future<void> _generatePairingLink() async {
    setState(() => _generating = true);
    try {
      // The invitationToken is already generated at child creation in ChildRepository.
      final token = widget.child?['invitationToken'] ?? 'ERROR';
      
      if (token == 'ERROR') {
        throw Exception('Invitation token not found for this profile.');
      }

      final link = 'https://the-guardian.app/child/pair?code=$token';
      setState(() {
        _token = token;
        _generatedLink = link;
        _generating = false;
      });
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.statusDanger),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final displayName = widget.child?['displayName'] ?? 'your child';
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Link for $displayName',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Generate a secure pairing link valid for 48 hours.',
                    style: TextStyle(color: AppColors.textGray400, fontSize: 16),
                  ),
                  const Spacer(),
                  if (_generatedLink == null) ...[
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.link, color: AppColors.primary, size: 80),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Tap below to generate a unique pairing link for this device.',
                            style: TextStyle(color: AppColors.textGray400, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                Text('Token: $_token',
                                    style: const TextStyle(
                                        color: AppColors.accentTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        letterSpacing: 3)),
                                const SizedBox(height: 8),
                                Text(
                                  _generatedLink!,
                                  style: const TextStyle(color: AppColors.textGray400, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Valid for 48 hours',
                              style: TextStyle(color: AppColors.textGray400, fontSize: 12)),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied!')));
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  CustomButton(
                    text: _generating
                        ? 'Generating...'
                        : _generatedLink == null
                            ? 'Generate Pairing Link'
                            : 'Generate New Link',
                    onPressed: _generating ? null : _generatePairingLink,
                  ),
                  if (_generatedLink != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: CustomButton(
                        text: 'View Instructions',
                        onPressed: () => context.push('/child/link-instr', extra: widget.child),
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
