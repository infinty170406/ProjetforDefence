import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// FaceService — Service de comparaison faciale utilisant l'API Face++.
class FaceService {
  final Dio _dio = Dio();
  final String _baseUrl = "https://api-us.faceplusplus.com/facepp/v3/compare";

  /// Compare deux visages : celui du document d'identité et un selfie.
  /// 
  /// Retourne le score de confiance (0-100) ou null en cas d'erreur.
  Future<double?> compareFaces(File imageFile1, File imageFile2) async {
    final String? apiKey = dotenv.env['FACEPLUSPLUS_API_KEY'];
    final String? apiSecret = dotenv.env['FACEPLUSPLUS_API_SECRET'];

    if (apiKey == null || apiSecret == null || apiKey == "YOUR_API_KEY") {
      debugPrint("FaceService: API Key ou Secret manquant dans le fichier .env");
      return null;
    }

    try {
      final formData = FormData.fromMap({
        'api_key': apiKey,
        'api_secret': apiSecret,
        'image_file1': await MultipartFile.fromFile(imageFile1.path),
        'image_file2': await MultipartFile.fromFile(imageFile2.path),
      });

      debugPrint("FaceService: Envoi de la requête de comparaison...");
      final response = await _dio.post(_baseUrl, data: formData);

      if (response.statusCode == 200) {
        final double confidence = response.data['confidence']?.toDouble() ?? 0.0;
        debugPrint("FaceService: Comparaison réussie. Confidence: $confidence");
        return confidence;
      } else {
        debugPrint("FaceService: Erreur API (${response.statusCode}): ${response.data}");
        return null;
      }
    } catch (e) {
      debugPrint("FaceService: Erreur critique lors de la comparaison: $e");
      return null;
    }
  }
}
