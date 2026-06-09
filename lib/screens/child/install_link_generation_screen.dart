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
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Link for $displayName',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Generate a secure pairing link valid for 48 hours.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                  Spacer(),
                  if (_generatedLink == null) ...[
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Icon(Icons.link, color: AppColors.primary, size: 80),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Tap below to generate a unique pairing link for this device.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
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
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
                          ),
                          SizedBox(height: 20),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                            ),
                            child: Column(
                              children: [
                                Text('Token: $_token',
                                    style: TextStyle(
                                        color: AppColors.accentTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        letterSpacing: 3)),
                                SizedBox(height: 8),
                                Text(
                                  _generatedLink!,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12),
                          Text('Valid for 48 hours',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Link copied!')));
                            },
                            icon: Icon(Icons.copy, size: 16),
                            label: Text('Copy Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Spacer(),
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
                      padding: EdgeInsets.only(top: 12),
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
