import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Gère l'invitation d'un second parent via un code Firestore.
class ParentInviteService {
  static final ParentInviteService _instance = ParentInviteService._internal();
  factory ParentInviteService() => _instance;
  ParentInviteService._internal();

  // ────────────────────────────────────────────────
  // 1. Génère un code d'invitation et l'écrit dans Firestore
  // ────────────────────────────────────────────────
  Future<String?> generateInviteCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final result = await FirebaseFunctions.instance
          .httpsCallable('createParentInvite')
          .call<Map<String, dynamic>>();
      return result.data['code'] as String?;
    } catch (e) {
      debugPrint('INVITE: Erreur lors de la génération du code: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────
  // 2. Un second parent entre le code pour rejoindre la famille
  // ────────────────────────────────────────────────
  Future<ParentInviteResult> acceptInviteCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ParentInviteResult.notAuthenticated;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('acceptParentInvite')
          .call<Map<String, dynamic>>({'code': code});
      return ParentInviteResult.success;
    } on FirebaseFunctionsException catch (e) {
      return switch (e.code) {
        'not-found' => ParentInviteResult.notFound,
        'deadline-exceeded' => ParentInviteResult.expired,
        'failed-precondition' => ParentInviteResult.alreadyUsed,
        'permission-denied' => ParentInviteResult.ownCode,
        _ => ParentInviteResult.error,
      };
    } catch (e) {
      debugPrint('INVITE: Erreur lors de l\'acceptation du code: $e');
      return ParentInviteResult.error;
    }
  }

  // ────────────────────────────────────────────────
  // 3. Supprime les invitations expirées (nettoyage optionnel)
  // ────────────────────────────────────────────────
  Future<void> cleanupExpiredInvites(String ownerUid) async {
    try {
      // Expiration is enforced transactionally when an invitation is accepted.
    } catch (e) {
      debugPrint('INVITE: Erreur nettoyage: $e');
    }
  }
}

enum ParentInviteResult {
  success,
  notFound,
  alreadyUsed,
  expired,
  ownCode,
  invalidData,
  notAuthenticated,
  error,
}

extension ParentInviteResultMessage on ParentInviteResult {
  String get message {
    switch (this) {
      case ParentInviteResult.success:
        return 'Vous avez rejoint la famille avec succès ✓';
      case ParentInviteResult.notFound:
        return 'Code d\'invitation introuvable.';
      case ParentInviteResult.alreadyUsed:
        return 'Ce code a déjà été utilisé.';
      case ParentInviteResult.expired:
        return 'Ce code a expiré (validité : 48h).';
      case ParentInviteResult.ownCode:
        return 'Vous ne pouvez pas utiliser votre propre code.';
      case ParentInviteResult.invalidData:
        return 'Données du code invalides. Contactez l\'expéditeur.';
      case ParentInviteResult.notAuthenticated:
        return 'Veuillez vous connecter d\'abord.';
      case ParentInviteResult.error:
        return 'Une erreur est survenue. Réessayez.';
    }
  }
}
