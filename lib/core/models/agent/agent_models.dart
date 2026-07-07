import 'package:flutter/material.dart';

/// Niveau de risque attribué par l'agent IA (cf. §2 et §4 de la spécification).
///   • low      → faible
///   • moderate → modéré
///   • critical → critique
enum RiskLevel { low, moderate, critical }

extension RiskLevelX on RiskLevel {
  /// Libellé lisible en français (utilisé dans l'UI).
  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Faible';
      case RiskLevel.moderate:
        return 'Modéré';
      case RiskLevel.critical:
        return 'Critique';
    }
  }

  /// Couleur d'affichage associée au niveau de risque.
  Color get color {
    switch (this) {
      case RiskLevel.low:
        return const Color(0xFF22C55E); // vert
      case RiskLevel.moderate:
        return const Color(0xFFF59E0B); // orange
      case RiskLevel.critical:
        return const Color(0xFFEF4444); // rouge
    }
  }

  /// Conversion vers la sévérité textuelle utilisée dans Firestore.
  String get severityString {
    switch (this) {
      case RiskLevel.low:
        return 'INFO';
      case RiskLevel.moderate:
        return 'MEDIUM';
      case RiskLevel.critical:
        return 'CRITICAL';
    }
  }

  /// Parse depuis une chaîne (réponse IA ou champ Firestore).
  static RiskLevel parse(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'critical':
      case 'critique':
      case 'high':
      case 'eleve':
      case 'élevé':
        return RiskLevel.critical;
      case 'moderate':
      case 'modere':
      case 'modéré':
      case 'medium':
      case 'moyen':
        return RiskLevel.moderate;
      default:
        return RiskLevel.low;
    }
  }
}

/// AgentAnalysis — résultat de l'enrichissement d'une alerte par l'IA (§4).
///
/// Chaque alerte brute remontée par l'enfant est enrichie d'une couche
/// d'analyse intelligente : gravité, fréquence, analyse contextuelle et
/// commentaire en langage naturel.
class AgentAnalysis {
  /// Niveau de gravité (faible / modéré / critique).
  final RiskLevel risk;

  /// Fréquence du comportement observé (ex: « 3 fois cette semaine »).
  final String frequency;

  /// Analyse contextuelle de la situation.
  final String context;

  /// Commentaire explicatif en langage naturel destiné au parent.
  final String comment;

  /// Actions rapides recommandées (libellés courts).
  final List<String> recommendedActions;

  const AgentAnalysis({
    required this.risk,
    required this.frequency,
    required this.context,
    required this.comment,
    this.recommendedActions = const [],
  });

  factory AgentAnalysis.fromJson(Map<String, dynamic> json) {
    return AgentAnalysis(
      risk: RiskLevelX.parse(json['risk'] as String? ?? json['severity'] as String?),
      frequency: json['frequency'] as String? ?? 'Non déterminée',
      context: json['context'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      recommendedActions: (json['actions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  /// Sérialisation pour réécriture dans le document d'alerte Firestore.
  Map<String, dynamic> toFirestore() => {
        'aiRisk': risk.name,
        'aiSeverity': risk.severityString,
        'aiFrequency': frequency,
        'aiContext': context,
        'aiComment': comment,
        'aiActions': recommendedActions,
      };
}

/// Recommendation — proposition d'action proactive de l'agent (§6).
///
/// [type] détermine l'action applicable automatiquement via
/// GuardianAgentService.appliquerRecommandation().
class Recommendation {
  /// Type machine de la recommandation :
  /// REDUCE_LIMIT | BLOCK_APP | ADJUST_HOURS | DIGITAL_BREAK | INFO
  final String type;

  /// Titre court de la recommandation.
  final String title;

  /// Explication détaillée à destination du parent.
  final String description;

  /// Paramètres optionnels (ex: {'minutes': 90} ou {'package': 'com.tiktok'}).
  final Map<String, dynamic> params;

  const Recommendation({
    required this.type,
    required this.title,
    required this.description,
    this.params = const {},
  });

  /// Indique si la recommandation peut être appliquée automatiquement.
  bool get isApplicable => type != 'INFO';

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      type: (json['type'] as String? ?? 'INFO').toUpperCase(),
      title: json['title'] as String? ?? 'Recommandation',
      description: json['description'] as String? ?? '',
      params: (json['params'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// BehaviorAnomaly — comportement inhabituel détecté (§8).
///
/// Ex: usage nocturne excessif, usage intensif d'apps addictives,
/// sortie de zone géographique autorisée.
class BehaviorAnomaly {
  /// Type machine : NIGHT_USAGE | ADDICTIVE_APP | GEOFENCE_EXIT | UNUSUAL_MOVEMENT
  final String type;
  final String title;
  final String description;
  final RiskLevel risk;

  const BehaviorAnomaly({
    required this.type,
    required this.title,
    required this.description,
    required this.risk,
  });
}

/// WeeklyReport — rapport d'activité hebdomadaire synthétique (§7).
class WeeklyReport {
  /// Temps d'écran total sur la semaine (minutes).
  final int totalMinutes;

  /// Classement des applications les plus utilisées (nom -> minutes).
  final List<MapEntry<String, int>> topApps;

  /// Nombre total d'alertes déclenchées sur la période.
  final int alertsCount;

  /// Analyse de l'évolution des comportements (rédigée par l'IA).
  final String evolution;

  /// Conseils personnalisés à destination des parents.
  final List<String> advice;

  /// Moment de génération du rapport.
  final DateTime generatedAt;

  const WeeklyReport({
    required this.totalMinutes,
    required this.topApps,
    required this.alertsCount,
    required this.evolution,
    required this.advice,
    required this.generatedAt,
  });

  /// Temps d'écran moyen par jour (minutes).
  int get dailyAverage => (totalMinutes / 7).round();
}
