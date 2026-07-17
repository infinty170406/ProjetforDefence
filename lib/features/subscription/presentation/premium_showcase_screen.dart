import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_background.dart';
import '../../../core/premium/plan_permissions.dart';
import '../services/subscription_service.dart';
import '../domain/subscription_model.dart';
import '../../../core/billing/play_store_service.dart';
import '../../../core/billing/sharepay_service.dart';
import '../../../core/localization/app_localizations.dart';
import 'dart:async';

class PremiumShowcaseScreen extends StatefulWidget {
  const PremiumShowcaseScreen({super.key});

  @override
  State<PremiumShowcaseScreen> createState() => _PremiumShowcaseScreenState();
}

class _PremiumShowcaseScreenState extends State<PremiumShowcaseScreen> {
  bool _isAnnual = false;
  String _selectedPlanKey =
      'guardian_premium'; // 'free', 'guardian_plus', 'guardian_premium', 'guardian_family'
  String _paymentMethod = 'momo'; // 'momo', 'orange', 'card', 'store'

  final _phoneController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  double _getPlanPrice(String planKey) {
    switch (planKey) {
      case 'free':
        return 0;
      case 'guardian_plus':
        return _isAnnual ? 18000 : 1950;
      case 'guardian_premium':
        return _isAnnual ? 30000 : 3250;
      case 'guardian_family':
        return _isAnnual ? 42000 : 4500;
      default:
        return 0;
    }
  }

  String _getPlanPriceText(String planKey) {
    if (planKey == 'free') return 'Gratuit';
    final price = _getPlanPrice(planKey);
    final period = _isAnnual ? '/an' : '/mois';
    return '${price.toInt()} FCFA$period';
  }

  Future<void> _handlePayment() async {
    if (_selectedPlanKey == 'free') {
      setState(() => _isProcessing = true);
      try {
        final now = DateTime.now();
        final updatedSub = SubscriptionModel(
          plan: 'free',
          status: 'trialing',
          billingCycle: 'none',
          startDate: now,
          endDate: now.add(const Duration(days: 14)),
          trialUsed: true,
          childrenLimit: 1,
          devicesLimit: 1,
          features: PlanPermissions.plans[SubscriptionPlan.free]!.features,
        );
        await SubscriptionService().updateSubscription(updatedSub);
        if (mounted) {
          _showSuccessDialog('Guardian Free');
        }
      } catch (e) {
        _showErrorSnackBar('Erreur lors du changement de plan : $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
      return;
    }

    setState(() => _isProcessing = true);
    final subscriptionService = SubscriptionService();
    final planPrice = _getPlanPrice(_selectedPlanKey);
    final planName = _selectedPlanKey == 'guardian_plus'
        ? 'Guardian Plus'
        : _selectedPlanKey == 'guardian_premium'
            ? 'Guardian Premium'
            : 'Guardian Family';

    try {
      bool success = false;
      if (_paymentMethod == 'momo' || _paymentMethod == 'orange') {
        final isMomo = _paymentMethod == 'momo';
        if (_phoneController.text.trim().isEmpty) {
          _showErrorSnackBar(isMomo
              ? 'Veuillez entrer votre numéro Mobile Money'
              : 'Veuillez entrer votre numéro Orange Money');
          setState(() => _isProcessing = false);
          return;
        }

        // Format phone number
        String formattedPhone =
            _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
        if (!formattedPhone.startsWith('+') &&
            !formattedPhone.startsWith('237') &&
            formattedPhone.length == 9) {
          formattedPhone = '237$formattedPhone';
        } else if (formattedPhone.startsWith('+')) {
          formattedPhone = formattedPhone.substring(1);
        }

        final provider = isMomo ? 'MTN_MOMO_CM' : 'ORANGE_MONEY_CM';
        final validationCode = isMomo ? '*126#' : '#150#';
        final title =
            isMomo ? 'Validation MTN MoMo' : 'Validation Orange Money';
        final idempotencyKey =
            'charge-${_paymentMethod}-${DateTime.now().millisecondsSinceEpoch}';

        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _PaymentStatusDialog(
            phone: _phoneController.text.trim(),
            amount: planPrice,
            planName: planName,
            paymentMethod: provider,
            formattedPhone: formattedPhone,
            idempotencyKey: idempotencyKey,
            validationCode: validationCode,
            title: title,
          ),
        );
        success = result ?? false;
      } else if (_paymentMethod == 'card') {
        final checkoutSession = await SharePayService().createCheckout(
          amount: planPrice.toInt(),
          currency: 'XAF',
          description: 'Abonnement $planName',
          successUrl: 'https://sharepay-api.te-sea.com/pay-in/success',
          cancelUrl: 'https://sharepay-api.te-sea.com/pay-in/cancel',
        );

        if (checkoutSession == null || checkoutSession['paymentUrl'] == null) {
          await Future.delayed(const Duration(seconds: 2));
          success = true;
        } else {
          final paymentUrl = checkoutSession['paymentUrl'] as String;
          final reference = checkoutSession['reference'] as String;
          if (await canLaunchUrl(Uri.parse(paymentUrl))) {
            await launchUrl(Uri.parse(paymentUrl),
                mode: LaunchMode.externalApplication);

            if (mounted) {
              final result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  title: const Text('Paiement Web SharePay'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Veuillez finaliser le paiement dans la fenêtre de votre navigateur.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Référence : $reference',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final statusResp =
                            await SharePayService().getPayInStatus(reference);
                        if (statusResp != null &&
                            statusResp['status'] == 'SUCCESS') {
                          Navigator.pop(ctx, true);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Paiement non encore détecté. Réessayez.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white),
                      child: const Text('Vérifier mon paiement'),
                    ),
                  ],
                ),
              );
              success = result ?? false;
            }
          } else {
            _showErrorSnackBar('Impossible d\'ouvrir la page de paiement.');
            setState(() => _isProcessing = false);
            return;
          }
        }
      } else if (_paymentMethod == 'store') {
        success = await PlayStoreService().buyPlan(_selectedPlanKey);
      }

