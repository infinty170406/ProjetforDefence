import 'package:google_maps_flutter/google_maps_flutter.dart';

class Child {
  final String id;
  final String displayName;
  final int age;
  final String? deviceStatus;
  final LatLng? lastLocation;
  final double? batteryLevel;

  Child({
    required this.id,
    required this.displayName,
    required this.age,
    this.deviceStatus,
    this.lastLocation,
    this.batteryLevel,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['lastLatitude'] != null && json['lastLongitude'] != null) {
      location = LatLng(
        (json['lastLatitude'] as num).toDouble(),
        (json['lastLongitude'] as num).toDouble(),
      );
    }

    return Child(
      id: json['id'] as String,
      displayName: json['displayName'] ?? 'Enfant',
      age: json['age'] as int? ?? 0,
      deviceStatus: json['deviceStatus'] as String?,
      lastLocation: location,
      batteryLevel: json['batteryLevel'] != null 
          ? (json['batteryLevel'] as num).toDouble() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'age': age,
      'deviceStatus': deviceStatus,
      'lastLatitude': lastLocation?.latitude,
      'lastLongitude': lastLocation?.longitude,
      'batteryLevel': batteryLevel,
    };
  }
}
