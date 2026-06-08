import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/liquid_background.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/services/api_service.dart';
import '../../core/models/geo_zone.dart';
import '../../core/services/location_service.dart';
import 'widgets/add_safe_zone_modal.dart';

class SafeZonesScreen extends StatefulWidget {
  const SafeZonesScreen({super.key});

  @override
  State<SafeZonesScreen> createState() => _SafeZonesScreenState();
}

class _SafeZonesScreenState extends State<SafeZonesScreen> {
  bool _isLoading = true;
  bool _isAdding = false;
  List<GeoZone> _zones = [];
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _fetchZones();
    _fetchChildren();
  }

  Future<void> _fetchChildren() async {
    try {
      final response = await ApiService().getMyChildren();
      final List<Map<String, dynamic>> children = List<Map<String, dynamic>>.from(response['children'] ?? []);
      if (mounted) setState(() => _children = children);
    } catch (e) {
      debugPrint('Error fetching children: $e');
    }
  }

  Future<void> _fetchZones() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await ApiService().getGeofences();
      if (mounted) {
        setState(() {
          _zones = data.map((json) => GeoZone.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching zones: $e');
    }
  }

  void _showAddZoneModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSafeZoneModal(
        children: _children,
        onAdd: (zone) async {
          debugPrint('DEBUG: Starting onAdd for zone: ${zone.name}');
          try {
            await ApiService().createGeofence(zone.toJson()).timeout(const Duration(seconds: 15));
            debugPrint('DEBUG: Geofence created successfully');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zone de sécurité enregistrée ✓'), backgroundColor: Colors.green),
            );
            await _fetchZones();
          } catch (e) {
            debugPrint('DEBUG: Error in onAdd: $e');
            String errorMsg = 'Erreur lors de l\'ajout';
            if (e.toString().contains('UNAVAILABLE') || e.toString().contains('host')) {
              errorMsg = 'Connexion impossible. Vérifiez votre accès internet.';
            } else {
              errorMsg = 'Erreur: $e';
            }
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: AppColors.statusDanger),
            );
            rethrow; 
          }
        },
      ),
    ).then((_) {
       if (mounted) setState(() => _isAdding = false);
    });
  }

  Future<void> _deleteZone(String? id) async {
    if (id == null) return;
    try {
      await ApiService().deleteGeofence(id);
      await _fetchZones();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting zone: $e')),
        );
      }
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Safe Zones',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Define security perimeters. You will be alerted if your child enters or leaves these zones.',
                    style: TextStyle(
                      color: AppColors.textGray400,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: _isLoading 
                        ? const Center(child: CircularProgressIndicator())
                        : _zones.isEmpty && !_isAdding
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _zones.length,
                                itemBuilder: (context, index) {
                                  final zone = _zones[index];
                                  return _buildZoneItem(zone);
                                },
                              ),
                  ),
                  CustomButton(
                    text: _isAdding ? 'Adding Zone...' : 'Add a zone',
                    onPressed: _isAdding ? null : () {
                      setState(() => _isAdding = true);
                      _showAddZoneModal();
                    },
                    icon: Icons.add_location_alt_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, color: Colors.white10, size: 80),
          SizedBox(height: 16),
          Text(
            'No zones defined yet',
            style: TextStyle(color: AppColors.textGray500),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneItem(GeoZone zone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Radius: ${zone.radiusMeters.toInt()}m',
                        style: const TextStyle(color: AppColors.textGray500, fontSize: 13),
                      ),
                      if (zone.childId != null) ...[
                        const Text(' • ', style: TextStyle(color: AppColors.textGray500)),
                        Text(
                          _children.firstWhere((c) => c['id'] == zone.childId, orElse: () => {'displayName': 'All'})['displayName'],
                          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _deleteZone(zone.id),
            ),
          ],
        ),
      ),
    );
  }
}

