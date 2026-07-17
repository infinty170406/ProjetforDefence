import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/kyc_models.dart';
import '../services/api_service.dart';

/// KycRepository — Gère la persistance sécurisée du workflow KYC dans Firestore.
///
/// NOTE : firebase_storage n'est pas dans les dépendances du projet.
/// Les images sont compressées localement et encodées en base64, puis stockées
/// dans Firestore sous la limite des 1 Mo par document (images de document typiques ~60-150 KB après compression).
/// Si le document dépasse la limite, on stocke uniquement les métadonnées d'analyse.
///
/// Structure Firestore :
///   parents/{uid}/
///     kycStatus        : String (NOT_STARTED | IN_PROGRESS | PENDING | VERIFIED | REJECTED)
///     kycVersion       : int
///     kycSubmittedAt   : Timestamp
///     kycValidatedAt   : Timestamp?
///     kycAttempts      : List<Map>  (historique sans images)
class KycRepository {
  static final KycRepository _instance = KycRepository._internal();
  factory KycRepository() => _instance;
  KycRepository._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference get _parentDoc => _db.collection('parents').doc(_uid);

  // ─────────────────────────────────────────────────────────────────────────
  // Lecture de l'état courant
  // ─────────────────────────────────────────────────────────────────────────

  Future<KycStatus> getCurrentStatus() async {
    try {
      final doc = await _parentDoc.get();
      if (!doc.exists) return KycStatus.notStarted;
      final data = doc.data() as Map<String, dynamic>?;
      return KycStatusLabel.fromFirestore(data?['kycStatus'] as String?);
    } catch (e) {
      debugPrint('KYC_REPO: Erreur lecture statut: $e');
      return KycStatus.notStarted;
    }
  }

  Stream<KycStatus> watchStatus() {
    if (_uid == null) return Stream.value(KycStatus.notStarted);
    return _parentDoc.snapshots().map((snap) {
      if (!snap.exists) return KycStatus.notStarted;
      final data = snap.data() as Map<String, dynamic>?;
      return KycStatusLabel.fromFirestore(data?['kycStatus'] as String?);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mise à jour du statut
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateStatus(KycStatus status) async {
    try {
      final updates = <String, dynamic>{
        'kycStatus': status.firestoreValue,
        'kycUpdatedAt': FieldValue.serverTimestamp(),
      };

      if (status == KycStatus.pending) {
        updates['kycSubmittedAt'] = FieldValue.serverTimestamp();
        updates['kycVersion'] = FieldValue.increment(1);
      } else if (status == KycStatus.verified) {
        updates['kycValidatedAt'] = FieldValue.serverTimestamp();
      }

      await _parentDoc.update(updates);

      // Synchronise ApiService pour la garde de navigation
      if (status == KycStatus.verified) {
        await ApiService().updateKycStatus('VERIFIED');
      } else if (status == KycStatus.pending) {
        await ApiService().updateKycStatus('PENDING');
      }

      debugPrint('KYC_REPO: Statut mis à jour → ${status.firestoreValue}');
    } catch (e) {
      debugPrint('KYC_REPO: Erreur mise à jour statut: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // "Upload" — stocke uniquement les métadonnées et l'image base64 dans Firestore
  // (firebase_storage non disponible dans ce projet)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> uploadDocument(File imageFileFront, String documentType,
      {File? imageFileBack, File? imageFileSelfie}) async {
    if (_uid == null) return null;
    try {
      final bytesFront = await imageFileFront.readAsBytes();
      final base64ImageFront = base64Encode(bytesFront);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final meta = <String, dynamic>{
        'localPath': imageFileFront.path,
        'documentType': documentType,
        'uploadedAt': timestamp,
        'uid': _uid,
      };

      // Si l'image fait moins de 800 Ko, on l'enregistre en Base64.
      if (bytesFront.length < 800000) {
        meta['base64Image'] = base64ImageFront;
        debugPrint('KYC_REPO: Image Recto Base64 intégrée aux métadonnées.');
      } else {
        debugPrint(
            'KYC_REPO: Image Recto trop volumineuse (${bytesFront.length} octets).');
      }

      if (imageFileBack != null) {
        final bytesBack = await imageFileBack.readAsBytes();
        final base64ImageBack = base64Encode(bytesBack);
        meta['localPathBack'] = imageFileBack.path;
        if (bytesBack.length < 800000) {
          meta['base64ImageBack'] = base64ImageBack;
          debugPrint('KYC_REPO: Image Verso Base64 intégrée aux métadonnées.');
        } else {
          debugPrint(
              'KYC_REPO: Image Verso trop volumineuse (${bytesBack.length} octets).');
        }
      }

      if (imageFileSelfie != null) {
        final bytesSelfie = await imageFileSelfie.readAsBytes();
        final base64ImageSelfie = base64Encode(bytesSelfie);
        meta['localPathSelfie'] = imageFileSelfie.path;
        if (bytesSelfie.length < 800000) {
          meta['base64ImageSelfie'] = base64ImageSelfie;
          debugPrint('KYC_REPO: Image Selfie Base64 intégrée aux métadonnées.');
        } else {
          debugPrint(
              'KYC_REPO: Image Selfie trop volumineuse (${bytesSelfie.length} octets).');
        }
      }

      await _parentDoc.update({'kycDocumentMeta': meta});
      debugPrint(
          'KYC_REPO: Métadonnées document (recto/verso/selfie) enregistrées avec succès.');
      return 'firestore://parents/$_uid/kycDocumentMeta';
    } catch (e) {
      debugPrint('KYC_REPO: Erreur enregistrement meta: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Enregistrement d'une tentative dans l'historique
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordAttempt({
    required KycAnalysisResult result,
    required String selectedDocType,
    String? storagePath,
  }) async {
    try {
      final attempt = {
        'timestamp': FieldValue.serverTimestamp(),
        'selectedDocType': selectedDocType,
        'detectedDocType': result.documentType,
        'confidence': result.confidence,
        'qualityScore': result.qualityScore,
        'isAccepted': result.isAccepted,
        'warnings': result.warnings,
        'processingTimeMs': result.processingTime.inMilliseconds,
        'errorCode': result.error?.code.name,
      };

      await _parentDoc.update({
        'kycAttempts': FieldValue.arrayUnion([attempt]),
      });

      debugPrint(
          'KYC_REPO: Tentative enregistrée (accepted=${result.isAccepted})');
    } catch (e) {
      debugPrint('KYC_REPO: Erreur enregistrement tentative: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Suppression du fichier temporaire local
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteTemporaryFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('KYC_REPO: Fichier temporaire supprimé: ${file.path}');
      }
    } catch (e) {
      debugPrint('KYC_REPO: Erreur suppression fichier: $e');
    }
  }
}
