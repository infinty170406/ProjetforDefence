import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PackageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Récupère la liste des applications "actives" (qui ont des stats)
  /// et les envoie dans Firestore pour que le parent puisse les bloquer.
  Future<void> syncInstalledApps() async {
    final prefs = await SharedPreferences.getInstance();
    final childPath = prefs.getString('child_path');
    if (childPath == null) return;

    try {
      const channel = MethodChannel('app.theguardian.child/system');
      final List<dynamic>? apps = await channel.invokeMethod<List<dynamic>>('getInstalledApps');
      
      if (apps == null) return;

      final appList = apps.map((a) {
        final map = Map<String, dynamic>.from(a as Map);
        return {
          'packageName': map['packageName'] as String,
          'appName':     map['appName'] as String,
          // On garde l'icône à part
          'iconBase64':  map['iconBase64'] as String? ?? '',
        };
      }).toList();

      debugPrint('PackageService: Found ${appList.length} installed apps. Syncing to Firestore...');

      // 1. Mise à jour de la liste simplifiée (pour compatibilité Parent App)
      await _firestore.doc('$childPath/inventory/apps').set({
        'lastSync':          FieldValue.serverTimestamp(),
        'installedPackages': appList.map((e) => e['packageName']).toList(),
      }, SetOptions(merge: true));

      // 2. Mise à jour des détails (icones) dans une sous-collection pour éviter la limite de 1 Mo
      final batch = _firestore.batch();
      for (final app in appList) {
        final docRef = _firestore.collection('$childPath/inventory/apps/details').doc(app['packageName'] as String);
        batch.set(docRef, {
          'packageName': app['packageName'],
          'appName':     app['appName'],
          'iconBase64':  app['iconBase64'],
          'lastUpdate':  FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      
      debugPrint('PackageService: Full app list and icons synced successfully.');
    } catch (e) {
      debugPrint('PackageService: Sync failed: $e');
    }
  }
}
