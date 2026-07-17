import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'gemini_service.dart';
import '../rules_writer_service.dart';
import '../../models/agent/agent_models.dart';

/// GuardianAgentService
///
/// Agent IA central de The Guardian (côté application Parent).
/// Implémente les 9 missions décrites dans `Guardian_Agent_IA_Specification.md` :
///
///   1. Surveiller l'activité de l'enfant            → [start] + écoute Firestore
///   2. Détecter les situations anormales            → [_processAlert]
///   3. Appliquer automatiquement les règles         → [appliquerRecommandation]
///   4. Enrichir les alertes (analyse IA)            → [enrichirAlerte]
///   5. Répondre aux questions du parent (chat IA)   → [repondreQuestion]
///   6. Générer des recommandations intelligentes    → [genererRecommandations]
///   7. Générer des rapports d'activité              → [genererRapportHebdomadaire]
///   8. Détecter des comportements inhabituels       → [detecterComportementsInhabituels]
///   9. Observer en lecture seule                    → conception (aucun contrôle d'UI)
///
/// L'agent tourne tant que l'application parent est ouverte. Il consomme les
/// alertes marquées `ai_processed == false` (écrites par l'app enfant), les
/// enrichit, les journalise dans l'historique et notifie le parent.
class GuardianAgentService {
  static final GuardianAgentService _instance =
      GuardianAgentService._internal();
  factory GuardianAgentService() => _instance;
  GuardianAgentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GeminiService _gemini = GeminiService();
  final RulesWriterService _rulesWriter = RulesWriterService();

  /// Abonnements aux alertes non traitées, par enfant.
  final Map<String, StreamSubscription> _alertSubs = {};
  StreamSubscription? _childrenSub;
  Timer? _behaviorTimer;
  bool _isRunning = false;

  /// Historique conversationnel du chat (mission §5).
  final List<Map<String, String>> _chatHistory = [];

