import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/services/open_router_service.dart';

// ── Data model for one child's AI analysis ────────────────────────────────────
class _ChildAnalysis {
  final Map<String, dynamic> child;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> alerts;
  final Map<String, dynamic> rules;
  String aiResponse;
  bool isLoading;
  String? error;

  _ChildAnalysis({
    required this.child,
    required this.stats,
    required this.alerts,
    required this.rules,
    this.aiResponse = '',
    this.isLoading = false,
    this.error,
  });

  String get childId => child['id'] as String? ?? '';
  String get name => child['displayName'] as String? ?? 'Enfant';
  int get age => child['age'] as int? ?? 12;
  String get deviceStatus => child['deviceStatus'] as String? ?? 'OFFLINE';
  int get usedMinutes => stats['usedMinutes'] as int? ?? stats['totalMinutes'] as int? ?? 0;
  int get limitMinutes => rules['dailyLimitMinutes'] as int? ?? 120;
  double get usageRatio => limitMinutes > 0 ? (usedMinutes / limitMinutes).clamp(0, 1) : 0;
  int get alertCount => alerts.length;

  Color get riskColor {
    if (alertCount > 3 || usageRatio > 0.9) return AppColors.statusDanger;
    if (alertCount > 1 || usageRatio > 0.7) return AppColors.statusWarning;
    return AppColors.statusSafe;
  }

