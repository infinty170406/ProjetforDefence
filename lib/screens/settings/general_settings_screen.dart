import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/app_state_manager.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help & Support',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _helpItem(context, Icons.email_outlined, 'Email us', 'support@theguardian.app'),
            const SizedBox(height: 12),
            _helpItem(context, Icons.web, 'Documentation', 'docs.theguardian.app'),
            const SizedBox(height: 12),
            _helpItem(context, Icons.info_outline, 'App version', 'The Guardian v1.0.0'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(BuildContext context, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  void _showThemeSelector(BuildContext context) {
    final stateManager = context.read<AppStateManager>();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Theme',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _themeOption(
              context,
              icon: Icons.settings_suggest_outlined,
              title: 'System default',
              isSelected: stateManager.themeMode == ThemeMode.system,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _themeOption(
              context,
              icon: Icons.light_mode_outlined,
              title: 'Light theme',
              isSelected: stateManager.themeMode == ThemeMode.light,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _themeOption(
              context,
              icon: Icons.dark_mode_outlined,
              title: 'Dark theme',
              isSelected: stateManager.themeMode == ThemeMode.dark,
              onTap: () {
                stateManager.setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final activeColor = AppColors.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : textColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? activeColor : textColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 16),
                  Text('Settings',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (user != null)
                    Text(user.email ?? '',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                  const SizedBox(height: 28),
                  _buildSettingItem(
                    context, 'Account', Icons.person_outline,
                    () => context.push('/settings/account'),
                  ),
                  _buildSettingItem(
                    context, 'App Theme', Icons.palette_outlined,
                    () => _showThemeSelector(context),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDestructive 
        ? AppColors.statusDanger 
        : Theme.of(context).colorScheme.onSurface;
    final iconColor = isDestructive 
        ? AppColors.statusDanger 
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final chevronColor = isDestructive 
        ? AppColors.statusDanger 
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final containerBg = isDark 
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04) 
        : const Color(0xFFF1F5F9);
    final borderColor = isDark 
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08) 
        : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}
