import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertSeverity { info, warning, critical }

class AlertModel {
  final String id;
  final String childId;
  final String title;
  final String description;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String? type; // legacy type e.g., 'GEOFENCE', 'CONTENT'
  final String? genre; // new classification field
  final String? status; // e.g., 'PENDING', 'TESTED'
  final String? actionType; // e.g., 'WEB_SEARCH', 'KEYWORD'
  final String? actionValue; // e.g., 'pornhub.com' or 'gambling'
  final bool read;
  final Map<String, dynamic>? metadata;

  // ── Champs d'enrichissement écrits par l'agent IA (§4) ────────────────────
  final String? aiComment; // commentaire en langage naturel
  final String? aiRisk; // niveau de risque (low/moderate/critical)
  final String? aiFrequency; // fréquence observée
  final String? aiContext; // analyse contextuelle
  final List<String> aiActions; // actions rapides recommandées
  final bool aiProcessed; // alerte déjà analysée par l'agent

  AlertModel({
    required this.id,
    required this.childId,
    required this.title,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.type,
    this.genre,
    this.status,
    this.actionType,
    this.actionValue,
    this.read = false,
    this.metadata,
    this.aiComment,
    this.aiRisk,
    this.aiFrequency,
    this.aiContext,
    this.aiActions = const [],
    this.aiProcessed = false,
  });

  bool get isInteractive => actionType != null && actionValue != null;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] ?? '',
      childId: json['childId'] ?? '',
      title: json['title'] ?? 'Guardian Alert',
      description: json['description'] ?? '',
      severity: _parseSeverity(json['severity']),
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is String 
              ? DateTime.parse(json['timestamp']) 
              : (json['timestamp'] as Timestamp).toDate())
          : DateTime.now(),
      type: json['type'],
      genre: json['genre'],
      status: json['status'] ?? 'PENDING',
      actionType: json['actionType'],
      actionValue: json['actionValue'],
      read: json['read'] ?? false,
      metadata: json['metadata'],
      aiComment: json['aiComment'],
      aiRisk: json['aiRisk'],
      aiFrequency: json['aiFrequency'],
      aiContext: json['aiContext'],
      aiActions: (json['aiActions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      aiProcessed: json['ai_processed'] ?? false,
    );
  }

  /// Indique si l'agent IA a déjà enrichi cette alerte d'un commentaire.
  bool get hasAiAnalysis => aiComment != null && aiComment!.trim().isNotEmpty;

  static AlertSeverity _parseSeverity(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL': return AlertSeverity.critical;
      case 'WARNING': return AlertSeverity.warning;
      default: return AlertSeverity.info;
    }
  }
}

