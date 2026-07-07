import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _getSelectedIndex(String location) {
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/map')) return 1;
    if (location.startsWith('/ai-hub')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/map');
        break;
      case 3:
        context.go('/ai-hub');
        break;
      case 4:
        context.go('/settings/general');
        break;
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.statusDanger.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: AppColors.statusDanger, size: 28),
              ),
              const SizedBox(height: 20),
              Text(
                'Sign out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to sign out of your Guardian account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusDanger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Sign out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      ApiService().clearToken();
      await FirebaseAuth.instance.signOut();
      await StorageService().clearAll();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    final int selectedIndex = _getSelectedIndex(location);
    final width = MediaQuery.sizeOf(context).width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool showBottomNav = ['/dashboard', '/map', '/ai-hub', '/settings/general'].contains(location);

    if (width < 768) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(bottom: showBottomNav ? 90.0 : 0.0),
                child: widget.child,
              ),
            ),
            if (showBottomNav) ...[
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: _buildBottomNavBar(selectedIndex, context),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: _buildMobileFab(context),
              ),
            ],
          ],
        ),
      );
    } else if (width < 1100) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            _buildNavigationRail(selectedIndex, context),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            _buildFullSidebar(selectedIndex, context),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBottomNavBar(int selectedIndex, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double navWidth = screenWidth * 0.92;
    final double itemWidth = (navWidth - 24) / 5;

    return Center(
      child: Container(
        width: navWidth,
        height: 72,
        decoration: BoxDecoration(
          color: isDark 
              ? const Color(0xFF1E293B).withOpacity(0.7) 
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
              color: isDark 
                  ? AppColors.glassBorder 
                  : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: isDark 
                    ? Colors.black.withOpacity(0.3) 
                    : const Color(0xFF4F46E5).withOpacity(0.06),
                blurRadius: 20,
                spreadRadius: 2)
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutQuint,
                  left: 12 + (selectedIndex * itemWidth),
                  bottom: 10,
                  child: Container(
                    width: itemWidth,
                    height: 4,
                    alignment: Alignment.center,
                    child: Container(
                      width: 20,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildNavBarItem(Icons.dashboard, 0, selectedIndex, context)),
                      Expanded(child: _buildNavBarItem(Icons.map_outlined, 1, selectedIndex, context)),
                      const SizedBox(width: 56), // spacer for FAB
                      Expanded(child: _buildNavBarItem(Icons.chat_bubble_outline, 3, selectedIndex, context)),
                      Expanded(child: _buildNavBarItem(Icons.settings_outlined, 4, selectedIndex, context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(IconData icon, int index, int selectedIndex, BuildContext context) {
    final bool isSelected = selectedIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected 
                    ? AppColors.primary 
                    : (isDark ? AppColors.textGray400 : const Color(0xFF94A3B8)),
                size: 24)
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFab(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: GestureDetector(
        onTap: () => context.push('/child/create'),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 3)
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildNavigationRail(int selectedIndex, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 80,
      color: isDark ? const Color(0xFF0B1329) : Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 40),
          _buildRailItem(Icons.dashboard, 'Dashboard', 0, selectedIndex, context),
          const SizedBox(height: 16),
          _buildRailItem(Icons.map_outlined, 'Map', 1, selectedIndex, context),
          const SizedBox(height: 16),
          _buildRailActionItem(Icons.person_add_outlined, 'Add Child', () => context.push('/child/create'), context),
          const SizedBox(height: 16),
          _buildRailItem(Icons.chat_bubble_outline, 'AI Hub', 3, selectedIndex, context),
          const SizedBox(height: 16),
          _buildRailItem(Icons.settings_outlined, 'Settings', 4, selectedIndex, context),
          const Spacer(),
          _buildRailActionItem(Icons.logout, 'Sign out', _handleLogout, context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRailItem(IconData icon, String label, int index, int selectedIndex, BuildContext context) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isSelected ? AppColors.primary : (isDark ? AppColors.textGray400 : const Color(0xFF64748B));
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => _onItemTapped(index, context),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.08) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
            ),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildRailActionItem(IconData icon, String label, VoidCallback onTap, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isDark ? AppColors.textGray400 : const Color(0xFF64748B), size: 22),
        ),
      ),
    );
  }

  Widget _buildFullSidebar(int selectedIndex, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: 260,
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "GUARDIAN",
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          
          Text(
            "NAVIGATION",
            style: TextStyle(
              color: subtextColor.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          _buildSidebarItem(Icons.dashboard, 'Dashboard', 0, selectedIndex, context),
          const SizedBox(height: 6),
          _buildSidebarItem(Icons.map_outlined, 'Real-time Map', 1, selectedIndex, context),
          const SizedBox(height: 6),
          _buildSidebarItem(Icons.chat_bubble_outline, 'AI Orchestrator', 3, selectedIndex, context),
          const SizedBox(height: 6),
          _buildSidebarItem(Icons.settings_outlined, 'Settings', 4, selectedIndex, context),
          const SizedBox(height: 28),

          Text(
            "QUICK ACTIONS",
            style: TextStyle(
              color: subtextColor.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () => context.push('/child/create'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentTeal],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Add Child Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),

          InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.logout, color: subtextColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index, int selectedIndex, BuildContext context) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final textColor = isSelected 
        ? activeColor 
        : (isDark ? Colors.white : const Color(0xFF334155));
    final iconColor = isSelected 
        ? activeColor 
        : (isDark ? AppColors.textGray400 : const Color(0xFF64748B));

    return InkWell(
      onTap: () => _onItemTapped(index, context),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? activeColor.withOpacity(isDark ? 0.12 : 0.06) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
