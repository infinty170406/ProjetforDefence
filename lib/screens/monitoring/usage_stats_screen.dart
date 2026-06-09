import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/app_tile_with_details.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/child_monitor_service.dart';
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

class UsageStatsScreen extends StatefulWidget {
  final dynamic child;
  const UsageStatsScreen({super.key, this.child});

  @override
  State<UsageStatsScreen> createState() =>
      _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _todayStats;
  List<Map<String, dynamic>> _weekStats = [];
  List<Map<String, dynamic>> _monthStats = [];
  List<Map<String, dynamic>> _apps = [];
  String _selectedPeriod = 'week';
  StreamSubscription<Map<String, dynamic>>? _statsSub;

  String get _childId =>
      widget.child?['id'] ?? widget.child?['childId'] ?? '';

  String get _childName =>
      widget.child?['displayName'] ?? 'Child';

  int get _dailyLimit =>
      (widget.child?['dailyLimitMinutes'] as num?)?.toInt() ?? 120;

  String? get _parentId => widget.child?['parentId'] as String?;

  @override
  void initState() {
    super.initState();
    _startListening();
    _loadStats();
  }

  void _startListening() {
    if (_childId.isEmpty) return;
    _statsSub = FirestoreService().usageStatsStream(_childId).listen((today) {
      if (mounted) {
        setState(() {
          _todayStats = today;
          final dynamic rawApps = today['apps'];
          if (rawApps is Map) {
            _apps = rawApps.entries.map((e) {
              final pkg = e.key;
              final val = e.value;
              return {
                'packageName': pkg,
                'usageMinutes': (val is Map ? val['minutes'] : val) ?? 0,
                'label': (val is Map ? val['label'] : null),
                'category': 'other'
              };
            }).toList();
          } else {
            _apps = List<Map<String, dynamic>>.from(rawApps ?? []);
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadWeekStats() async {
    if (_childId.isEmpty) return;
    try {
      final week = await ChildMonitorService().getWeekStats(_childId, parentId: _parentId);
      if (mounted) {
        setState(() {
          _weekStats = week;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMonthStats() async {
    if (_childId.isEmpty) return;
    try {
      final month = await ChildMonitorService().getMonthStats(_childId, parentId: _parentId);
      if (mounted) {
        setState(() {
          _monthStats = month;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    await Future.wait([
      _loadWeekStats(),
      _loadMonthStats(),
    ]);
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView(
                      padding: EdgeInsets.all(16),
                      children: [
                        _buildHeader(context),
                        SizedBox(height: 24),
                        _buildTodaySummary(),
                        SizedBox(height: 24),
                        _buildInteractiveStatsCard(),
                        SizedBox(height: 24),
                        _buildTopApps(),
                        SizedBox(height: 24),
                        _buildWebUsage(),
                        SizedBox(height: 40),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebUsage() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChildMonitorService().watchWebHistory(_childId, parentId: _parentId),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return GlassCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top websites today',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text(
                  'No web browsing history yet.\nHistory is recorded from the child\'s browser visits.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          );
        }

        // Group by domain to show "Top sites"
        final domainsCount = <String, int>{};
        final domainTitles = <String, String>{};
        for (var item in history) {
          final url = item['url'] as String? ?? '';
          final title = item['title'] as String? ?? '';
          final uri = Uri.tryParse(url);
          final domain = uri?.host ?? url;
          // Skip empty or invalid domains
          if (domain.isEmpty || domain == url && !url.contains('.')) continue;
          // Clean "www." prefix for display
          final cleanDomain = domain.startsWith('www.') ? domain.substring(4) : domain;
          domainsCount[cleanDomain] = (domainsCount[cleanDomain] ?? 0) + 1;
          // Prefer a real page title over a generic placeholder
          if (title.isNotEmpty && title != 'Website' && !domainTitles.containsKey(cleanDomain)) {
            domainTitles[cleanDomain] = title;
          }
        }

        if (domainsCount.isEmpty) {
          return GlassCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top websites today',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('No web history with valid URLs recorded.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          );
        }

        final sortedDomains = domainsCount.keys.toList()
          ..sort((a, b) => domainsCount[b]!.compareTo(domainsCount[a]!));
        final topDomains = sortedDomains.take(5).toList();
        final maxCount = domainsCount[topDomains.first] ?? 1;

        return GlassCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Top websites today',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Spacer(),
                  Text('${history.length} visits',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
              SizedBox(height: 16),
              ...topDomains.map((domain) {
                final count = domainsCount[domain]!;
                final title = domainTitles[domain] ?? _formatDomainName(domain);
                final ratio = count / maxCount;
                // Google favicon service — fast, reliable, no API key needed
                final faviconUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=64';

                return Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Favicon with fallback to globe icon
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                faviconUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.public,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  domain,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$count ${count == 1 ? 'visit' : 'visits'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 3,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Footer note
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textGray400, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Based on browser history from child\'s device',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Statistics',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            Text(_childName,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildTodaySummary() {
    final used = (_todayStats?['totalMinutes'] as num?)?.toInt() ?? 0;
    final limit = _dailyLimit;
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = (limit - used).clamp(0, 9999);
    final isOverLimit = used >= limit && limit > 0;

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverLimit
                      ? Colors.red.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOverLimit ? 'Allocated time reached' : '$remaining min left',
                  style: TextStyle(
                    color: isOverLimit ? Colors.red : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _buildTimeStat('Used', _formatMinutes(used), Theme.of(context).colorScheme.onSurface),
              SizedBox(width: 32),
              _buildTimeStat('Allocated', _formatMinutes(limit),
                  AppColors.textGray400),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverLimit ? Colors.red : AppColors.primary,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }

  Widget _buildInteractiveStatsCard() {
    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activité',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPeriodTab('day', 'Jour'),
                    _buildPeriodTab('week', 'Semaine'),
                    _buildPeriodTab('month', 'Mois'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _buildPeriodContent(),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String period, String label) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : AppColors.textGray400,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodContent() {
    if (_selectedPeriod == 'day') {
      final Map<String, int> catMinutes = {};
      for (var app in _apps) {
        final pkg = app['packageName'] as String? ?? '';
        final mins = (app['usageMinutes'] as num?)?.toInt() ?? 0;
        if (mins <= 0) continue;
        
        final known = _kKnownApps.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a?['pkg'] == pkg,
          orElse: () => null,
        );
        final cat = known?['cat'] ?? app['category'] as String? ?? 'other';
        final cleanCat = cat.toString().toLowerCase().trim();
        catMinutes[cleanCat] = (catMinutes[cleanCat] ?? 0) + mins;
      }

      final total = catMinutes.values.fold<int>(0, (a, b) => a + b);
      if (total <= 0) {
        return SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Aucune activité enregistrée aujourd\'hui',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
        );
      }

      final sortedCats = catMinutes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              width: double.infinity,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              child: Row(
                children: sortedCats.map((entry) {
                  final ratio = total > 0 ? entry.value / total : 0.0;
                  if (ratio <= 0) return SizedBox();
                  return Expanded(
                    flex: (ratio * 100).toInt().clamp(1, 100),
                    child: Container(
                      color: _categoryColor(entry.key),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: 20),
          ...sortedCats.map((entry) {
            final mins = entry.value;
            final ratio = total > 0 ? mins / total : 0.0;
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _categoryColor(entry.key),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _categoryColor(entry.key).withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    _formatCategoryName(entry.key),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  Spacer(),
                  Text(
                    _formatMinutes(mins),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '(${(ratio * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      );
    } else if (_selectedPeriod == 'week') {
      if (_weekStats.isEmpty) {
        return SizedBox(
          height: 120,
          child: Center(
            child: Text('Aucune donnée pour la semaine',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
        );
      }

      final maxMinutes = _weekStats
          .map((s) => (s['totalMinutes'] as num?)?.toDouble() ?? 0.0)
          .fold(0.0, (a, b) => a > b ? a : b);

      return SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _weekStats.reversed.map((s) {
            final mins = (s['totalMinutes'] as num?)?.toDouble() ?? 0.0;
            final ratio = maxMinutes > 0 ? mins / maxMinutes : 0.0;
            final date = s['date'] as String? ?? '';
            final dayLabel = date.length >= 10 ? _dayLabel(date) : '?';
            final isOverLimit = _dailyLimit > 0 && mins >= _dailyLimit;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (mins > 0)
                      Text(
                        mins.toInt().toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    SizedBox(height: 4),
                    Container(
                      height: (ratio * 85).clamp(4.0, 85.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isOverLimit
                              ? [Colors.redAccent.withValues(alpha: 0.5), Colors.redAccent]
                              : [AppColors.primary.withValues(alpha: 0.4), AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: (isOverLimit ? Colors.redAccent : AppColors.primary).withValues(alpha: 0.25),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(dayLabel,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    } else {
      // month view
      if (_monthStats.isEmpty) {
        return SizedBox(
          height: 120,
          child: Center(
            child: Text('Aucune donnée pour le mois',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
        );
      }

      final maxMinutes = _monthStats
          .map((s) => (s['totalMinutes'] as num?)?.toDouble() ?? 0.0)
          .fold(0.0, (a, b) => a > b ? a : b);

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthStats.reversed.map((s) {
                final mins = (s['totalMinutes'] as num?)?.toDouble() ?? 0.0;
                final ratio = maxMinutes > 0 ? mins / maxMinutes : 0.0;
                final date = s['date'] as String? ?? '';
                final dayNum = date.split('-').last;
                final isOverLimit = _dailyLimit > 0 && mins >= _dailyLimit;

                return Container(
                  width: 15,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (mins > 0)
                        Text(
                          mins.toInt().toString(),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      SizedBox(height: 4),
                      Container(
                        height: (ratio * 80).clamp(4.0, 80.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isOverLimit
                                ? [Colors.redAccent.withValues(alpha: 0.5), Colors.redAccent]
                                : [AppColors.primary.withValues(alpha: 0.4), AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        dayNum,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase().trim()) {
      case 'social_media':
      case 'social':
        return Colors.pinkAccent;
      case 'gaming':
      case 'game':
      case 'jeux':
        return Colors.purpleAccent;
      case 'education':
      case 'school':
      case 'educational':
        return Colors.greenAccent;
      case 'browser':
      case 'web':
      case 'internet':
        return Colors.blueAccent;
      case 'messaging':
      case 'message':
      case 'chat':
      case 'communication':
        return Colors.tealAccent;
      default:
        return AppColors.primary;
    }
  }

  String _formatCategoryName(String cat) {
    switch (cat.toLowerCase().trim()) {
      case 'social_media':
      case 'social':
        return 'Réseaux Sociaux';
      case 'gaming':
      case 'game':
      case 'jeux':
        return 'Jeux';
      case 'education':
      case 'school':
      case 'educational':
        return 'Éducation';
      case 'browser':
      case 'web':
      case 'internet':
        return 'Navigateur';
      case 'messaging':
      case 'message':
      case 'chat':
      case 'communication':
        return 'Messagerie';
      default:
        return 'Autres';
    }
  }

  Widget _buildTopApps() {
    if (_apps.isEmpty) {
      return GlassCard(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top apps today',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Center(
              child: Text('No app data yet',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }

    // Trier par usage décroissant
    final sorted = List<Map<String, dynamic>>.from(_apps)
      ..sort((a, b) => ((b['usageMinutes'] as num?) ?? 0)
          .compareTo((a['usageMinutes'] as num?) ?? 0));
    final top = sorted.take(10).toList();
    final totalUsed = top.fold<int>(
        0, (sum, a) => sum + ((a['usageMinutes'] as num?)?.toInt() ?? 0));

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top apps today',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          ...top.map((app) {
            final pkg = app['packageName'] as String? ?? '?';
            final mins = (app['usageMinutes'] as num?)?.toInt() ?? 0;
            final ratio = totalUsed > 0 ? mins / totalUsed : 0.0;
            
            final knownApp = _kKnownApps.cast<Map<String, dynamic>?>().firstWhere(
              (a) => a?['pkg'] == pkg,
              orElse: () => null,
            );

            final category = knownApp?['cat'] ?? app['category'] as String? ?? 'other';
            final fallbackIcon = knownApp?['icon'] as IconData?;

            return AppTileWithDetails(
              childId: _childId,
              packageName: pkg,
              usageMinutes: mins,
              progress: ratio,
              category: category,
              fallbackIcon: fallbackIcon,
              showProgress: true,
            );
          }),
        ],
      ),
    );
  }

  String _formatMinutes(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _dayLabel(String dateStr) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    try {
      final dt = DateTime.parse(dateStr);
      return days[dt.weekday % 7];
    } catch (_) {
      return '?';
    }
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