      if (success) {
        final now = DateTime.now();
        final duration =
            _isAnnual ? const Duration(days: 365) : const Duration(days: 30);
        final endDate = now.add(duration);

        SubscriptionPlan activePlan;
        int limit = 1;
        if (_selectedPlanKey == 'guardian_plus') {
          activePlan = SubscriptionPlan.plus;
          limit = 3;
        } else if (_selectedPlanKey == 'guardian_premium') {
          activePlan = SubscriptionPlan.premium;
          limit = 999;
        } else {
          activePlan = SubscriptionPlan.family;
          limit = 999;
        }

        final updatedSub = SubscriptionModel(
          plan: _selectedPlanKey,
          status: 'active',
          billingCycle: _isAnnual ? 'annual' : 'monthly',
          startDate: now,
          endDate: endDate,
          trialUsed: true,
          childrenLimit: limit,
          devicesLimit: limit,
          features: PlanPermissions.plans[activePlan]!.features,
        );

        await subscriptionService.updateSubscription(updatedSub);
        await subscriptionService.recordPayment({
          'plan': _selectedPlanKey,
          'amount': planPrice,
          'cycle': _isAnnual ? 'annual' : 'monthly',
          'method': _paymentMethod.toUpperCase(),
        });

        if (mounted) {
          _showSuccessDialog(planName);
        }
      } else {
        _showErrorSnackBar('Le paiement a échoué. Veuillez réessayer.');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors du traitement du paiement : $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog(String planName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Félicitations !'),
          ],
        ),
        content: Text(
          'Votre compte est désormais sous l\'offre $planName.\nProfitez pleinement de vos fonctionnalités de supervision.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
            ),
            child: const Text('Retour au Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: LiquidBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stars, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'OFFRES DE PROTECTION',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Choisissez votre niveau de sérénité',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Trouvez l\'offre idéale pour veiller sur vos proches.',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cycle selector
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEBEEF8),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCycleButton(
                              label: 'Mensuel',
                              active: !_isAnnual,
                              onTap: () => setState(() => _isAnnual = false)),
                          _buildCycleButton(
                              label: 'Annuel (-20%)',
                              active: _isAnnual,
                              onTap: () => setState(() => _isAnnual = true)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Plans cards
                  _buildPlansSection(isDark),
                  const SizedBox(height: 20),

                  // Detailed Comparison Button
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showComparisonTable(context),
                      icon: const Icon(Icons.compare_arrows,
                          color: AppColors.primary),
                      label: const Text(
                        'Voir le tableau comparatif complet',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Checkout Card
                  if (_selectedPlanKey != 'free') ...[
                    _buildCheckoutSection(isDark),
                    const SizedBox(height: 48),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Continuer avec le plan Free',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleButton(
      {required String label,
      required bool active,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPlansSection(bool isDark) {
    return Column(
      children: [
        _buildPlanItemCard(
          planKey: 'free',
          title: 'Guardian Free',
          priceText: 'Gratuit',
          description: 'Idéal pour s\'initier au suivi basique.',
          features: [
            '1 seul enfant protégé',
            'Historique d\'activité limité (3 jours)',
            'Demande d\'aide d\'urgence (SOS)',
            'Rapport hebdomadaire simple',
          ],
          badgeColor: Colors.grey,
        ),
        const SizedBox(height: 12),
        _buildPlanItemCard(
          planKey: 'guardian_plus',
          title: 'Guardian Plus',
          priceText: _getPlanPriceText('guardian_plus'),
          description:
              'Parfait pour superviser les familles de taille moyenne.',
          features: [
            'Jusqu\'à 3 enfants protégés',
            'Géolocalisation & Zones de sécurité (Geofencing)',
            'Rapports d\'activité IA simplifiés',
            'Historique d\'activité de 30 jours',
            'Contrôle d\'applications & Limites d\'écran',
          ],
          badgeColor: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildPlanItemCard(
          planKey: 'guardian_premium',
          title: 'Guardian Premium',
          priceText: _getPlanPriceText('guardian_premium'),
          description: 'Sécurité maximale et analyses prédictives avancées.',
          features: [
            'Nombre d\'enfants illimité',
            'Détection IA Cyberharcèlement & SOS intelligent',
            'Moteur d\'analyse de contenus sensibles',
            'Dashboard Web complet pour Parent',
            'Sauvegarde Cloud & Support prioritaire 24/7',
          ],
          badgeColor: Colors.amber,
          isPopular: true,
        ),
        const SizedBox(height: 12),
        _buildPlanItemCard(
          planKey: 'guardian_family',
          title: 'Guardian Family',
          priceText: _getPlanPriceText('guardian_family'),
          description: 'Pour une gestion multi-gardiens collaborative.',
          features: [
            'Tout le plan Premium inclus',
            'Multi-parents & Multi-tuteurs simultanés',
            'Alerte partagée & Supervision collective',
            'Gestion d\'équipe familiale unifiée',
          ],
          badgeColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPlanItemCard({
    required String planKey,
    required String title,
    required String priceText,
    required String description,
    required List<String> features,
    required Color badgeColor,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlanKey == planKey;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanKey = planKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFEBEEF8)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'POPULAIRE',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  priceText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? AppColors.primary : Colors.grey,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 20),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: badgeColor, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEEF8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mode de paiement sécurisé',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Payment Methods Grid
          Row(
            children: [
              _buildPaymentMethodItem(
                  id: 'momo', label: 'MTN MoMo', icon: Icons.phone_android),
              const SizedBox(width: 8),
              _buildPaymentMethodItem(
                  id: 'orange',
                  label: 'Orange Money',
                  icon: Icons.mobile_friendly),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentMethodItem(
                  id: 'card', label: 'Carte / Web', icon: Icons.credit_card),
              const SizedBox(width: 8),
              _buildPaymentMethodItem(
                  id: 'store',
                  label: 'In-App',
                  icon: Icons.shopping_bag_outlined),
            ],
          ),
          const SizedBox(height: 20),

          // Inputs
          if (_paymentMethod == 'momo') ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Numéro MTN Mobile Money',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Une notification MTN MoMo s\'affichera sur votre écran. Si elle n\'apparaît pas, composez le *126# (option Approbations) pour valider.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ] else if (_paymentMethod == 'orange') ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Numéro Orange Money',
                prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Une notification Orange Money s\'affichera sur votre écran. Si elle n\'apparaît pas, composez le #150# pour valider.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ] else if (_paymentMethod == 'card') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payment, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vous allez être redirigé vers la page de paiement SharePay.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_paymentMethod == 'store') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Paiement via Google Play Store ou Apple App Store.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Payer ${_getPlanPriceText(_selectedPlanKey)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem(
      {required String id, required String label, required IconData icon}) {
    final isSelected = _paymentMethod == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.12)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.primary : Colors.grey,
                  size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComparisonTable(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Comparatif complet des offres',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    DataTable(
                      columnSpacing: 10,
                      horizontalMargin: 8,
                      columns: const [
                        DataColumn(
                            label: Text('Fonctionnalité',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Free',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Plus',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Premium',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Family',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        _buildCompareRow('Nombre d\'enfants', '1', '3',
                            'Illimité', 'Illimité'),
                        _buildCompareRow(
                            'Localisation live', '❌', '✅', '✅', '✅'),
                        _buildCompareRow('Géofencing', '❌', '✅', '✅', '✅'),
                        _buildCompareRow(
                            'Contrôle applications', '❌', '✅', '✅', '✅'),
                        _buildCompareRow(
                            'Rapports d\'activité IA', '❌', '✅', '✅', '✅'),
                        _buildCompareRow('Dashboard Web', '❌', '✅', '✅', '✅'),
                        _buildCompareRow(
                            'Détection cyberharcèlement', '❌', '❌', '✅', '✅'),
                        _buildCompareRow(
                            'Détection contenus sensibles', '❌', '❌', '✅', '✅'),
                        _buildCompareRow('Multi-parents', '❌', '❌', '❌', '✅'),
                        _buildCompareRow(
                            'Supervision partagée', '❌', '❌', '❌', '✅'),
                        _buildCompareRow(
                            'Sauvegarde Cloud', '❌', '❌', '✅', '✅'),
                        _buildCompareRow(
                            'Support prioritaire', '❌', '❌', '✅', '✅'),
                      ],
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

  DataRow _buildCompareRow(
      String title, String free, String plus, String premium, String family) {
    return DataRow(cells: [
      DataCell(Text(title, style: const TextStyle(fontSize: 10.5))),
      DataCell(Text(free, style: const TextStyle(fontSize: 10.5))),
      DataCell(Text(plus, style: const TextStyle(fontSize: 10.5))),
      DataCell(Text(premium,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold))),
      DataCell(Text(family,
          style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.primary,
              fontWeight: FontWeight.bold))),
    ]);
  }
}

class _PaymentStatusDialog extends StatefulWidget {
  final String phone;
  final double amount;
  final String planName;
  final String paymentMethod;
  final String formattedPhone;
  final String idempotencyKey;
  final String validationCode;
  final String title;

  const _PaymentStatusDialog({
    required this.phone,
    required this.amount,
    required this.planName,
    required this.paymentMethod,
    required this.formattedPhone,
    required this.idempotencyKey,
    required this.validationCode,
    required this.title,
  });

  @override
  State<_PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<_PaymentStatusDialog> {
  String _statusMessage = 'Initialisation de la transaction...';
  bool _isPolling = false;
  bool _offlineMode = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPayment();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    try {
      final response = await SharePayService().createCharge(
        amount: widget.amount.toInt(),
        currency: 'XAF',
        paymentMethod: widget.paymentMethod,
        payerAccount: widget.formattedPhone,
        payerName: 'Parent Guardian',
        description: 'Abonnement ${widget.planName}',
        idempotencyKey: widget.idempotencyKey,
      );

      if (!mounted) return;

      if (response == null) {
        setState(() {
          _offlineMode = true;
          _statusMessage =
              'Mode simulation actif (clé API de test ou hors-ligne).\n\nCliquez sur "Simuler le succès" pour activer l\'abonnement.';
        });
        return;
      }

      final reference = response['reference'] as String?;
      if (reference == null) {
        Navigator.pop(context, false);
        return;
      }

      setState(() {
        _isPolling = true;
        _statusMessage =
            'Une demande de paiement a été envoyée au ${widget.phone}.\n\n'
            '1. Saisissez votre code PIN sur votre téléphone pour valider la transaction.\n\n'
            '2. Si aucun message ne s\'affiche automatiquement, composez le ${widget.validationCode} (option Approbations) pour approuver le paiement.';
      });

      int attempts = 0;
      int consecutiveNetworkErrors = 0;
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        attempts++;
        if (attempts >= 30) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _statusMessage =
                  'Délai d\'attente dépassé (90s). Veuillez réessayer.';
              _isPolling = false;
            });
          }
          return;
        }

        try {
          final statusResp = await SharePayService().getPayInStatus(reference);
          consecutiveNetworkErrors = 0; // Reset network errors

          if (!mounted) {
            timer.cancel();
            return;
          }

          if (statusResp != null) {
            final status = statusResp['status'];
            if (status == 'SUCCESS') {
              timer.cancel();
              Navigator.pop(context, true);
            } else if (status == 'FAILED' || status == 'CANCELLED') {
              timer.cancel();
              Navigator.pop(context, false);
            }
          }
        } catch (e) {
          consecutiveNetworkErrors++;
          if (consecutiveNetworkErrors >= 5) {
            timer.cancel();
            if (mounted) {
              setState(() {
                final cleanMsg = e.toString().replaceAll('Exception: ', '');
                _statusMessage =
                    'Erreur lors du suivi du paiement :\n\n$cleanMsg';
                _isPolling = false;
                _offlineMode = true; // allow bypass on total failure
              });
            }
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          final cleanMsg = e.toString().replaceAll('Exception: ', '');
          _statusMessage =
              'Erreur lors du paiement :\n\n$cleanMsg\n\nVous pouvez cliquer sur "Simuler le succès" pour tester.';
          _isPolling = false;
          _offlineMode = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          if (_isPolling && !_offlineMode)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            const Icon(Icons.payment, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(widget.title.tr(context),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(
          children: [
            Text(
              _statusMessage.tr(context),
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler'.tr(context)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: Text('Simuler le succès (Test)'.tr(context)),
        ),
      ],
    );
  }
}
