import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/open_router_service.dart';

class AiAlertDetailScreen extends StatefulWidget {
  const AiAlertDetailScreen({super.key});

  @override
  State<AiAlertDetailScreen> createState() => _AiAlertDetailScreenState();
}

class _AiAlertDetailScreenState extends State<AiAlertDetailScreen> {
  String? _aiAnalysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAiAnalysis();
  }

  Future<void> _fetchAiAnalysis() async {
    const prompt = "Analyze this parental control situation: 'Leo has been using his phone for more than 45 minutes after the scheduled bedtime (21:30) on YouTube. Battery is at 12%.' Give a short analysis and a recommendation as if you were a benevolent AI assistant named Guardian.";

    final result = await OpenRouterService ().sendMessage(prompt);

    if (mounted) {
      setState(() {
        _aiAnalysis = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
                        const Text('RECOMMENDED ACTIONS',
                            style: TextStyle(
                                color: AppColors.textGray500,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 16),
                        _buildActionButton('Adjust rule',
                            Icons.settings_outlined, AppColors.primary),
                        const SizedBox(height: 12),
                        _buildActionButton('Block immediately',
                            Icons.block_flipped, Colors.red),
                        const SizedBox(height: 12),
                        _buildActionButton('Ignore this time',
                            Icons.check_circle_outline, Colors.white24),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop()),
          const Text('ALERT DETAILS',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildAlertContext() {
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text('Nighttime Usage',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
              'Leo has been using his phone for more than 45 minutes after the scheduled bedtime (21:30).',
              style: TextStyle(
                  color: AppColors.textGray400, fontSize: 15, height: 1.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSmallBadge('App: YouTube', Colors.red),
              const SizedBox(width: 8),
              _buildSmallBadge('Battery: 12%', Colors.white),
            ],
          ),
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
            const Icon(Icons.auto_awesome, color: AppColors.accentTeal, size: 20),
            const SizedBox(width: 8),
            const Text('GUARDIAN ANALYSIS',
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
            _isLoading
                ? 'Analyzing the situation...'
                : (_aiAnalysis ?? 'Unable to generate analysis at this time.'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return GlassCard(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
