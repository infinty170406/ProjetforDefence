# Audit final de conformité parent/enfant — The Guardian

Date : 17 juillet 2026  
Projet enfant : `ProjetforDefence-feature-child-app-restructuring`  
Projet parent comparé : `the_guardian_new`  
Projet Firebase commun : `control-parental-5f115`

## Verdict

Le code enfant a été restructuré pour respecter les chemins et les restrictions Firestore du parent fourni. Les incompatibilités bloquantes côté enfant ont été corrigées : liaison serveur, identité Firebase unique, alertes via backend, schéma des statistiques, lecture des règles, synchronisation native et retrait des clés IA du terminal.

La conformité complète de production reste conditionnée à cinq actions dans le dépôt parent : accepter le token opaque dans ses écrans, fusionner/déployer les nouvelles fonctions, supprimer les champs Gemini des règles, recopier les géofences assignées dans `rules/active` et définir le contrat d'application de `customCategories`. Elles sont détaillées dans `integration/PARENT_ACTIONS_REQUIRED.md`.

## Corrections effectuées dans l'application enfant

### Liaison et identité

- Validation d'un token opaque URL-safe de 32 à 128 caractères.
- Prise en charge de `https://the-guardian.app/child/pair?code=...`, du schéma `guardian://` et d'un token brut valide.
- Rejet des anciens identifiants enfant ou codes à six caractères utilisés comme preuve de liaison.
- Activation exclusivement via la callable `activateChildDevice`.
- Conservation de l'UID Firebase anonyme créé pendant la liaison et vérification qu'il correspond à `childDeviceUid`.
- Suppression des recherches globales Firestore et des reliaisons directes côté client.

### Contrat Firestore

- Lecture unique des règles via `parents/{parentId}/children/{childId}/rules/active`.
- Suppression des fallbacks `collectionGroup` et des lectures directes de géofences interdites par les règles du parent.
- Persistance locale des interrupteurs `monitorAccountActivity` et `locationAlerts` pour que les composants natifs et GPS respectent immédiatement les choix du parent.
- Écritures directes sur le document enfant limitées à `deviceStatus`, `lastHeartbeat`, `fcmToken` et `lastTokenSync`.
- Batterie et position récapitulative mises à jour via une Cloud Function après vérification de l'appareil associé.
- Statistiques d'usage ramenées aux clés autorisées par les règles parent.
- File Firestore persistante bornée à 1 000 opérations, batchs limités à 450, identifiants d'ajout persistants et sentinelles JSON sûres.

### Alertes

- Suppression de toutes les écritures directes de l'enfant dans `alerts/notifications/items`, interdites par les règles parent.
- Nouvelle callable `reportChildAlert` avec authentification, vérification `childDeviceUid`, liste blanche de types, limites de taille et identifiant idempotent.
- Migration des alertes Flutter, SOS, géofences, GPS, blocages et notifications natives vers ce point d'entrée.
- Réduction du contenu sensible recopié dans les alertes : les recherches et messages complets ne sont plus placés dans la notification parentale.

### Android natif

- Le moteur natif ne crée plus un second compte Firebase anonyme susceptible de ne pas correspondre à l'appareil associé.
- Synchronisation native autorisée seulement lorsque l'UID Firebase courant égale l'UID enregistré pendant la liaison.
- Alertes natives envoyées par callable avec un identifiant déterministe pour éviter les doublons après retry.
- Appel Gemini HTTP et clé locale supprimés ; l'analyse passe par `analyzeChildNotification`.
- Le listener de notifications cesse toute analyse lorsque `monitorAccountActivity` est désactivé.
- Faux VPN retiré du manifeste, de `MainActivity`, du service de fond et du code Kotlin.
- Watchdog rendu non exporté.
- Simulations et affirmations Device Admin retirées.

### Démarrage, listeners et permissions

- Un appareil non associé est dirigé vers l'écran de bienvenue avant toute demande de permission sensible.
- Le démarrage GPS et des services n'intervient qu'après vérification de l'association.
- Abonnements Provider annulés/remplacés pour éviter les doublons.
- Timer de surveillance GPS conservé et annulé lors de l'arrêt.
- Les alertes GPS désactivé et les transitions de géofence ne sont émises que lorsque `locationAlerts` est activé.
- Gestion de deep link asynchrone sans journaliser le token brut.

### Secrets et livraison

