import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// [FirebaseOptions] synchronisées avec google-services.json
/// Projet : control-parental-5f115  |  Package : com.example.virt
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCV_rdZoHo-yV2Ozr3okVjuwqswabYnv6w',
    appId: '1:638981354516:android:1ccb3eb65b40d7e93a6301',
    messagingSenderId: '638981354516',
    projectId: 'control-parental-5f115',
    storageBucket: 'control-parental-5f115.firebasestorage.app',
  );
}