import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/ai/guardian_agent_service.dart';
import '../../core/models/agent/agent_models.dart';
import '../../core/models/alert_model.dart';

/// AiAlertDetailScreen
///
/// Affiche le détail d'une alerte enrichie par l'agent IA (§4) :
/// gravité, fréquence, analyse contextuelle, commentaire en langage naturel,
/// puis propose des actions rapides (§3 — application des règles).
///
/// Reçoit via `extra` une Map : { 'alert': AlertModel, 'child': Map }.
/// Si l'alerte n'a pas encore été analysée par l'agent autonome, l'analyse
/// est demandée à la volée.
class AiAlertDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? args;
  const AiAlertDetailScreen({super.key, this.args});

  @override
  State<AiAlertDetailScreen> createState() => _AiAlertDetailScreenState();
}

class _AiAlertDetailScreenState extends State<AiAlertDetailScreen> {
  final GuardianAgentService _agent = GuardianAgentService();

  AlertModel? _alert;
  Map<String, dynamic>? _child;
  AgentAnalysis? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _alert = widget.args?['alert'] as AlertModel?;
    _child = widget.args?['child'] as Map<String, dynamic>?;
    _loadAnalysis();
  }

  /// Charge l'analyse : depuis les champs déjà enrichis si présents,
  /// sinon en interrogeant l'agent IA en direct.
  Future<void> _loadAnalysis() async {
    final alert = _alert;
    if (alert == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Cas 1 : l'agent autonome a déjà enrichi cette alerte → on réutilise.
    if (alert.hasAiAnalysis) {
      setState(() {
        _analysis = AgentAnalysis(
          risk: RiskLevelX.parse(alert.aiRisk),
          frequency: alert.aiFrequency ?? 'Non déterminée',
          context: alert.aiContext ?? alert.description,
          comment: alert.aiComment ?? '',
          recommendedActions: alert.aiActions,
        );
        _isLoading = false;
      });
      return;
    }

    // Cas 2 : analyse à la volée.
    try {
      final analysis = await _agent.enrichirAlerte(
        childId: _child?['id'] ?? _child?['childId'] ?? '',
        childData: _child ?? {},
        alert: {
          'type': alert.type,
          'detail': alert.description,
          'description': alert.description,
        },
      );
      if (mounted)
        setState(() {
          _analysis = analysis;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAlertContext(),
                        const SizedBox(height: 24),
                        _buildAiAnalysis(),
                        const SizedBox(height: 32),
                        Text('ACTIONS RECOMMANDÉES',
                            style: TextStyle(
                                color: AppColors.textGray500,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        _buildActionButton(
                            'Ajuster les règles',
                            Icons.settings_outlined,
                            AppColors.primary,
                            _onAdjustRules),
                        const SizedBox(height: 12),
                        _buildActionButton(
                            'Réduire le temps d\'écran',
                            Icons.timer_off_outlined,
                            Colors.red,
                            _onReduceLimit),
                        const SizedBox(height: 12),
                        _buildActionButton(
                            'Ignorer cette fois',
                            Icons.check_circle_outline,
                            Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                            () => context.pop()),
                      ],
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

  // ── Actions (§3) ───────────────────────────────────────────────────────────

  void _onAdjustRules() {
    if (_child != null) {
      context.push('/child/rules', extra: _child);
    }
  }

  Future<void> _onReduceLimit() async {
    final childId = _child?['id'] ?? _child?['childId'];
    if (childId == null) return;
    try {
      // Application concrète d'une règle via l'agent (§3).
      await _agent.appliquerRecommandation(
        childId,
        const Recommendation(
          type: 'REDUCE_LIMIT',
          title: 'Réduction du temps d\'écran',
          description: 'Limite réduite suite à l\'analyse de l\'alerte.',
          params: {'minutes': 60},
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite quotidienne réduite à 60 min ✓')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: Icon(Icons.close,
                  color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => context.pop()),
          Text('DÉTAIL DE L\'ALERTE',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAlertContext() {
    final alert = _alert;
    final risk = _analysis?.risk ?? RiskLevel.moderate;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: risk.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child: Icon(Icons.warning_amber_rounded, color: risk.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(alert?.title ?? 'Alerte',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(alert?.description ?? 'Aucun détail disponible.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                  height: 1.5)),
          if (_analysis != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSmallBadge(
                    'Risque: ${_analysis!.risk.label}', _analysis!.risk.color),
                const SizedBox(width: 8),
                Flexible(
                    child: _buildSmallBadge(_analysis!.frequency,
                        Theme.of(context).colorScheme.onSurface)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAiAnalysis() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accentTeal, size: 20),
            const SizedBox(width: 8),
            Text('ANALYSE GUARDIAN',
                style: TextStyle(
                    color: AppColors.accentTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_analysis?.context.isNotEmpty ?? false) ...[
          Text(_analysis!.context,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.5)),
          const SizedBox(height: 10),
        ],
        Text(
            _isLoading
                ? 'Analyse de la situation en cours...'
                : (_analysis?.comment ??
                    'Analyse indisponible pour le moment.'),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                height: 1.6,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GlassCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.24)),
          ],
        ),
      ),
    );
  }
}
