import 'dart:async';
import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';
import '../../core/services/child_monitor_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/api_service.dart';
import '../../core/models/child.dart';
import '../../core/models/geo_zone.dart';
import 'widgets/add_safe_zone_modal.dart';

class RealTimeMapScreen extends StatefulWidget {
  final dynamic initialChild;
  const RealTimeMapScreen({super.key, this.initialChild});

  @override
  State<RealTimeMapScreen> createState() => _RealTimeMapScreenState();
}

class _RealTimeMapScreenState extends State<RealTimeMapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();


  LatLng _currentLocation = const LatLng(48.8566, 2.3522);
  bool _isLoading = true;
  bool _autoFollow = true; // NEW: Auto-centering feature
  StreamSubscription? _childrenSubscription;
  List<Child> _children = [];
  Child? _selectedChild;
  List<GeoZone> _safeZones = [];
  bool _isFirstLoad = true;
  String? _parentId;
  bool _isChildMode = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Initial focus if child passed
    if (widget.initialChild != null) {
      _selectedChild = Child.fromJson(widget.initialChild is Map<String, dynamic> 
        ? widget.initialChild 
        : (widget.initialChild as Child).toJson());
      _parentId = widget.initialChild?['parentId'] as String?;
      if (_selectedChild?.lastLocation != null) {
        _currentLocation = _selectedChild!.lastLocation!;
      }
    }

    _initializeScreen();
  }

  @override
  void dispose() {
    _childrenSubscription?.cancel();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _startRealTimeTracking() {
    if (_isChildMode && _selectedChild != null) {
      // Child mode: only track the current child
      _childrenSubscription = ChildMonitorService()
          .watchSingleChild(_selectedChild!.id, parentId: _parentId)
          .listen((data) {
        if (data != null && mounted) {
          setState(() {
            final child = Child.fromJson({...data, 'id': _selectedChild!.id});
            _children = [child];
            _selectedChild = child;
            if (child.lastLocation != null) {
              _currentLocation = child.lastLocation!;
              if (_isFirstLoad || _autoFollow) {
                _updateMapCamera();
                _isFirstLoad = false;
              }
            }
          });
        }
      });
      return;
    }

    _childrenSubscription = FirestoreService().childrenStream().listen((childrenData) {
      final List<Child> children = childrenData.map((json) => Child.fromJson(json)).toList();
      
      if (mounted) {
        setState(() {
          _children = children;
          if (_children.isNotEmpty) {
            // Pick child: passed one > already selected > first in list
            if (_selectedChild != null) {
              final updated = _children.firstWhere(
                  (c) => c.id == _selectedChild!.id,
                  orElse: () => _children[0]);
              _selectedChild = updated;
            } else {
              _selectedChild = _children[0];
            }

            if (_selectedChild?.lastLocation != null) {
              final newLocation = _selectedChild!.lastLocation!;
              
              // Force focus on first load or if auto-follow is ON
              if (_isFirstLoad || (_autoFollow && (newLocation.latitude != _currentLocation.latitude || newLocation.longitude != _currentLocation.longitude))) {
                 _currentLocation = newLocation;
                 _updateMapCamera();
                 _isFirstLoad = false;
              } else {
                 _currentLocation = newLocation;
              }
            }
          }
        });
      }
    });
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);
    try {
      final pairing = await StorageService().getChildPairing();
      _isChildMode = pairing['mode'] == 'child';
      if (_isChildMode) _parentId = pairing['parentId'];

      // 1. Init Location with timeout
      await _initLocation();
      
      // 2. Start tracking and load zones in parallel
      _startRealTimeTracking();
      await _loadAllSafeZones();
    } catch (e) {
      debugPrint("Init error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _selectedChild?.lastLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation, 14.0));
    }
  }

  Future<void> _initLocation() async {
    try {
      final hasService = await _locationService.requestService();
      if (!hasService) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez activer la localisation pour actualiser votre position.')),
        );
        return;
      }
      
      final position = await _locationService.getCurrentLocation().timeout(const Duration(seconds: 5));
      if (mounted && position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _updateMapCamera();
      }
    } catch (e) {
      debugPrint("GPS Timeout or error: $e");
    }
  }

  Future<void> _loadAllSafeZones() async {
    try {
      final List<dynamic> data = _isChildMode
          ? await ChildMonitorService().getGeofences(parentId: _parentId)
          : await FirestoreService().getGeofences();
      if (mounted) {
        setState(() {
          _safeZones = data.map((json) => GeoZone.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading geofences: $e');
      rethrow;
    }
  }

  Future<void> _loadSafeZones(String childId) async {
    // Already loading all, but can filter here if needed
  }

  void _onChildSwitched(Child child) {
    setState(() {
      _selectedChild = child;
      if (child.lastLocation != null) {
        _currentLocation = child.lastLocation!;
        _updateMapCamera();
      }
    });
    _loadSafeZones(child.id);
  }

  void _showAddZoneModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSafeZoneModal(
        children: _children.map((c) => c.toJson()).toList(),
        initialLocation: _currentLocation,
        onAdd: (zone) async {
          debugPrint('DEBUG: Starting onAdd for zone: ${zone.name}');
          try {
            await ApiService().createGeofence(zone.toJson()).timeout(const Duration(seconds: 15));
            debugPrint('DEBUG: Geofence created successfully');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Zone de sécurité enregistrée ✓'), backgroundColor: Colors.green),
            );
            await _loadAllSafeZones();
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
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.5),
              BlendMode.darken,
            ),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 15.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _updateMapCamera();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              markers: _children.where((c) => c.lastLocation != null).map((child) {
                return Marker(
                  markerId: MarkerId(child.id),
                  position: child.lastLocation!,
                  infoWindow: InfoWindow(title: child.displayName),
                  onTap: () => _onChildSwitched(child),
                );
              }).toSet(),
              circles: _safeZones.where((z) => _selectedChild == null || z.childId == null || z.childId == _selectedChild!.id).map((zone) {
                return Circle(
                  circleId: CircleId(zone.id ?? zone.name),
                  center: zone.center,
                  radius: zone.radius,
                  fillColor: AppColors.primary.withOpacity(0.15),
                  strokeColor: AppColors.primary.withOpacity(0.5),
                  strokeWidth: 2,
                );
              }).toSet(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderButton(Icons.arrow_back, () => context.pop()),
                      if (_selectedChild != null)
                        GestureDetector(
                          onTap: () {
                            final childMap = {
                              'id': _selectedChild!.id,
                              'displayName': _selectedChild!.displayName,
                              'age': _selectedChild!.age,
                            };
                            context.push('/child/details', extra: childMap);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(_selectedChild!.displayName[0],
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 8),
                                Text(_selectedChild!.displayName,
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(width: 4),
                                Icon(Icons.open_in_new,
                                    color: AppColors.primary, size: 16),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeaderButton(
                            _autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed,
                            () => setState(() => _autoFollow = !_autoFollow),
                            color: _autoFollow ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
                          ),
                          SizedBox(width: 8),
                          _buildHeaderButton(Icons.refresh, () => _startRealTimeTracking()),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_children.length > 1) _buildChildSwitcher(),
                  Spacer(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButton: _isChildMode
          ? null
          : FloatingActionButton(
              onPressed: _showAddZoneModal,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.add_location_alt_outlined, color: Theme.of(context).colorScheme.onSurface),
            ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap, {Color? color}) {
    final displayColor = color ?? Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(icon, color: displayColor, size: 24),
      ),
    );
  }

  Widget _buildChildSwitcher() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _children.map((child) {
          final isSelected = _selectedChild?.id == child.id;
          return Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => _onChildSwitched(child),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.glassBorder),
                ),
                child: Text(
                  child.displayName,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
