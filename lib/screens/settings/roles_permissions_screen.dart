import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';

class RolesPermissionsScreen extends StatelessWidget {
  final String title;

  const RolesPermissionsScreen({super.key, this.title = 'Roles & Permissions'});

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
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Manage account access and permissions.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 40),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildRoleItem(
                          context,
                          name: 'You',
                          role: 'Administrator',
                          email: 'parent@example.com',
                          isYou: true,
                          icon: Icons.admin_panel_settings,
                        ),
                        SizedBox(height: 16),
                        _buildRoleItem(
                          context,
                          name: 'Mom',
                          role: 'Co-Parent',
                          email: 'mom@example.com',
                          isYou: false,
                          icon: Icons.person_outline,
                        ),
                        SizedBox(height: 24),
                        GlassCard(
                          padding: EdgeInsets.all(20),
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_alt_1, color: AppColors.primary),
                                SizedBox(width: 12),
                                Text(
                                  'Invite a Co-Parent',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                  CustomButton(
                    text: 'Finish',
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRoleItem(BuildContext context, {
    required String name,
    required String role,
    required String email,
    required bool isYou,
    required IconData icon,
  }) {
    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isYou ? AppColors.primary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isYou ? AppColors.primary : Theme.of(context).colorScheme.onSurface, size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (isYou) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('You', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isYou)
            IconButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
              onPressed: () {},
            ),
        ],
      ),
    );
  }
}
