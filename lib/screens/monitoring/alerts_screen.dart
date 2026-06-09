import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/models/alert_model.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return Scaffold(
      
      body: Stack(
        children: [
          const LiquidBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildFilterBar(),
                Expanded(child: _buildAlertsList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
          SizedBox(width: 8),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f.$1;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f.$1),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(f.$3,
                        size: 14,
                        color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
                    SizedBox(width: 6),
                    Text(
                      f.$2,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Theme.of(context).colorScheme.onSurface,
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

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
        final alerts = rawAlerts.map((data) => AlertModel.fromJson(data)).toList();

        final filteredAlerts = _filter == 'ALL'
            ? alerts
            : alerts.where((a) => a.type == _filter).toList();

        if (filteredAlerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.primary, size: 64),
                SizedBox(height: 16),
                Text('No alerts found', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filteredAlerts.length,
          itemBuilder: (context, index) {
            final alert = filteredAlerts[index];
            return _buildAlertCard(alert);
          },
        );
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
                child: Icon(_alertIcon(type), color: _alertColor(type), size: 20),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (detail.isNotEmpty) ...[
            SizedBox(height: 10),
            Text(detail,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70), fontSize: 14)),
          ],
          
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
                      final Uri uri = Uri(scheme: 'tel', path: phone.toString());
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
          SnackBar(content: Text('Action $action processed for ${alert.actionValue}')),
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
      case 'SOS': return Icons.emergency;
      case 'BLOCKED_APP': return Icons.block;
      case 'TIME_LIMIT': return Icons.timer_off;
      case 'OUTSIDE_HOURS': return Icons.nights_stay;
      default: return Icons.info_outline;
    }
  }

  Color _alertColor(String type) {
    switch (type) {
      case 'SOS': return Colors.red;
      case 'BLOCKED_APP': return Colors.orange;
      case 'TIME_LIMIT': return Colors.amber;
      case 'OUTSIDE_HOURS': return Colors.purple;
      default: return AppColors.primary;
    }
  }

  String _alertLabel(String type) {
    switch (type) {
      case 'SOS': return '🆘 SOS Alert';
      case 'BLOCKED_APP': return '🚫 App blocked';
      case 'TIME_LIMIT': return '⏰ Limit reached';
      case 'OUTSIDE_HOURS': return '🌙 Outside schedule';
      default: return 'Alert';
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
