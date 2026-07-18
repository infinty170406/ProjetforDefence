import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/pairing_link_service.dart';
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
import '../../core/services/child_monitor_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/premium/entitlement_service.dart';
import '../../core/premium/plan_permissions.dart';

const _kKnownApps = [
  {
    'pkg': 'com.facebook.katana',
    'name': 'Facebook',
    'cat': 'Social',
    'icon': Icons.facebook
  },
  {
    'pkg': 'com.instagram.android',
    'name': 'Instagram',
    'cat': 'Social',
    'icon': Icons.photo_camera
  },
  {
    'pkg': 'com.snapchat.android',
    'name': 'Snapchat',
    'cat': 'Social',
    'icon': Icons.remove_red_eye
  },
  {
    'pkg': 'com.zhiliaoapp.musically',
    'name': 'TikTok',
    'cat': 'Social',
    'icon': Icons.music_video
  },
  {
    'pkg': 'com.twitter.android',
    'name': 'Twitter/X',
    'cat': 'Social',
    'icon': Icons.alternate_email
  },
  {
    'pkg': 'com.whatsapp',
    'name': 'WhatsApp',
    'cat': 'Messaging',
    'icon': Icons.chat
  },
  {
    'pkg': 'com.discord',
    'name': 'Discord',
    'cat': 'Messaging',
    'icon': Icons.headset
  },
  {
    'pkg': 'com.google.android.youtube',
    'name': 'YouTube',
    'cat': 'Entertainment',
    'icon': Icons.play_circle
  },
  {
    'pkg': 'com.netflix.mediaclient',
    'name': 'Netflix',
    'cat': 'Entertainment',
    'icon': Icons.live_tv
  },
  {
    'pkg': 'com.spotify.music',
    'name': 'Spotify',
    'cat': 'Entertainment',
    'icon': Icons.music_note
  },
  {
    'pkg': 'com.roblox.client',
    'name': 'Roblox',
    'cat': 'Gaming',
    'icon': Icons.games
  },
  {
    'pkg': 'com.mojang.minecraftpe',
    'name': 'Minecraft',
    'cat': 'Gaming',
    'icon': Icons.grid_view
  },
  {
    'pkg': 'com.activision.callofduty.shooter',
    'name': 'Call of Duty',
    'cat': 'Gaming',
    'icon': Icons.sports_esports
  },
  {
    'pkg': 'com.google.android.gm',
    'name': 'Gmail',
    'cat': 'Productivity',
    'icon': Icons.email
  },
  {
    'pkg': 'com.google.android.apps.maps',
    'name': 'Maps',
    'cat': 'Utility',
    'icon': Icons.map
  },
  {
    'pkg': 'com.android.chrome',
    'name': 'Chrome',
    'cat': 'Browser',
    'icon': Icons.language
  },
  {
    'pkg': 'com.pinterest',
    'name': 'Pinterest',
    'cat': 'Social',
    'icon': Icons.push_pin
  },
  {
    'pkg': 'com.facebook.lite',
    'name': 'Lite',
    'cat': 'Social',
    'icon': Icons.facebook
  },
  {
    'pkg': 'com.duolingo',
    'name': 'Duolingo',
    'cat': 'Education',
    'icon': Icons.language
  },
  {
    'pkg': 'com.openai.chatgpt',
    'name': 'ChatGPT',
    'cat': 'Productivity',
    'icon': Icons.chat
  },
  {
    'pkg': 'cn.wps.moffice_eng',
    'name': 'WPS Office',
    'cat': 'Productivity',
    'icon': Icons.description
  },
  {
    'pkg': 'com.radio.fmradio',
    'name': 'Radio FM',
    'cat': 'Entertainment',
    'icon': Icons.radio
  },
  {
    'pkg': 'com.miui.gallery',
    'name': 'Galerie',
    'cat': 'Utility',
    'icon': Icons.photo_library
  },
  {
    'pkg': 'com.sec.android.gallery3d',
    'name': 'Galerie',
    'cat': 'Utility',
    'icon': Icons.photo_library
  },
  {
    'pkg': 'com.miui.securitycenter',
    'name': 'Sécurité',
    'cat': 'Utility',
    'icon': Icons.security
  },
  {
    'pkg': 'com.miui.video',
    'name': 'Mi Vidéo',
    'cat': 'Entertainment',
    'icon': Icons.video_library
  },
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

  int _getDaysSinceSignup() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 1;
    final signupTime = user.metadata.creationTime ?? DateTime.now();
    final diff = DateTime.now().difference(signupTime).inDays;
    return (diff + 1).clamp(1, 99);
  }

  bool _isFeatureUnlockedByDay(String featureKey) {
    final activePlan = context.read<EntitlementService>().activePlan;
    if (activePlan != SubscriptionPlan.free) {
      return true;
    }

    final day = _getDaysSinceSignup();
    switch (featureKey) {
      case 'location':
        return day >= 1;
      case 'alerts':
        return day >= 2;
      case 'geofencing':
        return day >= 3;
      case 'appControl':
        return day >= 4;
      case 'aiReports':
        return day >= 5;
      default:
        return true;
    }
  }

  String _getFeatureUnlockDayText(String featureKey) {
    switch (featureKey) {
      case 'location':
        return 'Jour 1';
      case 'alerts':
        return 'Jour 2';
      case 'geofencing':
        return 'Jour 3';
      case 'appControl':
        return 'Jour 4';
      case 'aiReports':
        return 'Jour 5';
      default:
        return '';
    }
  }

  void _showUpsellLockSheet(String featureKey, String title) {
    final dayText = _getFeatureUnlockDayText(featureKey);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const CircleAvatar(
              radius: 36,
              backgroundColor: Colors.amberAccent,
              child: Icon(Icons.workspace_premium,
                  color: Colors.black87, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Débloquez $title immédiatement !',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Cette fonctionnalité fait partie de notre programme de découverte progressive et se débloquera au $dayText.\n\nPassez à une offre Premium pour lever TOUTES les limites et superviser votre famille sans attente !',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/premium-showcase');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Découvrir les offres Premium',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Patienter', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextualGuideIfNeeded(String featureKey, String title,
      String description, IconData icon, VoidCallback onConfirm) async {
    final seen = await StorageService().getFeatureTutorialSeen(featureKey);
    if (seen) {
      onConfirm();
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Icon(icon, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await StorageService()
                      .saveFeatureTutorialSeen(featureKey, true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Compris, c\'est parti !',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

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
      final stats =
          await context.read<StatsRepository>().getTodayStats(childId);
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _lastSync = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _handleDeleteProfile(dynamic child) async {
    final childId = child?['childId'] ?? child?['id'];
    if (childId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete profile',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
            'Do you really want to delete this child profile? This action is irreversible.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteChild(childId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile deleted')),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.statusDanger),
        );
      }
    }
  }

  Future<void> _showShareDialog() async {
    final displayName = widget.child?['displayName'] ?? 'Child';
    final childId = widget.child?['id']?.toString() ??
        widget.child?['childId']?.toString();

    if (childId == null || childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enfant introuvable.')),
      );
      return;
    }

    String token;
    try {
      // Un lien affiché dans une ancienne fiche peut être expiré. Le partage
      // crée donc toujours un jeton neuf valable 48 heures.
      final invitation =
          await FirestoreService().regeneratePairingInvitation(childId);
      final generatedToken = PairingLinkService.extractToken(
        invitation['invitationToken']?.toString(),
      );
      if (generatedToken == null) {
        throw StateError('Jeton généré invalide.');
      }
      token = generatedToken;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de générer le lien : $error'),
          backgroundColor: AppColors.statusDanger,
        ),
      );
      return;
    }

    if (!mounted) return;
    final pairingLink = PairingLinkService.buildPairingLink(token);
    final shareText =
        "Hello! To start monitoring $displayName, please install 'The Guardian Child' app and use this pairing link: $pairingLink\n\nInvitation Code: $token";

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share installation link',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Invite your child to install the app via:',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16)),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareOption('WhatsApp', Icons.chat_bubble_outline,
                    const Color(0xFF25D366), () async {
                  final url =
                      "whatsapp://send?text=${Uri.encodeComponent(shareText)}";
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('WhatsApp not installed')));
                  }
                }),
                _shareOption('SMS', Icons.sms_outlined, Colors.blueAccent,
                    () async {
                  final url = "sms:?body=${Uri.encodeComponent(shareText)}";
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                }),
                _shareOption(
                    'Copy Link',
                    Icons.copy_all,
                    Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54), () {
                  Clipboard.setData(ClipboardData(text: shareText));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copied to clipboard')));
                  Navigator.pop(context);
                }),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _shareOption(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12)),
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

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchUsageStats,
              color: AppColors.primary,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isWide ? 1200 : 900),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 32 : 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top bar ───────────────────────────────────────
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    size: 20),
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/dashboard');
                                  }
                                },
                              ),
                              const Spacer(),
                              _buildActionButtons(child),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ── Profile hero ──────────────────────────────────
                          _buildProfileHeader(
                              displayName, age, childId, childRepo),
                          const SizedBox(height: 36),

                          if (isWide) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Monitoring grid
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('Monitoring'),
                                      const SizedBox(height: 12),
                                      LayoutBuilder(
                                          builder: (context, constraints) {
                                        final cols =
                                            constraints.maxWidth > 560 ? 3 : 2;
                                        final ratio = constraints.maxWidth > 560
                                            ? 1.1
                                            : 0.85;
                                        return GridView.count(
                                          crossAxisCount: cols,
                                          crossAxisSpacing: 14,
                                          mainAxisSpacing: 14,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          childAspectRatio: ratio,
                                          children: [
                                            _buildRulesSummaryCard(
                                                childId, child, rulesRepo),
                                            _buildScreenTimeRemainingCard(
                                                childId, child, rulesRepo),
                                            _buildAppListingCard(childId),
                                            _buildAlertHistoryCard(
                                                childId, alertRepo),
                                            _buildWebHistoryCard(
                                                childId, statsRepo),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Right Column: Overview + config buttons
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('Activity Overview'),
                                      const SizedBox(height: 12),
                                      _buildOverviewCard(
                                          childId, childRepo, alertRepo),
                                      const SizedBox(height: 28),
                                      _buildConfigButtons(child),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // ── Monitoring cards ──────────────────────────────
                            _buildSectionTitle('Monitoring'),
                            const SizedBox(height: 4),
                            LayoutBuilder(builder: (context, constraints) {
                              final cols = constraints.maxWidth > 560 ? 3 : 2;
                              final ratio =
                                  constraints.maxWidth > 560 ? 1.1 : 0.85;
                              return GridView.count(
                                crossAxisCount: cols,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: ratio,
                                children: [
                                  _buildRulesSummaryCard(
                                      childId, child, rulesRepo),
                                  _buildScreenTimeRemainingCard(
                                      childId, child, rulesRepo),
                                  _buildAppListingCard(childId),
                                  _buildAlertHistoryCard(childId, alertRepo),
                                  _buildWebHistoryCard(childId, statsRepo),
                                ],
                              );
                            }),
                            const SizedBox(height: 32),

                            // ── Activity overview ─────────────────────────────
                            _buildSectionTitle('Activity Overview'),
                            const SizedBox(height: 4),
                            _buildOverviewCard(childId, childRepo, alertRepo),
                            const SizedBox(height: 28),

                            // ── Action buttons ────────────────────────────────
                            _buildConfigButtons(child),
                          ],
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
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
          icon: Icon(Icons.share_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.70),
              size: 20),
          tooltip: 'Share Link',
          onPressed: _showShareDialog,
        ),
        IconButton(
          icon: Icon(Icons.edit_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.70),
              size: 20),
          tooltip: 'Edit Profile',
          onPressed: () => context.push('/child/edit', extra: child),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.redAccent, size: 20),
          tooltip: 'Delete Profile',
          onPressed: () => _handleDeleteProfile(child),
        ),
        IconButton(
          icon: Icon(Icons.map_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.70),
              size: 20),
          tooltip: 'View on Map',
          onPressed: () => context.push('/map', extra: child),
        ),
        IconButton(
          icon: Icon(
            _isLoadingUsage ? Icons.sync : Icons.refresh,
            color: _isLoadingUsage
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
          tooltip: 'Refresh Stats',
          onPressed: _isLoadingUsage ? null : _fetchUsageStats,
        ),
      ],
    );
  }

  Widget _buildProfileHeader(String displayName, String age, String childId,
      ChildRepository childRepo) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final usedMinutes = (_usageStats?['usedMinutes'] ??
        _usageStats?['totalMinutes'] ??
        0) as num;
    final rawApps = _usageStats?['apps'];
    final appsCount = rawApps is Map
        ? rawApps.length
        : (rawApps is List ? rawApps.length : 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withValues(alpha: isLight ? 0.15 : 0.25),
            const Color(0xFF8B5CF6).withValues(alpha: isLight ? 0.10 : 0.20),
            const Color(0xFFEC4899).withValues(alpha: isLight ? 0.05 : 0.10),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: isLight ? 0.6 : 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF6366F1).withValues(alpha: isLight ? 0.1 : 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative glowing orbs
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899)
                        .withValues(alpha: isLight ? 0.2 : 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 50,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6)
                        .withValues(alpha: isLight ? 0.2 : 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with ring
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor:
                          isLight ? Colors.white : const Color(0xFF0F172A),
                      child: Text(
                        widget.child?['avatar']?.toString() ??
                            (displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?'),
                        style: TextStyle(
                          color: const Color(0xFF6366F1),
                          fontSize: widget.child?['avatar'] != null ? 38 : 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Info block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$age years old',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Status Badge
                            StreamBuilder<String>(
                              stream: childRepo.watchDeviceStatus(childId),
                              builder: (context, snapshot) {
                                final status = snapshot.data ?? 'OFFLINE';
                                final isOnline = status == 'ONLINE';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isOnline
                                            ? const Color(0xFF22C55E)
                                            : Colors.grey)
                                        .withValues(
                                            alpha: isLight ? 0.15 : 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (isOnline
                                              ? const Color(0xFF22C55E)
                                              : Colors.grey)
                                          .withValues(alpha: 0.40),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOnline
                                              ? const Color(0xFF4ADE80)
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                          boxShadow: isOnline
                                              ? [
                                                  const BoxShadow(
                                                      color: Color(0xFF4ADE80),
                                                      blurRadius: 4)
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOnline ? 'ON' : 'OFF',
                                        style: TextStyle(
                                          color: isOnline
                                              ? (isLight
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF4ADE80))
                                              : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (_lastSync != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.sync,
                                  size: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6)),
                              const SizedBox(width: 4),
                              Text(
                                'Synced at ${_lastSync!.hour}:${_lastSync!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Quick Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildQuickStat(
                      icon: Icons.timer_outlined,
                      label: 'Screen time',
                      value:
                          usedMinutes > 0 ? '${usedMinutes.toInt()} min' : '—',
                      color: const Color(0xFF6366F1),
                      isLight: isLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStat(
                      icon: Icons.apps_rounded,
                      label: 'Apps active',
                      value: _usageStats == null ? '—' : '$appsCount',
                      color: const Color(0xFF8B5CF6),
                      isLight: isLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream:
                        context.read<AlertRepository>().watchAlerts(childId),
                    builder: (context, snapshot) {
                      final unread = (snapshot.data ?? [])
                          .where((a) => a['read'] != true)
                          .length;
                      return Expanded(
                        child: _buildQuickStat(
                          icon: Icons.notifications_active_outlined,
                          label: 'Alerts',
                          value: unread == 0 ? 'None' : '$unread',
                          color: unread > 0
                              ? const Color(0xFFEC4899)
                              : const Color(0xFF14B8A6),
                          isLight: isLight,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isLight,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: isLight ? 0.6 : 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
      String childId, ChildRepository childRepo, AlertRepository alertRepo) {
    return GlassCard(
      padding: EdgeInsets.all(20),
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
                trailingColor: isOnline
                    ? Colors.greenAccent
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.24),
              );
            },
          ),
          Divider(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.10)),
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
                trailingColor: todayCount > 0
                    ? Colors.orange
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.24),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
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
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSummaryCard(
      String childId, dynamic child, RulesRepository rulesRepo) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: rulesRepo.watchRules(childId).map((r) => r.toJson()),
      builder: (context, rulesSnap) {
        final rules = rulesSnap.data ?? {};
        final bool blockAdult = rules['blockAdultContent'] == true;
        final bool isConfigured = rules['rulesConfigured'] == true;

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService().watchGeofences(childId),
          builder: (context, geoSnap) {
            final zones = geoSnap.data ?? [];

            String? subtitle;
            if (zones.isNotEmpty) {
              subtitle =
                  '${zones.length} safe zone${zones.length > 1 ? 's' : ''} active';
            } else if (rules.isNotEmpty && isConfigured) {
              subtitle = 'Content filters active';
            }

            return _buildActionCard(
              'Rules',
              Icons.shield_outlined,
              AppColors.primary,
              () => _showContextualGuideIfNeeded(
                'geofencing',
                'Zones de sécurité & Filtres',
                'Définissez des zones géographiques de sécurité (maison, école) et configurez les filtres de contenu Web pour votre enfant.',
                Icons.shield_outlined,
                () => context.push('/child/rules-summary', extra: {
                  'child': child,
                  'rules': rules,
                }),
              ),
              hasWarning: rules.isNotEmpty && isConfigured && !blockAdult,
              subtitle: subtitle,
              featureKey: 'geofencing',
            );
          },
        );
      },
    );
  }

  Widget _buildScreenTimeRemainingCard(
      String childId, dynamic child, RulesRepository rulesRepo) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: rulesRepo.watchRules(childId).map((r) => r.toJson()),
      builder: (context, rulesSnap) {
        final data = _usageStats ?? {};
        final used = (data['usedMinutes'] ?? 0) as num;
        final isLocked = data['isLocked'] == true;
        final limit = (rulesSnap.data?['dailyLimitMinutes'] ?? 120) as num;

        final int? remainingFromFs = data['remainingMinutes'] as int?;
        final int remaining =
            remainingFromFs ?? (limit - used).toInt().clamp(0, 9999);

        final bool lockedUI = isLocked;
        final bool limitReached = remaining <= 0 && !isLocked;

        return _buildActionCard(
          'Screen Time',
          Icons.timer_outlined,
          AppColors.accentTeal,
          () => _showContextualGuideIfNeeded(
            'appControl',
            'Temps d\'écran & Limites',
            'Configurez le temps d\'écran quotidien accordé à votre enfant pour l\'aider à garder un équilibre sain.',
            Icons.timer_outlined,
            () => _showScreenTimeDetail(childId, child),
          ),
          customSubtitle: _usageStats == null
              ? Text('Sync to update',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
                      fontSize: 9))
              : (lockedUI
                  ? Text('Téléphone verrouillé',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold))
                  : (limitReached
                      ? Text('Limite atteinte',
                          style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold))
                      : Text('$remaining min left of ${limit.toInt()}m',
                          style: TextStyle(
                              color: AppColors.textGray300, fontSize: 10)))),
          featureKey: 'appControl',
        );
      },
    );
  }

  Widget _buildAppListingCard(String childId) {
    final rawApps = _usageStats?['apps'];
    final int appsCount = rawApps is Map
        ? rawApps.length
        : (rawApps is List ? rawApps.length : 0);

    return _buildActionCard(
      'App Usage',
      Icons.apps,
      const Color(0xFF9C6FFF),
      () => _showContextualGuideIfNeeded(
        'appControl',
        'Contrôle des Applications',
        'Visualisez les applications installées sur le téléphone de votre enfant et bloquez instantanément les applications inappropriées.',
        Icons.apps,
        () => _showAppManager(childId),
      ),
      subtitle: _usageStats == null
          ? 'Sync required'
          : '$appsCount apps active today',
      featureKey: 'appControl',
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
          () => _showContextualGuideIfNeeded(
            'alerts',
            'Système d\'Alertes de Sécurité',
            'Recevez des alertes instantanées pour les événements critiques tels que le cyberharcèlement, les tentatives de contournement et les SOS.',
            Icons.notifications_active_outlined,
            () => context.push('/child/alerts', extra: widget.child),
          ),
          badgeCount: unread,
          subtitle: unread > 0 ? '$unread new alerts' : 'No new alerts',
          featureKey: 'alerts',
        );
      },
    );
  }

  Widget _buildWebHistoryCard(String childId, StatsRepository statsRepo) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChildMonitorService().watchWebHistory(childId),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        return _buildActionCard(
          'Browsing History',
          Icons.language_outlined,
          AppColors.accentTeal,
          () => _showContextualGuideIfNeeded(
            'aiReports',
            'Historique de Navigation & IA',
            'Suivez les recherches de votre enfant. Notre intelligence artificielle Gemini analyse le contenu web pour détecter les dérives.',
            Icons.language_outlined,
            () => _showWebHistoryDetail(childId),
          ),
          subtitle: history.isEmpty
              ? 'No recent activity'
              : '${history.length} sites visited',
          featureKey: 'aiReports',
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      {Color? trailingColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.60),
              size: 20),
          SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.70),
                  fontSize: 14)),
          Spacer(),
          Text(value,
              style: TextStyle(
                  color:
                      trailingColor ?? Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  void _showWebHistoryDetail(String childId) {
    List<Map<String, dynamic>> allHistory = [];
    DocumentSnapshot? lastDoc;
    bool isLoading = false;
    bool hasMore = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              final newItems =
                  snap.docs.map((d) => {'id': d.id, ...d.data()}).where((item) {
                final url = item['url'] as String? ?? '';
                return !url.startsWith('browser://');
              }).toList();
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
                if (controller.position.pixels >=
                    controller.position.maxScrollExtent - 200) {
                  loadMore();
                }
              });

              return Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Browsing History',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        IconButton(
                            icon: Icon(Icons.close,
                                color: Theme.of(context).colorScheme.onSurface),
                            onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    SizedBox(height: 16),
                    Expanded(
                      child: allHistory.isEmpty && !isLoading
                          ? Center(
                              child: Text('No history found',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.54))))
                          : StreamBuilder<Map<String, dynamic>>(
                              stream: FirestoreService().rulesStream(childId),
                              builder: (context, rulesSnap) {
                                final blockedSites = List<String>.from(
                                    rulesSnap.data?['blockedWebsites'] ?? []);

                                return ListView.builder(
                                  controller: controller,
                                  itemCount:
                                      allHistory.length + (hasMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == allHistory.length) {
                                      return Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 20),
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                      );
                                    }
                                    final item = allHistory[index];
                                    final url = item['url'] ?? '';
                                    final rawTitle = item['title'] ?? '';
                                    final domain =
                                        Uri.tryParse(url)?.host ?? url;
                                    final title = (rawTitle.isNotEmpty &&
                                            rawTitle != 'Website')
                                        ? rawTitle
                                        : _formatDomainName(domain);
                                    final isBlocked =
                                        blockedSites.contains(domain);

                                    final rawQuery =
                                        item['searchQuery'] as String?;
                                    String? displayQuery = (rawQuery != null &&
                                            rawQuery.isNotEmpty)
                                        ? rawQuery
                                        : null;
                                    if (displayQuery == null) {
                                      final uri = Uri.tryParse(url);
                                      if (uri != null) {
                                        if (domain.contains('google.com') ||
                                            domain.contains('bing.com') ||
                                            domain.contains('duckduckgo.com')) {
                                          displayQuery =
                                              uri.queryParameters['q'];
                                        } else if (domain
                                            .contains('yahoo.com')) {
                                          displayQuery =
                                              uri.queryParameters['p'];
                                        }
                                      }
                                    }

                                    return Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: GlassCard(
                                        padding: EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: AppColors.accentTeal
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(Icons.public,
                                                  color: AppColors.accentTeal,
                                                  size: 24),
                                            ),
                                            SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Title: page title or formatted domain
                                                  Text(
                                                    title,
                                                    style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2),
                                                  // Line 2: always show the URL/domain
                                                  Text(
                                                    domain,
                                                    style: TextStyle(
                                                      color:
                                                          AppColors.textGray300,
                                                      fontSize: 11,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  // Line 3: show search query if present
                                                  if (displayQuery != null &&
                                                      displayQuery
                                                          .isNotEmpty) ...[
                                                    SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.search,
                                                            size: 11,
                                                            color: AppColors
                                                                .accentTeal),
                                                        SizedBox(width: 3),
                                                        Expanded(
                                                          child: Text(
                                                            displayQuery,
                                                            style: TextStyle(
                                                              color: AppColors
                                                                  .accentTeal,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  FirestoreService()
                                                      .toggleWebsiteBlock(
                                                          childId,
                                                          domain,
                                                          !isBlocked),
                                              style: TextButton.styleFrom(
                                                foregroundColor: isBlocked
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 12),
                                              ),
                                              child: Text(
                                                  isBlocked ? 'ALLOW' : 'BLOCK',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
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
      Widget? customSubtitle,
      String? featureKey}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isUnlocked =
        featureKey == null || _isFeatureUnlockedByDay(featureKey);
    final VoidCallback activeTap;
    if (isUnlocked) {
      activeTap = onTap;
    } else {
      activeTap = () => _showUpsellLockSheet(featureKey, label);
    }
    final activeColor = isUnlocked ? color : Colors.grey.shade400;

    return GestureDetector(
      onTap: activeTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isLight
                  ? Colors.white.withOpacity(0.96)
                  : const Color(0xFF0D1B2A).withOpacity(0.7),
              isLight
                  ? activeColor.withOpacity(0.04)
                  : activeColor.withOpacity(0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLight
                ? activeColor.withOpacity(0.20)
                : activeColor.withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? activeColor.withOpacity(0.10)
                  : Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon bubble with badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(isLight ? 0.10 : 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: activeColor, size: 24),
                      ),
                      if (badgeCount != null && badgeCount > 0 && isUnlocked)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: badgeColor ?? Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 1.5),
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : badgeCount.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (!isUnlocked)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 1.5),
                            ),
                            child: const Icon(Icons.lock,
                                color: Colors.black, size: 8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Label
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  if (!isUnlocked)
                    Text(
                      'Bientôt disponible\n(${_getFeatureUnlockDayText(featureKey)})',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    )
                  else if (customSubtitle != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 36),
                      child: ClipRect(child: customSubtitle),
                    )
                  else if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // Tap indicator
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isUnlocked ? 'Consulter' : 'Débloquer',
                        style: TextStyle(
                          color: isUnlocked ? color : Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        isUnlocked
                            ? Icons.arrow_forward_ios_rounded
                            : Icons.workspace_premium,
                        color: isUnlocked ? color : Colors.amber,
                        size: 10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Warning dot
            if (hasWarning && isUnlocked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Screen Time Detail',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            SizedBox(height: 24),
            _buildScreenTimeSection(childId, childData: childData),
            SizedBox(height: 24),
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
              SizedBox(width: 12),
              SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
        // Read dailyLimit from rules stream; usedMinutes from live usage stats
        StreamBuilder<Map<String, dynamic>>(
          stream: FirestoreService().rulesStream(childId),
          builder: (context, rulesSnapshot) {
            final dailyLimit =
                ((rulesSnapshot.data?['dailyLimitMinutes'] ?? 120) as num)
                    .toInt();
            final startTime =
                rulesSnapshot.data?['allowedTimeStart'] as String?;
            final endTime = rulesSnapshot.data?['allowedTimeEnd'] as String?;
            final hasSchedule = startTime != null && endTime != null;

            // usedMinutes is sourced from the live stats subscription (_usageStats)
            final data = _usageStats ?? {};
            final usedMinutes =
                (data['usedMinutes'] ?? data['totalMinutes'] ?? 0) as num;
            final progress = (usedMinutes / (dailyLimit == 0 ? 1 : dailyLimit))
                .clamp(0.0, 1.0);
            final remaining =
                (dailyLimit - usedMinutes.toInt()).clamp(0, 99999);
            final isOver = dailyLimit > 0 && usedMinutes >= dailyLimit;

            return GlassCard(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Used: ${_fmtMin(usedMinutes.toInt())}',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 15)),
                          Text('Limit: ${_fmtMin(dailyLimit)}',
                              style: TextStyle(
                                  color: AppColors.textGray300, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isOver ? Colors.red : AppColors.primary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOver
                              ? 'Limit reached'
                              : '${_fmtMin(remaining)} left',
                          style: TextStyle(
                            color:
                                isOver ? Colors.redAccent : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? Colors.red : AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          color: AppColors.textGray300, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dailyLimit == 0
                              ? 'No daily limit set'
                              : 'Daily limit: ${_fmtMin(dailyLimit)}',
                          style: TextStyle(color: AppColors.textGray300),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showLimitPicker(childId, dailyLimit),
                        child: Text('Edit',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                  Divider(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.10)),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          color: AppColors.textGray300, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasSchedule
                              ? 'Schedule: $startTime – $endTime'
                              : 'No time schedule set',
                          style: TextStyle(color: AppColors.textGray300),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push('/child/config', extra: childData),
                        child: Text('Edit',
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set Daily Limit',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 32),
              Text('$selectedLimit minutes',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              Slider(
                value: selectedLimit.toDouble().clamp(0.0, 1440.0),
                min: 0,
                max: 1440,
                divisions: 96,
                activeColor: AppColors.primary,
                inactiveColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.10),
                onChanged: (val) =>
                    setModalState(() => selectedLimit = val.toInt()),
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface),
                          child: Text('Cancel'))),
                  SizedBox(width: 16),
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
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface),
                      child: Text('Save'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Manage Applications',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search applications...',
                hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.30)),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.30)),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.05),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
            SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: FirestoreService().usageStatsStream(widget.childId),
                builder: (context, usageSnap) {
                  final rawUsage = usageSnap.data?['apps'];
                  final usageData = rawUsage is Map ? rawUsage : {};

                  return StreamBuilder<List<String>>(
                    stream:
                        FirestoreService().appInventoryStream(widget.childId),
                    builder: (context, invSnap) {
                      return StreamBuilder<List<String>>(
                        stream: FirestoreService()
                            .blockedAppsStream(widget.childId),
                        builder: (context, blockSnap) {
                          final inventory = invSnap.data ?? [];
                          final blocked = blockSnap.data ?? [];

                          final sortedInventory = List<String>.from(inventory)
                            ..sort((a, b) {
                              final usageA = usageData[a];
                              final usageB = usageData[b];
                              // Fallback to 'minutes' if 'totalMinutes' is missing
                              final minsA = (usageA is Map
                                  ? (usageA['totalMinutes'] ??
                                      usageA['minutes'] ??
                                      0)
                                  : 0) as num;
                              final minsB = (usageB is Map
                                  ? (usageB['totalMinutes'] ??
                                      usageB['minutes'] ??
                                      0)
                                  : 0) as num;
                              return minsB.compareTo(minsA);
                            });

                          final filteredApps = sortedInventory
                              .where((pkg) =>
                                  pkg.toLowerCase().contains(_searchQuery))
                              .toList();

                          if (inventory.isEmpty &&
                              invSnap.connectionState ==
                                  ConnectionState.waiting) {
                            return Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary));
                          }
                          if (inventory.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.apps_outage,
                                      color: AppColors.textGray300, size: 48),
                                  SizedBox(height: 16),
                                  Text('No apps reported by device yet',
                                      style: TextStyle(
                                          color: AppColors.textGray300)),
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

                              final knownApp = _kKnownApps
                                  .cast<Map<String, dynamic>?>()
                                  .firstWhere(
                                    (a) => a?['pkg'] == pkg,
                                    orElse: () => null,
                                  );
                              final String category =
                                  knownApp?['cat'] ?? 'other';
                              final IconData? fallbackIcon =
                                  knownApp?['icon'] as IconData?;

                              return AppTileWithDetails(
                                childId: widget.childId,
                                packageName: pkg,
                                category: category,
                                showProgress: false,
                                fallbackIcon: fallbackIcon,
                                trailing: Switch(
                                  value: isBlocked,
                                  thumbColor:
                                      WidgetStateProperty.resolveWith<Color?>(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                            ? Colors.redAccent
                                            : null,
                                  ),
                                  activeTrackColor:
                                      Colors.redAccent.withValues(alpha: 0.3),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.10),
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
