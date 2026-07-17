import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/controllers/kyc_controller.dart';
import '../../core/models/kyc_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});
  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with TickerProviderStateMixin {
  late final KycController _ctrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = KycController()..init();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _ctrl.addListener(_onStepChanged);
    _fadeCtrl.forward();
  }

  void _onStepChanged() {
    _fadeCtrl.reset();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onStepChanged);
    _ctrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Progression ─────────────────────────────────────────────────────────

  static const int _totalSteps = 7; // steps 1-7 (0=welcome exclus)

  Widget _buildProgressBar(int step) {
    if (step == 0 || step >= 8) return const SizedBox.shrink();
    final progress = step / _totalSteps;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Étape $step sur $_totalSteps',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12)),
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ── Router interne ───────────────────────────────────────────────────────

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return _StepWelcome(ctrl: _ctrl);
      case 1:
        return _StepWhy(ctrl: _ctrl);
      case 2:
        return _StepPrivacy(ctrl: _ctrl);
      case 3:
        return _StepDocChoice(ctrl: _ctrl);
      case 4:
        return _StepTips(ctrl: _ctrl);
      case 5:
        return _StepCapture(ctrl: _ctrl);
      case 6:
        return _StepSelfie(ctrl: _ctrl);
      case 7:
        return _StepAnalysing(ctrl: _ctrl);
      default:
        return _StepResult(ctrl: _ctrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _ctrl,
      child: Consumer<KycController>(
        builder: (context, ctrl, _) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              const LiquidBackground(),
              SafeArea(
                child: Column(
                  children: [
                    // Header avec bouton retour et barre de progression
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          if (ctrl.step > 0 && ctrl.step < 7)
                            IconButton(
                              icon: Icon(Icons.arrow_back,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              onPressed: ctrl.prevStep,
                            )
                          else if (ctrl.step == 0)
                            IconButton(
                              icon: Icon(Icons.close,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              onPressed: () => context.pop(),
                            ),
                        ],
                      ),
                    ),
                    _buildProgressBar(ctrl.step),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fade,
                        child: _buildStep(ctrl.step),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ÉTAPES
// ══════════════════════════════════════════════════════════════════════════════

// ── 0. Bienvenue ─────────────────────────────────────────────────────────────

class _StepWelcome extends StatelessWidget {
  final KycController ctrl;
  const _StepWelcome({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.verified_user_rounded,
      iconColor: AppColors.primary,
      title: 'Vérifiez votre identité',
      subtitle:
          'Pour protéger votre famille, nous avons besoin de confirmer que vous êtes bien le parent responsable du compte.',
      child: _KycPrimaryButton(label: 'Commencer', onTap: ctrl.nextStep),
    );
  }
}

// ── 1. Pourquoi ───────────────────────────────────────────────────────────────

class _StepWhy extends StatelessWidget {
  final KycController ctrl;
  const _StepWhy({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.shield_outlined,
      iconColor: Colors.indigo,
      title: 'Pourquoi cette vérification ?',
      subtitle:
          'La vérification d\'identité garantit que seul un adulte responsable peut surveiller des enfants via The Guardian.',
      child: Column(
        children: [
          _KycBullet(
              icon: Icons.child_care,
              text: 'Protéger les enfants de personnes non autorisées'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.lock_outline,
              text: 'Sécuriser votre compte contre les usurpations'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.gpp_good_outlined,
              text: 'Se conformer aux exigences légales de protection'),
          const SizedBox(height: 24),
          _KycPrimaryButton(label: 'Continuer', onTap: ctrl.nextStep),
        ],
      ),
    );
  }
}

// ── 2. Confidentialité ────────────────────────────────────────────────────────

class _StepPrivacy extends StatelessWidget {
  final KycController ctrl;
  const _StepPrivacy({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.privacy_tip_outlined,
      iconColor: Colors.teal,
      title: 'Vos données sont protégées',
      subtitle: 'Nous prenons la confidentialité très au sérieux.',
      child: Column(
        children: [
          _KycBullet(
              icon: Icons.delete_outline,
              text: 'Votre document est supprimé après analyse'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.security,
              text: 'Stockage chiffré AES-256 pendant le transit'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.policy_outlined,
              text: 'Conforme au RGPD — aucune revente de données'),
          const SizedBox(height: 24),
          _KycPrimaryButton(
              label: 'J\'accepte et je continue', onTap: ctrl.nextStep),
        ],
      ),
    );
  }
}

// ── 3. Choix du document ──────────────────────────────────────────────────────

class _StepDocChoice extends StatelessWidget {
  final KycController ctrl;
  const _StepDocChoice({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.badge_outlined,
      iconColor: Colors.orange,
      title: 'Quel document avez-vous ?',
      subtitle:
          'Choisissez le document d\'identité que vous allez photographier.',
      child: Column(
        children: [
          _DocOptionCard(
            label: 'Carte Nationale d\'Identité',
            icon: Icons.credit_card,
            value: 'CNI',
            selected: ctrl.selectedDocType == 'CNI',
            onTap: () => ctrl.selectDocType('CNI'),
          ),
          const SizedBox(height: 12),
          _DocOptionCard(
            label: 'Passeport',
            icon: Icons.menu_book_outlined,
            value: 'PASSPORT',
            selected: ctrl.selectedDocType == 'PASSPORT',
            onTap: () => ctrl.selectDocType('PASSPORT'),
          ),
          const SizedBox(height: 12),
          _DocOptionCard(
            label: 'Permis de conduire',
            icon: Icons.directions_car_outlined,
            value: 'DRIVERS_LICENSE',
            selected: ctrl.selectedDocType == 'DRIVERS_LICENSE',
            onTap: () => ctrl.selectDocType('DRIVERS_LICENSE'),
          ),
          const SizedBox(height: 24),
          _KycPrimaryButton(label: 'Continuer', onTap: ctrl.nextStep),
        ],
      ),
    );
  }
}

// ── 4. Conseils ───────────────────────────────────────────────────────────────

class _StepTips extends StatelessWidget {
  final KycController ctrl;
  const _StepTips({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.tips_and_updates_outlined,
      iconColor: Colors.amber,
      title: 'Avant de photographier',
      subtitle: 'Quelques conseils pour une photo réussie du premier coup.',
      child: Column(
        children: [
          _KycBullet(
              icon: Icons.wb_sunny_outlined,
              text: 'Bonne lumière naturelle — évitez les ombres'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.flip_camera_android_outlined,
              text: 'Document entier visible — pas de coins coupés'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.pan_tool_alt_outlined,
              text: 'Ne cachez pas le document avec vos doigts'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.invert_colors_off_outlined,
              text: 'Fond uni — évitez les reflets'),
          const SizedBox(height: 10),
          _KycBullet(
              icon: Icons.crop_free, text: 'Restez stable — évitez le flou'),
          const SizedBox(height: 24),
          _KycPrimaryButton(
            label: 'Ouvrir la caméra',
            icon: Icons.camera_alt_outlined,
            onTap: ctrl.captureDocument,
          ),
        ],
      ),
    );
  }
}

// ── 5. Capture (placeholder UI — la vraie capture est déclenchée via captureDocument()) ─

class _StepCapture extends StatelessWidget {
  final KycController ctrl;
  const _StepCapture({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final hasFront = ctrl.documentImageFront != null;
    final isPassport = ctrl.selectedDocType == 'PASSPORT';

    return _KycStepLayout(
      icon: hasFront ? Icons.flip_to_back_rounded : Icons.credit_card_rounded,
      iconColor: AppColors.primary,
      title: hasFront ? 'Photographiez le Verso' : 'Photographiez le Recto',
      subtitle: hasFront
          ? 'Le recto (avant) a été capturé avec succès. Prenez maintenant le verso (dos) de votre carte.'
          : 'Veuillez prendre en photo le devant (recto) de votre document d\'identité.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      hasFront
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: hasFront ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Étape 1 : Recto (Avant)',
                      style: TextStyle(
                        fontWeight:
                            hasFront ? FontWeight.bold : FontWeight.normal,
                        color: hasFront
                            ? Colors.green
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (!isPassport) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Étape 2 : Verso (Arrière)',
                        style: TextStyle(
                          color: hasFront
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey,
                          fontWeight:
                              hasFront ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _KycPrimaryButton(
            label: hasFront ? 'Prendre le Verso' : 'Prendre le Recto',
            icon: Icons.camera_alt_outlined,
            onTap: ctrl.captureDocument,
          ),
          if (hasFront) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: ctrl.retake,
              child: const Text('Recommencer la capture du Recto',
                  style: TextStyle(color: AppColors.statusDanger)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 6. Selfie avec document ──────────────────────────────────────────────────

class _StepSelfie extends StatelessWidget {
  final KycController ctrl;
  const _StepSelfie({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _KycStepLayout(
      icon: Icons.face_retouching_natural_rounded,
      iconColor: AppColors.primary,
      title: 'Prenez un Selfie avec votre document',
      subtitle:
          'Tenez votre document d\'identité à côté de votre visage, sans le cacher. Veillez à ce que votre visage et le document soient bien éclairés.',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outline.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le selfie permet de s\'assurer que vous êtes bien le propriétaire légitime du document d\'identité fourni.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _KycPrimaryButton(
            label: 'Prendre le Selfie',
            icon: Icons.face_retouching_natural_rounded,
            onTap: ctrl.captureDocument,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: ctrl.prevStep,
            child: const Text('Retour à la capture du document',
                style: TextStyle(color: AppColors.textGray400)),
          ),
        ],
      ),
    );
  }
}

// ── 7. Analyse en cours ───────────────────────────────────────────────────────

class _StepAnalysing extends StatelessWidget {
  final KycController ctrl;
  const _StepAnalysing({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 24),
            Text('Analyse en cours…',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Ne fermez pas l\'application',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── 7. Résultat ───────────────────────────────────────────────────────────────

class _StepResult extends StatelessWidget {
  final KycController ctrl;
  const _StepResult({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final result = ctrl.result;
    final status = ctrl.status;

    // Vérification validée ou en attente
    if (status == KycStatus.verified) {
      return _KycStepLayout(
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
        title: 'Identité vérifiée ✓',
        subtitle:
            'Votre compte est sécurisé. Vous pouvez maintenant surveiller vos enfants.',
        child: Column(
          children: [
            _KycPrimaryButton(
                label: 'Accéder au tableau de bord',
                onTap: () => context_go(context, '/dashboard')),
            const SizedBox(height: 16),
            TextButton(
              onPressed: ctrl.resetKycStatus,
              child: const Text('Recommencer la vérification (Test)',
                  style: TextStyle(color: AppColors.textGray400)),
            ),
          ],
        ),
      );
    }

    if (status == KycStatus.pending || (result?.isAccepted ?? false)) {
      return _KycStepLayout(
        icon: Icons.hourglass_top_rounded,
        iconColor: Colors.orange,
        title: 'Document envoyé',
        subtitle:
            'Votre document est en cours de vérification. Vous recevrez une notification dès que c\'est validé.',
        child: Column(
          children: [
            _KycPrimaryButton(
                label: 'Aller au tableau de bord',
                onTap: () => context_go(context, '/dashboard')),
            const SizedBox(height: 16),
            TextButton(
              onPressed: ctrl.resetKycStatus,
              child: const Text('Recommencer la vérification (Test)',
                  style: TextStyle(color: AppColors.textGray400)),
            ),
          ],
        ),
      );
    }

    // Erreur / Rejet
    final error = result?.error;
    return _KycStepLayout(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.statusDanger,
      title: error?.message ?? 'Vérification échouée',
      subtitle: error?.solution ?? 'Veuillez réessayer.',
      child: Column(
        children: [
          if (result?.warnings.isNotEmpty ?? false)
            ...result!.warnings.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(w,
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 13)),
                )),
          const SizedBox(height: 16),
          _KycPrimaryButton(
              label: 'Réessayer', icon: Icons.refresh, onTap: ctrl.retake),
        ],
      ),
    );
  }

  void context_go(BuildContext ctx, String path) => ctx.go(path);
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPOSANTS RÉUTILISABLES
// ══════════════════════════════════════════════════════════════════════════════

class _KycStepLayout extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _KycStepLayout({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.1),
              border: Border.all(color: iconColor.withOpacity(0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 52),
          ),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                  height: 1.5)),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _KycPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _KycPrimaryButton(
      {required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: icon != null
            ? Icon(icon, color: Colors.white)
            : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
      ),
    );
  }
}

class _KycBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _KycBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  height: 1.4)),
        ),
      ],
    );
  }
}

class _DocOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _DocOptionCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 15)),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
