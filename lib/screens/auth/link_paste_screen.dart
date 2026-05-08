import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../models/link_activation.dart';
import 'connecting_screen.dart';
import 'invalid_link_screen.dart';
import 'expired_link_screen.dart';

class LinkPasteScreen extends StatefulWidget {
  const LinkPasteScreen({super.key});

  @override
  State<LinkPasteScreen> createState() => _LinkPasteScreenState();
}

class _LinkPasteScreenState extends State<LinkPasteScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasText = _controller.text.isNotEmpty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onConnect() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final activation = await AuthService().activateDevice(text);

      if (!mounted) return;

      setState(() => _isLoading = false);

      switch (activation.status) {
        case LinkStatus.success:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConnectingScreen()),
          );
          break;
        case LinkStatus.invalid:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => InvalidLinkScreen(status: activation.status)),
          );
          break;
        case LinkStatus.expired:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpiredLinkScreen()),
          );
          break;
        case LinkStatus.networkError:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(activation.errorMessage ?? 'Erreur réseau lors de l\'activation.'),
                backgroundColor: AppColors.statusDanger,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur inattendue: $e'),
              backgroundColor: AppColors.statusDanger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // Background glows
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 60,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 100,
                    spreadRadius: 60,
                  )
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top nav
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: AppColors.primary, size: 20),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'THE GUARDIAN CHILD',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Image.asset(
                                'assets/images/Rectangle 69.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        // Heading
                        const Text(
                          "Enter activation link",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Connect your device to start secure monitoring.',
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        // Text area
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _controller,
                            maxLines: 3,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(
                                    left: 12, top: 16, bottom: 0, right: 0),
                                child: Icon(Icons.link,
                                    color: AppColors.primary, size: 20),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              hintText: 'Paste link here',
                              hintStyle: TextStyle(
                                  color: Colors.grey[600], fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Help text
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 13,
                                      height: 1.4),
                                  children: const [
                                    TextSpan(
                                        text:
                                            "Copy the full link from the parent app. "),
                                    TextSpan(
                                      text: 'https://',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: " and "),
                                    TextSpan(
                                      text: 'guardian://',
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(text: " formats are accepted."),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                // Action button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (_hasText && !_isLoading) ? _onConnect : null,
                          icon: _isLoading
                              ? const SizedBox(width: 0, height: 0)
                              : const Text(''),
                          label: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Connect device",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.sensors,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasText
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: _hasText ? 8 : 0,
                            shadowColor:
                                AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'END-TO-END ENCRYPTION',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
