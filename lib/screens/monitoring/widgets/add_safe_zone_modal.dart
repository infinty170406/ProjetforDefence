import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/models/geo_zone.dart';
import '../../../core/services/location_service.dart';

class AddSafeZoneModal extends StatefulWidget {
  final List<Map<String, dynamic>> children;
  final Future<void> Function(GeoZone) onAdd;
  final LatLng? initialLocation;

  const AddSafeZoneModal({
    super.key, 
    required this.onAdd, 
    required this.children,
    this.initialLocation,
  });

  @override
  State<AddSafeZoneModal> createState() => _AddSafeZoneModalState();
}

class _AddSafeZoneModalState extends State<AddSafeZoneModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  late LatLng _center;
  double _radius = 200.0;
  bool _isSaving = false;
  bool _isLoadingLoc = true;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation ?? const LatLng(48.8566, 2.3522);
    if (widget.children.isNotEmpty) {
      _selectedChildId = widget.children[0]['id'];
    }
    if (widget.initialLocation == null) {
      _initCurrentLocation();
    } else {
      _isLoadingLoc = false;
    }
  }

  Future<void> _initCurrentLocation() async {
    try {
      final pos = await LocationService().getCurrentLocation().timeout(const Duration(seconds: 5));
      if (mounted && pos != null) {
        setState(() {
          _center = LatLng(pos.latitude, pos.longitude);
          _isLoadingLoc = false;
        });
      } else {
        setState(() => _isLoadingLoc = false);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => _isLoadingLoc = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add Safe Zone', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameCtrl,
                focusNode: _nameFocusNode,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Zone Name (e.g. School)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Apply to child:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.children.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final child = widget.children[index];
                        final isSelected = _selectedChildId == child['id'];
                        return ChoiceChip(
                          label: Text(child['displayName']),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedChildId = val ? child['id'] : null),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoadingLoc 
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 15.0,
                  ),
                  onCameraMove: (position) {
                    _center = position.target;
                  },
                  onCameraIdle: () {
                    setState(() {}); // to update the circle and marker
                  },
                  onTap: (point) {
                    setState(() => _center = point);
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('center'),
                      position: _center,
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: const CircleId('radius'),
                      center: _center,
                      radius: _radius,
                      fillColor: AppColors.primary.withOpacity(0.3),
                      strokeColor: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                ),
          ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Radius: ${_radius.toInt()} meters', style: const TextStyle(color: Colors.white)),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 2000,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _radius = val),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16).copyWith(top: 0),
            child: CustomButton(
              text: _isSaving ? 'Saving...' : 'Save Zone',
              onPressed: _isSaving ? null : () async {
                debugPrint('DEBUG: Save button clicked');
                
                if (!_formKey.currentState!.validate()) {
                  debugPrint('DEBUG: Form validation failed');
                  return;
                }
                
                setState(() => _isSaving = true);
                
                final zone = GeoZone(
                  name: _nameCtrl.text.trim(),
                  centerLatitude: _center.latitude,
                  centerLongitude: _center.longitude,
                  radiusMeters: _radius,
                  childId: _selectedChildId,
                );
                
                debugPrint('DEBUG: Creating zone: ${zone.name} at (${zone.centerLatitude}, ${zone.centerLongitude})');
                
                try {
                  await widget.onAdd(zone);
                  debugPrint('DEBUG: onAdd completed in modal');
                  if (!context.mounted) return;
                  setState(() => _isSaving = false);
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint('DEBUG: onAdd failed in modal: $e');
                  if (!mounted) return;
                  setState(() => _isSaving = false);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
