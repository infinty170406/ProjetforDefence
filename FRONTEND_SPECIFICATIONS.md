# 🛡️ Spécifications Frontend - The Guardian

Ce document détaille la structure, la logique et les interfaces nécessaires pour le développement du frontend (Flutter) du projet **The Guardian**.

---

## 📱 1. Arborescence des Pages (Screens)

L'application est divisée en trois phases principales : **Authentification**, **Configuration/Onboarding**, et **Gestion/Dashboard**.

### 1.1 Authentification & Onboarding
| Page | Description | Fonctionnalités Clés |
| :--- | :--- | :--- |
| **Welcome Screen** | Introduction à l'application. | Présentation des bénéfices, bouton "Commencer". |
| **Login Screen** | Connexion au compte parent. | Formulaire Email/Password, lien vers mot de passe oublié. |
| **Register Screen** | Création d'un nouveau compte parent. | Formulaire Nom, Email, Password, Téléphone. |
| **OTP Verification** | Sécurité renforcée après l'inscription. | Saisie du code reçu par email (6 chiffres). |

### 1.2 Dashboard & Gestion des Enfants
| Page | Description | Fonctionnalités Clés |
| :--- | :--- | :--- |
| **Children List (Home)** | Vue d'ensemble de tous les profils enfants. | Liste des enfants, statut (Online/Offline), bouton "+" (Ajouter). |
| **Link Child Screen** | Processus pour lier un nouvel appareil. | Scanner QR Code ou saisie manuelle de l'ID Enfant. |
| **Child Dashboard** | Vue détaillée pour un enfant spécifique. | Raccourcis vers règles, historique récent, état de la batterie/localisation (si implémenté). |

### 1.3 Contrôle Parental (Paramètres)
| Page | Description | Fonctionnalités Clés |
| :--- | :--- | :--- |
| **Schedule Manager** | Gestion du temps d'écran. | Liste des horaires, ajout/modification (Jours, Heure début/fin, Action). |
| **Content Screening** | Filtrage par catégories. | Toggles pour bloquer/autoriser (Adult, Violence, Social, etc.). |
| **Keyword Filter** | Liste noire de mots-clés. | Ajouter/Supprimer des termes interdits, choix du type de correspondance (Exact/Contient). |

### 1.4 Historique & Profil
| Page | Description | Fonctionnalités Clés |
| :--- | :--- | :--- |
| **Activity Logs** | Flux d'événements en temps réel. | Liste chronologique : "App X bloquée", "Site Y ouvert", etc. |
| **Parent Profile** | Paramètres du compte parent. | Modifier le profil, changer le mot de passe, déconnexion. |

---

## 🧠 2. Logique Métier (Business Logic)

### 2.1 Flux d'Authentification (Auth Flow)
1. **Persistance** : Le token JWT doit être stocké de manière sécurisée (`flutter_secure_storage`).
2. **Interception** : Toutes les requêtes API (sauf login/register) doivent inclure le header `Authorization: Bearer <token>`.
3. **Invalidation** : En cas de code `401 Unauthorized` de l'API, rediriger l'utilisateur vers l'écran de connexion.

### 2.2 Gestion des Règles (Sync Logic)
- **Optimisme de l'UI** : Lorsqu'une règle est mise à jour (ex: blocage d'une catégorie), l'UI doit refléter le changement immédiatement avant la confirmation du serveur.
- **Validation des horaires** : Empêcher la création de plages horaires qui se chevauchent (`startTime` < `endTime`).
- **Synchronisation par lot (Batch Sync)** : Pour les mots-clés, le frontend envoie la liste complète à chaque modification. L'API remplace l'intégralité des mots-clés existants pour la catégorie donnée.
- **Agrégation des données** : Toujours privilégier l'appel à `/parental/profile` pour récupérer l'état complet (horaires, règles de contenu, mots-clés) en un seul appel réseau, plutôt que de multiplier les requêtes individuelles.
- **Modes de Profil** : Implémenter trois modes prédéfinis dans l'UI :
    - `STRICT` : Blocage automatique des catégories à risque.
    - `MODERATE` : Avertissements au lieu de blocages.
    - `PERMISSIVE` : Surveillance uniquement.

### 2.3 Événements & Notifications
- **Polling vs WebSockets** : Dans cette version (V1), utiliser un rafraîchissement périodique (Polling) ou un "Pull to refresh" pour récupérer l'historique récent.
- **Interprétation des Payloads** : La logique frontend doit parser le `payloadJson` des événements pour afficher des messages lisibles (ex: `{"url": "site.com"}` -> "Tentative d'accès à site.com bloquée").

---

## 🔌 3. Catalogue des API (Backend Integration)

*Note: Toutes les routes sont préfixées par `/api/v1`.*

### 🔐 Authentification
| Méthode | Endpoint | Body | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/register` | `{name, email, password, ...}` | Création de compte. |
| `POST` | `/auth/verify-otp` | `{email, otpCode}` | Activation du compte. |
| `POST` | `/auth/login` | `{email, password}` | Obtention du JWT Token. |

### 👨‍👩‍👧 Management
| Méthode | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/parents/me/children` | Récupérer la liste des enfants liés. |
| `POST` | `/parents/me/children/link` | Lier un nouvel enfant via son ID. |

### 👶 Contrôle Parental
| Méthode | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/children/{id}/parental/profile` | Récupérer toute la configuration (Règles, Horaires, Mots-clés). |
| `PUT` | `/children/{id}/parental/profile` | Activer/Désactiver le contrôle ou changer le mode. |
| `POST/PUT` | `/children/{id}/parental/schedules` | Gérer les plages horaires d'accès. |
| `PUT` | `/children/{id}/parental/content/{cat}`| Définir l'action (BLOCK/WARN/ALLOW) pour une catégorie. |

### 📜 Rapports & Appareils
| Méthode | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/children/{id}/history` | Journal d'activités de l'enfant. |
| `GET` | `/device/children/{id}/rules`| (Usage Enfant) Télécharger la configuration actuelle. |

---

## 🛠️ 4. Recommandations Techniques

- **State Management** : Utiliser `Provider` ou `Bloc/Cubit` pour gérer l'état global (liste des enfants, session utilisateur).
- **Communication** : Utiliser la librairie `Dio` pour les requêtes HTTP (meilleure gestion des intercepteurs et des timeouts).
- **Architecture** : Suivre une architecture en couches :
    - `Data` : API Services & Repositories.
    - `Domain` : Models & Entities.
    - `Presentation` : Screens & Widgets.
- **UI/UX** :
    - Utiliser des skeletons (shimmer) pendant le chargement des listes.
    - Feedback visuel clair lors de l'envoi de commandes (Loading indicators).