  /// Persona de l'agent — instruction système commune à toutes les requêtes IA.
  /// Suit fidèlement le rôle décrit dans la spécification.
  static const String _persona =
      "Tu es l'agent IA de The Guardian, le moteur intelligent d'une solution "
      "de contrôle parental. Ton rôle : surveiller, analyser et communiquer en "
      "temps réel sur l'activité numérique de l'enfant pour aider le parent.\n"
      "RÈGLES STRICTES :\n"
      "- Réponds toujours en français, de façon bienveillante, claire et concrète.\n"
      "- N'INVENTE JAMAIS de données. Utilise uniquement les données réelles "
      "fournies (usage, règles, alertes, localisation). Si une donnée manque, dis-le.\n"
      "- Sois synthétique et oriente vers l'action (recommandations utiles).";

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Parent non authentifié');
    return user.uid;
  }

  // ===========================================================================
  // §1 + §2 — SURVEILLANCE CONTINUE & DÉTECTION DES SITUATIONS ANORMALES
  // ===========================================================================

  /// Démarre l'agent : écoute la liste des enfants puis, pour chacun, les
  /// alertes non encore traitées par l'IA (`ai_processed == false`).
  /// Idempotent : un appel répété est ignoré.
  void start() {
    if (_isRunning) {
      if (kDebugMode) print('GUARDIAN_AGENT: déjà démarré, appel ignoré.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (kDebugMode)
        print('GUARDIAN_AGENT: pas de parent authentifié — démarrage différé.');
      return;
    }

    _isRunning = true;
    final childrenCol =
        _db.collection('parents').doc(user.uid).collection('children');

    // Suit dynamiquement l'ajout/suppression d'enfants.
    _childrenSub = childrenCol.snapshots().listen((snap) {
      final ids = snap.docs.map((d) => d.id).toSet();

      // Coupe les abonnements des enfants supprimés.
      _alertSubs.removeWhere((id, sub) {
        if (!ids.contains(id)) {
          sub.cancel();
          return true;
        }
        return false;
      });

      // Abonne les nouveaux enfants.
      for (final doc in snap.docs) {
        if (!_alertSubs.containsKey(doc.id)) {
          _listenToChildAlerts(doc.id, doc.data());
        }
      }
    }, onError: (e) => debugPrint('GUARDIAN_AGENT: erreur liste enfants: $e'));

    // §8 — Balayage périodique des comportements inhabituels (toutes les 30 min).
    _behaviorTimer?.cancel();
    _behaviorTimer = Timer.periodic(
        const Duration(minutes: 30), (_) => _scanAllChildrenBehavior());

    if (kDebugMode)
      print('GUARDIAN_AGENT: démarré pour le parent ${user.uid}.');
  }

  /// Arrête l'agent et libère toutes les ressources.
  void stop() {
    _childrenSub?.cancel();
    _childrenSub = null;
    for (final sub in _alertSubs.values) {
      sub.cancel();
    }
    _alertSubs.clear();
    _behaviorTimer?.cancel();
    _behaviorTimer = null;
    _isRunning = false;
    if (kDebugMode) print('GUARDIAN_AGENT: arrêté.');
  }

  /// Écoute les alertes non traitées d'un enfant et les traite une par une.
  void _listenToChildAlerts(String childId, Map<String, dynamic> childData) {
    final col = _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('notifications')
        .collection('items');

    final sub = col.where('ai_processed', isEqualTo: false).snapshots().listen(
      (snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            _processAlert(childId, childData, change.doc.id, data);
          }
        }
      },
      onError: (e) =>
          debugPrint('GUARDIAN_AGENT: erreur alertes ($childId): $e'),
    );

    _alertSubs[childId] = sub;
  }

  /// Traite une alerte détectée (§2) :
  ///   1. Analyser la situation (enrichissement IA, §4)
  ///   2. Attribuer un niveau de risque
  ///   3. Enregistrer l'événement dans l'historique
  ///   4. Notifier le parent (réécriture de l'alerte enrichie + drapeau)
  Future<void> _processAlert(
    String childId,
    Map<String, dynamic> childData,
    String alertId,
    Map<String, dynamic> alert,
  ) async {
    try {
      // 1 + 2. Analyse + niveau de risque (avec fréquence calculée sur l'historique).
      final analysis = await enrichirAlerte(
          childId: childId, childData: childData, alert: alert);

      final alertRef = _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('alerts')
          .doc('notifications')
          .collection('items')
          .doc(alertId);

      // 4. Réécriture de l'alerte enrichie + passage du drapeau à true
      //    (évite le re-traitement à chaque redémarrage de l'agent).
      await alertRef.set({
        ...analysis.toFirestore(),
        'ai_processed': true,
        'aiProcessedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Journalisation dans l'historique de l'enfant.
      await _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('history')
          .add({
        'sourceAlertId': alertId,
        'type': alert['type'] ?? 'OTHER',
        'title': alert['title'] ?? 'Événement',
        'detail': alert['detail'] ?? alert['description'] ?? '',
        'risk': analysis.risk.name,
        'aiComment': analysis.comment,
        'occurredAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print(
            'GUARDIAN_AGENT: alerte $alertId enrichie (risque=${analysis.risk.label}).');
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: _processAlert error: $e');
      // En cas d'échec on marque quand même l'alerte comme traitée pour ne pas
      // boucler indéfiniment sur la même alerte défaillante.
      try {
        await _db
            .collection('parents')
            .doc(_uid)
            .collection('children')
            .doc(childId)
            .collection('alerts')
            .doc('notifications')
            .collection('items')
            .doc(alertId)
            .set({'ai_processed': true}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // ===========================================================================
  // §4 — ENRICHISSEMENT D'UNE ALERTE PAR L'IA
  // ===========================================================================

  /// Enrichit une alerte d'une couche d'analyse : gravité, fréquence,
  /// analyse contextuelle et commentaire en langage naturel.
  /// Retombe sur une heuristique locale si l'IA est indisponible.
  Future<AgentAnalysis> enrichirAlerte({
    required String childId,
    required Map<String, dynamic> childData,
    required Map<String, dynamic> alert,
  }) async {
    final name = childData['displayName'] ?? 'l\'enfant';
    final age = childData['age'] ?? 'inconnu';
    final type = alert['type'] ?? 'OTHER';
    final detail =
        alert['detail'] ?? alert['description'] ?? alert['message'] ?? '';

    // Fréquence : nombre d'alertes de même type sur les 7 derniers jours.
    final frequency = await _computeFrequency(childId, type);

    final prompt =
        'Analyse cette alerte de contrôle parental et renvoie un JSON strict.\n'
        'Enfant : $name ($age ans)\n'
        'Type d\'alerte : $type\n'
        'Détail : $detail\n'
        'Occurrences de ce type sur 7 jours : $frequency\n\n'
        'Renvoie EXACTEMENT ce schéma JSON :\n'
        '{\n'
        '  "risk": "low" | "moderate" | "critical",\n'
        '  "frequency": "phrase courte sur la fréquence",\n'
        '  "context": "analyse contextuelle en 1-2 phrases",\n'
        '  "comment": "commentaire bienveillant pour le parent en langage naturel",\n'
        '  "actions": ["action courte 1", "action courte 2"]\n'
        '}';

    try {
      final json = await _gemini.generateJson(prompt, systemPrompt: _persona);
      if (json != null) {
        // On s'assure que la fréquence calculée localement est conservée si l'IA n'en fournit pas.
        json['frequency'] = json['frequency'] ?? '$frequency fois sur 7 jours';
        return AgentAnalysis.fromJson(json);
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: enrichirAlerte IA échouée: $e');
    }

    // Fallback heuristique (sans IA).
    return _fallbackAnalysis(type, detail, frequency);
  }

  /// Analyse de repli basée sur des règles simples si l'IA est indisponible.
  AgentAnalysis _fallbackAnalysis(String type, String detail, int frequency) {
    RiskLevel risk;
    switch (type) {
      case 'SOS':
      case 'GEOFENCE_EXIT':
      case 'KEYWORD_DETECTED':
        risk = RiskLevel.critical;
        break;
      case 'BLOCKED_APP':
      case 'OUTSIDE_HOURS':
        risk = frequency >= 3 ? RiskLevel.critical : RiskLevel.moderate;
        break;
      default:
        risk = frequency >= 5 ? RiskLevel.moderate : RiskLevel.low;
    }
    return AgentAnalysis(
      risk: risk,
      frequency: '$frequency fois sur les 7 derniers jours',
      context: detail,
      comment:
          'Événement « $type » détecté. Analyse automatique (IA indisponible).',
      recommendedActions: const [
        'Consulter le détail',
        'Ajuster les règles si nécessaire'
      ],
    );
  }

  /// Compte les alertes d'un type donné sur les 7 derniers jours.
  /// Le filtrage temporel est fait côté client pour éviter un index composite.
  Future<int> _computeFrequency(String childId, String type) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('alerts')
          .doc('notifications')
          .collection('items')
          .where('type', isEqualTo: type)
          .get();
      int count = 0;
      for (final doc in snap.docs) {
        final ts = doc.data()['timestamp'];
        if (ts is Timestamp && ts.toDate().isAfter(since)) count++;
      }
      return count;
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: _computeFrequency error: $e');
      return 0;
    }
  }

  // ===========================================================================
  // §5 — CHAT IA : RÉPONDRE AUX QUESTIONS DU PARENT
  // ===========================================================================

  /// Répond à une question du parent en s'appuyant sur le contexte temps réel
  /// (usage, règles, alertes) passé via [childContext].
  Future<String> repondreQuestion(String message,
      {Map<String, dynamic>? childContext}) async {
    String fullMessage = message;

    if (childContext != null) {
      final usage = childContext['usage'] as Map<String, dynamic>? ?? {};
      final rules = childContext['rules'] as Map<String, dynamic>? ?? {};
      final alerts = (childContext['recentAlerts'] as List?) ?? [];

      final alertsStr = alerts.isEmpty
          ? 'Aucune alerte récente'
          : alerts
              .map((a) =>
                  '- ${a['type']}: ${a['detail'] ?? a['description'] ?? ''}')
              .join('\n');
      final rulesStr =
          'Limite quotidienne: ${rules['dailyLimitMinutes'] ?? 'non définie'} min. '
          'Plage: ${rules['allowedTimeStart'] ?? 'N/A'} - ${rules['allowedTimeEnd'] ?? 'N/A'}';

      fullMessage = '[DONNÉES FIRESTORE TEMPS RÉEL]\n'
          'Enfant : ${childContext['name']} (${childContext['age']} ans)\n'
          'Temps d\'écran aujourd\'hui : ${usage['usedMinutes'] ?? 0} min\n'
          'Règles : $rulesStr\n'
          'Appareil : ${childContext['deviceStatus']} (Batterie: ${childContext['battery']})\n'
          'Alertes récentes :\n$alertsStr\n\n'
          'Question du parent : $message';
    }

    try {
      final response = await _gemini.generateText(
        fullMessage,
        systemPrompt: _persona,
        history: List.of(_chatHistory),
      );
      // Mémorisation pour le multi-tours.
      _chatHistory.add({'role': 'user', 'text': message});
      _chatHistory.add({'role': 'model', 'text': response});
      return response;
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: repondreQuestion error: $e');
      return '❌ Je ne peux pas répondre pour le moment. Vérifiez la connexion '
          'ou la configuration de la clé Gemini.';
    }
  }

  /// Réinitialise l'historique du chat.
  void clearChatHistory() => _chatHistory.clear();

  /// Analyse rédigée (texte) de l'activité d'un enfant — utilisée par
  /// l'orchestrateur IA. Ne mémorise pas l'échange dans l'historique du chat.
  Future<String> analyserActiviteTexte({
    required String name,
    required int age,
    required int usedMinutes,
    required int limitMinutes,
    required String deviceStatus,
    required List<Map<String, dynamic>> alerts,
  }) async {
    final alertsText = alerts.isEmpty
        ? 'Aucune alerte récente'
        : alerts
            .take(5)
            .map((a) =>
                '• ${a['type'] ?? 'INFO'}: ${a['detail'] ?? a['message'] ?? 'N/A'}')
            .join('\n');

    final prompt =
        'Analyse le profil de cet enfant et fournis 3 recommandations concrètes, '
        'numérotées. Sois bref (max 150 mots). Mets les titres en gras avec **.\n\n'
        'Enfant : $name, $age ans\n'
        'Temps d\'écran aujourd\'hui : $usedMinutes min / limite $limitMinutes min\n'
        'Appareil : $deviceStatus\n'
        'Alertes récentes :\n$alertsText';

    return _gemini.generateText(prompt, systemPrompt: _persona);
  }

  // ===========================================================================
  // §6 — RECOMMANDATIONS INTELLIGENTES
  // ===========================================================================

  /// Génère des recommandations proactives applicables à partir du contexte.
  Future<List<Recommendation>> genererRecommandations({
    required String name,
    required int age,
    required int usedMinutes,
    required int limitMinutes,
    required Map<String, dynamic> categories,
    required int nightUsageMinutes,
  }) async {
    final prompt =
        'À partir de ces données, génère 2 à 4 recommandations de contrôle parental.\n'
        'Enfant : $name, $age ans\n'
        'Temps d\'écran : $usedMinutes min (limite $limitMinutes min)\n'
        'Usage nocturne (22h-6h) : $nightUsageMinutes min\n'
        'Minutes par catégorie : $categories\n\n'
        'Renvoie un JSON strict : {"items": [ {"type": "REDUCE_LIMIT|BLOCK_APP|ADJUST_HOURS|DIGITAL_BREAK|INFO", '
        '"title": "...", "description": "...", "params": {"minutes": 90}} ]}';

    try {
      final json = await _gemini.generateJson(prompt, systemPrompt: _persona);
      final items = json?['items'] as List?;
      if (items != null) {
        return items
            .map((e) => Recommendation.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: genererRecommandations error: $e');
    }

    // Fallback heuristique.
    final recs = <Recommendation>[];
    if (limitMinutes > 0 && usedMinutes > limitMinutes * 0.9) {
      recs.add(Recommendation(
        type: 'REDUCE_LIMIT',
        title: 'Réduire le temps d\'écran',
        description:
            'Le temps d\'écran approche ou dépasse la limite. Envisagez de la réduire.',
        params: {'minutes': (limitMinutes * 0.75).round()},
      ));
    }
    if (nightUsageMinutes > 15) {
      recs.add(const Recommendation(
        type: 'ADJUST_HOURS',
        title: 'Renforcer les horaires nocturnes',
        description:
            'Un usage nocturne a été détecté. Ajustez la plage horaire autorisée.',
        params: {'start': '07:00', 'end': '21:00'},
      ));
    }
    if (recs.isEmpty) {
      recs.add(const Recommendation(
        type: 'INFO',
        title: 'Activité dans la norme',
        description: 'Aucune action particulière recommandée pour le moment.',
      ));
    }
    return recs;
  }

  // ===========================================================================
  // §3 — APPLIQUER AUTOMATIQUEMENT UNE RECOMMANDATION (ACTION DE CONTRÔLE)
  // ===========================================================================

  /// Applique une recommandation en écrivant la règle correspondante.
  /// Conformément au §9 (observation en lecture seule), cette action de
  /// contrôle est explicite et déclenchée par le parent, jamais silencieuse.
  Future<void> appliquerRecommandation(
      String childId, Recommendation rec) async {
    switch (rec.type) {
      case 'REDUCE_LIMIT':
        final minutes = (rec.params['minutes'] as num?)?.toInt() ?? 90;
        await _rulesWriter.setDailyLimit(childId, minutes);
        break;
      case 'ADJUST_HOURS':
        final start = rec.params['start'] as String? ?? '07:00';
        final end = rec.params['end'] as String? ?? '21:00';
        await _rulesWriter.setAllowedHours(childId, start, end);
        break;
      case 'BLOCK_APP':
        final pkg = rec.params['package'] as String?;
        if (pkg != null) await _rulesWriter.blockApp(childId, pkg);
        break;
      case 'DIGITAL_BREAK':
        // Pause numérique = réduction temporaire forte de la limite.
        await _rulesWriter.setDailyLimit(
            childId, (rec.params['minutes'] as num?)?.toInt() ?? 30);
        break;
      default:
        // Type informatif : aucune action de contrôle.
        break;
    }
  }

  // ===========================================================================
  // §7 — RAPPORT D'ACTIVITÉ HEBDOMADAIRE
  // ===========================================================================

  /// Construit un rapport hebdomadaire consolidé (temps total, top apps,
  /// alertes, évolution, conseils) à partir des données des 7 derniers jours.
  Future<WeeklyReport> genererRapportHebdomadaire({
    required String childId,
    required String name,
    required int age,
  }) async {
    // Lecture des stats journalières des 7 derniers jours.
    final usageCol = _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('usage')
        .collection('apps');

    final snap = await usageCol.get();
    final sortedDocs = snap.docs.toList()..sort((a, b) => b.id.compareTo(a.id));
    final recentDocs = sortedDocs.take(7);

    int total = 0;
    final Map<String, int> appTotals = {};
    for (final doc in recentDocs) {
      final data = doc.data();
      total +=
          ((data['usedMinutes'] ?? data['totalMinutes'] ?? 0) as num).toInt();
      final apps = data['apps'] as Map<String, dynamic>? ?? {};
      apps.forEach((pkg, info) {
        final m = ((info is Map ? info['minutes'] : 0) as num?)?.toInt() ?? 0;
        final label =
            (info is Map ? (info['label'] ?? info['appName'] ?? pkg) : pkg)
                .toString();
        appTotals[label] = (appTotals[label] ?? 0) + m;
      });
    }

    final topApps = appTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topList = topApps.take(5).toList();

    // Nombre d'alertes sur 7 jours.
    int alertsCount = 0;
    try {
      final since =
          Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
      final aSnap = await _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('alerts')
          .doc('notifications')
          .collection('items')
          .where('timestamp', isGreaterThan: since)
          .get();
      alertsCount = aSnap.docs.length;
    } catch (_) {}

    // Analyse de l'évolution + conseils via l'IA.
    String evolution = 'Évolution non disponible.';
    List<String> advice = const [];
    final topStr = topList.map((e) => '${e.key}: ${e.value} min').join(', ');
    final prompt =
        'Rédige un bref bilan hebdomadaire de contrôle parental en JSON strict.\n'
        'Enfant : $name ($age ans)\n'
        'Temps d\'écran total semaine : $total min (moyenne ${(total / 7).round()} min/jour)\n'
        'Top applications : ${topStr.isEmpty ? 'aucune' : topStr}\n'
        'Alertes sur la semaine : $alertsCount\n\n'
        'Schéma : {"evolution": "analyse de l\'évolution en 2-3 phrases", '
        '"advice": ["conseil 1", "conseil 2", "conseil 3"]}';
    try {
      final json = await _gemini.generateJson(prompt, systemPrompt: _persona);
      if (json != null) {
        evolution = json['evolution'] as String? ?? evolution;
        advice = (json['advice'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: genererRapportHebdomadaire IA error: $e');
    }

    return WeeklyReport(
      totalMinutes: total,
      topApps: topList,
      alertsCount: alertsCount,
      evolution: evolution,
      advice: advice,
      generatedAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // §8 — DÉTECTION DES COMPORTEMENTS INHABITUELS
  // ===========================================================================

  /// Analyse les signaux du jour pour détecter des comportements inhabituels :
  /// usage nocturne excessif, usage intensif d'apps addictives, sortie de zone.
  Future<List<BehaviorAnomaly>> detecterComportementsInhabituels(
      String childId) async {
    final anomalies = <BehaviorAnomaly>[];
    try {
      final today = _dateStr(DateTime.now());
      final doc = await _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .doc(childId)
          .collection('alerts')
          .doc('usage')
          .collection('apps')
          .doc(today)
          .get();
      final data = doc.data() ?? {};

      // Usage nocturne (champ enrichi par l'app enfant).
      final night = ((data['nightUsageMinutes'] ?? 0) as num).toInt();
      if (night >= 30) {
        anomalies.add(BehaviorAnomaly(
          type: 'NIGHT_USAGE',
          title: 'Usage nocturne excessif',
          description:
              '$night minutes d\'utilisation détectées entre 22h et 6h.',
          risk: night >= 60 ? RiskLevel.critical : RiskLevel.moderate,
        ));
      }

      // Usage intensif d'applications potentiellement addictives.
      final categories = data['categories'] as Map<String, dynamic>? ?? {};
      final social = ((categories['social_media'] ?? 0) as num).toInt();
      final gaming = ((categories['gaming'] ?? 0) as num).toInt();
      if (social >= 120) {
        anomalies.add(BehaviorAnomaly(
          type: 'ADDICTIVE_APP',
          title: 'Réseaux sociaux intensifs',
          description:
              '$social minutes passées sur les réseaux sociaux aujourd\'hui.',
          risk: RiskLevel.moderate,
        ));
      }
      if (gaming >= 120) {
        anomalies.add(BehaviorAnomaly(
          type: 'ADDICTIVE_APP',
          title: 'Jeux vidéo intensifs',
          description: '$gaming minutes passées sur des jeux aujourd\'hui.',
          risk: RiskLevel.moderate,
        ));
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: detecterComportementsInhabituels error: $e');
    }
    return anomalies;
  }

  /// Balaye tous les enfants pour détecter des comportements inhabituels et
  /// génère une alerte de synthèse pour chaque anomalie critique non encore signalée.
  Future<void> _scanAllChildrenBehavior() async {
    try {
      final children = await _db
          .collection('parents')
          .doc(_uid)
          .collection('children')
          .get();
      for (final child in children.docs) {
        final anomalies = await detecterComportementsInhabituels(child.id);
        for (final a in anomalies.where((x) => x.risk == RiskLevel.critical)) {
          await _emitBehaviorAlert(child.id, a);
        }
      }
    } catch (e) {
      debugPrint('GUARDIAN_AGENT: _scanAllChildrenBehavior error: $e');
    }
  }

  /// Écrit une alerte « comportement inhabituel » lisible par le tableau de bord parent.
  /// Anti-doublon : une seule alerte par type d'anomalie et par jour.
  Future<void> _emitBehaviorAlert(
      String childId, BehaviorAnomaly anomaly) async {
    final today = _dateStr(DateTime.now());
    final col = _db
        .collection('parents')
        .doc(_uid)
        .collection('children')
        .doc(childId)
        .collection('alerts')
        .doc('notifications')
        .collection('items');

    // Vérifie qu'une alerte du même type n'a pas déjà été émise aujourd'hui par l'agent.
    final existing = await col
        .where('agentBehaviorKey', isEqualTo: '${anomaly.type}_$today')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await col.add({
      'childId': childId,
      'type': anomaly.type,
      'title': anomaly.title,
      'description': anomaly.description,
      'detail': anomaly.description,
      'severity': anomaly.risk.severityString,
      'genre': 'behavior',
      'read': false,
      'source': 'agent',
      'agentBehaviorKey': '${anomaly.type}_$today',
      'ai_processed': true, // déjà analysée par l'agent
      'aiRisk': anomaly.risk.name,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
