/// Modèle riche retourné par KycService après l'analyse d'un document.
class KycAnalysisResult {
  final String? documentType; // 'CNI' | 'PASSPORT' | 'DRIVERS_LICENSE' | null
  final double confidence; // 0.0 → 1.0
  final double qualityScore; // 0.0 → 1.0 (luminosité, netteté)
  final bool isBlurred;
  final bool isDocumentDetected;
  final bool isAccepted;
  final List<String> warnings;
  final Duration processingTime;
  final KycError? error;

  const KycAnalysisResult({
    this.documentType,
    this.confidence = 0.0,
    this.qualityScore = 0.0,
    this.isBlurred = false,
    this.isDocumentDetected = false,
    this.isAccepted = false,
    this.warnings = const [],
    this.processingTime = Duration.zero,
    this.error,
  });

  /// Résultat de rejet avec une erreur explicite.
  factory KycAnalysisResult.failure(KycError error) => KycAnalysisResult(
        isDocumentDetected: false,
        isAccepted: false,
        error: error,
      );

  /// Résultat réussi avec les données d'analyse.
  factory KycAnalysisResult.success({
    required String documentType,
    required double confidence,
    required double qualityScore,
    required Duration processingTime,
    List<String> warnings = const [],
  }) =>
      KycAnalysisResult(
        documentType: documentType,
        confidence: confidence,
        qualityScore: qualityScore,
        isBlurred: qualityScore < 0.4,
        isDocumentDetected: true,
        isAccepted: confidence >= 0.6 && qualityScore >= 0.4,
        warnings: warnings,
        processingTime: processingTime,
      );

  @override
  String toString() =>
      'KycAnalysisResult(type=$documentType, conf=${confidence.toStringAsFixed(2)}, quality=${qualityScore.toStringAsFixed(2)}, accepted=$isAccepted)';
}

// ── États du parcours KYC ────────────────────────────────────────────────────

enum KycStatus {
  notStarted,
  inProgress,
  analysing,
  pending,
  verified,
  rejected,
}

extension KycStatusLabel on KycStatus {
  String get label {
    switch (this) {
      case KycStatus.notStarted:
        return 'Non commencé';
      case KycStatus.inProgress:
        return 'En cours';
      case KycStatus.analysing:
        return 'Analyse';
      case KycStatus.pending:
        return 'En attente';
      case KycStatus.verified:
        return 'Validé';
      case KycStatus.rejected:
        return 'Refusé';
    }
  }

  String get firestoreValue {
    switch (this) {
      case KycStatus.notStarted:
        return 'NOT_STARTED';
      case KycStatus.inProgress:
        return 'IN_PROGRESS';
      case KycStatus.analysing:
        return 'ANALYSING';
      case KycStatus.pending:
        return 'PENDING';
      case KycStatus.verified:
        return 'VERIFIED';
      case KycStatus.rejected:
        return 'REJECTED';
    }
  }

  static KycStatus fromFirestore(String? value) {
    switch (value) {
      case 'IN_PROGRESS':
        return KycStatus.inProgress;
      case 'ANALYSING':
        return KycStatus.analysing;
      case 'PENDING':
        return KycStatus.pending;
      case 'VERIFIED':
        return KycStatus.verified;
      case 'REJECTED':
        return KycStatus.rejected;
      default:
        return KycStatus.notStarted;
    }
  }
}

// ── Erreurs hiérarchiques ────────────────────────────────────────────────────

enum KycErrorCode {
  blurredDocument,
  croppedDocument,
  documentNotRecognized,
  insufficientLighting,
  cameraUnavailable,
  analysisInterrupted,
  modelNotLoaded,
  uploadFailed,
  unknown,
}

class KycError {
  final KycErrorCode code;
  final String message;
  final String solution;

  const KycError({
    required this.code,
    required this.message,
    required this.solution,
  });

  static const blurred = KycError(
    code: KycErrorCode.blurredDocument,
    message: 'La photo est floue.',
    solution: 'Stabilisez votre téléphone et réessayez.',
  );

  static const cropped = KycError(
    code: KycErrorCode.croppedDocument,
    message: 'Le document est coupé.',
    solution: 'Reculez légèrement pour capturer le document entier.',
  );

  static const notRecognized = KycError(
    code: KycErrorCode.documentNotRecognized,
    message: 'Document non reconnu.',
    solution:
        'Vérifiez que vous utilisez une CNI, un passeport ou un permis valide.',
  );

  static const lighting = KycError(
    code: KycErrorCode.insufficientLighting,
    message: 'Éclairage insuffisant.',
    solution:
        'Placez-vous sous une bonne lumière naturelle ou activez la lampe torche.',
  );

  static const cameraUnavailable = KycError(
    code: KycErrorCode.cameraUnavailable,
    message: 'Caméra inaccessible.',
    solution:
        'Autorisez l\'accès à la caméra dans les paramètres de votre téléphone.',
  );

  static const interrupted = KycError(
    code: KycErrorCode.analysisInterrupted,
    message: 'Analyse interrompue.',
    solution: 'Vérifiez votre connexion internet et réessayez.',
  );

  static const modelNotLoaded = KycError(
    code: KycErrorCode.modelNotLoaded,
    message: 'Modèle d\'analyse non disponible.',
    solution: 'Vérifiez votre connexion et relancez l\'application.',
  );

  static const uploadFailed = KycError(
    code: KycErrorCode.uploadFailed,
    message: 'Échec de l\'envoi du document.',
    solution: 'Vérifiez votre connexion internet et réessayez.',
  );

  static KycError unknown(String detail) => KycError(
        code: KycErrorCode.unknown,
        message: 'Une erreur est survenue.',
        solution: 'Réessayez. Si le problème persiste : $detail',
      );
}