  String get riskLabel {
    if (alertCount > 3 || usageRatio > 0.9) return 'RISQUE ÉLEVÉ';
    if (alertCount > 1 || usageRatio > 0.7) return 'ATTENTION';
    return 'SÉCURISÉ';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class DashboardAiOrchestratorScreen extends StatefulWidget {
  const DashboardAiOrchestratorScreen({super.key});

  @override
  State<DashboardAiOrchestratorScreen> createState() => _State();
}

class _State extends State<DashboardAiOrchestratorScreen>
    with TickerProviderStateMixin {
  final _fs = FirestoreService();
  final _monitor = ChildMonitorService();
  final _ai = OpenRouterService();

  List<_ChildAnalysis> _analyses = [];
  bool _initialLoading = true;
  String? _loadError;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── Load all children + their data ──────────────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _initialLoading = true; _loadError = null; _analyses = []; });
    try {
      final children = await _fs.getMyChildren();
      if (children.isEmpty) {
        if (mounted) setState(() => _initialLoading = false);
        return;
      }

      final futures = children.map((child) async {
        final childId = child['id'] as String? ?? '';

        Map<String, dynamic> stats = {};
        Map<String, dynamic> rules = {};
        List<Map<String, dynamic>> alerts = [];

        try {
          stats = await _fs.getTodayStats(childId);
        } catch (_) {}

        try {
          rules = await _fs.getRules(childId);
        } catch (_) {}

        try {
          final snap = await _monitor.getAlertsPaginated(childId, limit: 10);
          alerts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        } catch (_) {}

        return _ChildAnalysis(
          child: child,
          stats: stats,
          rules: rules,
          alerts: alerts,
        );
      });

      final list = await Future.wait(futures);
      if (!mounted) return;
      setState(() { _analyses = list; _initialLoading = false; });

      // Now request AI analysis per child (non-blocking)
      for (final a in _analyses) {
        _analyzeChild(a);
      }
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _initialLoading = false; });
    }
  }

  // ── Send one child's data to OpenRouter ─────────────────────────────────────
  Future<void> _analyzeChild(_ChildAnalysis a) async {
    if (!mounted) return;
    setState(() => a.isLoading = true);

    final alertsText = a.alerts.isEmpty
        ? 'Aucune alerte récente'
        : a.alerts
            .take(5)
            .map((al) => '• ${al['type'] ?? 'INFO'}: ${al['detail'] ?? al['message'] ?? 'N/A'}')
            .join('\n');

    final prompt =
        'Tu es un assistant parental expert en sécurité numérique pour enfants.\n'
        'Analyse le profil de cet enfant et fournis 3 recommandations concrètes, numérotées.\n'
        'Sois bref et précis (max 150 mots). Mets les titres en gras avec **.\n\n'
        'Enfant: ${a.name}, ${a.age} ans\n'
        'Temps d\'écran aujourd\'hui: ${a.usedMinutes} min / limite ${a.limitMinutes} min\n'
        'Appareils: ${a.deviceStatus}\n'
        'Alertes récentes:\n$alertsText';

    try {
      _ai.clearHistory();
      final resp = await _ai.sendMessage(prompt);
      if (!mounted) return;
      setState(() { a.aiResponse = resp; a.isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { a.error = 'Erreur IA: $e'; a.isLoading = false; });
    }
  }

  // ── Quick-action: tighten daily limit ───────────────────────────────────────
  Future<void> _reduceDailyLimit(_ChildAnalysis a) async {
    final current = a.limitMinutes;
    final reduced = (current * 0.75).round().clamp(30, current);
    try {
      final rules = a.rules;
      await _fs.saveRules(
        a.childId,
        dailyLimitMinutes: reduced,
        blockAdultContent: rules['blockAdultContent'] ?? true,
        blockSexualPredators: rules['blockSexualPredators'] ?? true,
        blockSelfHarm: rules['blockSelfHarm'] ?? true,
        blockCyberbullying: rules['blockCyberbullying'] ?? true,
        blockViolence: rules['blockViolence'] ?? true,
        blockDrugs: rules['blockDrugs'] ?? true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Limite réduite à $reduced min pour ${a.name} ✓'),
        backgroundColor: AppColors.statusSuccess,
      ));
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.statusDanger,
      ));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (Theme.of(context).brightness == Brightness.dark)
            const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
          SizedBox(width: 4),
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [AppColors.primary, AppColors.accentTeal],
              ).createShader(r),
              child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 28),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orchestrateur IA',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Analyse intelligente en temps réel',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _initialLoading ? null : _loadAll,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) return _buildLoader();
    if (_loadError != null) return _buildError();
    if (_analyses.isEmpty) return _buildEmpty();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildSummaryRow(),
        SizedBox(height: 20),
        ..._analyses.map((a) => _buildChildCard(a)),
      ],
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _glowAnim.value * 0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            ),
          ),
          SizedBox(height: 20),
          Text('Chargement des données...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.statusDanger, size: 60),
            SizedBox(height: 16),
            Text('Impossible de charger les données',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(_loadError ?? '', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                textAlign: TextAlign.center),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: Icon(Icons.refresh),
              label: Text('Réessayer'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.child_care, color: AppColors.textGray500, size: 72),
          SizedBox(height: 16),
          Text('Aucun enfant associé', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
          SizedBox(height: 8),
          Text('Ajoutez un enfant depuis le tableau de bord.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalAlerts = _analyses.fold(0, (s, a) => s + a.alertCount);
    final highRisk = _analyses.where((a) => a.riskColor == AppColors.statusDanger).length;
    final online = _analyses.where((a) => a.deviceStatus == 'ONLINE').length;

    return Row(
      children: [
        _summaryChip(Icons.notifications_active, '$totalAlerts', 'Alertes', AppColors.statusDanger),
        SizedBox(width: 10),
        _summaryChip(Icons.warning_amber_rounded, '$highRisk', 'Risque élevé', AppColors.statusWarning),
        SizedBox(width: 10),
        _summaryChip(Icons.wifi, '$online', 'En ligne', AppColors.statusSafe),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                SizedBox(height: 4),
                Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildCard(_ChildAnalysis a) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) => Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: a.riskColor.withValues(alpha: _glowAnim.value * 0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    a.riskColor.withValues(alpha: 0.08),
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: a.riskColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChildHeader(a),
                  _buildUsageBar(a),
                  _buildAiSection(a),
                  _buildActionRow(a),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildHeader(_ChildAnalysis a) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: a.riskColor.withValues(alpha: 0.2),
            child: Text(a.name[0].toUpperCase(),
                style: TextStyle(color: a.riskColor, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${a.age} ans • ${a.alertCount} alerte${a.alertCount != 1 ? 's' : ''}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: a.riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: a.riskColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: a.riskColor),
                ),
                SizedBox(width: 5),
                Text(a.riskLabel,
                    style: TextStyle(color: a.riskColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBar(_ChildAnalysis a) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Temps écran: ${a.usedMinutes} min',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), fontSize: 12)),
              Text('/ ${a.limitMinutes} min',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: a.usageRatio,
              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(a.riskColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(_ChildAnalysis a) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.accentTeal],
                ).createShader(r),
                child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onSurface, size: 16),
              ),
              SizedBox(width: 6),
              Text('Analyse IA', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              Spacer(),
              if (!a.isLoading)
                GestureDetector(
                  onTap: () => _analyzeChild(a),
                  child: Icon(Icons.refresh_rounded, color: AppColors.textGray400, size: 16),
                ),
            ],
          ),
          SizedBox(height: 8),
          if (a.isLoading)
            _buildAiLoadingShimmer()
          else if (a.error != null)
            Text(a.error!, style: TextStyle(color: AppColors.statusDanger, fontSize: 12))
          else if (a.aiResponse.isEmpty)
            Text('Analyse en attente...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))
          else
            _buildFormattedAiText(a.aiResponse),
        ],
      ),
    );
  }

  Widget _buildAiLoadingShimmer() {
    const widths = [0.85, 0.65, 0.75];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => FractionallySizedBox(
              widthFactor: widths[i],
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12 * _glowAnim.value),
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFormattedAiText(String text) {
    final parts = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((line) {
        if (line.trim().isEmpty) return SizedBox(height: 4);
        final isBold = line.contains('**');
        final cleaned = line.replaceAll('**', '');
        return Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            cleaned,
            style: TextStyle(
              color: isBold ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              height: 1.4,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionRow(_ChildAnalysis a) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/child/details', extra: a.child),
              icon: Icon(Icons.visibility_outlined, size: 15),
              label: Text('Détails', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70),
                side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/child/rules', extra: a.child),
              icon: Icon(Icons.edit_outlined, size: 15),
              label: Text('Règles', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (a.usageRatio > 0.7) ...[
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _reduceDailyLimit(a),
                icon: Icon(Icons.timer_off_outlined, size: 15),
                label: Text('Réduire', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusDanger,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
