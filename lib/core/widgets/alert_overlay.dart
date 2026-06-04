import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../router/app_router.dart';
import '../models/app_state_manager.dart';
import '../models/alert_model.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class AlertOverlay extends StatefulWidget {
  final Widget child;
  const AlertOverlay({super.key, required this.child});

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay> {
  bool _hasReachedDashboard = false;
  int _lastTapTime = 0;

  @override
  void initState() {
    super.initState();
    _hasReachedDashboard = FirebaseAuth.instance.currentUser != null;
  }

  @override
  Widget build(BuildContext context) {
    String location = '';
    try {
      location = AppRouter.router.state.uri.path;
    } catch (_) {
      try {
        location = AppRouter.router.routerDelegate.currentConfiguration.last
            .matchedLocation;
      } catch (__) {}
    }

    // RESET if no user (logout)
    if (FirebaseAuth.instance.currentUser == null) {
      _hasReachedDashboard = false;
    }

    // Trigger dashboard state ONLY when actually hitting the dashboard
    if (!_hasReachedDashboard && location.contains('dashboard')) {
      _hasReachedDashboard = true;
    }

    return Stack(
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - _lastTapTime < 500) {
              // Global double tap detected
            }
            _lastTapTime = now;
          },
          child: widget.child,
        ),
        // Alerts Section
        Consumer<AppStateManager>(
          builder: (context, stateManager, _) {
            if (stateManager.alerts.isEmpty) return const SizedBox.shrink();
            final latestAlert = stateManager.alerts.first;
            return Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Dismissible(
                key: Key(latestAlert.id),
                onDismissed: (_) => stateManager.clearAlerts(),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _getSeverityColor(latestAlert.severity)
                      .withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(_getIcon(latestAlert.severity),
                          color: _getSeverityColor(latestAlert.severity)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(latestAlert.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text(latestAlert.description,
                                style: const TextStyle(
                                    color: AppColors.textGray400, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.info:
        return AppColors.primary;
    }
  }

  IconData _getIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Icons.report_problem;
      case AlertSeverity.warning:
        return Icons.warning_amber;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }
}
