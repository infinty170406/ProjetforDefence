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
                    'Link for $displayName',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Use this code on the child's device to link the account.",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 30),
                  GlassCard(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Invitation code',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.70),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          token,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Direct link:',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.70),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          link,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        SizedBox(height: 24),
                        CustomButton(
                          text: 'Copy link',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied to clipboard'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
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
