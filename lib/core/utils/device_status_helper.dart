import 'package:cloud_firestore/cloud_firestore.dart';

/// Seuil au-delà duquel un heartbeat absent signifie que l'enfant est hors ligne,
/// même si [deviceStatus] est resté figé sur ONLINE (crash, extinction brutale…).
const Duration deviceHeartbeatStaleThreshold = Duration(minutes: 5);

/// Résout le statut réel d'un appareil en combinant [deviceStatus] et [lastHeartbeat].
String resolveDeviceStatus(Map<String, dynamic>? data) {
  if (data == null) return 'OFFLINE';

  final lastHeartbeat = data['lastHeartbeat'];
  if (lastHeartbeat is Timestamp) {
    final age = DateTime.now().difference(lastHeartbeat.toDate());
    if (age > deviceHeartbeatStaleThreshold) return 'OFFLINE';
  }

  return (data['deviceStatus'] as String?) ?? 'OFFLINE';
}
