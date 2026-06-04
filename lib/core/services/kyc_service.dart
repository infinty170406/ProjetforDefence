import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_v2/tflite_v2.dart';

/// KycService — Service de classification de document d'identité utilisant TFLite.
class KycService {
  bool _isModelLoaded = false;

  /// Tente de charger le modèle TFLite depuis les assets.
  Future<void> loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/model/model.tflite",
        labels: "assets/model/labels.txt",
        numThreads: 1, // Limiter pour la stabilité sur mobile
        isAsset: true,
        useGpuDelegate: false, // Plus compatible sur une large gamme d'appareils
      );
      _isModelLoaded = res == "success";
      if (_isModelLoaded) {
        debugPrint("KYC Service: Modèle TFLite chargé avec succès.");
      } else {
        debugPrint("KYC Service: Échec du chargement du modèle.");
      }
    } catch (e) {
      debugPrint("KYC Service: Erreur critique lors du chargement: $e");
      _isModelLoaded = false;
    }
  }

  /// Tente de classifier un document d'identité (CNI ou PASSPORT).
  ///
  /// Retourne le label détecté ou null si la confiance est trop faible (< 0.6).
  Future<String?> classifyDocument(File imageFile) async {
    if (!_isModelLoaded) {
      await loadModel();
    }

    if (!_isModelLoaded) {
      debugPrint("KYC Service: Classification impossible (modèle non chargé).");
      return null;
    }

    try {
      final List? recognitions = await Tflite.runModelOnImage(
        path: imageFile.path,
        imageMean: 127.5,
        imageStd: 127.5,
        numResults: 1,
        threshold: 0.6, // Seuil de confiance minimal
        asynch: true,
      );

      if (recognitions != null && recognitions.isNotEmpty) {
        final String label = recognitions.first['label']?.toString() ?? "";
        final double confidence = recognitions.first['confidence']?.toDouble() ?? 0.0;
        
        debugPrint("KYC Service: Détection: $label (confiance: ${confidence.toStringAsFixed(2)})");
        
        // Nettoyage du label (Teachable Machine ajoute souvent un index comme "0 PASSPORT")
        if (label.toUpperCase().contains('PASSPORT')) return 'PASSPORT';
        if (label.toUpperCase().contains('CNI')) return 'CNI';
        
        return label;
      }
      return null;
    } catch (e) {
      debugPrint("KYC Service: Erreur pendant l'inférence: $e");
      return null;
    }
  }

  /// Libère les ressources du modèle.
  Future<void> dispose() async {
    try {
      await Tflite.close();
      _isModelLoaded = false;
      debugPrint("KYC Service: Ressources TFLite libérées.");
    } catch (e) {
      debugPrint("KYC Service: Erreur lors de la fermeture: $e");
    }
  }
}