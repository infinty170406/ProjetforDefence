import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../features/subscription/services/subscription_service.dart';
import '../../features/subscription/domain/subscription_model.dart';

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  SubscriptionModel? _subscription;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    try {
      final sub = await SubscriptionService().getSubscription();
      final history = await SubscriptionService().getPaymentHistory();
      setState(() {
        _subscription = sub;
        _paymentHistory = history;
      });
    } catch (e) {
      // Ignore or show snackbar
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Résilier l\'abonnement ?'),
        content: const Text(
          'Vous continuerez à bénéficier des avantages Premium jusqu\'à la fin de votre période de facturation en cours. Souhaitez-vous continuer ?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Retour')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Confirmer la résiliation'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await SubscriptionService().cancelSubscription();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Abonnement résilié avec succès.'),
              backgroundColor: Colors.orange),
        );
        await _loadSubscriptionData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      await SubscriptionService().restoreSubscription();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Votre abonnement a été restauré avec succès !'),
            backgroundColor: Colors.green),
      );
      await _loadSubscriptionData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getPlanDisplayName(String planKey) {
    switch (planKey) {
      case 'free':
        return 'Guardian Free';
      case 'guardian_plus':
        return 'Guardian Plus';
      case 'guardian_premium':
        return 'Guardian Premium';
      case 'guardian_family':
        return 'Guardian Family';
      default:
        return 'Guardian Premium (Trial)';
    }
  }

  Color _getPlanColor(String planKey) {
    switch (planKey) {
      case 'free':
        return Colors.grey;
      case 'guardian_plus':
        return Colors.blue;
      case 'guardian_premium':
        return Colors.amber;
      case 'guardian_family':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = _subscription;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text('Mon Abonnement',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: LiquidBackground()),
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Subscription Card
                      if (sub != null) ...[
                        _buildSubscriptionCard(sub, isDark),
                        const SizedBox(height: 24),
                      ],

                      // Actions Block
                      _buildActionsSection(sub),
                      const SizedBox(height: 32),

                      // History Header
                      Text(
                        'Historique des paiements',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment History List
                      _buildHistorySection(isDark),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(SubscriptionModel sub, bool isDark) {
    final planName = _getPlanDisplayName(sub.plan);
    final planColor = _getPlanColor(sub.plan);
    final dateFormat = DateFormat('dd MMMM yyyy', 'fr_FR');
    final formattedEndDate = dateFormat.format(sub.endDate);
    final statusLabel = sub.status == 'trial'
        ? 'PÉRIODE D\'ESSAI'
        : sub.status == 'active'
            ? 'ACTIF'
            : sub.status == 'cancelled'
                ? 'RÉSIGNE / EXPIRERA'
                : 'EXPIRÉ';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: planColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: planColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (sub.status == 'trial')
                const Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange, size: 14),
                    SizedBox(width: 4),
                    Text('14 jours gratuits',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            planName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                sub.status == 'trial'
                    ? 'Fin de l\'essai le $formattedEndDate'
                    : 'Renouvellement automatique le $formattedEndDate',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
              ),
            ],
          ),
          const Divider(height: 32),
          // Limits Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLimitBadge(
                  'Enfants',
                  sub.childrenLimit == 999
                      ? 'Illimités'
                      : '${sub.childrenLimit} max'),
              _buildLimitBadge(
                  'Appareils',
                  sub.devicesLimit == 999
                      ? 'Illimités'
                      : '${sub.devicesLimit} max'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }

  Widget _buildActionsSection(SubscriptionModel? sub) {
    if (sub == null) return const SizedBox();
    return Column(
      children: [
        // Upgrade button
        if (sub.plan == 'free' || sub.status == 'trial')
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/premium-showcase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Passer à une offre supérieure',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

        // Cancel / Restore buttons
        if (sub.status == 'active') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _handleCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: Colors.redAccent),
                foregroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Résilier l\'abonnement',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ] else if (sub.status == 'cancelled') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleRestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Restaurer l\'abonnement',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistorySection(bool isDark) {
    if (_paymentHistory.isEmpty) {
      // Mock history for preview/trial if empty
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Aucune transaction facturée',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                _subscription?.status == 'trial'
                    ? 'Vous bénéficiez de la période d\'essai gratuite.'
                    : 'Les factures apparaîtront ici après le paiement.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _paymentHistory.map((item) {
        final amount = item['amount'] ?? 0.0;
        final plan = item['plan'] ?? 'guardian_premium';
        final method = item['method'] ?? 'MOBILE';
        final timestamp = item['timestamp'] as Timestamp?;
        final dateStr = timestamp != null
            ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR')
                .format(timestamp.toDate())
            : 'Date inconnue';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEEF8),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payment_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlanDisplayName(plan),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • via $method',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                amount > 0 ? '${amount.toInt()} FCFA' : 'Gratuit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: amount > 0
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.green,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
