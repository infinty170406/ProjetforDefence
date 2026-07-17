# The Guardian — application enfant

Ce dépôt contient l'application Flutter/Android installée sur l'appareil de l'enfant. Elle utilise le même projet Firebase que l'application parent : `control-parental-5f115`.

## Contrat avec l'application parent

- Package Android : `app.theguardian.child`
- Liaison : lien opaque à usage unique, par exemple `https://the-guardian.app/child/pair?code=<token>`
- Authentification enfant : compte Firebase anonyme créé pendant la liaison
- Identité autorisée : le document enfant contient `childDeviceUid`, qui doit correspondre à l'UID Firebase actif sur l'appareil
- Règles actives : `parents/{parentId}/children/{childId}/rules/active`
- Statistiques : `parents/{parentId}/children/{childId}/alerts/usage/{apps|websites}/{date}`
- Inventaire : `parents/{parentId}/children/{childId}/inventory/**`
- Position : `parents/{parentId}/children/{childId}/location/current` et `location_history/**`
- Alertes parentales : créées uniquement par la Cloud Function authentifiée `reportChildAlert`

L'application enfant n'accepte plus les anciens codes enfant à six caractères comme preuve de liaison. Le code OTP à six chiffres de l'application parent est un flux distinct et ne doit pas être confondu avec le token de liaison enfant.

## Sécurité

- Aucune clé Gemini n'est copiée dans l'application ou dans `SharedPreferences`.
- L'analyse facultative des notifications passe par `analyzeChildNotification` côté serveur.
- Les secrets de signature Android sont chargés depuis `android/key.properties`, ignoré par Git. Utiliser `android/key.properties.example` comme modèle.
- Les anciennes archives et représentations Base64 de secrets ont été retirées du projet. Elles doivent aussi être purgées de l'historique Git et les secrets concernés doivent être renouvelés.
- Le faux service VPN et les affirmations Device Admin ont été supprimés. L'application ne garantit pas l'impossibilité de désinstallation sans provisioning Android de type device owner.

## Backend partagé

Le dossier `functions/` contient la version du backend nécessaire à l'application enfant. Avant déploiement :

1. Fusionner ces fonctions dans le dépôt parent canonique ou utiliser cette copie comme source de déploiement unique.
2. Configurer le secret `GEMINI_API_KEY` et le paramètre non secret `GEMINI_MODEL`.
3. Déployer les fonctions sur le projet Firebase explicitement indiqué par `.firebaserc`.

Voir `BACKEND_DEPLOYMENT.md`, `AUDIT_ARCHITECTURE_FLUTTER.md` et `integration/PARENT_ACTIONS_REQUIRED.md`.

## Vérifications locales recommandées

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
cd ../functions && npm ci && node --check index.js
```

Des tests sur un appareil Android réel restent indispensables pour l'accessibilité, les permissions, la relance après redémarrage, la collecte d'usage et la géolocalisation de fond.
