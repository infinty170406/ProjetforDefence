# Actions nécessaires dans le projet parent

L'application enfant a été alignée sur les règles, chemins et interrupteurs actuellement publiés par le parent. Cinq corrections doivent encore être appliquées dans le dépôt parent canonique pour obtenir une conformité complète de bout en bout.

## 1. Accepter le vrai token de liaison enfant

Le parent génère un token opaque URL-safe et le lien :

```text
https://the-guardian.app/child/pair?code=<token>
```

Cependant, deux écrans parent utilisent encore une validation à six caractères :

- `lib/screens/onboarding/initial_setup_screen.dart` autour de la ligne 113 ;
- `lib/screens/auth/child_pairing_screen.dart` autour de la ligne 151.

Remplacer la condition `length == 6` par la même validation que l'enfant : `^[A-Za-z0-9_-]{32,128}$`. Les codes OTP et co-parent à six caractères restent des flux différents.

## 2. Fusionner et déployer les fonctions serveur

Fusionner dans le backend parent :

- `reportChildAlert` ;
- `updateChildDeviceMetadata` ;
- `analyzeChildNotification` ;
- les validateurs et constantes associés ;
- le passage du runtime Functions à Node 20 ;
- la configuration `GEMINI_API_KEY` via Secret Manager et `GEMINI_MODEL` comme paramètre.

Le patch `integration/parent-functions.patch` représente les différences entre le backend parent fourni et la version requise par l'enfant. Le fichier `functions/index.js` de l'archive enfant contient également la version fusionnée de référence.

## 3. Ne plus enregistrer ou envoyer la clé Gemini dans les règles enfant

Le parent contient encore des champs et contrôleurs `geminiApiKey` / `gemini_api_key`, notamment dans :

- `lib/screens/child/rules_editor_screen.dart` ;
- `lib/core/models/child_rules.dart` ;
- `lib/core/services/firestore_service.dart` ;
- `lib/core/services/api_config.dart` ;
- `lib/core/services/ai/gemini_service.dart`.

Supprimer la saisie et la sérialisation de la clé depuis le document `rules/active`. Une clé fournisseur ne doit jamais être distribuée à l'appareil enfant. Les anciens champs déjà présents dans Firestore doivent être supprimés.

## 4. Publier les géofences dans le document de règles autorisé

Les règles Firestore autorisent l'enfant à lire `children/{childId}/rules/{doc}`, mais pas `parents/{parentId}/geofences`. L'enfant lit donc uniquement le tableau `geofences` intégré à `rules/active`.

Lors de la création, modification ou suppression d'une zone dans `lib/core/services/firestore_service.dart`, le parent doit reconstruire pour chaque enfant concerné le tableau minimal suivant dans `children/{childId}/rules/active` :

```json
{
  "geofences": [
    {"id":"...","name":"...","latitude":0.0,"longitude":0.0,"radius":100.0}
  ]
}
```

Ne pas ouvrir la collection parent-level `geofences` aux comptes enfants.

## 5. Définir le contrat de `customCategories`

Le parent enregistre actuellement `customCategories`, mais le projet enfant fourni ne contient pas de vocabulaire ni de comportement d'application déterministe pour ces catégories. Une catégorie libre ne peut donc pas être présentée comme une protection effectivement appliquée.

Choisir une seule stratégie canonique :

- supprimer ou désactiver ce réglage tant qu'il n'est pas pris en charge ; ou
- définir une liste/version de catégories supportées, leur effet exact, leur sérialisation dans `rules/active` et leur application dans les moteurs Flutter/natifs ; ou
- transformer ces catégories en règles serveur explicites consommables par l'enfant.

Ajouter ensuite des tests de contrat parent/enfant pour chaque catégorie prise en charge. Les champs de métadonnées comme `mode`, `rulesConfigured` ou `blockReason` peuvent rester ignorés par l'enfant s'ils n'ont pas vocation à déclencher une règle locale.

## Validation de bout en bout

Effectuer le test avec deux comptes/appareils : création de l'enfant, scan du lien, consommation unique du token, réception des règles, activation/désactivation de `monitorAccountActivity` et `locationAlerts`, blocage, statistiques, GPS, géofences, alerte SOS, notification parentale et révocation/re-liaison contrôlée.
