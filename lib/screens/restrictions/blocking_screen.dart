import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../dashboard/dashboard_screen.dart';

/// BlockingScreen
///
/// Écran infranchissable affiché quand une règle parentale est enfreinte :
///   - App bloquée détectée au premier plan
///   - Limite journalière de temps d'écran atteinte
///   - Utilisation hors de la plage horaire autorisée
///
/// La navigation arrière est désactivée (PopScope canPop: false).
/// L'écran se déverrouille automatiquement si le parent modifie les règles
/// (ex: accorde du temps supplémentaire, retire le blocage).
class BlockingScreen extends StatefulWidget {
  final String reason;

  const BlockingScreen({super.key, required this.reason});

  @override
  State<BlockingScreen> createState() => _BlockingScreenState();
}

class _BlockingScreenState extends State<BlockingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  Timer? _refreshTimer;
  Timer? _unlockCheckTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addObserver(this);

    // Timer pour rafraîchir le compteur chaque seconde
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Vérifier toutes les 10s si les règles ont changé
    _unlockCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkIfUnlocked(),
    );
  }

  void _checkIfUnlocked() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    
    // Si l'app est juste bloquée par package (WhatsApp etc), widget.reason contient le nom
    // On ne débloque automatiquement que pour le temps et les horaires.
    if (!appState.isScreenTimeLimitReached && !appState.isOutsideAllowedHours) {
       // On vérifie si c'est un blocage d'app spécifique (pas de countdown possible)
       if (widget.reason.contains('Cette application est bloquée')) {
         // On reste ici, c'est l'AccessibilityService qui nous fermera si on quitte l'app
         return;
       }
      _goToDashboard();
    }
  }

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    _unlockCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si l'enfant tente de quitter l'écran de blocage (Home/Recents),
    // on demande au système de ramener l'app au premier plan après un court délai.
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      debugPrint('BlockingScreen: Child attempted to leave. Requesting foreground...');
      const MethodChannel('app.theguardian.child/system')
          .invokeMethod('bringToForeground');
    }
  }

  String _formatCountdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return "00:00:00";
    
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final nextUnlock = appState.nextUnlockTime;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.8,
              colors: [
                AppColors.statusDanger.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/Rectangle 69.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'The Guardian',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenu central
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icône de blocage avec pulse (SANS secousses)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              ScaleTransition(
                                scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                                  CurvedAnimation(
                                    parent: _pulseController,
                                    curve: Curves.easeInOut,
                                  ),
                                ),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.statusDanger.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.statusDanger.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: AppColors.statusDanger.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.statusDanger,
                                  size: 50,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 36),
                          const Text(
                            'Accès restreint',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Raison du blocage
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.statusDanger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.statusDanger.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              widget.reason,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // COMPTEUR DE DÉBLOCAGE
                          if (nextUnlock != null) ...[
                            Text(
                              'DÉVERROUILLAGE DANS',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCountdown(nextUnlock),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),
                          Text(
                            'Contactez vos parents pour modifier\nles restrictions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Pied de page
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[850]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.autorenew,
                                color: Colors.grey[600], size: 15),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Déverrouillage automatique si les règles changent',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
