import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _alertsEnabled = true;
  bool _weeklyReport = true;

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
                    'Notifications',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 32),
                  _buildToggleItem('Security Alerts', _alertsEnabled,
                      (val) => setState(() => _alertsEnabled = val)),
                  _buildToggleItem('Weekly Reports', _weeklyReport,
                      (val) => setState(() => _weeklyReport = val)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String title, bool value, Function(bool) onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16)),
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primary
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
