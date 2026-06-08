# 🛡️ The Guardian - Workspace Application Enfant (Child App)

Ce dossier contient le code source de l'application **Enfant** du projet **The Guardian**. Elle fonctionne en étroite collaboration avec l'application **Parent** (`ProjetforDefence-frontend`) et le backend **Firebase**.

## 🚀 Rôle de l'application Enfant

L'application enfant a pour but d'exécuter les restrictions définies par les parents et de remonter les informations d'état de l'appareil. Elle est composée de deux couches principales :

1.  **Interface Flutter** : Permet la liaison initiale à l'aide d'un code d'invitation à 6 chiffres généré par le parent, et affiche le statut de connexion.
2.  **Moteur Natif Android (Kotlin)** : Exécute les règles de sécurité en arrière-plan de manière robuste et non contournable.

---

## ⚙️ Composants Natifs Clés

*   **`GuardianAccessibilityService`** :
    *   *Blocage d'applications* : Intercepte le lancement des packages interdits.
    *   *Filtrage Web* : Analyse la barre d'adresse (Chrome, Samsung Internet, Firefox) pour bloquer les URLs interdites.
    *   *Auto-Défense* : Empêche l'accès aux paramètres d'accessibilité et d'administration système pour éviter la désactivation du service par l'enfant.
*   **`BlockActivity`** : Écran natif s'affichant immédiatement lors d'une tentative d'ouverture d'un contenu bloqué (neutre vis-à-vis du bouton retour).
*   **`GuardianForegroundService`** : Service d'arrière-plan avec notification persistante pour la géolocalisation continue et la survie du processus.
*   **`GuardianDeviceAdminReceiver`** : Gestionnaire d'administration pour empêcher la désinstallation de l'application.

---

## 🎨 Architecture & Cache Local

Les règles de blocage (applications et URLs) sont synchronisées via Firestore puis mises en cache localement dans les `SharedPreferences` de l'appareil. 
Le service d'accessibilité écoute les changements sur ce cache et applique les règles en mémoire vive, garantissant des performances maximales et un impact minimal sur la batterie.

Pour plus d'informations sur l'architecture globale, veuillez consulter le dossier principal de l'application Parent : [ProjetforDefence-frontend](../ProjetforDefence-frontend/README.md).
