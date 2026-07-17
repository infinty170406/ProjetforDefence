import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../core/premium/entitlement_service.dart';
import '../../core/premium/feature_flags.dart';
import '../../core/premium/plan_permissions.dart';
import '../../features/subscription/widgets/locked_feature_sheet.dart';
import 'interactive_tutorial_overlay.dart';
import 'dart:ui';
import 'dart:async';

enum GuardianState { noChild, dataReady }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  GuardianState _currentState = GuardianState.noChild;
  bool _isLoading = true;
  bool _showTutorial = false;
  List<dynamic> _children = [];
  List<dynamic> _rawChildren = [];
  String _userName = '';
  final Map<String, int> _unreadCounts = {};
  final Map<String, StreamSubscription> _alertSubs = {};

  int get _totalUnread =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);

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
        _alertSubs[childId] =
            FirestoreService().watchAlerts(childId).listen((alerts) {
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
        if (_children.isEmpty) {
          context.go('/initial-setup');
        } else {
          final done = await StorageService().getTutorialCompleted();
          if (!done && mounted) {
            setState(() {
              _showTutorial = true;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.24),
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
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView(
                      controller: scrollController,
                      padding: EdgeInsets.all(16),
                      children: [
                        Text('Select a child to see their notifications:',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final childId = child['id'] ?? child['childId'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEEF8),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.pop(ctx);
            final raw = _rawChildren.firstWhere(
              (c) => (c['id'] ?? c['childId']) == childId,
              orElse: () => child,
            );
            context.push('/child/alerts', extra: raw);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    child['avatar']?.toString() ??
                        (child['displayName'] ?? 'C')[0],
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: child['avatar'] != null ? 20 : 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child['displayName'] ?? 'Child',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold)),
                      const Text('View notifications →',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textGray400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body = Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _fetchChildren,
                  color: AppColors.primary,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isWide ? 32 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreetingSection(),
                        const SizedBox(height: 32),
                        if (_currentState == GuardianState.noChild) ...[
                          _buildEmptyState(),
                        ] else if (isWide) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column: Children list
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFamilyOverviewHeader(),
                                    const SizedBox(height: 12),
                                    ...(_children.map(
                                        (child) => _buildChildCard(child))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              // Right column: AI orchestrator & KYC banners
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                        height:
                                            48), // aligns with overview header
                                    _buildAiOrchestratorBanner(),
                                    if (!ApiService().isKycVerified) ...[
                                      const SizedBox(height: 16),
                                      _buildKycBanner(),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildFamilyOverviewHeader(),
                          ...(_children.map((child) => _buildChildCard(child))),
                          const SizedBox(height: 16),
                          _buildAiOrchestratorBanner(),
                          if (!ApiService().isKycVerified) ...[
                            const SizedBox(height: 8),
                            _buildKycBanner(),
                          ],
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: LiquidBackground()),
          SafeArea(
            child: body,
          ),
          if (_showTutorial)
            Positioned.fill(
              child: InteractiveTutorialOverlay(
                onFinish: () async {
                  await StorageService().saveTutorialCompleted(true);
                  if (mounted) {
                    setState(() {
                      _showTutorial = false;
                    });
                  }
                },
              ),
            ),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Icon(Icons.notifications_outlined,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24),
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
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 1.5),
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
    final entitlement = context.watch<EntitlementService>();
    final plan = entitlement.currentSubscription.planEnum;

    Color planColor;
    String planLabel;
    switch (plan) {
      case SubscriptionPlan.free:
        planColor = Colors.grey;
        planLabel = 'Guardian Free';
        break;
      case SubscriptionPlan.plus:
        planColor = AppColors.primary;
        planLabel = 'Guardian Plus';
        break;
      case SubscriptionPlan.premium:
        planColor = Colors.amber.shade700;
        planLabel = 'Guardian Premium';
        break;
      case SubscriptionPlan.family:
        planColor = AppColors.accentTeal;
        planLabel = 'Guardian Family';
        break;
    }

    String greeting;
    if (_userName.isNotEmpty) {
      greeting = 'Bonjour $_userName 👋';
    } else {
      greeting = 'Bonjour 👋';
    }

    String statusText;
    if (_currentState == GuardianState.noChild) {
      statusText = 'Tout est sous contrôle aujourd\'hui.';
    } else {
      if (_children.length == 1) {
        final childName = _children.first['displayName'] ?? 'Votre enfant';
        statusText = '$childName est actuellement protégé.';
      } else {
        statusText = 'Vos enfants sont actuellement protégés.';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              greeting,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const _PulseIndicator(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          statusText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/settings/subscription'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: planColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: planColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  plan == SubscriptionPlan.free
                      ? Icons.star_border_outlined
                      : (plan == SubscriptionPlan.plus
                          ? Icons.star_half_outlined
                          : Icons.star),
                  color: planColor,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  planLabel,
                  style: TextStyle(
                    color: planColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: planColor, size: 12),
              ],
            ),
          ),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final childId = child['id'] ?? child['childId'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEEF8),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/child/details', extra: child),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    child['avatar']?.toString() ??
                        (child['displayName'] ?? 'C')[0],
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: child['avatar'] != null ? 22 : 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
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
                        stream: FirestoreService().rulesStream(childId),
                        builder: (context, rulesSnapshot) {
                          final limit =
                              (rulesSnapshot.data?['dailyLimitMinutes'] ?? 120)
                                  as num;
                          return StreamBuilder<Map<String, dynamic>>(
                            stream:
                                FirestoreService().usageStatsStream(childId),
                            builder: (context, snapshot) {
                              final used =
                                  (snapshot.data?['usedMinutes'] ?? 0) as num;
                              final remaining = (limit - used).clamp(0, 9999);
                              final isOver = used >= limit;
                              return Row(
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 13,
                                      color: isOver
                                          ? Colors.red
                                          : AppColors.textGray400),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isOver
                                          ? '${child['age'] ?? '?'} yrs · Allocation reached'
                                          : '${child['age'] ?? '?'} yrs · ${_fmtMin(remaining)} left of ${limit.toInt()}m',
                                      style: TextStyle(
                                        color: isOver
                                            ? Colors.red
                                            : AppColors.textGray400,
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
                StreamBuilder<String>(
                  stream: FirestoreService().watchDeviceStatus(childId),
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? 'OFFLINE';
                    final isOnline = status == 'ONLINE';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isOnline ? Colors.green : Colors.grey)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.textGray400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilyOverviewHeader() {
    final entitlement = context.watch<EntitlementService>();
    final isLocationEnabled =
        entitlement.isFeatureEnabled(FeatureFlags.realTimeLocation);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Family Overview',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        TextButton(
          onPressed: () {
            if (isLocationEnabled) {
              context.push('/map');
            } else {
              LockedFeatureSheet.show(
                context,
                featureName: "Localisation en temps réel",
                featureDescription:
                    "Suivez vos enfants en direct et recevez des mises à jour régulières sur leur position géographique.",
                requiredPlan: "Guardian Plus",
                benefits: const [
                  "Position GPS actualisée en permanence",
                  "Historique complet des trajets sur 30 jours",
                  "Cartographie interactive multi-enfants",
                ],
              );
            }
          },
          child: Row(
            children: [
              Text(
                isLocationEnabled ? 'View Map' : 'Unlock Map',
                style: const TextStyle(color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              Icon(
                isLocationEnabled ? Icons.chevron_right : Icons.lock_outline,
                color: AppColors.primary,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiOrchestratorBanner() {
    final entitlement = context.watch<EntitlementService>();
    final isAiEnabled = entitlement.isFeatureEnabled(FeatureFlags.aiReports);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (isAiEnabled) {
          context.push('/ai-orchestrator');
        } else {
          LockedFeatureSheet.show(
            context,
            featureName: "Rapports & Assistant IA",
            featureDescription:
                "L'Orchestrateur IA analyse en continu les activités de vos enfants pour vous fournir des rapports synthétiques et des conseils personnalisés.",
            requiredPlan: "Guardian Plus",
            benefits: const [
              "Synthèse hebdomadaire des menaces et usages",
              "Recommandations éducatives et de sécurité",
              "Interface de chat conversationnel IA avec context",
            ],
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.primary.withOpacity(0.15),
              AppColors.accentTeal.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.25),
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.04),
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
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Orchestrateur IA',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isAiEnabled) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PLUS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
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
            Icon(
              isAiEnabled ? Icons.chevron_right : Icons.lock_outline,
              color: AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.push('/onboarding/kyc'),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.20),
              AppColors.accentTeal.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.3 * (1 - _controller.value)),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }
}