- Signature release chargée depuis `android/key.properties` local/CI ; le build release échoue si la configuration manque.
- Suppression physique de `keystore_base64.txt`, `google_services_base64.txt`, `android.zip` et `lib.zip`.
- Ajout d'un runbook de rotation, d'un exemple de propriété de signature et de règles `.gitignore` renforcées.
- Backend configuré pour Secret Manager (`GEMINI_API_KEY`) et paramètre (`GEMINI_MODEL`).
- Runtime Cloud Functions porté à Node 20.

## Fichiers principaux modifiés ou ajoutés

### Flutter/Dart

- `lib/services/auth_service.dart`
- `lib/utils/pairing_token.dart`
- `lib/models/child_profile.dart`
- `lib/services/rules_service.dart`
- `lib/services/alert_service.dart`
- `lib/services/sos_service.dart`
- `lib/services/device_status_service.dart`
- `lib/services/location_service.dart`
- `lib/services/monitoring_service.dart`
- `lib/services/enforcement_service.dart`
- `lib/services/firestore_sync_queue.dart`
- `lib/services/notification_service.dart`
- `lib/services/link_handler_service.dart`
- `lib/services/background_service.dart`
- `lib/providers/app_state.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/permissions_onboarding_screen.dart`

### Android/Kotlin

- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/app/theguardian/child/NativeFirebaseSync.kt`
- `android/app/src/main/kotlin/app/theguardian/child/GeminiNotificationAnalyzer.kt`
- `android/app/src/main/kotlin/app/theguardian/child/NotificationRiskEngine.kt`
- `android/app/src/main/kotlin/app/theguardian/child/MainActivity.kt`
- `android/app/src/main/kotlin/app/theguardian/child/SecurityMonitor.kt`
- `android/app/src/main/kotlin/app/theguardian/child/EventReporter.kt`
- `android/app/src/main/kotlin/app/theguardian/child/NativeHistoryRepository.kt`
- `android/app/src/main/kotlin/app/theguardian/child/NotificationHistoryRepository.kt`
- `android/app/src/main/kotlin/app/theguardian/child/GuardianNotificationListenerService.kt`
- `android/app/src/main/kotlin/app/theguardian/child/UrlAnalyzer.kt`
- `android/app/src/main/kotlin/app/theguardian/child/WebsiteBlockEngine.kt`
- suppression de `GuardianVpnService.kt`

### Backend, configuration et documentation

- `functions/index.js`
- `functions/package.json`
- `functions/package-lock.json`
- `functions/.env.example`
- `.firebaserc`
- `.gitignore`
- `android/key.properties.example`
- `README.md`
- `BACKEND_DEPLOYMENT.md`
- `SECURITY_ROTATION_RUNBOOK.md`
- `MODIFICATIONS_COMPLETE.md`
- `integration/PARENT_ACTIONS_REQUIRED.md`
- `integration/parent-functions.patch`

### Tests

- `test/pairing_token_test.dart`
- `test/list_children_test.dart`
- `test/web_enforcement_test.dart`
- `test/widget_test.dart`
- mise à jour de `pubspec.yaml` et `pubspec.lock` pour `cloud_functions`

## Vérifications exécutées dans l'environnement d'audit

- syntaxe JavaScript : `node --check functions/index.js` ;
- validité XML du manifeste Android ;
- cohérence du package Android et du projet Firebase avec le parent ;
- recherche statique d'écritures directes d'alertes, de clés Gemini client, de fallbacks Firestore non autorisés et d'anciens codes de liaison ;
- contrôle `git diff --check` ;
- contrôles structurels des fichiers Dart/Kotlin et du contenu de l'archive finale.

Le SDK Flutter/Dart n'est pas installé dans l'environnement fourni. `flutter analyze`, `flutter test` et la compilation Gradle Flutter n'ont donc pas pu être exécutés ici. Ils doivent être lancés sur la machine de développement ou en CI avant publication.

## Risques résiduels

- Les anciens secrets sont encore récupérables dans l'historique Git tant que celui-ci n'a pas été réécrit ; rotation et purge obligatoires.
- L'historique de notifications conserve des messages complets dans `inventory/notifications/history`. Définir consentement, durée de conservation, suppression et minimisation avant production.
- Les capacités Android sensibles nécessitent des essais réels Android 13 à 15 et sur plusieurs constructeurs.
- L'accessibilité n'empêche pas à elle seule la désinstallation ; une garantie plus forte exige un provisioning device owner géré.
- Le backend doit avoir une source canonique unique pour éviter qu'un futur déploiement parent écrase les fonctions ajoutées.
- `customCategories` n'a pas encore de sémantique d'application commune : le parent doit soit retirer ce réglage, soit définir puis tester un contrat pris en charge par l'enfant.
