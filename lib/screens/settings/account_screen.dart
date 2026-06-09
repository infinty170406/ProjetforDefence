import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _name = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);

    // Load from local storage first (fast)
    final info = await StorageService().getUserInfo();
    if (mounted) {
      setState(() {
        _name = info['name'] ?? '';
        _email = info['email'] ?? '';
        _isLoading = false;
      });
    }

    // Then refresh from API in background
    try {
      final profile = await ApiService().getMyProfile();
      if (mounted && profile.isNotEmpty) {
        final freshName = profile['name'] ?? profile['displayName'] ?? _name;
        final freshEmail = profile['email'] ?? _email;
        // Save updated info
        await StorageService().saveUserInfo(freshName, freshEmail);
        if (mounted) {
          setState(() {
            _name = freshName;
            _email = freshEmail;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () => context.pop(),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'My Account',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar card
                              GlassCard(
                                padding: EdgeInsets.all(28),
                                child: Column(
                                  children: [
                                    // Avatar circle
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(alpha: 0.8),
                                            AppColors.primary.withValues(alpha: 0.3),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.4),
                                            blurRadius: 20,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: 44,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      _name.toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _email.toLowerCase(),
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    // Badge
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_user, color: AppColors.primary, size: 16),
                                          SizedBox(width: 6),
                                          Text(
                                            'Verified Parent',
                                            style: TextStyle(color: AppColors.primary, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20),

                              // Info details card
                              GlassCard(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    _buildInfoTile(
                                      icon: Icons.person_outline,
                                      label: 'Full name',
                                      value: _name.isNotEmpty ? _name : '—',
                                    ),
                                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10)),
                                    _buildInfoTile(
                                      icon: Icons.email_outlined,
                                      label: 'Email address',
                                      value: _email.isNotEmpty ? _email : '—',
                                    ),
                                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10)),
                                    _buildInfoTile(
                                      icon: Icons.shield_outlined,
                                      label: 'Account type',
                                      value: 'Parent',
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 20),

                              // Logout button
                              GlassCard(
                                padding: EdgeInsets.zero,
                                child: ListTile(
                                  leading: Icon(Icons.logout, color: Colors.redAccent),
                                  title: Text(
                                    'Log out',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                  onTap: () async {
                                    await StorageService().clearAll();
                                    if (context.mounted) context.go('/login');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      subtitle: Text(
        value,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
