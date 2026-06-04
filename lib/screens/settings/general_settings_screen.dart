import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ApiService().clearToken();
      await FirebaseAuth.instance.signOut();
      await StorageService().clearAll();
      if (context.mounted) context.go('/login');
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Support',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _helpItem(Icons.email_outlined, 'Email us', 'support@theguardian.app'),
            const SizedBox(height: 12),
            _helpItem(Icons.web, 'Documentation', 'docs.theguardian.app'),
            const SizedBox(height: 12),
            _helpItem(Icons.info_outline, 'App version', 'The Guardian v1.0.0'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text(subtitle, style: const TextStyle(color: AppColors.textGray400, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (user != null)
                    Text(user.email ?? '',
                        style: const TextStyle(color: AppColors.textGray400, fontSize: 14)),
                  const SizedBox(height: 28),
                  _buildSettingItem(
                    context, 'Account', Icons.person_outline,
                    () => context.push('/settings/account'),
                  ),
                  _buildSettingItem(
                    context, 'Help & Support', Icons.help_outline,
                    () => _showHelp(context),
                  ),
                  _buildSettingItem(
                    context, 'Sign out', Icons.logout,
                    () => _handleLogout(context),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isDestructive ? AppColors.statusDanger : Colors.white70,
                size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: isDestructive ? AppColors.statusDanger : Colors.white70,
                      fontSize: 16)),
            ),
            Icon(Icons.chevron_right,
                color: isDestructive ? AppColors.statusDanger : Colors.white38,
                size: 20),
          ],
        ),
      ),
    );
  }
}
