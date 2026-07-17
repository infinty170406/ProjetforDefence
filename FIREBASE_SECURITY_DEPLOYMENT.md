# Déploiement sécurisé du jumelage Firebase

## Changements livrés

- `activateChildDevice` consomme un token enfant à usage unique dans une transaction Cloud Functions.
- `acceptParentInvite` accepte une invitation co-parent côté serveur.
- Les règles Firestore interdisent désormais le jumelage client direct, la lecture globale des documents enfant porteurs d'un token et les accès ouverts à `families` / `parent_invites`.
- Les nouveaux tokens enfant ont 48 caractères, expirent après 48 heures et sont supprimés à l'appairage.

## Ordre de déploiement requis

1. Mettre à niveau la Firebase CLI sur Node.js 20 ou plus récent.
2. Déployer le backend Render avec les secrets OTP et SharePay ; valider le webhook signé en staging.
3. Déployer les fonctions : `firebase deploy --only functions:activateChildDevice,functions:acceptParentInvite`.
4. Publier les nouvelles versions de l'application parent et de l'application enfant.
5. Créer de nouveaux liens d'appairage pour tous les enfants non appairés : les anciens codes à 6 chiffres ne sont pas acceptés par le nouveau protocole.
6. Vérifier en staging un appairage, une synchronisation d'usage enfant et un webhook paiement signé.
7. Déployer les règles : `firebase deploy --only firestore:rules,firestore:indexes`.

Ne déployez pas les règles avant les fonctions et les deux clients : cela empêcherait l'ancien appairage, sans que les clients puissent encore appeler la fonction sécurisée.

## Vérifications de recette

- Un token neuf associe exactement un appareil enfant ; une seconde utilisation échoue.
- Un token expiré ou un code à 6 chiffres échoue.
- Un utilisateur authentifié ne peut ni lister les enfants, ni lire une invitation enfant hors de son périmètre.
- Un co-parent ne peut rejoindre la famille qu'au moyen de `acceptParentInvite`.
- La position enfant est écrite dans `location_history` puis lue par le parent.
- Une écriture directe client dans `subscriptions` ou `payments` est refusée.
- Une écriture enfant dans `alerts/notifications/items` est refusée ; une écriture
  de télémétrie est limitée à `alerts/usage/apps|websites/{date}`.
