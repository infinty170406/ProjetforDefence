# Liste complète des modifications de l'audit

Cette liste décrit les différences apportées au projet enfant audité par rapport à son état Git fourni.

## Racine, configuration et documentation

| Fichier | Statut | Modification |
|---|---|---|
| `.gitignore` | modifié | Ignore secrets, clés, archives locales, chemins SDK et diagnostics générés. |
| `.firebaserc` | ajouté | Fixe explicitement le projet Firebase partagé `control-parental-5f115`. |
| `README.md` | réécrit | Documente le vrai contrat parent/enfant, le token opaque, les chemins Firestore, les fonctions et les limites Android. |
| `AUDIT_ARCHITECTURE_FLUTTER.md` | ajouté/réécrit | Rapport final de conformité, corrections, validations et risques résiduels. |
| `BACKEND_DEPLOYMENT.md` | ajouté | Procédure de fusion/configuration/déploiement du backend partagé. |
| `SECURITY_ROTATION_RUNBOOK.md` | ajouté | Procédure de rotation et purge des secrets exposés. |
| `MODIFICATIONS_COMPLETE.md` | ajouté | Présente la liste exhaustive des changements. |
| `analyze_output.txt` | supprimé | Ancien résultat d'analyse généré, obsolète et trompeur. |
| `android/build_error.txt` | supprimé | Ancien journal de compilation généré. |

## Secrets et archives supprimés

| Fichier | Statut | Motif |
|---|---|---|
| `android.zip` | supprimé | Archive de code suivie par Git et susceptible de conserver des secrets. |
| `lib.zip` | supprimé | Archive redondante suivie par Git. |
| `google_services_base64.txt` | supprimé | Export Base64 de configuration sensible. |
| `keystore_base64.txt` | supprimé | Export Base64 du matériel de signature. |

## Flutter/Dart

| Fichier | Statut | Modification |
|---|---|---|
| `lib/utils/pairing_token.dart` | ajouté | Parse et valide uniquement le token opaque, les domaines/routes officiels et le schéma Guardian. |
| `lib/utils/test_helper.dart` | modifié | Retire les URL/mots-clés sensibles des logs de diagnostic et remplace les données de démonstration par des valeurs neutres. |
| `lib/services/auth_service.dart` | réécrit | Activation via callable, auth anonyme unique, stockage sécurisé, validation UID/path et nettoyage de session. |
| `lib/models/child_profile.dart` | modifié | Compatibilité avec le champ parent `childDeviceUid`. |
| `lib/services/rules_service.dart` | restructuré | Écoute seulement `rules/active`, cache validé, retry borné, suppression des clés Gemini locales, parsing sûr et publication locale des interrupteurs `monitorAccountActivity` / `locationAlerts`. |
| `lib/services/alert_service.dart` | réécrit | Alertes via `reportChildAlert`, types normalisés, identifiants idempotents et cooldown après succès. |
| `lib/services/sos_service.dart` | réécrit | SOS via backend authentifié avec position/batterie facultatives. |
| `lib/services/device_status_service.dart` | modifié | Écriture directe limitée aux champs autorisés ; batterie via callable vérifiée. |
| `lib/services/location_service.dart` | modifié | Chemins GPS conformes, métadonnées via callable, type `GPS_DISABLED`, timer annulable et respect de `locationAlerts` pour GPS/géofences. |
| `lib/services/monitoring_service.dart` | modifié | Schéma d'usage réduit aux clés autorisées par les règles parent. |
| `lib/services/enforcement_service.dart` | modifié | Sentinelles de queue sûres, alertes minimisées, retrait du code VPN obsolète. |
| `lib/services/firestore_sync_queue.dart` | restructuré | Queue bornée, batchs de 450, add idempotent, sérialisation explicite et backoff exponentiel. |
| `lib/services/notification_service.dart` | modifié | Mise à jour FCM limitée à `fcmToken` et `lastTokenSync`. |
| `lib/services/link_handler_service.dart` | modifié | Gestion async sûre, aucun log du token brut et reprise du contexte après activation. |
| `lib/services/background_service.dart` | modifié | Retrait du canal VPN et de l'auth anonyme native parallèle. |
| `lib/providers/app_state.dart` | modifié | Annulation/remplacement des abonnements et prévention des listeners dupliqués. |
| `lib/screens/splash_screen.dart` | réécrit | Vérifie l'association avant toute permission ou démarrage de service. |
| `lib/screens/permissions_onboarding_screen.dart` | modifié | Retire la présentation Device Admin non fonctionnelle et nettoie l'UI. |
| `pubspec.yaml` | modifié | Ajoute `cloud_functions`. |
| `pubspec.lock` | modifié | Verrouille les dépendances callable Firebase correspondantes. |

