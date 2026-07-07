import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/child_path_helper.dart';

/// PackageService
///
/// Scanne les applications installées via le MethodChannel natif Android
/// (qui utilise PackageManager pour récupérer les icônes) et les synchronise
/// dans Firestore pour que le parent puisse les bloquer / voir les détails.
class PackageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _channel = MethodChannel('app.theguardian.child/system');

  /// Récupère la liste des applications installées avec leurs icônes Base64
  /// et les envoie dans Firestore pour que le parent puisse les bloquer.
  Future<void> syncInstalledApps() async {
    final prefs = await SharedPreferences.getInstance();
    final childPath = await readChildPath(prefs);
    if (childPath == null) {
      debugPrint('PackageService: Aborting sync - child_path is null');
      return;
    }

    try {
      // Appel natif Android — getInstalledApps est implémenté dans MainActivity.kt
      // Il retourne : [{packageName, appName, iconBase64}]
      final List<dynamic>? rawApps =
          await _channel.invokeMethod<List<dynamic>>('getInstalledApps');

      if (rawApps == null || rawApps.isEmpty) {
        debugPrint('PackageService: No apps returned from native channel.');
        return;
      }

      final appList = rawApps.map((a) {
        final map = Map<String, dynamic>.from(a as Map);
        return {
          'packageName': map['packageName'] as String? ?? '',
          'appName':     map['appName']     as String? ?? '',
          'iconBase64':  map['iconBase64']  as String? ?? '',
        };
      }).where((a) => (a['packageName'] as String).isNotEmpty).toList();

      debugPrint('PackageService: ${appList.length} apps to sync.');

      // 1. Liste simplifiée (compatibilité Dashboard Parent)
      await _firestore.doc('$childPath/inventory/apps').set({
        'lastSync':          FieldValue.serverTimestamp(),
        'installedPackages': appList.map((e) => e['packageName']).toList(),
      }, SetOptions(merge: true));

      // 2. Détails (avec icônes) par tranches de 500 (limite batch Firestore)
      for (var i = 0; i < appList.length; i += 500) {
        final end   = (i + 500 < appList.length) ? i + 500 : appList.length;
        final chunk = appList.sublist(i, end);

        final batch = _firestore.batch();
        for (final app in chunk) {
          final pkg    = app['packageName'] as String;
          final docRef = _firestore
              .collection('$childPath/inventory/apps/details')
              .doc(pkg);

          batch.set(docRef, {
            'packageName': pkg,
            'appName':     app['appName'],
            'label':       app['appName'],   // fallback attendu par Parent App
            'name':        app['appName'],   // second fallback
            'iconBase64':  app['iconBase64'],
            'icon':        app['iconBase64'], // second fallback
            'lastUpdate':  FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
        debugPrint('PackageService: Batch $i→$end committed.');
      }

      debugPrint('PackageService: ✅ Sync complete (${appList.length} apps).');
    } on PlatformException catch (e) {
      debugPrint('PackageService: Native channel error: ${e.message}');
    } catch (e) {
      debugPrint('PackageService: Sync failed: $e');
    }
  }
}
