import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/repositories/child_repository.dart';
import '../../core/repositories/rules_repository.dart';
import '../../core/repositories/alert_repository.dart';
import '../../core/repositories/stats_repository.dart';
import '../../core/widgets/app_tile_with_details.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';

const _kKnownApps = [
  {'pkg': 'com.facebook.katana', 'name': 'Facebook', 'cat': 'Social', 'icon': Icons.facebook},
  {'pkg': 'com.instagram.android', 'name': 'Instagram', 'cat': 'Social', 'icon': Icons.photo_camera},
  {'pkg': 'com.snapchat.android', 'name': 'Snapchat', 'cat': 'Social', 'icon': Icons.remove_red_eye},
  {'pkg': 'com.zhiliaoapp.musically', 'name': 'TikTok', 'cat': 'Social', 'icon': Icons.music_video},
  {'pkg': 'com.twitter.android', 'name': 'Twitter/X', 'cat': 'Social', 'icon': Icons.alternate_email},
  {'pkg': 'com.whatsapp', 'name': 'WhatsApp', 'cat': 'Messaging', 'icon': Icons.chat},
  {'pkg': 'com.discord', 'name': 'Discord', 'cat': 'Messaging', 'icon': Icons.headset},
  {'pkg': 'com.google.android.youtube', 'name': 'YouTube', 'cat': 'Entertainment', 'icon': Icons.play_circle},
  {'pkg': 'com.netflix.mediaclient', 'name': 'Netflix', 'cat': 'Entertainment', 'icon': Icons.live_tv},
  {'pkg': 'com.spotify.music', 'name': 'Spotify', 'cat': 'Entertainment', 'icon': Icons.music_note},
  {'pkg': 'com.roblox.client', 'name': 'Roblox', 'cat': 'Gaming', 'icon': Icons.games},
  {'pkg': 'com.mojang.minecraftpe', 'name': 'Minecraft', 'cat': 'Gaming', 'icon': Icons.grid_view},
  {'pkg': 'com.activision.callofduty.shooter', 'name': 'Call of Duty', 'cat': 'Gaming', 'icon': Icons.sports_esports},
  {'pkg': 'com.google.android.gm', 'name': 'Gmail', 'cat': 'Productivity', 'icon': Icons.email},
  {'pkg': 'com.google.android.apps.maps', 'name': 'Maps', 'cat': 'Utility', 'icon': Icons.map},
  {'pkg': 'com.android.chrome', 'name': 'Chrome', 'cat': 'Browser', 'icon': Icons.language},
  {'pkg': 'com.pinterest', 'name': 'Pinterest', 'cat': 'Social', 'icon': Icons.push_pin},
  {'pkg': 'com.facebook.lite', 'name': 'Lite', 'cat': 'Social', 'icon': Icons.facebook},
  {'pkg': 'com.duolingo', 'name': 'Duolingo', 'cat': 'Education', 'icon': Icons.language},
  {'pkg': 'com.openai.chatgpt', 'name': 'ChatGPT', 'cat': 'Productivity', 'icon': Icons.chat},
  {'pkg': 'cn.wps.moffice_eng', 'name': 'WPS Office', 'cat': 'Productivity', 'icon': Icons.description},
  {'pkg': 'com.radio.fmradio', 'name': 'Radio FM', 'cat': 'Entertainment', 'icon': Icons.radio},
  {'pkg': 'com.miui.gallery', 'name': 'Galerie', 'cat': 'Utility', 'icon': Icons.photo_library},
  {'pkg': 'com.sec.android.gallery3d', 'name': 'Galerie', 'cat': 'Utility', 'icon': Icons.photo_library},
  {'pkg': 'com.miui.securitycenter', 'name': 'Sécurité', 'cat': 'Utility', 'icon': Icons.security},
  {'pkg': 'com.miui.video', 'name': 'Mi Vidéo', 'cat': 'Entertainment', 'icon': Icons.video_library},
];

