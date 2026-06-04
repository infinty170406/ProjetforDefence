import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import 'package:flutter/services.dart';

class ChildInstallLinkScreen extends StatelessWidget {
  final dynamic child;
  final String title;

  const ChildInstallLinkScreen(
      {super.key, this.child, this.title = 'Installation Link'});

  @override
  Widget build(BuildContext context) {
    final displayName = child?['displayName'] ?? 'your child';
    final token = child?['invitationToken'] ?? '---';
    final link = 'https://the-guardian.app/child/pair?code=$token';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Use this code on the child's device to link the account.",
                    style: TextStyle(
                      color: AppColors.textGray400,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Invitation code',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          token,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Direct link:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          link,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Copy link',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Link copied to clipboard'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Done',
                    onPressed: () => context.go('/dashboard'),
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
