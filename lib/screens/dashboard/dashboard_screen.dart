import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/firestore_service.dart';
import 'dart:ui';
import 'dart:async';

enum GuardianState { noChild, dataReady }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNavIndex = 0;
  GuardianState _currentState = GuardianState.noChild;
  bool _isLoading = true;
  List<dynamic> _children = [];
  List<dynamic> _rawChildren = [];
  String _userName = '';
  final Map<String, int> _unreadCounts = {};
  final Map<String, StreamSubscription> _alertSubs = {};

  int get _totalUnread => _unreadCounts.values.fold(0, (sum, count) => sum + count);

  String _fmtMin(dynamic minutes) {
    final min = minutes is int ? minutes : (minutes as num).toInt();
    if (min < 60) return '${min}min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h${m}m';
  }

  @override
  void initState() {
    super.initState();
    ApiService().addListener(_fetchChildren);
    _fetchChildren();
    _loadUserName();
  }

  @override
  void dispose() {
    ApiService().removeListener(_fetchChildren);
    for (var sub in _alertSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _updateAlertStreams() {
    for (var child in _children) {
      final childId = child['id'] ?? child['childId'];
      if (childId != null && !_alertSubs.containsKey(childId)) {
        _alertSubs[childId] = FirestoreService().watchAlerts(childId).listen((alerts) {
          int unread = alerts.where((a) => a['read'] == false).length;
          if (mounted) {
            setState(() {
              _unreadCounts[childId] = unread;
            });
          }
        });
      }
    }
  }

  Future<void> _loadUserName() async {
    final name = await StorageService().getUserName();
    if (mounted && name != null) {
      setState(() {
        _userName = name;
      });
    }
  }

  Future<void> _fetchChildren() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getMyChildren();
      if (mounted) {
        setState(() {
          _children = data['children'] ?? [];
          _rawChildren = List<dynamic>.from(_children);
          _currentState = _children.isEmpty
              ? GuardianState.noChild
              : GuardianState.dataReady;
          _isLoading = false;
        });
        _updateAlertStreams();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ADDED: dynamic greeting based on time of day
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, ';
    if (hour < 18) return 'Good afternoon, ';
    return 'Good evening, ';
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Close',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none,
                              color: AppColors.textGray400, size: 48),
                          SizedBox(height: 16),
                          Text('No children added yet',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: EdgeInsets.all(16),
                      children: [
                        Text('Select a child to see their notifications:',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                        SizedBox(height: 12),
                        ..._children
                            .map((child) => _buildNotifChildTile(ctx, child)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifChildTile(BuildContext ctx, dynamic child) {
    return GlassCard(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          final raw = _rawChildren.firstWhere(
            (c) =>
                (c['id'] ?? c['childId']) == (child['id'] ?? child['childId']),
            orElse: () => child,
          );
          context.push('/child/alerts', extra: raw);
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                (child['displayName'] ?? 'C')[0],
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(child['displayName'] ?? 'Child',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  Text('View notifications →',
                      style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textGray400),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (Theme.of(context).brightness == Brightness.dark)
            const Positioned.fill(child: LiquidBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : RefreshIndicator(
                          onRefresh: _fetchChildren,
                          color: AppColors.primary,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGreetingSection(),
                                SizedBox(height: 32),
                                if (_currentState == GuardianState.noChild) ...[
                                  _buildEmptyState(),
                                ] else ...[
                                  _buildFamilyOverviewHeader(),
                                  ...(_children
                                      .map((child) => _buildChildCard(child))),
                                  SizedBox(height: 16),
                                  _buildAiOrchestratorBanner(),
                                  SizedBox(height: 8),
                                  _buildKycBanner(),
                                ],
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          Positioned(
              bottom: 24, left: 0, right: 0, child: _buildFloatingNavBar()),
          Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildCenterFloatingButton()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // SAME: title block
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE GUARDIAN',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5),
              ),
              Text(
                'Dashboard',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          // SAME: notification button design, ADDED: tap opens panel
          Row(
            children: [
              // Notification button
              GestureDetector(
                onTap: _showNotificationsPanel,
                child: Stack(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(Icons.notifications_outlined,
                          color: Theme.of(context).colorScheme.onSurface, size: 24),
                    ),
                    if (_totalUnread > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                          ),
                          child: Text(
                            _totalUnread > 9 ? '9+' : '$_totalUnread',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingSection() {
    // CHANGED: dynamic greeting (morning/afternoon/evening)
    String greeting =
        _currentState == GuardianState.noChild ? 'Welcome, ' : _greeting;
    String name = _userName.isNotEmpty
        ? _userName
        : (_currentState == GuardianState.noChild ? 'The Guardian' : 'Parent');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SAME: RichText design
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: greeting,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w300),
              ),
              TextSpan(
                text: name,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          _currentState == GuardianState.noChild
              ? 'Start by adding your first child profile to begin monitoring.'
              : 'Monitoring active. Select a child to view activity.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.family_restroom_outlined,
                color: AppColors.primary, size: 40),
          ),
          SizedBox(height: 24),
          Text('No Children Added Yet',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Text(
            'Add your first child profile to start\nprotecting and monitoring their digital life.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.push('/child/create'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 8),
                Text('Add First Child')
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(dynamic child) {
    return GlassCard(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.push('/child/details', extra: child),
        child: Row(
          children: [
            // SAME: avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                (child['displayName'] ?? 'C')[0],
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child['displayName'] ?? 'Unknown',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: FirestoreService().rulesStream(child['id']),
                    builder: (context, rulesSnapshot) {
                      final limit = (rulesSnapshot.data?['dailyLimitMinutes'] ?? 120) as num;
                      return StreamBuilder<Map<String, dynamic>>(
                      stream: FirestoreService().usageStatsStream(child['id']),
                        builder: (context, snapshot) {
                          final used = (snapshot.data?['usedMinutes'] ?? 0) as num;
                          final remaining = (limit - used).clamp(0, 9999);
                          final isOver = used >= limit;
                          return Row(
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 13,
                                  color:
                                      isOver ? Colors.red : AppColors.textGray400),
                              SizedBox(width: 4),
                              Flexible(
                                  child: Text(
                                    isOver
                                        ? '${child['age'] ?? '?'} yrs · Allocation reached'
                                        : '${child['age'] ?? '?'} yrs · ${_fmtMin(remaining)} left of ${limit.toInt()}m',
                                  style: TextStyle(
                                    color:
                                        isOver ? Colors.red : AppColors.textGray400,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            // ADDED: Online/Offline badge
            StreamBuilder<String>(
              stream: FirestoreService().watchDeviceStatus(child['id'] ?? ''),
              builder: (context, snapshot) {
                final status = snapshot.data ?? 'OFFLINE';
                final isOnline = status == 'ONLINE';
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isOnline ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? Colors.greenAccent : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textGray400),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyOverviewHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Family Overview',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        TextButton(
          onPressed: () => context.push('/map'),
          child: Row(
            children: [
              Text('View Map', style: TextStyle(color: AppColors.primary)),
              Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiOrchestratorBanner() {
    return GestureDetector(
      onTap: () => context.push('/ai-orchestrator'),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.accentTeal.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Orchestrateur IA',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Analyse intelligente • Recommandations personnalisées',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildKycBanner() {
    return GestureDetector(
      onTap: () => context.push('/onboarding/kyc'),
      child: Container(
        margin: EdgeInsets.only(top: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.25),
              AppColors.accentTeal.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_outlined,
                  color: AppColors.primary, size: 22),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complete your verification',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text('Verify your identity to unlock all features',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }

  // SAME: floating navbar - no design change
  Widget _buildFloatingNavBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double navWidth = MediaQuery.of(context).size.width * 0.9;
    final double itemWidth = (navWidth - 24) / 5;

    return Center(
      child: Container(
        width: navWidth,
        height: 80,
        decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF121212).withValues(alpha: 0.7) 
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
            color: isDark 
                ? AppColors.glassBorder 
                : const Color(0xFFDDE3F5)),
        boxShadow: [
          BoxShadow(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.5) 
                  : const Color(0xFF4F46E5).withValues(alpha: 0.10),
              blurRadius: 30,
              spreadRadius: 5)
        ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutQuint,
                  left: 12 + (_selectedNavIndex * itemWidth),
                  bottom: 12,
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
                              color: AppColors.primary.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _buildNavBarItem(Icons.dashboard, 0)),
                      Expanded(child: _buildNavBarItem(Icons.map_outlined, 1)),
                      SizedBox(width: 56),
                      Expanded(
                          child:
                              _buildNavBarItem(Icons.chat_bubble_outline, 3)),
                      Expanded(
                          child: _buildNavBarItem(Icons.settings_outlined, 4)),
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

  Widget _buildNavBarItem(IconData icon, int index) {
    final bool isSelected = _selectedNavIndex == index;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedNavIndex = index;
        });
        switch (index) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            await context.push('/map');
            if (mounted) setState(() => _selectedNavIndex = 0);
            break;
          case 3:
            await context.push('/ai-hub');
            if (mounted) setState(() => _selectedNavIndex = 0);
            break;
          case 4:
            await context.push('/settings/general');
            if (mounted) setState(() => _selectedNavIndex = 0);
            break;
        }
      },
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

  Widget _buildCenterFloatingButton() {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Center(
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
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5)
              ],
            ),
            child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface, size: 28),
          ),
        ),
      ),
    );
  }
}
