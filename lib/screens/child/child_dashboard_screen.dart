import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/services/storage_service.dart';

class ChildDashboardScreen extends StatefulWidget {
  final dynamic child;
  const ChildDashboardScreen({super.key, this.child});

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  Map<String, dynamic>? _usageStats;
  Map<String, dynamic>? _childData;
  bool _isLoading = true;
  bool _isChildMode = false;
  // parentId stored once so all StreamBuilders can use it safely.
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _initChildMode();
  }

  Future<void> _initChildMode() async {
    final pairing = await StorageService().getChildPairing();
    _isChildMode = pairing['mode'] == 'child';
    // Store parentId for use by StreamBuilders and _loadStats.
    _parentId = pairing['parentId'];

    if (widget.child != null) {
      // Parent app opened this screen: parentId comes from Firebase Auth.
      // No need to override _parentId (null means ChildMonitorService
      // will fall back to FirebaseAuth.instance.currentUser?.uid).
      _loadStats();
      return;
    }

    // Child device: restore from SharedPreferences pairing.
    if (pairing['childId'] != null && pairing['parentId'] != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(pairing['parentId']!)
            .collection('children')
            .doc(pairing['childId']!)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _childData = {
              ...?doc.data(),
              'id': pairing['childId'],
              'parentId': pairing['parentId'],
            };
          });
          _loadStats();
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint('CHILD_MODE: Restore failed: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _loadStats() async {
    final child = _childData ?? widget.child;
    final childId = child?['id'] ?? child?['childId'] ?? '';
    if (childId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Use ChildMonitorService with explicit parentId so child devices
      // (no Firebase Auth) can read Firestore without crashing.
      final stats = await ChildMonitorService()
          .getTodayStats(childId, parentId: _parentId);
      setState(() {
        _usageStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ChildDashboardScreen: Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  String _fmtMin(dynamic v) {
    final m = (v is num ? v.toInt() : 0);
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}min';
  }

  String _timeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is String) {
      dt = DateTime.parse(timestamp);
    } else {
      return 'Unknown';
    }

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final child = _childData ?? widget.child ?? {};
    final childId = child['id'] ?? child['childId'] ?? '';
    final name = child['displayName'] ?? 'Child';

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
                        const Spacer(),
                        if (!_isChildMode)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white),
                            onPressed: () => context.push('/child/config', extra: child),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    StreamBuilder<String>(
                      stream: ChildMonitorService().watchDeviceStatus(childId, parentId: _parentId),
                      builder: (_, s) {
                        final online = (s.data ?? 'OFFLINE') == 'ONLINE';
                        final lastSync = _usageStats?['lastSync'];
                        
                        return Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(
                              color: online ? Colors.green : Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(online ? 'Online' : 'Offline', style: TextStyle(color: online ? Colors.green : Colors.red, fontSize: 13)),
                            const SizedBox(width: 12),
                            const Text('•', style: TextStyle(color: Colors.white24)),
                            const SizedBox(width: 12),
                            const Icon(Icons.sync, color: Colors.white24, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Last sync: ${_timeAgo(lastSync)}',
                              style: const TextStyle(color: AppColors.textGray400, fontSize: 13),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Screen Time
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                                  SizedBox(width: 8),
                                  Text('Screen Time Today', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Builder(builder: (context) {
                                final used = _usageStats?['totalMinutes'] ?? 0;
                                final limit = child['dailyLimitMinutes'] ?? 120;
                                final progress = (used / limit).clamp(0.0, 1.0);
                                return Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white10,
                                      valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.red : AppColors.primary),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_fmtMin(used), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        Text('of ${_fmtMin(limit)}', style: const TextStyle(color: AppColors.textGray400)),
                                      ],
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Last Location
                    StreamBuilder<Map<String, dynamic>?>(
                      stream: ChildMonitorService().watchLocation(childId, parentId: _parentId),
                      builder: (_, snap) {
                        final loc = snap.data;
                        return GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.accentTeal, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Last Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    Text(
                                      loc == null ? 'No location data' : '${loc['lat']?.toStringAsFixed(4)}, ${loc['lng']?.toStringAsFixed(4)}',
                                      style: const TextStyle(color: AppColors.textGray400, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                                onPressed: () => context.push('/map'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Quick Actions
                    const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!_isChildMode) ...[
                          Expanded(
                            child: _quickAction(
                              icon: Icons.block_flipped,
                              label: 'Block Apps',
                              color: Colors.redAccent,
                              onTap: () => context.push('/child/rules', extra: child),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else ...[
                          Expanded(
                            child: _quickAction(
                              icon: Icons.gavel_outlined,
                              label: 'Rules',
                              color: Colors.orangeAccent,
                              onTap: () => context.push('/child/rules-summary', extra: {'child': child, 'rules': null}),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _quickAction(
                            icon: Icons.bar_chart,
                            label: 'Stats',
                            color: AppColors.accentTeal,
                            onTap: () => context.push('/child/stats', extra: child),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickAction(
                            icon: Icons.notifications_active_outlined,
                            label: 'Alerts',
                            color: Colors.purpleAccent,
                            onTap: () => context.push('/child/alerts', extra: child),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recent Alerts
                    const Text('Recent Alerts', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: ChildMonitorService().watchAlerts(childId, parentId: _parentId),
                      builder: (_, snap) {
                        final alerts = snap.data?.take(3).toList() ?? [];
                        if (alerts.isEmpty) return const Text('No recent alerts', style: TextStyle(color: AppColors.textGray400));
                        return Column(
                          children: alerts.map((a) => _alertTile(a)).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertTile(Map<String, dynamic> alert) {
    final type = alert['type'] ?? 'ALERT';
    final isSos = type == 'SOS';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isSos ? Colors.red : AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isSos ? Colors.red : AppColors.primary).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isSos ? Icons.sos : Icons.notifications_outlined,
              color: isSos ? Colors.red : AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(type, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
