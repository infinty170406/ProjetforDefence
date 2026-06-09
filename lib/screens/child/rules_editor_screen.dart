import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/app_tile_with_details.dart';

class RulesEditorScreen extends StatefulWidget {
  final dynamic child;
  const RulesEditorScreen({super.key, this.child});

  @override
  State<RulesEditorScreen> createState() => _RulesEditorScreenState();
}

class _RulesEditorScreenState extends State<RulesEditorScreen> {
  int _dailyLimitMinutes = 120;
  bool _scheduleEnabled = false;
  TimeOfDay _allowedStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _allowedEnd = const TimeOfDay(hour: 21, minute: 0);
  bool _blockSocialMedia = false;
  bool _blockGaming = false;
  bool _blockAdultContent = true;
  bool _blockViolence = true;
  bool _blockDrugs = true;
  bool _blockSexualPredators = true;
  bool _blockAnxietyDepression = false;
  bool _blockSelfHarm = true;
  bool _blockCyberbullying = true;
  bool _blockMatureContent = false;
  bool _blockEatingDisorders = false;
  bool _monitorAccountActivity = true;
  bool _locationAlerts = true;

  bool _isSaving = false;
  List<String> _installedApps = [];
  List<String> _blockedApps = [];
  List<String> _customKeywords = [];
  final _keywordController = TextEditingController();
  final _appSearchController = TextEditingController();
  final _blockReasonController = TextEditingController();
  String _appSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
    if (childId.isEmpty) return;
    try {
      final snap = await FirestoreService().getRules(childId);
      if (snap.isNotEmpty && mounted) {
        setState(() {
          _dailyLimitMinutes = (snap['dailyLimitMinutes'] ?? 120) as int;
          _blockSocialMedia = snap['blockSocialMedia'] ?? false;
          _blockGaming = snap['blockGaming'] ?? false;
          _blockAdultContent = snap['blockAdultContent'] ?? true;
          _blockViolence = snap['blockViolence'] ?? true;
          _blockDrugs = snap['blockDrugs'] ?? true;
          _blockSexualPredators = snap['blockSexualPredators'] ?? true;
          _blockAnxietyDepression = snap['blockAnxietyDepression'] ?? false;
          _blockSelfHarm = snap['blockSelfHarm'] ?? true;
          _blockCyberbullying = snap['blockCyberbullying'] ?? true;
          _blockMatureContent = snap['blockMatureContent'] ?? false;
          _blockEatingDisorders = snap['blockEatingDisorders'] ?? false;
          _monitorAccountActivity = snap['monitorAccountActivity'] ?? true;
          _locationAlerts = snap['locationAlerts'] ?? true;
          _blockedApps = List<String>.from(snap['blockedApps'] ?? []);
          _customKeywords = List<String>.from(snap['customKeywords'] ?? []);
          if (snap['block_reason'] != null) {
            _blockReasonController.text = snap['block_reason'] as String;
          }

          final start = snap['allowedTimeStart'] as String?;
          final end = snap['allowedTimeEnd'] as String?;
          if (start != null && end != null) {
            _scheduleEnabled = true;
            final sParts = start.split(':');
            final eParts = end.split(':');
            _allowedStart = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
            _allowedEnd = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadInstalledApps() async {
    final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
    if (childId.isEmpty) return;
    try {
      final apps = await ChildMonitorService().getInstalledApps(childId);
      if (mounted) setState(() => _installedApps = apps);
    } catch (_) {}
  }

  bool _isTimeValid() {
    if (!_scheduleEnabled) return true;
    final startMinutes = _allowedStart.hour * 60 + _allowedStart.minute;
    final endMinutes = _allowedEnd.hour * 60 + _allowedEnd.minute;
    return endMinutes > startMinutes;
  }

  Future<void> _save() async {
    if (!_isTimeValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Start time must be before end time."),
          backgroundColor: AppColors.statusDanger,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
      await FirestoreService().saveRules(
        childId,
        blockedApps: _blockedApps,
        dailyLimitMinutes: _dailyLimitMinutes,
        allowedTimeStart: _scheduleEnabled
            ? '${_allowedStart.hour.toString().padLeft(2, '0')}:${_allowedStart.minute.toString().padLeft(2, '0')}'
            : null,
        allowedTimeEnd: _scheduleEnabled
            ? '${_allowedEnd.hour.toString().padLeft(2, '0')}:${_allowedEnd.minute.toString().padLeft(2, '0')}'
            : null,
        blockSocialMedia: _blockSocialMedia,
        blockGaming: _blockGaming,
        blockAdultContent: _blockAdultContent,
        blockViolence: _blockViolence,
        blockDrugs: _blockDrugs,
        blockSexualPredators: _blockSexualPredators,
        blockAnxietyDepression: _blockAnxietyDepression,
        blockSelfHarm: _blockSelfHarm,
        blockCyberbullying: _blockCyberbullying,
        blockMatureContent: _blockMatureContent,
        blockEatingDisorders: _blockEatingDisorders,
        monitorAccountActivity: _monitorAccountActivity,
        locationAlerts: _locationAlerts,
        customKeywords: _customKeywords,
        blockReason: _blockReasonController.text.trim().isEmpty ? null : _blockReasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Rules saved ✓'), backgroundColor: Colors.green));
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

  String _fmtMin(int m) {
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}min';
  }

  void _addEditorKeyword() {
    final kw = _keywordController.text.trim();
    if (kw.isNotEmpty && !_customKeywords.contains(kw)) {
      setState(() {
        _customKeywords = [..._customKeywords, kw];
        _keywordController.clear();
      });
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _appSearchController.dispose();
    _blockReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
                          onPressed: () => context.pop()),
                      Text('Edit Rules',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Limit
                        Text('Daily screen time allocation',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Center(
                            child: Text(_fmtMin(_dailyLimitMinutes),
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold))),
                        Slider(
                          value: _dailyLimitMinutes.toDouble(),
                          min: 15,
                          max: 480,
                          divisions: 31,
                          activeColor: AppColors.primary,
                          inactiveColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                          onChanged: (v) =>
                              setState(() => _dailyLimitMinutes = v.round()),
                        ),
                        SizedBox(height: 24),
                        // Schedule
                        _toggleRow(
                            'Allowed Hours',
                            Icons.schedule,
                            _scheduleEnabled,
                            (v) => setState(() => _scheduleEnabled = v),
                            isDanger: false),
                        if (_scheduleEnabled) ...[
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                  child: _timeTile(
                                      'From',
                                      _allowedStart,
                                      (t) =>
                                          setState(() => _allowedStart = t))),
                              SizedBox(width: 12),
                              Expanded(
                                  child: _timeTile('To', _allowedEnd,
                                      (t) => setState(() => _allowedEnd = t))),
                            ],
                          ),
                        ],
                        SizedBox(height: 24),
                        // Categories
                        _toggleRow(
                            'Block Adult & Pornography',
                            Icons.no_adult_content,
                            _blockAdultContent,
                            (v) => setState(() => _blockAdultContent = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Block Drugs & Alcohol',
                            Icons.medication_outlined,
                            _blockDrugs,
                            (v) => setState(() => _blockDrugs = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Block Violence & Gore',
                            Icons.warning_amber_outlined,
                            _blockViolence,
                            (v) => setState(() => _blockViolence = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Block Sexual Predators',
                            Icons.security_outlined,
                            _blockSexualPredators,
                            (v) => setState(() => _blockSexualPredators = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Monitor Anxiety / Depression',
                            Icons.psychology_outlined,
                            _blockAnxietyDepression,
                            (v) => setState(() => _blockAnxietyDepression = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Monitor Self-Harm / Suicide',
                            Icons.healing_outlined,
                            _blockSelfHarm,
                            (v) => setState(() => _blockSelfHarm = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Monitor Cyberbullying',
                            Icons.gavel_outlined,
                            _blockCyberbullying,
                            (v) => setState(() => _blockCyberbullying = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'Monitor Eating Disorders',
                            Icons.accessibility_new_outlined,
                            _blockEatingDisorders,
                            (v) => setState(() => _blockEatingDisorders = v),
                            isDanger: true),
                        SizedBox(height: 8),
                        _toggleRow(
                            'General Mature Content',
                            Icons.explicit_outlined,
                            _blockMatureContent,
                            (v) => setState(() => _blockMatureContent = v),
                            isDanger: true),
                        SizedBox(height: 24),
                        // Safe Zones Section
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('GEOGRAPHIC SECURITY',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _toggleRow(
                            'Location Alerts',
                            Icons.notifications_active_outlined,
                            _locationAlerts,
                            (v) => setState(() => _locationAlerts = v),
                            isDanger: false),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/safe-zones'),
                          icon: Icon(Icons.map, size: 18),
                          label: Text('Manage Safe Zones'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                            foregroundColor: Theme.of(context).colorScheme.onSurface,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        if (_installedApps.isNotEmpty) ...[
                          SizedBox(height: 32),
                          Row(
                            children: [
                              Icon(Icons.apps, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('APPLICATION CONTROL',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Spacer(),
                              Text('${_blockedApps.length} blocked',
                                style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                            ],
                          ),
                          SizedBox(height: 16),
                          // Search Box for Apps
                          TextField(
                            controller: _appSearchController,
                            onChanged: (v) => setState(() => _appSearchQuery = v.trim().toLowerCase()),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search apps...',
                              hintStyle: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF94A3B8) : AppColors.textGray400),
                              prefixIcon: Icon(Icons.search, color: AppColors.textGray400, size: 18),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          SizedBox(height: 16),
                          ..._installedApps
                            .where((pkg) => pkg.toLowerCase().contains(_appSearchQuery))
                            .map((pkg) {
                            final blocked = _blockedApps.contains(pkg);
                            final childId = widget.child?['id'] ?? widget.child?['childId'] ?? '';
                            return Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: AppTileWithDetails(
                                childId: childId,
                                packageName: pkg,
                                trailing: Switch(
                                  value: blocked,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v) {
                                        _blockedApps = [..._blockedApps, pkg];
                                      } else {
                                        _blockedApps = _blockedApps
                                            .where((p) => p != pkg)
                                            .toList();
                                      }
                                    });
                                  },
                                  activeTrackColor: Colors.redAccent.withValues(alpha: 0.3),
                                  activeThumbColor: Colors.redAccent,
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
                                ),
                              ),
                            );
                          }),
                        ],
                        SizedBox(height: 24),
                        // ── Custom Keywords Section ──────────────────────
                        Row(
                          children: [
                            Icon(Icons.manage_search, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('CUSTOM MONITORING',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Add words or topics to monitor. You will be alerted when they are detected on the device.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12, height: 1.4),
                        ),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _keywordController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Fortnite, gambling...',
                                  hintStyle: TextStyle(color: AppColors.textGray400, fontSize: 13),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onSubmitted: (_) => _addEditorKeyword(),
                              ),
                            ),
                            SizedBox(width: 10),
                            GestureDetector(
                              onTap: _addEditorKeyword,
                              child: Container(
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.add, color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                        if (_customKeywords.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _customKeywords.map((kw) => Container(
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
                                  Text(kw, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
                                  SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _customKeywords = _customKeywords.where((k) => k != kw).toList();
                                    }),
                                    child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), size: 13),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                        SizedBox(height: 24),
                        Row(
                          children: [
                            Icon(Icons.message, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('CUSTOM BLOCK MESSAGE',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Message displayed on the child\'s device when an app or website is blocked.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12, height: 1.4),
                        ),
                        SizedBox(height: 14),
                        TextField(
                          controller: _blockReasonController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'e.g. It\'s time to sleep, put your phone down.',
                            hintStyle: TextStyle(color: AppColors.textGray400, fontSize: 13),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Theme.of(context).colorScheme.onSurface))
                          : Text('Apply Rules',
                              style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _toggleRow(
      String label, IconData icon, bool value, void Function(bool) onChanged,
      {bool isDanger = false}) {
    final activeCol = isDanger ? AppColors.statusDanger : Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), size: 20),
          SizedBox(width: 12),
          Expanded(
              child:
                  Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeCol,
            activeTrackColor: activeCol.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(
      String label, TimeOfDay time, void Function(TimeOfDay) onSet) {
    return GestureDetector(
      onTap: () async {
        final picked =
            await showTimePicker(context: context, initialTime: time);
        if (picked != null) onSet(picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
          SizedBox(height: 4),
          Text(time.format(context),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ]),
      ),
    );
  }
}
