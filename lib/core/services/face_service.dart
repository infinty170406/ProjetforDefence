import 'dart:io';
import 'package:flutter/foundation.dart';

/// FaceService — Service de comparaison faciale utilisant l'API Face++.
class FaceService {
  /// Compare deux visages : celui du document d'identité et un selfie.
  ///
  /// Retourne le score de confiance (0-100) ou null en cas d'erreur.
  Future<double?> compareFaces(File imageFile1, File imageFile2) async {
    debugPrint(
      'FaceService: comparaison distante désactivée ; elle doit passer par un backend sécurisé.',
    );
    return null;
  }
}
