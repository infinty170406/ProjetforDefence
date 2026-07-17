import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/firestore_service.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class _RulesConfig {
  int dailyLimitMinutes;
  bool screenTimeEnabled = true;
  String? allowedTimeStart;
  String? allowedTimeEnd;
  bool scheduleEnabled = false;
  List<String> blockedApps = [];
  List<String> blockedWebsites = [];
  List<String> customKeywords = [];
  List<String> customCategories = [];
  bool blockAdultContent;
  bool blockSocialMedia;
  bool blockGaming;
  bool blockViolence;
  bool blockDrugs;
  bool blockSexualPredators;
  bool blockAnxietyDepression;
  bool blockSelfHarm;
  bool blockCyberbullying;
  bool blockMatureContent;
  bool blockEatingDisorders;
  bool monitorAccountActivity;
  bool locationAlerts;
  String? blockReason;

  _RulesConfig({
    this.dailyLimitMinutes = 120,
    this.blockAdultContent = true,
    this.blockSocialMedia = false,
    this.blockGaming = false,
    this.blockViolence = true,
    this.blockDrugs = true,
    this.blockSexualPredators = true,
    this.blockAnxietyDepression = false,
    this.blockSelfHarm = true,
    this.blockCyberbullying = true,
    this.blockMatureContent = false,
    this.blockEatingDisorders = false,
    this.monitorAccountActivity = true,
    this.locationAlerts = true,
  });

  factory _RulesConfig.defaultForAge(int age) {
    if (age <= 6) {
      return _RulesConfig(
        dailyLimitMinutes: 60,
        blockAdultContent: true,
        blockSocialMedia: true,
        blockGaming: true,
        blockViolence: true,
      );
    } else if (age <= 10) {
      return _RulesConfig(
        dailyLimitMinutes: 90,
        blockAdultContent: true,
        blockSocialMedia: true,
        blockGaming: false,
        blockViolence: true,
      );
    } else if (age <= 13) {
      return _RulesConfig(
        dailyLimitMinutes: 120,
        blockAdultContent: true,
        blockSocialMedia: false,
        blockGaming: false,
        blockViolence: true,
        blockDrugs: true,
        blockSexualPredators: true,
        blockAnxietyDepression: false,
        blockSelfHarm: true,
        blockCyberbullying: true,
        blockMatureContent: false,
        blockEatingDisorders: false,
        monitorAccountActivity: true,
        locationAlerts: true,
      );
    } else if (age <= 17) {
      return _RulesConfig(
        dailyLimitMinutes: 180,
        blockAdultContent: true,
        blockSocialMedia: false,
        blockGaming: false,
        blockViolence: false,
        blockDrugs: true,
        blockSexualPredators: true,
        blockAnxietyDepression: false,
        blockSelfHarm: true,
        blockCyberbullying: true,
        blockMatureContent: false,
        blockEatingDisorders: false,
        monitorAccountActivity: true,
        locationAlerts: true,
      );
    } else {
      return _RulesConfig(
        dailyLimitMinutes: 240,
        blockAdultContent: false,
        blockSocialMedia: false,
        blockGaming: false,
        blockViolence: false,
        blockDrugs: false,
        blockSexualPredators: false,
        blockAnxietyDepression: false,
        blockSelfHarm: false,
        blockCyberbullying: false,
        blockMatureContent: false,
        blockEatingDisorders: false,
        monitorAccountActivity: false,
        locationAlerts: false,
      );
    }
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

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
];

const _kKnownWebsites = [
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
];

const _kStepLabels = [
  'Screen Time',
  'Apps',
  'Websites',
  'Content',
  'Keywords',
  'Safe Zones',
  'Summary'
];
const _kStepIcons = [
  Icons.timer_outlined,
  Icons.apps,
  Icons.language,
  Icons.shield_outlined,
  Icons.manage_search,
  Icons.location_on,
  Icons.check_circle_outline
];

// ── Screen ────────────────────────────────────────────────────────────────────

class RulesConfigWizardScreen extends StatefulWidget {
  final dynamic child;
  const RulesConfigWizardScreen({super.key, this.child});

  @override
  State<RulesConfigWizardScreen> createState() =>
      _RulesConfigWizardScreenState();
}

class _RulesConfigWizardScreenState extends State<RulesConfigWizardScreen> {
  int _step = 0;
  bool _isSaving = false;
  String? _timeError;
  String _appSearch = '';
  final _domainController = TextEditingController();
  final _keywordController = TextEditingController();
  final _categoryController = TextEditingController();
  late _RulesConfig _cfg;

  @override
  void initState() {
    super.initState();
    final age = (widget.child?['age'] ?? 12) as int;
    _cfg = _RulesConfig.defaultForAge(age);
  }

  @override
  void dispose() {
    _domainController.dispose();
    _keywordController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  String _formatMinutes(int min) {
    if (min == 0) return '0 min';
    if (min < 60) return '${min}min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }

  void _validateTime() {
    setState(() {
      _timeError = null;
      if (_cfg.scheduleEnabled) {
        final startParts = (_cfg.allowedTimeStart ?? '08:00').split(':');
        final endParts = (_cfg.allowedTimeEnd ?? '21:00').split(':');
        final startMin =
            int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        int scheduleDuration = endMin - startMin;
        if (scheduleDuration < 0) {
          scheduleDuration += 24 * 60; // overnight
        }

        if (_cfg.screenTimeEnabled &&
            _cfg.dailyLimitMinutes > scheduleDuration) {
          _timeError =
              "Schedule duration must be greater than or equal to the screen time limit.";
        }
      }
    });
  }

  Future<void> _save() async {
    _validateTime();
    if (_timeError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_timeError!),
            backgroundColor: AppColors.statusDanger));
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
      await FirestoreService().saveRules(
        childId,
        blockedApps: _cfg.blockedApps,
        blockedWebsites: _cfg.blockedWebsites,
        dailyLimitMinutes:
            _cfg.screenTimeEnabled ? _cfg.dailyLimitMinutes : 1440,
        allowedTimeStart:
            _cfg.scheduleEnabled ? (_cfg.allowedTimeStart ?? '08:00') : null,
        allowedTimeEnd:
            _cfg.scheduleEnabled ? (_cfg.allowedTimeEnd ?? '21:00') : null,
        blockSocialMedia: _cfg.blockSocialMedia,
        blockGaming: _cfg.blockGaming,
        blockAdultContent: _cfg.blockAdultContent,
        blockViolence: _cfg.blockViolence,
        blockDrugs: _cfg.blockDrugs,
        blockSexualPredators: _cfg.blockSexualPredators,
        blockAnxietyDepression: _cfg.blockAnxietyDepression,
        blockSelfHarm: _cfg.blockSelfHarm,
        blockCyberbullying: _cfg.blockCyberbullying,
        blockMatureContent: _cfg.blockMatureContent,
        blockEatingDisorders: _cfg.blockEatingDisorders,
        monitorAccountActivity: _cfg.monitorAccountActivity,
        locationAlerts: _cfg.locationAlerts,
        customKeywords: _cfg.customKeywords,
        customCategories: _cfg.customCategories,
        blockReason: _cfg.blockReason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Rules saved ✓'),
            backgroundColor: Colors.green.shade700));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.statusDanger));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.child?['displayName'] ?? 'Child';
    final age = (widget.child?['age'] ?? 12) as int;

    return Scaffold(
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(displayName, age),
                _buildStepper(),
                Expanded(child: _buildStepContent()),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, int age) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close,
                    color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => context.pop(),
              ),
              Spacer(),
              Text('Configure Rules',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Spacer(),
              SizedBox(width: 48),
            ],
          ),
          SizedBox(height: 4),
          Center(
            child: Text('$name · $age years old',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: List.generate(_kStepLabels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector line
            final stepIdx = i ~/ 2;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                color: stepIdx < _step
                    ? AppColors.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < _step;
          final isCurrent = stepIdx == _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.primary
                  : isCurrent
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06),
              border: Border.all(
                color: (isDone || isCurrent)
                    ? AppColors.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.24),
                width: 2,
              ),
            ),
            child: Center(
              child: isDone
                  ? Icon(Icons.check,
                      color: Theme.of(context).colorScheme.onSurface, size: 16)
                  : Icon(_kStepIcons[stepIdx],
                      color: isCurrent
                          ? AppColors.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.38),
                      size: 16),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: [
            _buildStep1(),
            _buildStep2(),
            _buildStep3(),
            _buildStep4(),
            _buildStep5(),
            _buildStep6(),
            _buildStep7(),
          ][_step],
        ),
      ),
    );
  }

  // ── Step 1: Screen Time ───────────────────────────────────────────────────

  Widget _buildStep1() {
    final age = (widget.child?['age'] ?? 12) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(0, age)),
        _sectionTitle('Screen Time', Icons.timer_outlined),
        SizedBox(height: 16),
        _buildContentToggle(
          'Screen Time Limit',
          'Enable a daily limit for screen time',
          Icons.hourglass_empty,
          _cfg.screenTimeEnabled,
          (v) {
            setState(() => _cfg.screenTimeEnabled = v);
            _validateTime();
          },
          isDanger: false,
        ),
        if (_cfg.screenTimeEnabled) ...[
          SizedBox(height: 24),
          Text('Daily screen time limit',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.70),
                  fontSize: 14)),
          SizedBox(height: 16),
          Center(
            child: Text(
              _formatMinutes(_cfg.dailyLimitMinutes),
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Slider(
            value: _cfg.dailyLimitMinutes.toDouble(),
            min: 0,
            max: 1440,
            divisions: 96,
            activeColor: AppColors.primary,
            inactiveColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            onChanged: (v) {
              setState(() => _cfg.dailyLimitMinutes = v.round());
              _validateTime();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0 min',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11)),
              Text('24 hours',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11)),
            ],
          ),
        ],
        SizedBox(height: 28),
        _buildContentToggle(
          'Schedule Active',
          'Only allow device use during specific hours',
          Icons.timer_outlined,
          _cfg.scheduleEnabled,
          (v) {
            setState(() => _cfg.scheduleEnabled = v);
            _validateTime();
          },
          isDanger: false, // Neutral for scheduling
        ),
        if (_cfg.scheduleEnabled) ...[
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _timePicker('From', _cfg.allowedTimeStart ?? '08:00',
                      (t) {
                setState(() => _cfg.allowedTimeStart = t);
                _validateTime();
              }, hasError: _timeError != null)),
              SizedBox(width: 12),
              Expanded(
                  child: _timePicker('To', _cfg.allowedTimeEnd ?? '21:00', (t) {
                setState(() => _cfg.allowedTimeEnd = t);
                _validateTime();
              }, hasError: _timeError != null)),
            ],
          ),
          if (_timeError != null)
            Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text(
                _timeError!,
                style: TextStyle(
                    color: AppColors.statusDanger,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
        SizedBox(height: 80),
      ],
    );
  }

  Widget _timePicker(String label, String value, void Function(String) onSet,
      {bool hasError = false}) {
    return GestureDetector(
      onTap: () async {
        final parts = value.split(':');
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 8,
              minute: int.tryParse(parts[1]) ?? 0),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.dark(
                  primary:
                      AppColors.primary.withValues(alpha: 0.6), // Dimmed purple
                  surface: Theme.of(context).scaffoldBackgroundColor,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                  onPrimary: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onSet(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: hasError
              ? AppColors.statusDanger.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasError
                  ? AppColors.statusDanger
                  : AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11)),
            SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
      ),
    );
  }

  // ── Step 2: App Blocking ──────────────────────────────────────────────────

  Widget _buildStep2() {
    final age = (widget.child?['age'] ?? 12) as int;
    final categories =
        _kKnownApps.map((a) => a['cat'] as String).toSet().toList();
    final filtered = _kKnownApps.where((a) {
      final n = (a['name'] as String).toLowerCase();
      return _appSearch.isEmpty || n.contains(_appSearch.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(1, age)),
        _sectionTitle('App Blocking', Icons.apps),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: 0.92)
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: TextField(
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search apps...',
              hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              border: InputBorder.none,
              icon: Icon(Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            onChanged: (v) => setState(() => _appSearch = v),
          ),
        ),
        SizedBox(height: 16),
        ...categories.map((cat) {
          final apps = filtered.where((a) => a['cat'] == cat).toList();
          if (apps.isEmpty) return SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 12, bottom: 8),
                child: Text(cat,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              ...apps.map((app) => _buildAppTile(app)),
            ],
          );
        }),
        SizedBox(height: 80),
      ],
    );
  }

  Widget _buildAppTile(Map<dynamic, dynamic> app) {
    final pkg = app['pkg'] as String;
    final blocked = _cfg.blockedApps.contains(pkg);
    final catColors = {
      'Social': AppColors.primary,
      'Messaging': AppColors.accentTeal,
      'Entertainment': Colors.orange,
      'Gaming': Colors.red,
      'Productivity': Colors.green,
      'Utility': Colors.blue,
      'Browser': Colors.purple,
    };
    final color = catColors[app['cat']] ?? AppColors.primary;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: blocked
            ? AppColors.statusDanger.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: blocked
              ? AppColors.statusDanger.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(app['icon'] as IconData, color: color, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(app['name'] as String,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: blocked,
            onChanged: (v) {
              setState(() {
                if (v) {
                  _cfg.blockedApps = [..._cfg.blockedApps, pkg];
                } else {
                  _cfg.blockedApps =
                      _cfg.blockedApps.where((p) => p != pkg).toList();
                }
              });
            },
            thumbColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.statusDanger
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Website Filter ────────────────────────────────────────────────

  Widget _buildStep3() {
    final age = (widget.child?['age'] ?? 12) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(2, age)),
        _sectionTitle('Website Filter', Icons.language),
        SizedBox(height: 8),
        Text('Block specific websites',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.70),
                fontSize: 13)),
        SizedBox(height: 16),
        Text('SUGGESTED',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        ..._kKnownWebsites.map((site) {
          final domain = site['domain']!;
          final blocked = _cfg.blockedWebsites.contains(domain);
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: blocked
                  ? AppColors.statusDanger.withValues(alpha: 0.1)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: blocked
                    ? AppColors.statusDanger.withValues(alpha: 0.3)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.language,
                    color: blocked
                        ? AppColors.statusDanger
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.54),
                    size: 18),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(site['name']!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w500)),
                      Text(domain,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: blocked,
                  onChanged: (v) => setState(() {
                    if (v) {
                      _cfg.blockedWebsites = [..._cfg.blockedWebsites, domain];
                    } else {
                      _cfg.blockedWebsites = _cfg.blockedWebsites
                          .where((d) => d != domain)
                          .toList();
                    }
                  }),
                  thumbColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColors.statusDanger
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: 20),
        Text('CUSTOM DOMAINS',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 10),
        if (_cfg.blockedWebsites
            .where((d) => !_kKnownWebsites.any((s) => s['domain'] == d))
            .isNotEmpty)
          ..._cfg.blockedWebsites
              .where((d) => !_kKnownWebsites.any((s) => s['domain'] == d))
              .map((d) => Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.statusDanger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.statusDanger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.block,
                            color: AppColors.statusDanger, size: 16),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(d,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface))),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                              size: 18),
                          onPressed: () => setState(() {
                            _cfg.blockedWebsites = _cfg.blockedWebsites
                                .where((x) => x != d)
                                .toList();
                          }),
                        ),
                      ],
                    ),
                  )),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _domainController,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'example.com',
                  hintStyle: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? const Color(0xFF94A3B8)
                          : AppColors.textGray400),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.withValues(alpha: 0.92)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _addCustomDomain(),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _addCustomDomain,
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
        SizedBox(height: 80),
      ],
    );
  }

  void _addCustomDomain() {
    final d = _domainController.text.trim();
    if (d.isNotEmpty && !_cfg.blockedWebsites.contains(d)) {
      setState(() {
        _cfg.blockedWebsites = [..._cfg.blockedWebsites, d];
        _domainController.clear();
      });
    }
  }

  // ── Step 4: Content Rules ─────────────────────────────────────────────────

  Widget _buildStep4() {
    final age = (widget.child?['age'] ?? 12) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(3, age)),
        _sectionTitle('Content Rules', Icons.shield_outlined),
        SizedBox(height: 8),
        Text('Block inappropriate content categories',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.70),
                fontSize: 13)),
        SizedBox(height: 24),
        Text('SAFETY & WELL-BEING',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        _buildContentToggle(
          'Anxiety / Depression',
          'Monitor signs of emotional distress',
          Icons.psychology_outlined,
          _cfg.blockAnxietyDepression,
          (v) => setState(() => _cfg.blockAnxietyDepression = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Self-Harm / Suicide',
          'Alert for dangerous self-harm content',
          Icons.healing_outlined,
          _cfg.blockSelfHarm,
          (v) => setState(() => _cfg.blockSelfHarm = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Cyberbullying',
          'Detect bullying and harassment',
          Icons.gavel_outlined,
          _cfg.blockCyberbullying,
          (v) => setState(() => _cfg.blockCyberbullying = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Eating Disorders',
          'Body or eating related images',
          Icons.accessibility_new_outlined,
          _cfg.blockEatingDisorders,
          (v) => setState(() => _cfg.blockEatingDisorders = v),
          isDanger: true,
        ),
        SizedBox(height: 24),
        Text('RESTRICTED CONTENT',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        _buildContentToggle(
          'Adult & Pornography',
          'Porn and explicit material',
          Icons.no_adult_content,
          _cfg.blockAdultContent,
          (v) => setState(() => _cfg.blockAdultContent = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Drugs & Alcohol',
          'Drugs, Alcohol & Tobacco content',
          Icons.medication_outlined,
          _cfg.blockDrugs,
          (v) => setState(() => _cfg.blockDrugs = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Sexual Predators',
          'Detect grooming and dangerous contacts',
          Icons.security_outlined,
          _cfg.blockSexualPredators,
          (v) => setState(() => _cfg.blockSexualPredators = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Violence & Gore',
          'Violent or graphic content',
          Icons.warning_amber_outlined,
          _cfg.blockViolence,
          (v) => setState(() => _cfg.blockViolence = v),
          isDanger: true,
        ),
        _buildContentToggle(
          'Mature Content',
          'General mature-rated content',
          Icons.explicit_outlined,
          _cfg.blockMatureContent,
          (v) => setState(() => _cfg.blockMatureContent = v),
          isDanger: true,
        ),
        SizedBox(height: 28),
        // ── Custom Categories ─────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.category, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'CUSTOM CATEGORIES',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          'Enter custom content categories (e.g. Manga, Betting) to restrict.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.54),
              fontSize: 12,
              height: 1.4),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _categoryController,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Manga, Betting...',
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.withValues(alpha: 0.92)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.6))),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _addCategory(),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _addCategory,
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
        if (_cfg.customCategories.isNotEmpty) ...[
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cfg.customCategories
                .map((c) => _buildCategoryChip(c))
                .toList(),
          ),
        ],
        SizedBox(height: 80),
      ],
    );
  }

  void _addCategory() {
    final cat = _categoryController.text.trim();
    if (cat.isNotEmpty && !_cfg.customCategories.contains(cat)) {
      setState(() {
        _cfg.customCategories = [..._cfg.customCategories, cat];
        _categoryController.clear();
      });
    }
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.statusWarning.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category, color: AppColors.statusWarning, size: 14),
          SizedBox(width: 6),
          Text(category,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _cfg.customCategories =
                _cfg.customCategories.where((c) => c != category).toList()),
            child: Icon(Icons.close,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
                size: 14),
          ),
        ],
      ),
    );
  }

  // ── Step 5: Custom Monitoring ─────────────────────────────────────────────

  Widget _buildStep5() {
    final age = (widget.child?['age'] ?? 12) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(4, age)),
        _sectionTitle('Custom Monitoring', Icons.manage_search),
        SizedBox(height: 16),
        Text(
          'Add specific words, slang, or topics you want to monitor. Alerts will be triggered when detected.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.54),
              fontSize: 13,
              height: 1.4),
        ),
        SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keywordController,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Fortnite, vaping...',
                  hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.6)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (_) => _addKeyword(),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _addKeyword,
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
        if (_cfg.customKeywords.isNotEmpty) ...[
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _cfg.customKeywords.map((kw) => _buildKeywordChip(kw)).toList(),
          ),
        ],
        SizedBox(height: 32),
        Text(
          'CATEGORIES / SUGGESTIONS',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2),
        ),
        SizedBox(height: 12),
        _buildSuggestionCategory(
            'Trends & Apps',
            ['Roblox', 'Fortnite', 'Omegle', 'Discord', 'TikTok'],
            Colors.teal.shade400),
        _buildSuggestionCategory('Slang & Mature',
            ['NSFW', 'OnlyFans', 'Sugar Daddy', 'Nudes'], Colors.pink.shade400),
        _buildSuggestionCategory(
            'Substances',
            ['Vaping', 'Weed', 'Puff', 'Juul', 'Smoke'],
            Colors.orange.shade400),
        _buildSuggestionCategory('Toxicity & Bullying',
            ['Kys', 'Loser', 'Ugly', 'Hate', 'Die'], Colors.redAccent),
        SizedBox(height: 32),
        Row(
          children: [
            Icon(Icons.message, color: AppColors.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'CUSTOM BLOCK MESSAGE',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2),
            ),
          ],
        ),
        SizedBox(height: 6),
        Text(
          'Message displayed on the child\'s device when an app or website is blocked.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.54),
              fontSize: 12,
              height: 1.4),
        ),
        SizedBox(height: 14),
        TextField(
          onChanged: (val) =>
              _cfg.blockReason = val.trim().isEmpty ? null : val.trim(),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. It\'s time to focus on homework.',
            hintStyle: TextStyle(color: AppColors.textGray400, fontSize: 13),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        SizedBox(height: 80),
      ],
    );
  }

  Widget _buildSuggestionCategory(
      String title, List<String> words, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(title,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words.map((w) {
            final isSelected = _cfg.customKeywords.contains(w);
            return GestureDetector(
              onTap: () {
                if (!isSelected) {
                  setState(
                      () => _cfg.customKeywords = [..._cfg.customKeywords, w]);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.05)
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.12)
                          : color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isSelected ? Icons.check : Icons.add,
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.54)
                            : color,
                        size: 14),
                    SizedBox(width: 4),
                    Text(w,
                        style: TextStyle(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.54)
                                : color,
                            fontSize: 12)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  void _addKeyword() {
    final kw = _keywordController.text.trim();
    if (kw.isNotEmpty && !_cfg.customKeywords.contains(kw)) {
      setState(() {
        _cfg.customKeywords = [..._cfg.customKeywords, kw];
        _keywordController.clear();
      });
    }
  }

  Widget _buildKeywordChip(String keyword) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_outline, color: AppColors.primary, size: 14),
          SizedBox(width: 6),
          Text(
            keyword,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _cfg.customKeywords =
                  _cfg.customKeywords.where((k) => k != keyword).toList();
            }),
            child: Icon(Icons.close,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.38),
                size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContentToggle(String title, String subtitle, IconData icon,
      bool value, void Function(bool) onChanged,
      {bool isDanger = false}) {
    final activeCol = isDanger
        ? AppColors.statusDanger
        : Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? activeCol.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? activeCol.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (value ? activeCol : Theme.of(context).colorScheme.onSurface)
                      .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: value
                    ? activeCol
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.70),
                size: 20),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeCol,
            activeTrackColor: activeCol.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  // ── Step 6: Safe Zones ────────────────────────────────────────────────────

  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(
            "Define geographic boundaries. Alerts will trigger if the device leaves these zones."),
        _sectionTitle('Safe Zones', Icons.location_on),
        SizedBox(height: 16),
        Text(
          'Manage the safe areas for your child. Tap below to configure locations on the map.',
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.54),
              fontSize: 13,
              height: 1.4),
        ),
        SizedBox(height: 24),
        _buildContentToggle(
          'Location Alerts',
          'Get notified when child enters/leaves safe zones',
          Icons.notifications_active_outlined,
          _cfg.locationAlerts,
          (v) => setState(() => _cfg.locationAlerts = v),
          isDanger: false,
        ),
        SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            // Fix: navigate to the correct route /safe-zones
            await context.push('/safe-zones');
          },
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.map, color: AppColors.primary, size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configure Safe Zones',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('Open the map to set perimeters',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: AppColors.primary, size: 16),
              ],
            ),
          ),
        ),
        SizedBox(height: 80),
      ],
    );
  }

  // ── Step 7: Summary ───────────────────────────────────────────────────────

  Widget _buildStep7() {
    final age = (widget.child?['age'] ?? 12) as int;

    // Collect all active content blocks for a compact display
    final contentBlocks = <Map<String, dynamic>>[
      if (_cfg.blockAdultContent)
        {
          'label': 'Adult & Porn',
          'icon': Icons.no_adult_content,
          'color': Colors.red
        },
      if (_cfg.blockDrugs)
        {
          'label': 'Drugs & Alcohol',
          'icon': Icons.medication_outlined,
          'color': Colors.deepPurpleAccent
        },
      if (_cfg.blockViolence)
        {
          'label': 'Violence & Gore',
          'icon': Icons.warning_amber_outlined,
          'color': Colors.deepOrange
        },
      if (_cfg.blockSexualPredators)
        {
          'label': 'Sexual Predators',
          'icon': Icons.security_outlined,
          'color': Colors.indigoAccent
        },
      if (_cfg.blockSocialMedia)
        {
          'label': 'Social Media',
          'icon': Icons.people_outline,
          'color': AppColors.primary
        },
      if (_cfg.blockGaming)
        {'label': 'Gaming', 'icon': Icons.sports_esports, 'color': Colors.red},
      if (_cfg.blockSelfHarm)
        {
          'label': 'Self-Harm',
          'icon': Icons.healing_outlined,
          'color': Colors.redAccent
        },
      if (_cfg.blockCyberbullying)
        {
          'label': 'Cyberbullying',
          'icon': Icons.gavel_outlined,
          'color': Colors.orangeAccent
        },
      if (_cfg.blockAnxietyDepression)
        {
          'label': 'Anxiety/Depression',
          'icon': Icons.psychology_outlined,
          'color': Colors.tealAccent
        },
      if (_cfg.blockEatingDisorders)
        {
          'label': 'Eating Disorders',
          'icon': Icons.accessibility_new_outlined,
          'color': Colors.pinkAccent
        },
      if (_cfg.blockMatureContent)
        {
          'label': 'Mature Content',
          'icon': Icons.explicit_outlined,
          'color': Colors.blueGrey
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAiInsightCard(_getSuggestionForStep(4, age)),
        _sectionTitle('Summary', Icons.check_circle_outline),
        SizedBox(height: 4),
        Text('Review all settings before saving',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.70),
                fontSize: 13)),
        SizedBox(height: 20),

        // ── STEP 1: Screen Time ──────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _step = 0),
          child: Container(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryGroupTitle('Step 1 · Screen Time', Icons.timer_outlined,
                    stepIndex: 0),
                SizedBox(height: 10),
                _summaryRow(
                    'Daily Limit',
                    _formatMinutes(_cfg.dailyLimitMinutes),
                    Icons.timer_outlined,
                    isAlert: false),
                if (_cfg.scheduleEnabled)
                  _summaryRow(
                    'Allowed Hours',
                    '${_cfg.allowedTimeStart ?? "08:00"} → ${_cfg.allowedTimeEnd ?? "21:00"}',
                    Icons.schedule,
                  )
                else
                  _summaryRow(
                      'Allowed Hours', 'No schedule set', Icons.schedule,
                      isAlert: false),
              ],
            ),
          ),
        ),
        SizedBox(height: 18),

        // ── STEP 2: App Blocking ─────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryGroupTitle('Step 2 · App Blocking', Icons.apps,
                    stepIndex: 1),
                SizedBox(height: 10),
                _summaryRow(
                  'Blocked Apps',
                  _cfg.blockedApps.isEmpty
                      ? 'None'
                      : '${_cfg.blockedApps.length} blocked',
                  Icons.block,
                  isAlert: _cfg.blockedApps.isNotEmpty,
                ),
                if (_cfg.blockedApps.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8, top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _cfg.blockedApps.map((pkg) {
                        final app = _kKnownApps.firstWhere(
                          (a) => a['pkg'] == pkg,
                          orElse: () => {'name': pkg, 'pkg': pkg},
                        );
                        return Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.statusDanger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.statusDanger
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(app['name'] as String,
                              style: TextStyle(
                                  color: AppColors.statusDanger, fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 18),

        // ── STEP 3: Website Filter ───────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _step = 2),
          child: Container(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryGroupTitle('Step 3 · Website Filter', Icons.language,
                    stepIndex: 2),
                SizedBox(height: 10),
                _summaryRow(
                  'Blocked Sites',
                  _cfg.blockedWebsites.isEmpty
                      ? 'None'
                      : '${_cfg.blockedWebsites.length} blocked',
                  Icons.language,
                  isAlert: _cfg.blockedWebsites.isNotEmpty,
                ),
                if (_cfg.blockedWebsites.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8, top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _cfg.blockedWebsites
                          .map((domain) => Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.statusDanger
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.statusDanger
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(domain,
                                    style: TextStyle(
                                        color: AppColors.statusDanger,
                                        fontSize: 11)),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 18),

        // ── STEP 4: Content Rules ────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _step = 3),
          child: Container(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryGroupTitle(
                    'Step 4 · Content Rules', Icons.shield_outlined,
                    stepIndex: 3),
                SizedBox(height: 10),
                if (contentBlocks.isEmpty)
                  _summaryRow(
                      'Content Filters', 'None enabled', Icons.shield_outlined,
                      isAlert: false)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: contentBlocks.map((b) {
                      final color = b['color'] as Color;
                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(b['icon'] as IconData, color: color, size: 13),
                            SizedBox(width: 6),
                            Text(b['label'] as String,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                // Custom Categories logic for Step 4
                if (_cfg.customCategories.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cfg.customCategories
                        .map((cat) => Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.statusWarning
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.statusWarning
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.category,
                                      color: AppColors.statusWarning, size: 13),
                                  SizedBox(width: 6),
                                  Text(cat,
                                      style: TextStyle(
                                          color: AppColors.statusWarning,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: 24), // Increased spacing between step 4 and step 5

        // ── STEP 5: Custom Monitoring ────────────────────────────────────────
        if (_cfg.customKeywords.isNotEmpty) ...[
          GestureDetector(
            onTap: () => setState(() => _step = 4),
            child: Container(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryGroupTitle(
                      'Step 5 · Custom Monitoring', Icons.manage_search,
                      stepIndex: 4),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.manage_search,
                                color: AppColors.primary, size: 16),
                            SizedBox(width: 8),
                            Text(
                              '${_cfg.customKeywords.length} Custom Keyword${_cfg.customKeywords.length > 1 ? 's' : ''} Monitored',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.70),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _cfg.customKeywords
                              .map((kw) => Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(kw,
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        SizedBox(height: 80),
      ],
    );
  }

  Widget _summaryGroupTitle(String title, IconData icon, {int? stepIndex}) {
    return GestureDetector(
      onTap: stepIndex != null ? () => setState(() => _step = stepIndex) : null,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 15),
          SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          if (stepIndex != null) ...[
            SizedBox(width: 4),
            Icon(Icons.edit, color: AppColors.primary, size: 12),
          ],
          SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 1, color: AppColors.primary.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon,
      {bool isAlert = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: isAlert ? AppColors.statusDanger : AppColors.textGray400,
              size: 18),
          SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.70)))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAlert
                  ? AppColors.statusDanger.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isAlert ? AppColors.statusDanger : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final isLast = _step == _kStepLabels.length - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color:
            Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        border: Border(
            top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24)),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back'),
              ),
            ),
          if (_step > 0) SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : isLast
                      ? _save
                      : () {
                          if (_step == 0 && !_isTimeValid()) {
                            setState(
                                () {}); // Show error message and red fields
                            return; // Block navigation
                          }
                          setState(() => _step++);
                        },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onSurface),
                    )
                  : Text(
                      isLast ? 'Save Rules' : 'Continue',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isTimeValid() {
    if (!_cfg.scheduleEnabled) {
      _timeError = null;
      return true;
    }
    final start = _cfg.allowedTimeStart ?? "08:00";
    final end = _cfg.allowedTimeEnd ?? "21:00";

    final sParts = start.split(':');
    final eParts = end.split(':');
    final sMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
    final eMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);

    if (sMin >= eMin) {
      _timeError = "Start time must be before end time.";
      return false;
    }

    final int intervalMinutes = eMin - sMin;
    if (_cfg.dailyLimitMinutes > intervalMinutes) {
      _timeError = "Daily limit cannot exceed allowed hours interval.";
      return false;
    }

    _timeError = null;
    return true;
  }

  Widget _buildAiInsightCard(String suggestion) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI INSIGHT',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.70),
                      fontSize: 13,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSuggestionForStep(int step, int age) {
    if (age <= 9) {
      // Young Child
      switch (step) {
        case 0:
          return "Max 45-60 mins/day. Young children benefit from short, structured sessions with educational focus.";
        case 1:
          return "Complete Social Media block is standard for this age. Focus only on trusted learning and play apps.";
        case 2:
          return "Strict 'Allow-list' recommended. Browsing should be limited to specifically approved educational sites.";
        case 3:
          return "Focus on blocking all mature content and protecting from accidental exposure to graphic materials.";
        case 4:
          return "No need for heavy slang mapping here, but monitoring basic app names ensures they stay on track.";
        default:
          return "Review has been tailored for a curious young mind. Safety is prioritized over flexibility.";
      }
    } else if (age <= 13) {
      // Pre-teen
      switch (step) {
        case 0:
          return "1.5h - 2h is a common standard. Help them balance digital exploration with homework and physical play.";
        case 1:
          return "Monitor social apps closely. This is a key age for managing screen dependency and digital habits.";
        case 2:
          return "Enable SafeSearch strictly. Block adult content while allowing access to school-related resources.";
        case 3:
          return "Prioritize Cyberbullying and Sexual Predator detection as online social interaction increases.";
        case 4:
          return "Adding trendy slang or specific games like 'Roblox' ensures you're aware of their social circles.";
        default:
          return "Balanced rules for a pre-teen. Encouraging discovery within safe, monitored boundaries.";
      }
    } else {
      // Teenager
      switch (step) {
        case 0:
          return "Build trust by focusing on bedtime boundaries rather than hard daily limits. Discuss responsible use.";
        case 1:
          return "Manage high-usage apps but allow most social platforms. Focus on discussion rather than total blocks.";
        case 2:
          return "Discuss online privacy and phishing. Block malicious or gambling sites but allow general information.";
        case 3:
          return "Focus on nuanced monitoring like Anxiety/Depression and Self-Harm signs to support their well-being.";
        case 4:
          return "Monitor for concerning slang or substance references rather than general keywords. Allow privacy but maintain a safety net.";
        default:
          return "Trust-based setup for a teenager. Fosters independence while keeping a safety net for critical risks.";
      }
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
