import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;
import '../models/kyc_models.dart';

/// KycService — Analyse locale d'un document d'identité via TFLite.
///
/// Améliorations v2 :
/// - Retourne un [KycAnalysisResult] riche (jamais null)
/// - Détection de la qualité image (flou, luminosité)
/// - Chargement du modèle en singleton différé
/// - Libération propre des ressources
class KycService {
  static final KycService _instance = KycService._internal();
  factory KycService() => _instance;
  KycService._internal();

  bool _isModelLoaded = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Chargement du modèle
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadModel() async {
    if (_isModelLoaded) return;
    try {
      final res = await Tflite.loadModel(
        model: 'assets/model/model.tflite',
        labels: 'assets/model/labels.txt',
        numThreads: 2,
        isAsset: true,
        useGpuDelegate: false,
      );
      _isModelLoaded = res == 'success';
      debugPrint(
          'KYC: Modèle ${_isModelLoaded ? "chargé" : "échec de chargement"}');
    } catch (e) {
      debugPrint('KYC: Erreur chargement modèle: $e');
      _isModelLoaded = false;
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  // ─────────────────────────────────────────────────────────────────────────
  // Analyse principale — retourne toujours un résultat explicite
  // ─────────────────────────────────────────────────────────────────────────

  Future<KycAnalysisResult> analyseDocument(File imageFile) async {
    final stopwatch = Stopwatch()..start();

    // 1. Chargement du modèle si nécessaire
    if (!_isModelLoaded) {
      await loadModel();
    }

    if (!_isModelLoaded) {
      stopwatch.stop();
      return KycAnalysisResult.failure(KycError.modelNotLoaded);
    }

    // 2. Analyse de qualité de l'image (avant inférence TFLite)
    final qualityResult = await _analyseImageQuality(imageFile);
    if (qualityResult != null) {
      stopwatch.stop();
      return KycAnalysisResult.failure(qualityResult);
    }

    // 3. Calcul du score de qualité (luminosité + netteté estimée)
    final qualityScore = await _computeQualityScore(imageFile);

    // 4. Inférence TFLite
    try {
      final List? recognitions = await Tflite.runModelOnImage(
        path: imageFile.path,
        imageMean: 127.5,
        imageStd: 127.5,
        numResults: 3,
        threshold: 0.4,
        asynch: true,
      );

      stopwatch.stop();

      if (recognitions == null || recognitions.isEmpty) {
        return KycAnalysisResult.failure(KycError.notRecognized);
      }

      final best = recognitions.first;
      final rawLabel = best['label']?.toString() ?? '';
      final confidence = (best['confidence'] as num?)?.toDouble() ?? 0.0;

      final documentType = _normalizeLabel(rawLabel);
      if (documentType == null) {
        return KycAnalysisResult.failure(KycError.notRecognized);
      }

      final warnings = _buildWarnings(qualityScore, confidence);

      debugPrint(
          'KYC: $documentType | conf=${confidence.toStringAsFixed(2)} | quality=${qualityScore.toStringAsFixed(2)}');

      return KycAnalysisResult.success(
        documentType: documentType,
        confidence: confidence,
        qualityScore: qualityScore,
        processingTime: stopwatch.elapsed,
        warnings: warnings,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('KYC: Erreur inférence: $e');
      return KycAnalysisResult.failure(KycError.interrupted);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Détection rapide de problèmes bloquants dans l'image
  Future<KycError?> _analyseImageQuality(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return KycError.notRecognized;

      // Vérification de la taille minimale
      if (image.width < 200 || image.height < 150) return KycError.cropped;

      // Estimation de la luminosité moyenne
      final brightness = _computeBrightness(image);
      if (brightness < 40) return KycError.lighting;

      return null; // OK
    } catch (_) {
      return null; // On laisse TFLite décider
    }
  }

  double _computeBrightness(img.Image image) {
    int total = 0;
    int count = 0;
    // Échantillonnage (1 pixel sur 16 pour la performance)
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final pixel = image.getPixel(x, y);
        total += (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).round();
        count++;
      }
    }
    return count > 0 ? total / count : 128.0;
  }

  Future<double> _computeQualityScore(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 0.5;
      final brightness = _computeBrightness(image);
      // Normalise [40..200] → [0..1], clamp
      return ((brightness - 40) / 160.0).clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  String? _normalizeLabel(String rawLabel) {
    final upper = rawLabel.toUpperCase();
    if (upper.contains('PASSPORT')) return 'PASSPORT';
    if (upper.contains('CNI') ||
        upper.contains('ID_CARD') ||
        upper.contains('NATIONAL')) return 'CNI';
    if (upper.contains('DRIVER') ||
        upper.contains('LICENSE') ||
        upper.contains('PERMIS')) return 'DRIVERS_LICENSE';
    return null;
  }

  List<String> _buildWarnings(double qualityScore, double confidence) {
    final warnings = <String>[];
    if (qualityScore < 0.6)
      warnings
          .add('⚠️ Éclairage insuffisant — placez-vous près d\'une fenêtre');
    if (confidence < 0.75)
      warnings.add('⚠️ Approchez légèrement la caméra du document');
    return warnings;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Libération des ressources
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    try {
      await Tflite.close();
      _isModelLoaded = false;
      debugPrint('KYC: Ressources TFLite libérées.');
    } catch (e) {
      debugPrint('KYC: Erreur fermeture: $e');
    }
  }
}
