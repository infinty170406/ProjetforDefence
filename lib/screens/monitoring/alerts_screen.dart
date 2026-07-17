import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/models/alert_model.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/timezone_helper.dart';

class AlertsScreen extends StatefulWidget {
  final dynamic child;
  const AlertsScreen({super.key, this.child});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'ALL'; // ALL, SOS, BLOCKED_APP, TIME_LIMIT, OUTSIDE_HOURS

  String get _childId => widget.child?['id'] ?? widget.child?['childId'] ?? '';
  String get _childName => widget.child?['displayName'] ?? 'Child';
  String? get _parentId => widget.child?['parentId'] as String?;

  @override
  void initState() {
    super.initState();
    if (_childId.isNotEmpty) {
      ChildMonitorService().markAllAlertsRead(_childId, parentId: _parentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return Scaffold(
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isWide ? 1200 : double.infinity),
                child: Column(
                  children: [
                    _buildHeader(context),
                    _buildFilterBar(),
                    Expanded(child: _buildAlertsList()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerts',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _childName,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      ('ALL', 'All', Icons.list),
      ('SOS', 'SOS', Icons.emergency),
      ('BLOCKED_APP', 'Apps', Icons.block),
      ('TIME_LIMIT', 'Time', Icons.timer_off),
      ('OUTSIDE_HOURS', 'Schedule', Icons.nights_stay),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(f.$3,
                        size: 14,
                        color: isSelected
                            ? Colors.black
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.70)),
                    const SizedBox(width: 6),
                    Text(
                      f.$2,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertsList() {
    if (_childId.isEmpty) {
      return Center(
        child: Text('Child not found',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final width = MediaQuery.of(context).size.width;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChildMonitorService().watchAlerts(_childId, parentId: _parentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red)),
          );
        }

        final rawAlerts = snapshot.data ?? [];
        final alerts =
            rawAlerts.map((data) => AlertModel.fromJson(data)).toList();

        final filteredAlerts = _filter == 'ALL'
            ? alerts
            : alerts.where((a) => a.type == _filter).toList();

        if (filteredAlerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    color: AppColors.primary, size: 64),
                const SizedBox(height: 16),
                Text('No alerts found',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18)),
              ],
            ),
          );
        }

        if (width < 600) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filteredAlerts.length,
            itemBuilder: (context, index) {
              final alert = filteredAlerts[index];
              return _buildAlertCard(alert);
            },
          );
        } else {
          final int cols = width <= 1024 ? 2 : 3;
          final List<List<AlertModel>> columns = List.generate(cols, (_) => []);
          for (int i = 0; i < filteredAlerts.length; i++) {
            columns[i % cols].add(filteredAlerts[i]);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(cols, (colIndex) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: columns[colIndex]
                          .map((alert) => _buildAlertCard(alert))
                          .toList(),
                    ),
                  ),
                );
              }),
            ),
          );
        }
      },
    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    final type = alert.type ?? 'UNKNOWN';
    final detail = alert.description;
    final isSos = type == 'SOS';
    final isUnread = !alert.read;
    final time = _formatDate(alert.timestamp);

    // Metadata extract for SOS
    final lat = alert.metadata?['latitude'] as double?;
    final lng = alert.metadata?['longitude'] as double?;
    final batt = alert.metadata?['battery'] as int?;

    return GlassCard(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      // Tap → écran de détail enrichi par l'agent IA (§4).
      onTap: () => context.push('/alert/details', extra: {
        'alert': alert,
        'child': widget.child,
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _alertColor(type).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_alertIcon(type), color: _alertColor(type), size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _alertLabel(type),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isUnread) ...[
                          SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(time,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            SizedBox(height: 10),
            Text(detail,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.70),
                    fontSize: 14)),
          ],

          // Analyse Guardian (§4) — commentaire IA + badge de risque si présent.
          if (alert.hasAiAnalysis) _buildAiBadge(alert),

          // NEW: Interactive buttons (Allow / Deny)
          if (alert.isInteractive) ...[
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAlertAction(alert, 'ALLOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      foregroundColor: Colors.greenAccent,
                      side: BorderSide(color: Colors.greenAccent, width: 0.5),
                    ),
                    child: Text('ALLOW'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => _handleAlertAction(alert, 'DENY'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                    ),
                    child: Text('DENY'),
                  ),
                ),
              ],
            ),
          ],

          if (isSos && batt != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.battery_std, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text('Battery: $batt%',
                    style: TextStyle(color: Colors.orange, fontSize: 13)),
              ],
            ),
          ],
          if (isSos && lat != null && lng != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.map, size: 16),
                    label: Text('View on map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                    ),
                    onPressed: () => context.push('/map'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.call, size: 16),
                    label: Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () async {
                      final phone = alert.metadata?['phone'] ?? '112';
                      final Uri uri =
                          Uri(scheme: 'tel', path: phone.toString());
                      final canLaunch = await canLaunchUrl(uri);
                      if (!context.mounted) return;
                      if (canLaunch) {
                        await launchUrl(uri);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot launch dialer')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Encart compact présentant l'analyse de l'agent IA sur la carte d'alerte.
  Widget _buildAiBadge(AlertModel alert) {
    final risk = alert.aiRisk ?? 'low';
    final riskColor = _riskColor(risk);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.accentTeal, size: 15),
              const SizedBox(width: 6),
              Text('Analyse Guardian',
                  style: TextStyle(
                      color: AppColors.accentTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                ),
                child: Text(_riskLabel(risk),
                    style: TextStyle(
                        color: riskColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(alert.aiComment ?? '',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4)),
        ],
      ),
    );
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return Colors.redAccent;
      case 'moderate':
        return Colors.orangeAccent;
      default:
        return Colors.greenAccent;
    }
  }

  String _riskLabel(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return 'CRITIQUE';
      case 'moderate':
        return 'MODÉRÉ';
      default:
        return 'FAIBLE';
    }
  }

  void _handleAlertAction(AlertModel alert, String action) async {
    try {
      await ChildMonitorService().handleAlertInteraction(
        childId: _childId,
        parentId: _parentId,
        alertId: alert.id,
        action: action,
        actionType: alert.actionType!,
        actionValue: alert.actionValue!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Action $action processed for ${alert.actionValue}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'SOS':
        return Icons.emergency;
      case 'BLOCKED_APP':
        return Icons.block;
      case 'TIME_LIMIT':
        return Icons.timer_off;
      case 'OUTSIDE_HOURS':
        return Icons.nights_stay;
      default:
        return Icons.info_outline;
    }
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'SOS':
        return Colors.red;
      case 'BLOCKED_APP':
        return Colors.orange;
      case 'TIME_LIMIT':
        return Colors.amber;
      case 'OUTSIDE_HOURS':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  String _alertLabel(String type) {
    switch (type) {
      case 'SOS':
        return '🆘 SOS Alert';
      case 'BLOCKED_APP':
        return '🚫 App blocked';
      case 'TIME_LIMIT':
        return '⏰ Limit reached';
      case 'OUTSIDE_HOURS':
        return '🌙 Outside schedule';
      default:
        return 'Alert';
    }
  }

  String _formatDate(DateTime dt) {
    final adjustedDt = TimezoneHelper.getAdjustedDateTime(context, dt);
    final adjustedNow =
        TimezoneHelper.getAdjustedDateTime(context, DateTime.now());
    final diff = adjustedNow.difference(adjustedDt);
    if (diff.inMinutes < 1) return 'Just now'.tr(context);
    if (diff.inHours < 1) return '${diff.inMinutes} min ago'.tr(context);
    if (diff.inDays < 1) return '${diff.inHours}h ago'.tr(context);
    return '${adjustedDt.day}/${adjustedDt.month} at ${adjustedDt.hour}:${adjustedDt.minute.toString().padLeft(2, '0')}';
  }
}
