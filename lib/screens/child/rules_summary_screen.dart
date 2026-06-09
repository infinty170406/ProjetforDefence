import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/widgets/app_tile_with_details.dart';

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
];

class RulesSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> child;
  final Map<String, dynamic>? initialRules;

  const RulesSummaryScreen({
    super.key,
    required this.child,
    this.initialRules,
  });

  String get _childId => child['id'] ?? child['childId'] ?? '';
  String get _childName => child['displayName'] ?? 'Child';
  String? get _parentId => child['parentId'] as String?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: StreamBuilder<Map<String, dynamic>>(
              stream: ChildMonitorService().watchRules(_childId, parentId: _parentId),
              initialData: initialRules,
              builder: (context, snapshot) {
                final rules = snapshot.data ?? {};
                return Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        children: [
                          _buildScreenTimeCard(context, rules),
                          SizedBox(height: 16),
                          _buildScheduleCard(context, rules),
                          SizedBox(height: 16),
                          _buildSafeZonesCard(context),
                          SizedBox(height: 16),
                          _buildContentFilterCard(context, rules),
                          SizedBox(height: 16),
                          _buildBlockedAppsCard(context, rules),
                          SizedBox(height: 16),
                          _buildBlockedSitesCard(context, rules),
                          SizedBox(height: 16),
                          _buildCustomKeywordsCard(context, rules),
                          SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
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
                'Rules Summary',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                _childName,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section header helper ─────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 12),
        Text(title,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Screen Time ───────────────────────────────────────────────────────────

  Widget _buildScreenTimeCard(BuildContext context, Map<String, dynamic> rules) {
    final int limit = (rules['dailyLimitMinutes'] ?? 0) as int;
    final String timeStr = limit == 0
        ? 'No limit set'
        : (limit < 60 ? '${limit}m' : '${limit ~/ 60}h ${limit % 60 == 0 ? '' : '${limit % 60}m'}').trim();

    return GlassCard(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration:
                BoxDecoration(color: AppColors.accentTeal.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(Icons.timer_outlined, color: AppColors.accentTeal, size: 36),
          ),
          SizedBox(height: 14),
          Text('Daily Screen Time Limit',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          SizedBox(height: 6),
          Text(
            timeStr,
            style: TextStyle(
              color: limit == 0 ? AppColors.textGray400 : Theme.of(context).colorScheme.onSurface,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  Widget _buildScheduleCard(BuildContext context, Map<String, dynamic> rules) {
    final String? start = rules['allowedTimeStart'] as String?;
    final String? end = rules['allowedTimeEnd'] as String?;
    final bool isActive = start != null && end != null;

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Usage Schedule', Icons.schedule, AppColors.primary),
          SizedBox(height: 16),
          Row(
            children: [
              Icon(
                isActive ? Icons.event_available : Icons.event_busy,
                color: isActive ? Colors.tealAccent : AppColors.textGray400,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                isActive ? 'Allowed between $start and $end' : 'No schedule set (always allowed)',
                style: TextStyle(
                    color: isActive ? Theme.of(context).colorScheme.onSurface : AppColors.textGray400, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Safe Zones ────────────────────────────────────────────────────────────

  Widget _buildSafeZonesCard(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChildMonitorService().watchGeofences(_childId, parentId: _parentId),
      builder: (context, snapshot) {
        final zones = snapshot.data ?? [];
        return GlassCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(context, 'Safe Zones', Icons.location_on, AppColors.accentTeal),
              SizedBox(height: 16),
              if (zones.isEmpty)
                Text('No safe zones configured.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))
              else
                Column(
                  children: zones.map((zone) {
                    final name = zone['name'] ?? 'Unnamed Zone';
                    final radius = zone['radiusMeters'] ?? 0;
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.tealAccent, size: 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text('${radius.toInt()}m radius', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Content Filters ───────────────────────────────────────────────────────

  Widget _buildContentFilterCard(BuildContext context, Map<String, dynamic> rules) {
    final filters = <Map<String, dynamic>>[
      // Safety & Well-being
      {'label': 'Anxiety / Depression', 'icon': Icons.psychology_outlined,          'color': Colors.tealAccent,        'key': 'blockAnxietyDepression'},
      {'label': 'Self-Harm / Suicide',  'icon': Icons.healing_outlined,             'color': Colors.redAccent,         'key': 'blockSelfHarm'},
      {'label': 'Cyberbullying',         'icon': Icons.gavel_outlined,               'color': Colors.orangeAccent,      'key': 'blockCyberbullying'},
      {'label': 'Eating Disorders',      'icon': Icons.accessibility_new_outlined,   'color': Colors.pinkAccent,        'key': 'blockEatingDisorders'},
      // Restricted content
      {'label': 'Adult & Pornography',   'icon': Icons.no_adult_content,             'color': Colors.red,               'key': 'blockAdultContent'},
      {'label': 'Drugs & Alcohol',       'icon': Icons.medication_outlined,           'color': Colors.deepPurpleAccent,  'key': 'blockDrugs'},
      {'label': 'Sexual Predators',      'icon': Icons.security_outlined,             'color': Colors.indigoAccent,      'key': 'blockSexualPredators'},
      {'label': 'Violence & Gore',       'icon': Icons.warning_amber_outlined,        'color': Colors.deepOrange,        'key': 'blockViolence'},
      {'label': 'Mature Content',        'icon': Icons.explicit_outlined,             'color': Colors.blueGrey,          'key': 'blockMatureContent'},
      // Category blocks
      {'label': 'Social Media',          'icon': Icons.people_outline,                'color': AppColors.primary,        'key': 'blockSocialMedia'},
      {'label': 'Gaming',                'icon': Icons.sports_esports,                'color': Colors.redAccent,         'key': 'blockGaming'},
    ];

    final activeFilters = filters.where((f) => rules[f['key']] == true).toList();
    final List<String> categories = List<String>.from(rules['customCategories'] ?? []);

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'Content Filters', Icons.shield_outlined, Colors.orangeAccent),
          SizedBox(height: 20),
          if (activeFilters.isEmpty && categories.isEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No content filters or custom categories set.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          ...activeFilters.asMap().entries.map((entry) {
            final f = entry.value;
            final Color color = f['color'] as Color;
            return Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: _buildDetailRow(
                context,
                f['icon'] as IconData,
                f['label'] as String,
                'Blocked',
                Colors.redAccent,
                active: true,
                activeColor: color,
              ),
            );
          }),
          // Affichage intégré des custom categories
          if (categories.isNotEmpty) ...[
            if (activeFilters.isNotEmpty)
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10), height: 20),
            SizedBox(height: 10),
            Text(
              'CUSTOM CATEGORIES',
              style: TextStyle(color: AppColors.statusWarning, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.statusWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, color: AppColors.statusWarning, size: 13),
                    SizedBox(width: 6),
                    Text(cat,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Blocked Apps ──────────────────────────────────────────────────────────

  Widget _buildBlockedAppsCard(BuildContext context, Map<String, dynamic> rules) {
    final List<dynamic> blockedPackages = rules['blockedApps'] as List? ?? [];

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader(context, 'Blocked Apps', Icons.block, Colors.redAccent),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${blockedPackages.length}',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (blockedPackages.isNotEmpty) ...[
            SizedBox(height: 16),
            Column(
              children: blockedPackages.map((pkg) {
                final pkgStr = pkg.toString();
                final knownApp = _kKnownApps.cast<Map<String,dynamic>?>().firstWhere(
                  (a) => a?['pkg'] == pkgStr,
                  orElse: () => null,
                );
                final category = knownApp?['cat'] ?? 'other';
                final fallbackIcon = knownApp?['icon'] as IconData?;
                
                return AppTileWithDetails(
                  childId: _childId,
                  packageName: pkg.toString(),
                  category: category,
                  trailing: Text(
                    'Blocked',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  showProgress: false,
                  fallbackIcon: fallbackIcon,
                );
              }).toList(),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('No specific applications are blocked.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ── Blocked Websites ──────────────────────────────────────────────────────

  Widget _buildBlockedSitesCard(BuildContext context, Map<String, dynamic> rules) {
    final List<String> blockedSites =
        List<String>.from(rules['blockedWebsites'] ?? []);

    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader(context, 'Blocked Websites', Icons.language, Colors.orange),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${blockedSites.length}',
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (blockedSites.isNotEmpty) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: blockedSites.map((domain) => Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.orange, size: 12),
                    SizedBox(width: 6),
                    Text(_formatDomainName(domain),
                        style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('No specific websites are blocked.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
        ],
      ),
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

  // ── Custom Keywords ───────────────────────────────────────────────────────

  Widget _buildCustomKeywordsCard(BuildContext context, Map<String, dynamic> rules) {
    final List<String> keywords = List<String>.from(rules['customKeywords'] ?? []);


    return GlassCard(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader(context, 'Custom Monitoring', Icons.manage_search, AppColors.primary),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${keywords.length}',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Alerts will be triggered when these words are detected on the device.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12, height: 1.4),
          ),
          if (keywords.isNotEmpty) ...[
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((kw) => Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_outline, color: AppColors.primary, size: 13),
                    SizedBox(width: 6),
                    Text(kw,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )).toList(),
            ),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('No custom keywords added.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ── Detail Row ────────────────────────────────────────────────────────────

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color statusColor, {
    bool active = false,
    Color? activeColor,
  }) {
    final displayColor = active ? (activeColor ?? Colors.redAccent) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24);
    return Row(
      children: [
        Icon(icon, color: active ? displayColor : AppColors.textGray400, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? Colors.redAccent.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active
                    ? Colors.redAccent.withValues(alpha: 0.35)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: active ? Colors.redAccent : AppColors.textGray400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
