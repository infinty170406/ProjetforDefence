import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeoZone {
  final String? id;
  final String name;
  final String? childId;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final bool enabled;

  GeoZone({
    this.id,
    required this.name,
    this.childId,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    this.enabled = true,
  });

  LatLng get center => LatLng(centerLatitude, centerLongitude);
  double get radius => radiusMeters;

  factory GeoZone.fromJson(Map<String, dynamic> json) {
    return GeoZone(
      id: json['id']?.toString() ?? json['geofenceId']?.toString(),
      name: json['name'] ?? '',
      childId: json['childId'],
      centerLatitude:
          (json['centerLatitude'] ?? json['latitude'] ?? 0.0).toDouble(),
      centerLongitude:
          (json['centerLongitude'] ?? json['longitude'] ?? 0.0).toDouble(),
      radiusMeters:
          (json['radiusMeters'] ?? json['radius'] ?? 100.0).toDouble(),
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (childId != null) 'childId': childId,
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'enabled': enabled,
    };
  }
}
