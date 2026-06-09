import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'link_paste_screen.dart';
import '../../models/link_activation.dart';

class InvalidLinkScreen extends StatelessWidget {
  final LinkStatus? status;
  const InvalidLinkScreen({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0DB32BEE),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0DEF4444),
                    blurRadius: 150,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(Icons.close,
                                      color: AppColors.textDark, size: 24),
                                ),
                                const Text(
                                  'The Guardian',
                                  style: TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 24),
                              ],
                            ),
                          ),
                          // Content
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Warning icon
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Color(0x33FF5252),
                                                blurRadius: 60,
                                                spreadRadius: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: const BoxDecoration(
                                            color: Color(0x1AFF5252),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Color(0xFFFF5252),
                                            size: 48,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Text(
                                      status == LinkStatus.networkError
                                          ? 'Timeout'
                                          : status == LinkStatus.expired
                                              ? 'Link Expired'
                                              : 'Invalid Link',
                                      style: const TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      status == LinkStatus.networkError
                                          ? 'The server is taking too long to respond. Please try again in a few moments.'
                                          : status == LinkStatus.expired
                                              ? 'This link is no longer valid. Ask your parents for a new link.'
                                              : 'Check that the link is complete or ask for a new link to continue.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFBDBDBD),
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    // Divider
                                    Container(
                                      height: 1,
                                      width: double.infinity,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0x4DB32BEE),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    // Buttons
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const LinkPasteScreen()),
                                        ),
                                        icon: const Text(''),
                                        label: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Retry',
                                              style: TextStyle(
                                                color: AppColors.textDark,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.refresh,
                                                color: AppColors.textDark, size: 20),
                                          ],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          elevation: 10,
                                          shadowColor: AppColors.primary
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          side: const BorderSide(
                                              color: Color(0xFF424242), width: 1),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                        ),
                                          child: const Text(
                                            'Contact support',
                                            style: TextStyle(
                                              color: Color(0xFF9E9E9E),
                                              fontSize: 15,
                                            ),
                                          ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Footer
                          const Padding(
                            padding: EdgeInsets.only(bottom: 32),
                            child: Text(
                              'SECURED BY THE GUARDIAN',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