## Android/Kotlin

| Fichier | Statut | Modification |
|---|---|---|
| `android/app/build.gradle.kts` | modifié | Signature release externe, validation obligatoire, dépendance Firebase Functions native. |
| `android/key.properties.example` | ajouté | Modèle sans secret pour la signature locale/CI. |
| `android/app/src/main/AndroidManifest.xml` | modifié | Routes de liaison conformes, watchdog non exporté, suppression du service VPN. |
| `android/app/src/main/kotlin/app/theguardian/child/NativeFirebaseSync.kt` | réécrit | Réutilise l'UID appairé, synchronise la télémétrie autorisée et transmet les alertes par callable. |
| `android/app/src/main/kotlin/app/theguardian/child/GeminiNotificationAnalyzer.kt` | réécrit | Supprime la clé et l'appel HTTP local ; appelle la fonction serveur. |
| `android/app/src/main/kotlin/app/theguardian/child/NotificationRiskEngine.kt` | modifié | Type d'alerte conforme, contenu parental minimisé, queue native unique. |
| `android/app/src/main/kotlin/app/theguardian/child/MainActivity.kt` | modifié | Retire les méthodes et callbacks VPN incomplets. |
| `android/app/src/main/kotlin/app/theguardian/child/SecurityMonitor.kt` | modifié | Retire la simulation Device Admin toujours active. |
| `android/app/src/main/kotlin/app/theguardian/child/EventReporter.kt` | modifié | Retire les URL complètes des logs de rapport. |
| `android/app/src/main/kotlin/app/theguardian/child/NativeHistoryRepository.kt` | modifié | Retire les URL complètes des logs d’historique. |
| `android/app/src/main/kotlin/app/theguardian/child/NotificationHistoryRepository.kt` | modifié | Retire l’expéditeur des logs de notification. |
| `android/app/src/main/kotlin/app/theguardian/child/GuardianNotificationListenerService.kt` | modifié | Retire les expéditeurs des logs, utilise l’analyse serveur authentifiée et s'arrête lorsque `monitorAccountActivity` est désactivé. |
| `android/app/src/main/kotlin/app/theguardian/child/UrlAnalyzer.kt` | modifié | Retire l’URL brute des erreurs de parsing. |
| `android/app/src/main/kotlin/app/theguardian/child/WebsiteBlockEngine.kt` | modifié | Retire l’URL brute des erreurs de normalisation. |
| `android/app/src/main/kotlin/app/theguardian/child/GuardianVpnService.kt` | supprimé | Service VPN non fonctionnel qui ne relayait pas le trafic. |

## Cloud Functions

| Fichier | Statut | Modification |
|---|---|---|
| `functions/index.js` | étendu | Ajoute `reportChildAlert`, `updateChildDeviceMetadata`, `analyzeChildNotification`, validations et Secret Manager ; conserve les fonctions parent existantes. |
| `functions/package.json` | modifié | Runtime Node 20 et métadonnées harmonisées. |
| `functions/package-lock.json` | ajouté | Verrouillage reproductible des dépendances Functions. |
| `functions/.env.example` | ajouté | Documente le paramètre non secret `GEMINI_MODEL`. |
| `integration/parent-functions.patch` | ajouté | Patch de fusion entre le backend parent fourni et le backend requis. |
| `integration/PARENT_ACTIONS_REQUIRED.md` | ajouté | Liste les cinq modifications encore requises dans le dépôt parent. |

## Tests

| Fichier | Statut | Modification |
|---|---|---|
| `test/pairing_token_test.dart` | ajouté | Couvre lien actuel, lien historique, deep link, token brut et rejets de sécurité. |
| `test/list_children_test.dart` | réécrit | Teste la normalisation du chemin enfant sans dépendre de Firebase. |
| `test/web_enforcement_test.dart` | modifié | Tests purs pour mots-clés, domaines et plages horaires, y compris la nuit. |
| `test/widget_test.dart` | réécrit | Remplace le test compteur du template par un rendu de thème sans initialisation Firebase. |

## Modifications encore requises côté parent

Elles ne sont pas appliquées dans l'archive enfant :

1. remplacer les validations enfant `length == 6` par le token opaque dans les écrans de liaison ;
2. fusionner et déployer les fonctions serveur ajoutées ;
3. supprimer la saisie/sérialisation de `geminiApiKey` dans les règles enfant ;
4. recopier les géofences affectées dans `children/{childId}/rules/active` au lieu d'autoriser l'enfant à lire la collection parent-level ;
5. supprimer `customCategories` ou définir une sémantique/version de catégories réellement appliquée et testée par l'enfant.
