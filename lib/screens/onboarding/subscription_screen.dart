import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/storage_service.dart';
import '../../features/subscription/services/subscription_service.dart';
import '../../features/subscription/domain/subscription_model.dart';
import '../../core/premium/plan_permissions.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'free';
  String _premiumDuration = 'monthly';

  final List<Map<String, dynamic>> _premiumOptions = [
    {
      'label': '1 Month',
      'key': 'monthly',
      'price': '3 250 FCFA/mo',
      'badge': null
    },
    {
      'label': '6 Months',
      'key': 'biannual',
      'price': '2 600 FCFA/mo',
      'badge': 'Save 20%'
    },
    {
      'label': '1 Year',
      'key': 'annual',
      'price': '1 950 FCFA/mo',
      'badge': 'Best Value'
    },
  ];

  Future<void> _confirmPlan() async {
    try {
      final now = DateTime.now();
      final duration = _selectedPlan == 'free'
          ? const Duration(days: 14) // 14-day free trial
          : _premiumDuration == 'monthly'
              ? const Duration(days: 30)
              : _premiumDuration == 'biannual'
                  ? const Duration(days: 180)
                  : const Duration(days: 365);

      final endDate = now.add(duration);
      final activePlan = _selectedPlan == 'free'
          ? SubscriptionPlan.free
          : SubscriptionPlan.premium;
      final limit = activePlan == SubscriptionPlan.free ? 1 : 999;

      final updatedSub = SubscriptionModel(
        plan: activePlan.name,
        status: _selectedPlan == 'free' ? 'trialing' : 'active',
        billingCycle: _premiumDuration,
        startDate: now,
        endDate: endDate,
        trialUsed: _selectedPlan != 'free',
        childrenLimit: limit,
        devicesLimit: limit,
        features: PlanPermissions.plans[activePlan]!.features,
      );

      await SubscriptionService().updateSubscription(updatedSub);
      await StorageService().savePlanSelected(true);

      if (mounted) context.go('/dashboard');
    } catch (e) {
      debugPrint('Error confirming plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de la configuration du plan : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shield_outlined,
                              color: AppColors.primary, size: 40),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Choose Your Plan',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Protect your children with The Guardian',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 36),
                  _buildPlanCard(
                    planKey: 'free',
                    title: 'Free Trial',
                    subtitle: '2 weeks — No credit card required',
                    price: 'FREE',
                    priceNote: 'for 14 days',
                    icon: Icons.lock_open_outlined,
                    color: AppColors.accentTeal,
                    features: const [
                      'Basic location tracking',
                      'SOS alerts',
                      'Limited history (3 days)',
                      '1 child profile',
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildPremiumCard(),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirmPlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurface,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50)),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedPlan == 'free'
                            ? 'Start Free Trial'
                            : 'Start Premium',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      _selectedPlan == 'free'
                          ? 'No payment needed. Upgrade anytime.'
                          : 'Secure payment. Cancel anytime.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String planKey,
    required String title,
    required String subtitle,
    required String price,
    required String priceNote,
    required IconData icon,
    required Color color,
    required List<String> features,
  }) {
    final isSelected = _selectedPlan == planKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(price,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(priceNote,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                  SizedBox(height: 12),
                  ...features.map((f) => Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: color, size: 16),
                            SizedBox(width: 8),
                            Text(f,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.70),
                                    fontSize: 13)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard() {
    final isSelected = _selectedPlan == 'premium';
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = 'premium'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.workspace_premium,
                      color: AppColors.primary, size: 22),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    Text('Full protection, unlimited features',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: _premiumOptions.map((opt) {
                final isActive = _premiumDuration == opt['key'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _premiumDuration = opt['key'];
                      _selectedPlan = 'premium';
                    }),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: opt['key'] != 'annual' ? 8 : 0),
                      padding:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (opt['badge'] != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(opt['badge'],
                                  style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          Text(opt['label'],
                              style: TextStyle(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.60),
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              textAlign: TextAlign.center),
                          SizedBox(height: 2),
                          Text(opt['price'],
                              style: TextStyle(
                                  color: isActive
                                      ? Theme.of(context).colorScheme.onSurface
                                      : AppColors.textGray400,
                                  fontSize: 11),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            ...[
              'Unlimited child profiles',
              'Full location history (30 days)',
              'AI-powered activity analysis',
              'Content filtering & app management',
              'Geofencing & safe zones',
              'Priority support',
            ].map((f) => Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 8),
                      Text(f,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.70),
                              fontSize: 13)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
