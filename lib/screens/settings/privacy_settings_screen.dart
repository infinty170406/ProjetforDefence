import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends State<PrivacySettingsScreen> {
  bool _shareAnalytics = true;
  bool _diagnosticData = true;

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Privacy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      children: [
                        const GlassCard(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield, color: Colors.greenAccent),
                                  SizedBox(width: 12),
                                  Text(
                                    'Your data is protected',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                'The Guardian uses end-to-end encryption for all data communications between parents and children.',
                                style: TextStyle(
                                    color: AppColors.textGray400,
                                    fontSize: 14,
                                    height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Data Preferences',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                title: 'End-to-End Encryption',
                                subtitle: 'Always active for family data',
                                value: true,
                                onChanged: null,
                                icon: Icons.lock_outline,
                              ),
                              const Divider(color: Colors.white10, height: 1),
                              _buildSwitchTile(
                                title: 'Share Analytics with AI',
                                subtitle: 'Help improve AI monitoring accuracy',
                                value: _shareAnalytics,
                                onChanged: (val) => setState(() => _shareAnalytics = val),
                                icon: Icons.analytics_outlined,
                              ),
                              const Divider(color: Colors.white10, height: 1),
                              _buildSwitchTile(
                                title: 'Anonymous Diagnostic Data',
                                subtitle: 'Send crash reports to developers',
                                value: _diagnosticData,
                                onChanged: (val) => setState(() => _diagnosticData = val),
                                icon: Icons.bug_report_outlined,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Account Data',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          padding: const EdgeInsets.all(4),
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Delete Account & Data',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        Text('Permanently remove all family data',
                                            style: TextStyle(color: AppColors.textGray400, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textGray400, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
