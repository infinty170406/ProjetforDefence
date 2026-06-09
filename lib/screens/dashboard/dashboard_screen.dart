import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/sos_notification.dart';
import '../../services/sos_service.dart';
import '../../services/monitoring_service.dart';
import '../../services/background_service.dart';
import '../../services/package_service.dart';
import '../restrictions/blocking_screen.dart';

/// DashboardScreen
///
/// Interface principale de l'app enfant selon le CDC :
///   1. Statut de connexion
///   2. Règles actives (info transparente pour l'enfant)
///   3. Bouton SOS
///   4. Bouton de sync manuelle
///
/// Écoute [BlockEventService.stream] pour naviguer automatiquement
/// vers [BlockingScreen] quand l'EnforcementService détecte une violation.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pingController;
  StreamSubscription<String>? _blockSub;
  bool _sosSending = false;
  bool _sosJustSent = false;

  @override
  void initState() {
    super.initState();
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Consommer un éventuel événement de blocage en attente (cold start)
    // Utilise consumePendingAsync pour lire aussi SharedPreferences
    // au cas où l'EventChannel n'était pas prêt quand le blocage est arrivé
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pending = await BlockEventService.consumePendingAsync();
      if (pending != null && mounted) _navigateToBlock(pending);

      // Force la synchronisation des applications installées pour que 
      // l'application parente puisse recevoir les vrais noms et icônes
      // juste après l'appairage. (Appelé sur le main thread)
      PackageService().syncInstalledApps();
    });

    // Écouter les blocages en temps réel
    _blockSub = BlockEventService.stream.listen(_navigateToBlock);

    // Observer le cycle de vie pour relire SharedPreferences quand l'app reprend
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'app vient de reprendre le focus (ex: après blocage AccessibilityService)
      // Lire SharedPreferences au cas où un SHOW_BLOCK est en attente
      BlockEventService.consumePendingAsync().then((pending) {
        if (pending != null && mounted) _navigateToBlock(pending);
      });
    }
  }

  void _navigateToBlock(String reason) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => BlockingScreen(reason: reason)),
      (route) => false,
    );
  }

  Future<void> _handleSos() async {
    if (_sosSending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Envoyer une alerte SOS ?',
            style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: Text(
          'Vos parents recevront immédiatement votre position et une alerte.',
          style: TextStyle(color: Colors.grey[400], height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusDanger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Envoyer',
                style: TextStyle(
                    color: AppColors.textDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _sosSending = true);

    final success = await SosService().sendSos();
    
    if (mounted) {
      setState(() {
        _sosSending = false;
        _sosJustSent = success;
      });

      // Retour tactile
      if (success) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.vibrate();
      }

      // Afficher la notification premium
      SosNotificationOverlay.show(
        context,
        success: success,
        message: success
            ? 'Vos parents ont été alertés et ont reçu votre position actuelle.'
            : 'Échec de l\'envoi. Vérifiez votre connexion internet.',
      );

      if (success) {
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) setState(() => _sosJustSent = false);
      }
    }
  }

  @override
  void dispose() {
    _pingController.dispose();
    _blockSub?.cancel();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(appState),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        if (!appState.hasUsagePermission)
                          _buildPermissionWarning(
                            title: 'Accès aux données d\'usage',
                            description: 'Requis pour détecter l\'utilisation des applications.',
                            onPressed: () => appState.requestUsagePermission(),
                          ),
                        if (!appState.hasAccessibilityPermission)
                          _buildPermissionWarning(
                            title: 'Service d\'accessibilité',
                            description: 'Requis pour bloquer instantanément les applications.',
                            onPressed: () => appState.requestAccessibilityPermission(),
                          ),
                        if (!appState.hasOverlayPermission)
                          _buildPermissionWarning(
                            title: 'Affichage par-dessus les autres',
                            description: 'Requis pour afficher l\'écran de blocage.',
                            onPressed: () => appState.requestOverlayPermission(),
                          ),
                        const SizedBox(height: 16),
                        _buildStatusCard(appState),
                        const SizedBox(height: 20),
                        _buildActiveRulesCard(appState),
                        const SizedBox(height: 20),
                        _buildSosButton(),
                        const SizedBox(height: 20),
                        _buildSyncButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppState appState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The Guardian',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  if (appState.childName.isNotEmpty)
                    Text(appState.childName,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ],
          ),
          _buildOnlineBadge(appState.isOnline),
        ],
      ),
    );
  }

  Widget _buildPermissionWarning({
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusDanger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.statusDanger, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusDanger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Activer dans les paramètres',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineBadge(bool isOnline) {
    return AnimatedBuilder(
      animation: _pingController,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              if (isOnline)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentTeal.withValues(
                        alpha: 0.5 * (1 - _pingController.value)),
                  ),
                ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isOnline ? AppColors.accentTeal : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Text(
            isOnline ? 'EN LIGNE' : 'HORS LIGNE',
            style: TextStyle(
              color:
                  isOnline ? AppColors.accentTeal : Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte statut ──────────────────────────────────────────────────────────

  Widget _buildStatusCard(AppState appState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appareil protégé',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Surveillance et enforcement actifs.',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.2)),
            ),
            child: const Text('ACTIF',
                style: TextStyle(
                    color: AppColors.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  // ── Carte règles actives ──────────────────────────────────────────────────

  Widget _buildActiveRulesCard(AppState appState) {
    final rules = appState.activeRules;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textDark.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_outlined,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      size: 17),
                  const SizedBox(width: 8),
                  Text('Règles parentales actives',
                      style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              // Badge : nombre de règles ou "Aucune"
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rules.hasAnyRule
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  rules.hasAnyRule ? 'Actives' : 'Aucune',
                  style: TextStyle(
                    color: rules.hasAnyRule
                        ? AppColors.primary
                        : Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!rules.hasAnyRule)
            Text('Aucune restriction configurée par vos parents.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13))
          else
            Column(
              children: [
                // Limite journalière
                if (rules.dailyLimitMinutes > 0)
                  _RuleRow(
                    icon: Icons.access_time_outlined,
                    label: 'Limite journalière',
                    value: '${rules.dailyLimitMinutes} min',
                  ),
                // Plages horaires
                if (rules.allowedTimeStart != null &&
                    rules.allowedTimeEnd != null) ...[
                  if (rules.dailyLimitMinutes > 0)
                    const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.schedule_outlined,
                    label: 'Heures autorisées',
                    value:
                        '${rules.allowedTimeStart} – ${rules.allowedTimeEnd}',
                  ),
                ],
                // Apps bloquées
                if (appState.blockedAppCount > 0) ...[
                  const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.block_outlined,
                    label: 'Applications bloquées',
                    value: '${appState.blockedAppCount} app(s)',
                  ),
                ],
                // Catégories
                if (rules.blockSocialMedia || rules.blockGaming) ...[
                  const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.category_outlined,
                    label: 'Catégories bloquées',
                    value: [
                      if (rules.blockSocialMedia) 'Réseaux sociaux',
                      if (rules.blockGaming) 'Jeux',
                    ].join(', '),
                  ),
                ],
                // [NEW] Filtrage Web
                if (appState.blockedWebsiteCount > 0 || appState.isWebFilteringActive) ...[
                  const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.public_outlined,
                    label: 'Filtrage Web',
                    value: appState.isWebFilteringActive 
                      ? 'Actif (+${appState.blockedWebsiteCount} sites)' 
                      : '${appState.blockedWebsiteCount} site(s) bloqué(s)',
                  ),
                ],
                // [NEW] Mots-clés
                if (appState.keywordCount > 0) ...[
                  const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.key_outlined,
                    label: 'Mots-clés surveillés',
                    value: '${appState.keywordCount} actif(s)',
                  ),
                ],
                // [NEW] Zones GPS
                if (appState.geofenceSummary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _RuleRow(
                    icon: Icons.location_on_outlined,
                    label: 'Zones de sécurité',
                    value: appState.geofenceSummary,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  // ── Bouton SOS ────────────────────────────────────────────────────────────

  Widget _buildSosButton() {
    return Column(
      children: [
        Text(
          'EN CAS D\'URGENCE',
          style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _sosSending ? null : _handleSos,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: _sosJustSent
                  ? AppColors.statusSuccess.withValues(alpha: 0.12)
                  : AppColors.statusDanger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _sosJustSent
                    ? AppColors.statusSuccess.withValues(alpha: 0.35)
                    : AppColors.statusDanger.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_sosJustSent
                          ? AppColors.statusSuccess
                          : AppColors.statusDanger)
                      .withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sosSending)
                  const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppColors.statusDanger, strokeWidth: 2.5))
                else
                  Icon(
                    _sosJustSent
                        ? Icons.check_circle_outline
                        : Icons.emergency_outlined,
                    color: _sosJustSent
                        ? AppColors.statusSuccess
                        : AppColors.statusDanger,
                    size: 26,
                  ),
                const SizedBox(width: 12),
                Text(
                  _sosSending
                      ? 'Envoi en cours…'
                      : _sosJustSent
                          ? 'Alerte envoyée'
                          : 'Bouton SOS',
                  style: TextStyle(
                    color: _sosJustSent
                        ? AppColors.statusSuccess
                        : AppColors.statusDanger,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Appuyez en cas d\'urgence — vos parents\nseront alertés immédiatement.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.grey[700], fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  // ── Bouton de sync ────────────────────────────────────────────────────────

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: () async {
        await MonitoringService().forceSyncNow();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Synchronisation effectuée.'),
            duration: Duration(seconds: 2),
          ));
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync,
                color: AppColors.primary.withValues(alpha: 0.8),
                size: 16),
            const SizedBox(width: 8),
            Text(
              'Synchroniser les données',
              style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget _RuleRow ───────────────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RuleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ),
        Text(
          value,
          style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
