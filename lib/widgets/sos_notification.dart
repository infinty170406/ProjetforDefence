import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosNotificationOverlay extends StatefulWidget {
  final bool success;
  final String message;
  final VoidCallback onDismiss;

  const SosNotificationOverlay({
    super.key,
    required this.success,
    required this.message,
    required this.onDismiss,
  });

  static void show(BuildContext context, {required bool success, required String message}) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => SosNotificationOverlay(
        success: success,
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<SosNotificationOverlay> createState() => _SosNotificationOverlayState();
}

class _SosNotificationOverlayState extends State<SosNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: widget.success
                          ? Colors.black.withValues(alpha: 0.7)
                          : AppColors.statusDanger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.success
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.statusDanger.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left Warning Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.success
                                ? AppColors.statusSuccess.withValues(alpha: 0.15)
                                : AppColors.statusDanger.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                            color: widget.success ? AppColors.statusSuccess : AppColors.statusDanger,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text Content
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // The Red SOS box
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusDanger,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'sos',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.success ? 'Alerte Envoyée !' : 'Échec SOS',
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Yellow underline decoration
                              Container(
                                height: 2,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: widget.success ? AppColors.accentAmber : Colors.transparent,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
