import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/ai/guardian_agent_service.dart';
import '../../core/models/agent/agent_models.dart';

/// WeeklyReportScreen
///
/// Présente le rapport d'activité hebdomadaire généré par l'agent IA (§7) :
/// temps d'écran total et moyen, applications les plus utilisées, nombre
/// d'alertes, analyse de l'évolution et conseils personnalisés.
///
/// Reçoit l'enfant via `extra`. Si aucun enfant n'est fourni, sélectionne
/// automatiquement le premier enfant du parent.
class WeeklyReportScreen extends StatefulWidget {
  final dynamic child;
  const WeeklyReportScreen({super.key, this.child});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final GuardianAgentService _agent = GuardianAgentService();
  final FirestoreService _fs = FirestoreService();

  WeeklyReport? _report;
  bool _loading = true;
  String? _error;
  String _childName = 'Enfant';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Résolution de l'enfant cible (param ou premier enfant du parent).
      dynamic child = widget.child;
      if (child == null) {
        final children = await _fs.getMyChildren();
        if (children.isNotEmpty) child = children.first;
      }

      if (child == null) {
        setState(() {
          _error = 'Aucun enfant associé.';
          _loading = false;
        });
        return;
      }

      final childId = child['id'] ?? child['childId'] ?? '';
      _childName = child['displayName'] ?? 'Enfant';
      final age = (child['age'] as int?) ?? 12;

      final report = await _agent.genererRapportHebdomadaire(
        childId: childId,
        name: _childName,
        age: age,
      );
      if (mounted)
        setState(() {
          _report = report;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rapport hebdomadaire',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text(_childName,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Régénérer',
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loading ? null : _generate,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text('Génération du rapport par Guardian IA...',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.statusDanger, size: 56),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final r = _report!;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    final statsRow = Row(
      children: [
        _statCard('Temps total', '${r.totalMinutes} min', Icons.schedule,
            AppColors.primary),
        const SizedBox(width: 10),
        _statCard('Moyenne/jour', '${r.dailyAverage} min', Icons.trending_up,
            AppColors.accentTeal),
        const SizedBox(width: 10),
        _statCard('Alertes', '${r.alertsCount}', Icons.notifications_active,
            AppColors.statusWarning),
      ],
    );

    final appsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Applications les plus utilisées',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: r.topApps.isEmpty
              ? Text('Aucune donnée d\'usage sur la semaine.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
              : Column(
                  children: r.topApps.map((e) {
                    final max = r.topApps.first.value;
                    final ratio = max > 0 ? e.value / max : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(e.key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontSize: 13)),
                              ),
                              Text('${e.value} min',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );

    final evolutionSection = _sectionCard(
      icon: Icons.auto_awesome,
      title: 'Évolution des comportements',
      child: Text(r.evolution,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              height: 1.5)),
    );

    final adviceSection = r.advice.isEmpty
        ? const SizedBox.shrink()
        : _sectionCard(
            icon: Icons.lightbulb_outline,
            title: 'Conseils personnalisés',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: r.advice
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.accentTeal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 13.5,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          );

    if (isWide) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: stats + apps
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statsRow,
                        const SizedBox(height: 24),
                        appsSection,
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Right Column: AI analysis & Advice
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        evolutionSection,
                        const SizedBox(height: 16),
                        adviceSection,
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        statsRow,
        const SizedBox(height: 20),
        appsSection,
        const SizedBox(height: 20),
        evolutionSection,
        const SizedBox(height: 16),
        adviceSection,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
      {required IconData icon, required String title, required Widget child}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentTeal, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: AppColors.accentTeal,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
