import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../dashboard/dashboard_screen.dart';
import '../../services/rules_service.dart';

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

  late ActiveRules _initialRules;
  String _parentPhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _loadParentPhone();
    // Enregistre les règles au moment du blocage pour détecter un changement
    _initialRules = context.read<AppState>().activeRules;
    debugPrint('BlockingScreen: Shown with reason: ${widget.reason}');

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

  Future<void> _loadParentPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _parentPhoneNumber = prefs.getString('parent_emergency_phone') ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveParentPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('parent_emergency_phone', phone);
      if (mounted) {
        setState(() {
          _parentPhoneNumber = phone;
        });
      }
    } catch (_) {}
  }

  Future<void> _triggerCall(String number) async {
    try {
      await const MethodChannel('app.theguardian.child/system')
          .invokeMethod('makeEmergencyCall', {'phoneNumber': number});
    } catch (e) {
      debugPrint('BlockingScreen: Error triggering call: $e');
    }
  }

  void _showEmergencySheet() {
    final phoneController = TextEditingController(text: _parentPhoneNumber);
    bool isEditing = _parentPhoneNumber.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
              decoration: const BoxDecoration(
                color: Color(0xFF161616),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusDanger.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_in_talk, color: AppColors.statusDanger, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Appel d\'urgence & SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'En cas de danger ou d\'urgence, vous pouvez appeler immédiatement les secours ou vos parents.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _triggerCall('112');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3333),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFFFF3333).withValues(alpha: 0.3),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Appeler les secours (112)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isEditing) ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _triggerCall(_parentPhoneNumber);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people, color: AppColors.accentTeal, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Appeler Parent ($_parentPhoneNumber)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          isEditing = true;
                        });
                      },
                      child: const Text(
                        'Modifier le numéro du parent',
                        style: TextStyle(color: AppColors.textGray400, fontSize: 13),
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Entrez le numéro du parent',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          icon: const Icon(Icons.phone, color: AppColors.textGray400, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final phone = phoneController.text.trim();
                        if (phone.isNotEmpty) {
                          _saveParentPhone(phone);
                          setModalState(() {
                            isEditing = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Enregistrer et appeler',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (_parentPhoneNumber.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            isEditing = false;
                          });
                        },
                        child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _checkIfUnlocked() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    
    // Si ce n'est pas un blocage lié au temps ou à l'heure, 
    // on vérifie si la configuration des apps a changé.
    if (!appState.isScreenTimeLimitReached && !appState.isOutsideAllowedHours) {
       if (widget.reason.contains('Cette application est bloquée')) {
         // Si les règles de packages ont changé, le parent a peut-être débloqué l'app.
         // On quitte l'écran. Si l'enfant retourne sur l'app interdite, 
         // l'EnforcementService le bloquera de nouveau.
         if (appState.activeRules.blockedApps.length != _initialRules.blockedApps.length ||
             appState.activeRules.blockSocialMedia != _initialRules.blockSocialMedia ||
             appState.activeRules.blockGaming != _initialRules.blockGaming) {
           _goToDashboard();
         }
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
                          
                          // SOS Emergency Call Button
                          ElevatedButton.icon(
                            onPressed: _showEmergencySheet,
                            icon: const Icon(Icons.phone_in_talk, size: 20),
                            label: const Text(
                              'Appel d\'urgence / SOS',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusDanger.withValues(alpha: 0.15),
                              foregroundColor: AppColors.statusDanger,
                              minimumSize: const Size(220, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                                side: BorderSide(color: AppColors.statusDanger.withValues(alpha: 0.35), width: 1.5),
                              ),
                              elevation: 0,
                            ),
                          ),

                          const SizedBox(height: 20),
                          Text(
                            'Contactez vos parents pour modifier\nles restrictions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              height: 1.4,
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
