import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/liquid_background.dart';
import '../../../core/premium/entitlement_service.dart';
import '../../../core/premium/plan_permissions.dart';
import '../services/subscription_service.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  bool _isProcessing = false;
  List<Map<String, dynamic>> _paymentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await SubscriptionService().getPaymentHistory();
    setState(() {
      _paymentHistory = list;
    });
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Résilier l\'abonnement ?'),
        content: const Text(
          'Êtes-vous sûr de vouloir résilier votre abonnement ? Vous conserverez vos accès premium jusqu\'à la fin de la période de facturation en cours.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50)),
              elevation: 0,
            ),
            child: const Text('Résilier'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      await SubscriptionService().cancelSubscription();
      await _loadHistory();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abonnement résilié avec succès')),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);
    await SubscriptionService().restoreSubscription();
    await _loadHistory();
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Achats restaurés avec succès')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = context.watch<EntitlementService>();
    final sub = entitlement.currentSubscription;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMMM yyyy');

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
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/dashboard');
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mon abonnement',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Current Plan Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFEBEEF8),
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                sub.planEnum.displayName.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    (sub.isActive ? Colors.green : Colors.red)
                                        .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                sub.status == 'trialing'
                                    ? 'Essai Gratuit'
                                    : (sub.status == 'cancelled'
                                        ? 'Résilié'
                                        : 'Actif'),
                                style: TextStyle(
                                  color:
                                      sub.isActive ? Colors.green : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Période de facturation',
                          style: TextStyle(
                              color: AppColors.textGray400, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sub.billingCycle == 'annual'
                              ? 'Annuel (Renouvellement automatique)'
                              : (sub.billingCycle == 'monthly'
                                  ? 'Mensuel'
                                  : 'Aucun (Essai gratuit)'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date de début',
                                    style: TextStyle(
                                        color: AppColors.textGray400,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(sub.startDate),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sub.status == 'cancelled'
                                        ? 'Fin d\'accès'
                                        : 'Renouvellement',
                                    style: const TextStyle(
                                        color: AppColors.textGray400,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(sub.endDate),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32, thickness: 1),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => context.push('/premium-showcase'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50)),
                                ),
                                child: const Text(
                                  'Changer d\'offre',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            if (sub.plan != 'free' &&
                                sub.status != 'cancelled') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isProcessing ? null : _handleCancel,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withOpacity(0.1),
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Résilier',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildPlanComparison(sub.planEnum, isDark),
                  const SizedBox(height: 28),

                  // Actions Section
                  Text(
                    'Options d\'abonnement',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFEBEEF8),
                      ),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.restore,
                              color: AppColors.primary),
                          title: const Text('Restaurer les achats'),
                          subtitle: const Text(
                              'Re-synchronise vos abonnements Google Play/App Store'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _isProcessing ? null : _handleRestore,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Payment History
                  Text(
                    'Historique de facturation',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _paymentHistory.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text(
                              'Aucune transaction enregistrée',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFEBEEF8),
                            ),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _paymentHistory.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _paymentHistory[index];
                              final amount = item['amount'] ?? 0.0;
                              final plan = item['plan'] == 'guardian_plus'
                                  ? 'Plus'
                                  : 'Premium';
                              final dateText = item['timestamp'] != null
                                  ? dateFormat.format(
                                      (item['timestamp'] as Timestamp).toDate())
                                  : '';
                              return ListTile(
                                leading: const Icon(Icons.receipt_long_outlined,
                                    color: Colors.green),
                                title: Text('Mise à niveau $plan'),
                                subtitle: Text(
                                    '$dateText via ${item['method'] ?? 'MOMO'}'),
                                trailing: Text(
                                  '${amount.toInt()} FCFA',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanComparison(SubscriptionPlan activePlan, bool isDark) {
    final plans = [
      _PlanDetails(
        plan: SubscriptionPlan.free,
        title: 'Guardian Free',
        price: 'Gratuit',
        color: Colors.grey,
        features: [
          '1 enfant & 1 appareil maximum',
          'Temps d\'écran de base',
          'Historique d\'activité de 3 jours',
        ],
      ),
      _PlanDetails(
        plan: SubscriptionPlan.plus,
        title: 'Guardian Plus',
        price: '1 950 FCFA/mois',
        color: AppColors.primary,
        features: [
          'Jusqu\'à 3 enfants & 3 appareils',
          'Localisation GPS en temps réel & Geofencing',
          'Rapports d\'analyse & Orchestrateur IA',
          'Historique d\'activité de 30 jours',
        ],
      ),
      _PlanDetails(
        plan: SubscriptionPlan.premium,
        title: 'Guardian Premium',
        price: '3 250 FCFA/mois',
        color: Colors.amber.shade700,
        features: [
          'Enfants & Appareils illimités',
          'Détection du harcèlement (Cyberintimidation)',
          'Historique d\'activité complet de 365 jours',
          'Assistant IA avancé & support prioritaire',
        ],
      ),
      _PlanDetails(
        plan: SubscriptionPlan.family,
        title: 'Guardian Family',
        price: '4 500 FCFA/mois',
        color: AppColors.accentTeal,
        features: [
          'Toutes les fonctionnalités Premium incluses',
          'Gestion de la co-parentalité',
          'Partage familial des alertes et règles',
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparer les offres',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...plans.map((p) {
          final isActive = p.plan == activePlan;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? p.color
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFEBEEF8)),
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: p.color.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Actif',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      p.price,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: p.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...p.features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: p.color, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PlanDetails {
  final SubscriptionPlan plan;
  final String title;
  final String price;
  final Color color;
  final List<String> features;

  _PlanDetails({
    required this.plan,
    required this.title,
    required this.price,
    required this.color,
    required this.features,
  });
}