class ChildDetailsScreen extends StatefulWidget {
  final dynamic child;
  const ChildDetailsScreen({super.key, this.child});

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = false;
  DateTime? _lastSync;
  StreamSubscription<Map<String, dynamic>>? _usageSub;

  @override
  void initState() {
    super.initState();
    _startListeningUsageStats();
  }

  void _startListeningUsageStats() {
    final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
    if (childId.isEmpty) return;

    setState(() => _isLoadingUsage = true);
    
    // We listen to the live stream
    _usageSub = context.read<StatsRepository>().watchTodayStats(childId).listen(
      (stats) {
        if (mounted) {
          setState(() {
            _usageStats = stats;
            _lastSync = DateTime.now();
            _isLoadingUsage = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoadingUsage = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _usageSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsageStats() async {
    // Left for pull-to-refresh compatibility, though stream auto-updates
    final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
    if (childId.isEmpty) return;
    
    setState(() => _isLoadingUsage = true);
    try {
      final stats = await context.read<StatsRepository>().getTodayStats(childId);
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _lastSync = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _showShareDialog() async {
    final displayName = widget.child?['displayName'] ?? 'Child';
    final token = widget.child?['invitationToken'] ?? '---';
    final shareText = "Hello! To start monitoring $displayName, please install 'The Guardian Child' app and use this pairing link: https://the-guardian.app/child/pair?code=$token\n\nInvitation Code: $token";
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share installation link', 
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Invite your child to install the app via:', 
              style: TextStyle(color: AppColors.textGray300, fontSize: 14)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareOption(
                  'WhatsApp', 
                  Icons.chat_bubble_outline, 
                  const Color(0xFF25D366),
                  () async {
                    final url = "whatsapp://send?text=${Uri.encodeComponent(shareText)}";
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not installed')));
                    }
                  }
                ),
                _shareOption(
                  'SMS', 
                  Icons.sms_outlined, 
                  Colors.blueAccent,
                  () async {
                    final url = "sms:?body=${Uri.encodeComponent(shareText)}";
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    }
                  }
                ),
                _shareOption(
                  'Copy Link', 
                  Icons.copy_all, 
                  Colors.white54,
                  () {
                    Clipboard.setData(ClipboardData(text: shareText));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                    Navigator.pop(context);
                  }
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? {};
    final displayName = child['displayName'] ?? 'Child';
    final age = child['age']?.toString() ?? '?';
    final childId = child['id'] ?? child['childId'] ?? '';

    // Repositories from Provider
    final childRepo = context.read<ChildRepository>();
    final rulesRepo = context.read<RulesRepository>();
    final alertRepo = context.read<AlertRepository>();
    final statsRepo = context.read<StatsRepository>();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchUsageStats,
              color: AppColors.primary,
              backgroundColor: const Color(0xFF1A1A2E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button and actions
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        const Spacer(),
                        _buildActionButtons(child),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileHeader(displayName, age, childId, childRepo),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Monitoring'),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      children: [
                        _buildRulesSummaryCard(childId, child, rulesRepo),
                        _buildScreenTimeRemainingCard(childId, child, rulesRepo),
                        _buildAppListingCard(childId),
                        _buildAlertHistoryCard(childId, alertRepo),
                        _buildWebHistoryCard(childId, statsRepo),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Activity Overview'),
                    _buildOverviewCard(childId, childRepo, alertRepo),
                    const SizedBox(height: 40),
                    _buildConfigButtons(child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(dynamic child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
          tooltip: 'Share Link',
          onPressed: _showShareDialog,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
          tooltip: 'Edit Profile',
          onPressed: () => context.push('/child/edit', extra: child),
        ),
        IconButton(
          icon: const Icon(Icons.map_outlined, color: Colors.white70, size: 20),
          tooltip: 'View on Map',
          onPressed: () => context.push('/map', extra: child),
        ),
        IconButton(
          icon: Icon(
            _isLoadingUsage ? Icons.sync : Icons.refresh,
            color: _isLoadingUsage ? AppColors.primary : Colors.white,
            size: 20,
          ),
          tooltip: 'Refresh Stats',
          onPressed: _isLoadingUsage ? null : _fetchUsageStats,
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String displayName, String age, String childId, ChildRepository childRepo) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              displayName[0],
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 40,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          Text(displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          Text('$age years old',
              style: const TextStyle(color: AppColors.textGray300, fontSize: 16)),
          if (_lastSync != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last updated: ${_lastSync!.hour}:${_lastSync!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ),
          const SizedBox(height: 12),
          StreamBuilder<String>(
            stream: childRepo.watchDeviceStatus(childId),
            builder: (context, snapshot) {
              final status = snapshot.data ?? 'OFFLINE';
              final isOnline = status == 'ONLINE';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (isOnline ? Colors.greenAccent : Colors.grey).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: isOnline ? Colors.greenAccent : Colors.grey,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: isOnline ? Colors.greenAccent : Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(String childId, ChildRepository childRepo, AlertRepository alertRepo) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          StreamBuilder<String>(
            stream: childRepo.watchDeviceStatus(childId),
            builder: (context, snapshot) {
              final status = snapshot.data ?? 'OFFLINE';
              final isOnline = status == 'ONLINE';
              return _buildStatItem(
                'Device Status',
                status,
                Icons.sensors,
                trailingColor: isOnline ? Colors.greenAccent : Colors.white24,
              );
            },
          ),
          const Divider(color: Colors.white10),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: alertRepo.watchAlerts(childId),
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              final todayCount = alerts.where((a) {
                final ts = a['timestamp'] as Timestamp?;
                if (ts == null) return false;
                return ts.toDate().day == DateTime.now().day;
              }).length;
              return _buildStatItem(
                'Alerts Today',
                todayCount.toString(),
                Icons.notifications_none,
                trailingColor: todayCount > 0 ? Colors.orange : Colors.white24,
              );
            },
          ),
          _buildStatItem(
            'Total Usage Today',
            '${(_usageStats?['totalMinutes'] ?? 0)} min',
            Icons.timer_outlined,
            trailingColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildConfigButtons(dynamic child) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Configure Rules'),
            onPressed: () => context.push('/child/config', extra: child),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bar_chart, size: 18),
            label: const Text('Usage Statistics'),
            onPressed: () => context.push('/child/stats', extra: child),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSummaryCard(String childId, dynamic child, RulesRepository rulesRepo) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: rulesRepo.watchRules(childId).map((r) => r.toJson()),
      builder: (context, rulesSnap) {
        final rules = rulesSnap.data ?? {};
        final bool blockAdult = rules['blockAdultContent'] == true;
        
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().watchGeofences(childId),
          builder: (context, geoSnap) {
            final zones = geoSnap.data ?? [];
            
            String subtitle = 'Not configured';
            if (zones.isNotEmpty) {
              subtitle = '${zones.length} safe zone${zones.length > 1 ? 's' : ''} active';
            } else if (rules.isNotEmpty) {
              subtitle = 'Content filters active';
            }

            return _buildActionCard(
              'Rules',
              Icons.shield_outlined,
              AppColors.primary,
              () => context.push('/child/rules-summary', extra: {
                'child': child,
                'rules': rules,
              }),
              hasWarning: rules.isNotEmpty && !blockAdult,
              subtitle: subtitle,
            );
          },
        );
      },
    );
  }

  Widget _buildScreenTimeRemainingCard(String childId, dynamic child, RulesRepository rulesRepo) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: rulesRepo.watchRules(childId).map((r) => r.toJson()),
      builder: (context, rulesSnap) {
        final data = _usageStats ?? {};
        final used = (data['usedMinutes'] ?? 0) as num;
        final isLocked = data['isLocked'] == true;
        final limit = (rulesSnap.data?['dailyLimitMinutes'] ?? 120) as num;
        
        final int? remainingFromFs = data['remainingMinutes'] as int?;
        final int remaining = remainingFromFs ?? (limit - used).toInt().clamp(0, 9999);
        
        final bool lockedUI = isLocked;
        final bool limitReached = remaining <= 0 && !isLocked;

        return _buildActionCard(
          'Screen Time',
          Icons.timer_outlined,
          AppColors.accentTeal,
          () => _showScreenTimeDetail(childId, child),
          customSubtitle: _usageStats == null 
            ? const Text('Sync to update', style: TextStyle(color: Colors.white24, fontSize: 9))
            : (lockedUI 
                ? const Text('Téléphone verrouillé', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold))
                : (limitReached
                    ? const Text('Limite atteinte', style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold))
                    : Text('$remaining min left of ${limit.toInt()}m', style: const TextStyle(color: AppColors.textGray300, fontSize: 10)))),
        );
      },
    );
  }

  Widget _buildAppListingCard(String childId) {
    final rawApps = _usageStats?['apps'];
    final int appsCount = rawApps is Map ? rawApps.length : (rawApps is List ? rawApps.length : 0);
    
    return _buildActionCard(
      'App Usage',
      Icons.apps,
      const Color(0xFF9C6FFF),
      () => _showAppManager(childId),
      subtitle: _usageStats == null ? 'Sync required' : '$appsCount apps active today',
    );
  }

  Widget _buildAlertHistoryCard(String childId, AlertRepository alertRepo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: alertRepo.watchAlerts(childId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        final unread = alerts.where((a) => a['read'] != true).length;

        return _buildActionCard(
          'Alerts',
          Icons.notifications_active_outlined,
          unread > 0 ? Colors.redAccent : Colors.orange,
          () => context.push('/child/alerts', extra: widget.child),
          badgeCount: unread,
          subtitle: unread > 0 ? '$unread new alerts' : 'No new alerts',
        );
      },
    );
  }

  Widget _buildWebHistoryCard(String childId, StatsRepository statsRepo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('parents').doc(FirebaseAuth.instance.currentUser?.uid)
          .collection('children').doc(childId).collection('inventory').doc('websites').collection('history')
          .orderBy('timestamp', descending: true).limit(50).snapshots().map((s) => s.docs.map((d) => d.data()).toList()),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        return _buildActionCard(
          'Browsing History',
          Icons.language_outlined,
          AppColors.accentTeal,
          () => _showWebHistoryDetail(childId),
          subtitle: history.isEmpty ? 'No recent activity' : '${history.length} sites visited',
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? trailingColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(color: trailingColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  void _showWebHistoryDetail(String childId) {
    List<Map<String, dynamic>> allHistory = [];
    DocumentSnapshot? lastDoc;
    bool isLoading = false;
    bool hasMore = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> loadMore() async {
            if (isLoading || !hasMore) return;
            setModalState(() => isLoading = true);
            try {
              final snap = await FirestoreService().getWebHistoryPaginated(
                childId,
                startAfter: lastDoc,
              );
              final newItems = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
              setModalState(() {
                allHistory.addAll(newItems);
                lastDoc = snap.docs.isNotEmpty ? snap.docs.last : lastDoc;
                hasMore = newItems.length >= 20;
                isLoading = false;
              });
            } catch (e) {
              setModalState(() => isLoading = false);
            }
          }

          // Initial load
          if (allHistory.isEmpty && hasMore && !isLoading) {
            loadMore();
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, controller) {
              controller.addListener(() {
                if (controller.position.pixels >= controller.position.maxScrollExtent - 200) {
                  loadMore();
                }
              });

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Browsing History',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: allHistory.isEmpty && !isLoading
                        ? const Center(child: Text('No history found', style: TextStyle(color: Colors.white54)))
                        : StreamBuilder<Map<String, dynamic>>(
                            stream: FirestoreService().rulesStream(childId),
                            builder: (context, rulesSnap) {
                              final blockedSites = List<String>.from(rulesSnap.data?['blockedWebsites'] ?? []);
                              
                              return ListView.builder(
                                controller: controller,
                                itemCount: allHistory.length + (hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == allHistory.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  }
                                  final item = allHistory[index];
                                  final url = item['url'] ?? '';
                                  final rawTitle = item['title'] ?? '';
                                  final domain = Uri.tryParse(url)?.host ?? url;
                                  final title = (rawTitle.isNotEmpty && rawTitle != 'Website') ? rawTitle : _formatDomainName(domain);
                                  final isBlocked = blockedSites.contains(domain);
                                  
                                  final rawQuery = item['searchQuery'] as String?;
                                  String? displayQuery = (rawQuery != null && rawQuery.isNotEmpty) ? rawQuery : null;
                                  if (displayQuery == null) {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null) {
                                          if (domain.contains('google.com') || domain.contains('bing.com') || domain.contains('duckduckgo.com')) {
                                              displayQuery = uri.queryParameters['q'];
                                          } else if (domain.contains('yahoo.com')) {
                                              displayQuery = uri.queryParameters['p'];
                                          }
                                      }
                                  }
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: AppColors.accentTeal.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.public, color: AppColors.accentTeal, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                           Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Title: page title or formatted domain
                                                Text(
                                                  title,
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                // Line 2: always show the URL/domain
                                                Text(
                                                  domain,
                                                  style: TextStyle(
                                                    color: AppColors.textGray300,
                                                    fontSize: 11,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                // Line 3: show search query if present
                                                if (displayQuery != null && displayQuery.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.search, size: 11, color: AppColors.accentTeal),
                                                      const SizedBox(width: 3),
                                                      Expanded(
                                                        child: Text(
                                                          displayQuery,
                                                          style: TextStyle(
                                                            color: AppColors.accentTeal,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => FirestoreService().toggleWebsiteBlock(childId, domain, !isBlocked),
                                            style: TextButton.styleFrom(
                                              foregroundColor: isBlocked ? Colors.greenAccent : Colors.redAccent,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                            ),
                                            child: Text(isBlocked ? 'ALLOW' : 'BLOCK', 
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }


  Widget _buildActionCard(
      String label, IconData icon, Color color, VoidCallback onTap,
      {String? subtitle, 
       int? badgeCount, 
       Color? badgeColor,
       bool hasWarning = false,
       Widget? customSubtitle}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    if (badgeCount != null && badgeCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: badgeColor ?? Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.backgroundDark, width: 1.5),
                          ),
                          child: Text(
                            badgeCount > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ),
                if (customSubtitle != null) ...[
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 52),
                    child: ClipRect(child: customSubtitle),
                  ),
                ] else if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textGray300,
                            fontSize: 10,
                            fontWeight: FontWeight.normal),
                        textAlign: TextAlign.center,
                        maxLines: 1),
                  ),
                ],
              ],
            ),
            if (hasWarning)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.backgroundDark, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showScreenTimeDetail(String childId, dynamic childData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Screen Time Detail',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 24),
            _buildScreenTimeSection(childId, childData: childData),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Removed unused _showAlertHistoryDetail

  // Removed unused _buildAlertCounters



  Widget _buildScreenTimeSection(String childId,
      {Map<dynamic, dynamic>? childData}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('Current Status'),
            if (_isLoadingUsage) ...[
              const SizedBox(width: 12),
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        // Read dailyLimit from rules stream; usedMinutes from live usage stats
        StreamBuilder<Map<String, dynamic>>(
          stream: FirestoreService().rulesStream(childId),
          builder: (context, rulesSnapshot) {
            final dailyLimit = ((rulesSnapshot.data?['dailyLimitMinutes'] ?? 120) as num).toInt();
            final startTime = rulesSnapshot.data?['allowedTimeStart'] as String?;
            final endTime   = rulesSnapshot.data?['allowedTimeEnd'] as String?;
            final hasSchedule = startTime != null && endTime != null;

            // usedMinutes is sourced from the live stats subscription (_usageStats)
            final data = _usageStats ?? {};
            final usedMinutes = (data['usedMinutes'] ?? data['totalMinutes'] ?? 0) as num;
            final progress = (usedMinutes / (dailyLimit == 0 ? 1 : dailyLimit)).clamp(0.0, 1.0);
            final remaining = (dailyLimit - usedMinutes.toInt()).clamp(0, 99999);
            final isOver = dailyLimit > 0 && usedMinutes >= dailyLimit;

            return GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Used: ${_fmtMin(usedMinutes.toInt())}',
                              style: const TextStyle(color: Colors.white, fontSize: 15)),
                          Text('Limit: ${_fmtMin(dailyLimit)}',
                              style: const TextStyle(color: AppColors.textGray300, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isOver ? Colors.red : AppColors.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOver ? 'Limit reached' : '${_fmtMin(remaining)} left',
                          style: TextStyle(
                            color: isOver ? Colors.redAccent : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? Colors.red : AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: AppColors.textGray300, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dailyLimit == 0
                              ? 'No daily limit set'
                              : 'Daily limit: ${_fmtMin(dailyLimit)}',
                          style: const TextStyle(color: AppColors.textGray300),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showLimitPicker(childId, dailyLimit),
                        child: const Text('Edit',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          color: AppColors.textGray300, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasSchedule
                              ? 'Schedule: $startTime – $endTime'
                              : 'No time schedule set',
                          style: const TextStyle(color: AppColors.textGray300),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/child/config', extra: childData),
                        child: const Text('Edit',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Formats minutes to a readable string, e.g. 90 → "1h30", 45 → "45m"
  String _fmtMin(int mins) {
    if (mins <= 0) return '0m';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  void _showLimitPicker(String childId, int currentLimit) {
    int selectedLimit = currentLimit;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set Daily Limit',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              Text('$selectedLimit minutes',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              Slider(
                value: selectedLimit.toDouble(),
                min: 0,
                max: 480,
                divisions: 32,
                activeColor: AppColors.primary,
                inactiveColor: Colors.white10,
                onChanged: (val) =>
                    setModalState(() => selectedLimit = val.toInt()),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white),
                          child: const Text('Cancel'))),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirestoreService()
                            .updateDailyLimit(childId, selectedLimit);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        if (mounted) {
                          _fetchUsageStats(); // Re-fetch to update local cache
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppManager(String childId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      useSafeArea: true,
      builder: (context) => _AppManagerWidget(childId: childId),
    );
  }

  String _formatDomainName(String domain) {
    final knownSites = [
      {'domain': 'reddit.com', 'name': 'Reddit'},
      {'domain': 'twitch.tv', 'name': 'Twitch'},
      {'domain': 'pornhub.com', 'name': 'Pornhub'},
      {'domain': '4chan.org', 'name': '4chan'},
      {'domain': 'gambling.com', 'name': 'Gambling'},
      {'domain': 'onlyfans.com', 'name': 'OnlyFans'},
      {'domain': 'twitter.com', 'name': 'Twitter/X'},
      {'domain': 'tiktok.com', 'name': 'TikTok'},
      {'domain': 'discord.com', 'name': 'Discord'},
      {'domain': 'roblox.com', 'name': 'Roblox'},
      {'domain': 'youtube.com', 'name': 'YouTube'},
      {'domain': 'instagram.com', 'name': 'Instagram'},
      {'domain': 'facebook.com', 'name': 'Facebook'},
      {'domain': 'google.com', 'name': 'Google'},
    ];
    
    for (var site in knownSites) {
      if (domain.contains(site['domain']!)) {
        return site['name']!;
      }
    }
    
    String cleanDomain = domain.replaceFirst(RegExp(r'^www\.'), '');
    List<String> parts = cleanDomain.split('.');
    if (parts.isNotEmpty) {
        String name = parts.first;
        if (name.length > 1) {
            return name[0].toUpperCase() + name.substring(1);
        }
        return name;
    }
    return domain;
  }
}

class _AppManagerWidget extends StatefulWidget {
  final String childId;
  const _AppManagerWidget({required this.childId});

  @override
  State<_AppManagerWidget> createState() => _AppManagerWidgetState();
}

class _AppManagerWidgetState extends State<_AppManagerWidget> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Manage Applications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search applications...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: FirestoreService().usageStatsStream(widget.childId),
                builder: (context, usageSnap) {
                  final rawUsage = usageSnap.data?['apps'];
                  final usageData = rawUsage is Map ? rawUsage : {};
                  
                  return StreamBuilder<List<String>>(
                    stream: FirestoreService().appInventoryStream(widget.childId),
                    builder: (context, invSnap) {
                      return StreamBuilder<List<String>>(
                        stream:
                            FirestoreService().blockedAppsStream(widget.childId),
                        builder: (context, blockSnap) {
                          final inventory = invSnap.data ?? [];
                          final blocked = blockSnap.data ?? [];
                          
                          final sortedInventory = List<String>.from(inventory)..sort((a, b) {
                            final usageA = usageData[a];
                            final usageB = usageData[b];
                            // Fallback to 'minutes' if 'totalMinutes' is missing
                            final minsA = (usageA is Map ? (usageA['totalMinutes'] ?? usageA['minutes'] ?? 0) : 0) as num;
                            final minsB = (usageB is Map ? (usageB['totalMinutes'] ?? usageB['minutes'] ?? 0) : 0) as num;
                            return minsB.compareTo(minsA);
                          });

                          final filteredApps = sortedInventory
                              .where(
                                  (pkg) => pkg.toLowerCase().contains(_searchQuery))
                              .toList();

                          if (inventory.isEmpty &&
                              invSnap.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary));
                          }
                          if (inventory.isEmpty) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps_outage,
                                      color: AppColors.textGray300, size: 48),
                                  SizedBox(height: 16),
                                  Text('No apps reported by device yet',
                                      style:
                                          TextStyle(color: AppColors.textGray300)),
                                  Text('Make sure the child app is running',
                                      style: TextStyle(
                                          color: AppColors.textGray300,
                                          fontSize: 12)),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: filteredApps.length,
                            itemBuilder: (context, index) {
                              final pkg = filteredApps[index];
                              final isBlocked = blocked.contains(pkg);
                              
                              final knownApp = _kKnownApps.cast<Map<String, dynamic>?>().firstWhere(
                                (a) => a?['pkg'] == pkg,
                                orElse: () => null,
                              );
                              final String category = knownApp?['cat'] ?? 'other';
                              final IconData? fallbackIcon = knownApp?['icon'] as IconData?;

                              return AppTileWithDetails(
                                childId: widget.childId,
                                packageName: pkg,
                                category: category,
                                showProgress: false,
                                fallbackIcon: fallbackIcon,
                                trailing: Switch(
                                  value: isBlocked,
                                  thumbColor: WidgetStateProperty.resolveWith<Color?>(
                                    (states) => states.contains(WidgetState.selected) ? Colors.redAccent : null,
                                  ),
                                  activeTrackColor: Colors.redAccent.withValues(alpha: 0.3),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Colors.white10,
                                  onChanged: (val) {
                                    final newList = List<String>.from(blocked);
                                    if (val) {
                                      newList.add(pkg);
                                    } else {
                                      newList.remove(pkg);
                                    }
                                    FirestoreService().updateBlockedApps(
                                        widget.childId, newList);
                                  },
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
