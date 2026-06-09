import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'alert_service.dart';
import 'rules_service.dart';

/// LocationService
///
/// Gère le suivi GPS de l'enfant et le Geofencing (zones de sécurité).
///
/// Responsabilités :
///   1. Suivi GPS en temps réel (stream) et périodique.
///   2. Sauvegarde de l'historique dans Firestore (avec anti-spam).
///   3. Détection d'entrée/sortie de zones de sécurité (Geofencing).
///   4. Alerte si le GPS est désactivé.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AlertService _alertService = AlertService();
  final RulesService _rulesService = RulesService();

  StreamSubscription<geo.Position>? _positionStream;
  Timer? _periodicTimer;

  bool _isTracking = false;

  geo.Position? _lastSavedPosition;
  DateTime? _lastSaveTime;

  // État local des zones (ID Geofence -> est_dedans)
  final Map<String, bool> _lastGeofenceStates = {};

  static const double MIN_DISTANCE = 30; // mètres minimum pour sauvegarder l'historique
  static const int MIN_TIME = 300;       // 5 minutes minimum entre deux sauvegardes si peu de mouvement

  // ───────── PERMISSIONS ─────────

  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint("LocationService: GPS disabled.");
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      debugPrint("LocationService: permission refused.");
      return false;
    }

    // Permission "Toujours" pour le background sur Android 10+
    if (!kIsWeb && Platform.isAndroid) {
      permission = await geo.Geolocator.checkPermission();
      if (permission != geo.LocationPermission.always) {
        debugPrint("LocationService: Background permission (always) not granted.");
      }
    }

    return true;
  }

  // ───────── START TRACKING ─────────

  Future<void> startTracking() async {
    if (_isTracking) return;

    bool permission = await requestPermissions();
    if (!permission) {
      debugPrint("LocationService: cannot start tracking.");
      return;
    }

    _isTracking = true;
    debugPrint("LocationService: tracking started.");

    const geo.LocationSettings locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (geo.Position position) => _handlePosition(position),
      onError: (e) => debugPrint("LocationService: stream error $e"),
    );

    // Update de sécurité toutes le 5 minutes
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );
        _handlePosition(position);
      } catch (e) {
        debugPrint("LocationService: periodic update error $e");
      }
    });

    // Surveillance GPS OFF
    Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!_isTracking) return;
      bool enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint("LocationService: GPS disabled by user.");
        _sendGpsDisabledAlert();
      }
    });
  }

  // ───────── STOP TRACKING ─────────

  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _periodicTimer?.cancel();
    _positionStream = null;
    _periodicTimer = null;
    _isTracking = false;
    debugPrint("LocationService: tracking stopped.");
  }

  // ───────── POSITION HANDLER ─────────

  void _handlePosition(geo.Position position) {
    if (!_isTracking) return;

    // 1. Vérifier les zones (Geofencing)
    _checkGeofences(position);

    // 2. Sauvegarde Firestore avec anti-spam
    if (!_shouldSave(position)) return;

    _saveLocationToFirestore(position);
    _lastSavedPosition = position;
    _lastSaveTime = DateTime.now();
  }

  // ───────── GEOFENCING ─────────

  void _checkGeofences(geo.Position position) {
    final rules = _rulesService.current;
    if (rules.geofences.isEmpty) return;

    for (final zone in rules.geofences) {
      final distance = geo.Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude,
      );

      final isCurrentlyInside = distance <= zone.radius;
      final wasInside = _lastGeofenceStates[zone.id];

      // Initialisation
      if (wasInside == null) {
        _lastGeofenceStates[zone.id] = isCurrentlyInside;
        continue;
      }

      if (isCurrentlyInside && !wasInside) {
        // ENTREE
        debugPrint("LocationService: -> ENTER zone ${zone.name}");
        _alertService.sendAlert(
          type: AlertType.geofenceEnter,
          detail: "Votre enfant vient d'entrer dans la zone : ${zone.name}",
        );
      } else if (!isCurrentlyInside && wasInside) {
        // SORTIE
        debugPrint("LocationService: <- EXIT zone ${zone.name}");
        _alertService.sendAlert(
          type: AlertType.geofenceExit,
          detail: "Votre enfant vient de quitter la zone : ${zone.name}",
        );
      }

      _lastGeofenceStates[zone.id] = isCurrentlyInside;
    }
  }

  // ───────── ANTI SPAM GPS ─────────

  bool _shouldSave(geo.Position newPosition) {
    if (_lastSavedPosition == null || _lastSaveTime == null) return true;

    final distance = geo.Geolocator.distanceBetween(
      _lastSavedPosition!.latitude,
      _lastSavedPosition!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    final timeDiff = DateTime.now().difference(_lastSaveTime!).inSeconds;

    if (distance > MIN_DISTANCE) return true;
    if (timeDiff > MIN_TIME) return true;

    return false;
  }

  // ───────── FIRESTORE SAVE ─────────

  Future<void> _saveLocationToFirestore(geo.Position position) async {
    final prefs = await SharedPreferences.getInstance();
    final rawChildPath = prefs.getString("child_path");
    if (rawChildPath == null || rawChildPath.isEmpty) return;

    // Assurez-vous qu'il n'y a pas de slash final pour éviter les chemins invalides
    final childPath = rawChildPath.endsWith('/') 
        ? rawChildPath.substring(0, rawChildPath.length - 1) 
        : rawChildPath;

    try {
      final locationData = {
        "lat":       position.latitude,
        "lng":       position.longitude,
        "accuracy":  position.accuracy,
        "speed":     position.speed,
        "timestamp": FieldValue.serverTimestamp(),
      };

      // Update position actuelle sur le document principal
      await _firestore.doc(childPath).update({
        "lastLatitude":       position.latitude,
        "lastLongitude":      position.longitude,
        "lastLocationUpdate": FieldValue.serverTimestamp(),
      });

      // Point actuel dans collection dédiée
      await _firestore.doc("$childPath/location/current").set(locationData);

      // Historique
      await _firestore.collection("$childPath/location_history").add(locationData);

      debugPrint("LocationService: Saved lat=${position.latitude}, lng=${position.longitude}");
    } catch (e) {
      debugPrint("LocationService: Firestore error $e");
    }
  }

  // ───────── GPS OFF ALERT ─────────

  Future<void> _sendGpsDisabledAlert() async {
    await _alertService.sendAlert(
      type: AlertType.outsideHours, // Utilisation par défaut
      detail: "Le GPS a été désactivé sur l'appareil de l'enfant.",
    );
  }
}