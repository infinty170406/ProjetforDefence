# 📚 The Guardian API - Documentation Frontend

> Documentation complète de l'API backend pour l'intégration avec le frontend Flutter.

---

## 🔧 Configuration

### URL de Base

| Environnement | URL |
|---------------|-----|
| **Local (PC)** | `http://localhost:8080` |
| **Émulateur Android** | `http://10.0.2.2:8080` |
| **iOS Simulator** | `http://localhost:8080` |
| **Appareil physique (même réseau)** | `http://<IP_LOCAL>:8080` |

### Headers Requis

```http
Content-Type: application/json
User-Agent: TheGuardianApp/1.0
```

### Header d'Authentification (routes protégées)

```http
Authorization: Bearer <accessToken>
```

---

## 🔐 1. Authentification

### 1.1 Inscription (Register)

**Endpoint:** `POST /api/v1/auth/register`  
**Auth:** ❌ Non requis

#### Request Body

```json
{
  "name": "string",          // Requis, max 120 caractères
  "email": "string",         // Requis, format email valide
  "password": "string",      // Requis, minimum 8 caractères
  "phoneNumber": "string"    // Optionnel, max 20 caractères
}
```

#### Response (200 OK)

```json
{
  "parentId": "uuid-string",
  "email": "user@example.com",
  "message": "OTP envoyé à votre adresse email"
}
```

#### Codes d'erreur

| Code | Description |
|------|-------------|
| 409 | Email déjà utilisé |
| 400 | Données invalides |

---

### 1.2 Vérification OTP

**Endpoint:** `POST /api/v1/auth/verify-otp`  
**Auth:** ❌ Non requis

#### Request Body

```json
{
  "email": "string",    // Requis, format email valide
  "otpCode": "string"   // Requis, code OTP reçu par email
}
```

#### Response (200 OK)

```json
{
  "success": true,
  "message": "Compte vérifié avec succès",
  "accessToken": "jwt-token-string",
  "expiresInSeconds": 86400
}
```

#### Codes d'erreur

| Code | Description |
|------|-------------|
| 400 | Code OTP invalide ou expiré |

---

### 1.3 Connexion (Login)

**Endpoint:** `POST /api/v1/auth/login`  
**Auth:** ❌ Non requis

#### Request Body

```json
{
  "email": "string",     // Requis, format email valide
  "password": "string"   // Requis
}
```

#### Response (200 OK)

```json
{
  "accessToken": "jwt-token-string",
  "tokenType": "Bearer",
  "expiresInSeconds": 86400,
  "parent": {
    "parentId": "uuid-string",
    "name": "John Doe",
    "email": "user@example.com"
  }
}
```

#### Codes d'erreur

| Code | Description |
|------|-------------|
| 401 | Identifiants invalides ou compte non vérifié |

---

## 👨‍👩‍👧 2. Gestion Parent

### 2.1 Liste des enfants

**Endpoint:** `GET /api/v1/parents/me/children`  
**Auth:** ✅ Bearer Token requis

#### Response (200 OK)

```json
{
  "children": [
    {
      "childId": "uuid-string",
      "displayName": "Enfant 1",
      "age": 10,
      "deviceStatus": "ONLINE",
      "lastSeenAt": "2026-01-30T12:00:00Z"
    }
  ]
}
```

---

### 2.2 Lier un enfant

**Endpoint:** `POST /api/v1/parents/me/children/link`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "childId": "string"   // Requis, ID de l'enfant à lier
}
```

#### Response (200 OK)

Aucun contenu retourné (void).

---

## 👶 3. Contrôle Parental

### 3.1 Récupérer le profil agrégé

**Endpoint:** `GET /api/v1/children/{childId}/parental/profile`  
**Auth:** ✅ Bearer Token requis

#### Response (200 OK)

```json
{
  "childId": "uuid-string",
  "profile": {
    "profileId": "uuid-string",
    "childId": "uuid-string",
    "enabled": true,
    "mode": "STRICT",
    "timezone": "Europe/Paris",
    "updatedAt": "2026-01-30T12:00:00Z"
  },
  "scheduleRules": [
    {
      "scheduleId": "uuid-string",
      "childId": "uuid-string",
      "daysOfWeek": ["MONDAY", "TUESDAY", "WEDNESDAY"],
      "startTime": "08:00",
      "endTime": "20:00",
      "action": "ALLOW",
      "enabled": true,
      "updatedAt": "2026-01-30T12:00:00Z"
    }
  ],
  "contentRules": [
    {
      "ruleId": "uuid-string",
      "childId": "uuid-string",
      "category": "ADULT",
      "action": "BLOCK",
      "confidenceThreshold": 0.8,
      "enabled": true,
      "updatedAt": "2026-01-30T12:00:00Z"
    }
  ],
  "blockedKeywords": [
    {
      "keywordId": "uuid-string",
      "childId": "uuid-string",
      "category": "ADULT",
      "term": "mot-interdit",
      "locale": "fr",
      "matchType": "EXACT",
      "enabled": true,
      "updatedAt": "2026-01-30T12:00:00Z"
    }
  ]
}
```

---

### 3.2 Mettre à jour le profil

**Endpoint:** `PUT /api/v1/children/{childId}/parental/profile`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "enabled": true,           // Requis, boolean
  "mode": "STRICT",          // Requis, ex: "STRICT", "MODERATE", "PERMISSIVE"
  "timezone": "Europe/Paris" // Optionnel
}
```

#### Response (200 OK)

```json
{
  "profileId": "uuid-string",
  "childId": "uuid-string",
  "enabled": true,
  "mode": "STRICT",
  "timezone": "Europe/Paris",
  "updatedAt": "2026-01-30T12:00:00Z"
}
```

---

### 3.3 Créer une règle d'horaire

**Endpoint:** `POST /api/v1/children/{childId}/parental/schedules`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "daysOfWeek": ["MONDAY", "TUESDAY", "WEDNESDAY"],  // Requis, liste non vide
  "startTime": "08:00",   // Requis, format HH:mm
  "endTime": "20:00",     // Requis, format HH:mm
  "action": "ALLOW",      // Requis, ex: "ALLOW", "BLOCK", "RESTRICT"
  "enabled": true         // Optionnel, défaut: true
}
```

#### Response (201 Created)

```json
{
  "scheduleId": "uuid-string",
  "childId": "uuid-string",
  "daysOfWeek": ["MONDAY", "TUESDAY", "WEDNESDAY"],
  "startTime": "08:00",
  "endTime": "20:00",
  "action": "ALLOW",
  "enabled": true,
  "updatedAt": "2026-01-30T12:00:00Z"
}
```

---

### 3.4 Modifier une règle d'horaire

**Endpoint:** `PUT /api/v1/children/{childId}/parental/schedules/{scheduleId}`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "daysOfWeek": ["MONDAY", "FRIDAY"],
  "startTime": "09:00",
  "endTime": "18:00",
  "action": "RESTRICT",
  "enabled": true
}
```

#### Response (200 OK)

```json
{
  "scheduleId": "uuid-string",
  "childId": "uuid-string",
  "daysOfWeek": ["MONDAY", "FRIDAY"],
  "startTime": "09:00",
  "endTime": "18:00",
  "action": "RESTRICT",
  "enabled": true,
  "updatedAt": "2026-01-30T12:00:00Z"
}
```

---

### 3.5 Supprimer une règle d'horaire

**Endpoint:** `DELETE /api/v1/children/{childId}/parental/schedules/{scheduleId}`  
**Auth:** ✅ Bearer Token requis

#### Response (204 No Content)

Aucun contenu retourné.

---

### 3.6 Créer/Modifier une règle de contenu

**Endpoint:** `PUT /api/v1/children/{childId}/parental/content/{category}`  
**Auth:** ✅ Bearer Token requis

**Catégories disponibles:** `ADULT`, `VIOLENCE`, `GAMBLING`, `SOCIAL`, `GAMES`, `STREAMING`, etc.

#### Request Body

```json
{
  "action": "BLOCK",           // Requis, ex: "BLOCK", "WARN", "ALLOW"
  "confidenceThreshold": 0.8,  // Optionnel, seuil de confiance (0.0 à 1.0)
  "enabled": true              // Optionnel, défaut: true
}
```

#### Response (200 OK)

```json
{
  "ruleId": "uuid-string",
  "childId": "uuid-string",
  "category": "ADULT",
  "action": "BLOCK",
  "confidenceThreshold": 0.8,
  "enabled": true,
  "updatedAt": "2026-01-30T12:00:00Z"
}
```

---

### 3.7 Remplacer les mots-clés bloqués

**Endpoint:** `PUT /api/v1/children/{childId}/parental/content/{category}/keywords`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "keywords": ["mot1", "mot2", "mot3"],
  "locale": "fr",
  "matchType": "EXACT"   // ex: "EXACT", "CONTAINS", "REGEX"
}
```

#### Response (204 No Content)

Aucun contenu retourné.

---

## 📜 4. Historique

### 4.1 Récupérer l'historique d'un enfant

**Endpoint:** `GET /api/v1/children/{childId}/history`  
**Auth:** ✅ Bearer Token requis

#### Response (200 OK)

```json
[
  {
    "eventId": "uuid-string",
    "childId": "uuid-string",
    "type": "CONTENT_BLOCKED",
    "actor": "SYSTEM",
    "occurredAt": "2026-01-30T12:00:00Z",
    "payloadJson": "{\"url\": \"example.com\", \"reason\": \"ADULT\"}",
    "createdAt": "2026-01-30T12:00:00Z"
  }
]
```

---

## 📱 5. Device (Appareil Enfant)

### 5.1 Récupérer les règles de l'appareil

**Endpoint:** `GET /api/v1/device/children/{childId}/rules`  
**Auth:** ✅ Bearer Token requis

#### Response (200 OK)

```json
{
  "childId": "uuid-string",
  "generatedAt": "2026-01-30T12:00:00Z",
  "profileAggregate": {
    // Même structure que ProfileAggregateDto (section 3.1)
  }
}
```

---

### 5.2 Envoyer un événement depuis l'appareil

**Endpoint:** `POST /api/v1/device/children/{childId}/events`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "eventId": "uuid-string",       // Requis
  "type": "APP_OPENED",           // Requis, type d'événement
  "occurredAt": "2026-01-30T12:00:00Z",  // Requis, ISO 8601
  "payload": {},                  // Optionnel, données supplémentaires
  "source": "DEVICE"              // Optionnel, défaut: "DEVICE"
}
```

#### Response (202 Accepted)

```json
{
  "accepted": true,
  "serverReceivedAt": "2026-01-30T12:00:00Z"
}
```

---

## ⚡ 6. Execute (Commandes automatisées)

### 6.1 Exécuter une commande

**Endpoint:** `POST /api/v1/execute`  
**Auth:** ✅ Bearer Token requis

#### Request Body

```json
{
  "requestId": "uuid-string",     // Requis
  "childId": "uuid-string",       // Requis
  "intent": "CREATE_SCHEDULE",    // Requis, type d'action
  "parameters": {},               // Requis, paramètres spécifiques à l'intent
  "source": "N8N",                // Optionnel, défaut: "N8N"
  "timestamp": "2026-01-30T12:00:00Z"  // Optionnel
}
```

#### Response (200 OK)

```json
{
  "requestId": "uuid-string",
  "status": "SUCCESS",
  "message": "Action exécutée avec succès",
  "data": {},
  "errors": []
}
```

---

## 🛠️ Configuration Flutter - Classe ApiConfig

```dart
import 'dart:io';

class ApiConfig {
  /// URL de base de l'API
  static String get baseUrl {
    // Détection automatique pour Android Emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  // ==================== AUTH ====================
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String verifyOtp = '/api/v1/auth/verify-otp';

  // ==================== PARENT ====================
  static const String myChildren = '/api/v1/parents/me/children';
  static const String linkChild = '/api/v1/parents/me/children/link';

  // ==================== PARENTAL CONTROL ====================
  static String parentalProfile(String childId) =>
      '/api/v1/children/$childId/parental/profile';

  static String schedules(String childId) =>
      '/api/v1/children/$childId/parental/schedules';

  static String schedule(String childId, String scheduleId) =>
      '/api/v1/children/$childId/parental/schedules/$scheduleId';

  static String contentRule(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category';

  static String contentKeywords(String childId, String category) =>
      '/api/v1/children/$childId/parental/content/$category/keywords';

  // ==================== HISTORY ====================
  static String history(String childId) =>
      '/api/v1/children/$childId/history';

  // ==================== DEVICE ====================
  static String deviceRules(String childId) =>
      '/api/v1/device/children/$childId/rules';

  static String deviceEvents(String childId) =>
      '/api/v1/device/children/$childId/events';

  // ==================== EXECUTE ====================
  static const String execute = '/api/v1/execute';
}
```

---

## 🔗 Exemple de Service HTTP (Dio)

```dart
import 'package:dio/dio.dart';

class ApiService {
  late final Dio _dio;
  String? _accessToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'TheGuardianApp/1.0',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
    ));
  }

  void setAccessToken(String token) {
    _accessToken = token;
  }

  void clearToken() {
    _accessToken = null;
  }

  // ==================== AUTH ====================

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final response = await _dio.post(ApiConfig.register, data: {
      'name': name,
      'email': email,
      'password': password,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final response = await _dio.post(ApiConfig.verifyOtp, data: {
      'email': email,
      'otpCode': otpCode,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(ApiConfig.login, data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }

  // ==================== PARENT ====================

  Future<Map<String, dynamic>> getMyChildren() async {
    final response = await _dio.get(ApiConfig.myChildren);
    return response.data;
  }

  Future<void> linkChild(String childId) async {
    await _dio.post(ApiConfig.linkChild, data: {'childId': childId});
  }

  // ==================== PARENTAL ====================

  Future<Map<String, dynamic>> getParentalProfile(String childId) async {
    final response = await _dio.get(ApiConfig.parentalProfile(childId));
    return response.data;
  }

  Future<Map<String, dynamic>> updateParentalProfile(
    String childId, {
    required bool enabled,
    required String mode,
    String? timezone,
  }) async {
    final response = await _dio.put(
      ApiConfig.parentalProfile(childId),
      data: {
        'enabled': enabled,
        'mode': mode,
        if (timezone != null) 'timezone': timezone,
      },
    );
    return response.data;
  }

  Future<List<dynamic>> getHistory(String childId) async {
    final response = await _dio.get(ApiConfig.history(childId));
    return response.data;
  }
}
```

---

## 📋 Résumé des Routes

| Méthode | Endpoint | Auth | Description |
|---------|----------|:----:|-------------|
| `POST` | `/api/v1/auth/register` | ❌ | Inscription |
| `POST` | `/api/v1/auth/verify-otp` | ❌ | Vérification OTP |
| `POST` | `/api/v1/auth/login` | ❌ | Connexion |
| `GET` | `/api/v1/parents/me/children` | ✅ | Liste des enfants |
| `POST` | `/api/v1/parents/me/children/link` | ✅ | Lier un enfant |
| `GET` | `/api/v1/children/{childId}/parental/profile` | ✅ | Profil parental |
| `PUT` | `/api/v1/children/{childId}/parental/profile` | ✅ | MAJ profil |
| `POST` | `/api/v1/children/{childId}/parental/schedules` | ✅ | Créer horaire |
| `PUT` | `/api/v1/children/{childId}/parental/schedules/{id}` | ✅ | MAJ horaire |
| `DELETE` | `/api/v1/children/{childId}/parental/schedules/{id}` | ✅ | Supprimer horaire |
| `PUT` | `/api/v1/children/{childId}/parental/content/{cat}` | ✅ | Règle contenu |
| `PUT` | `/api/v1/children/{childId}/parental/content/{cat}/keywords` | ✅ | MAJ mots-clés |
| `GET` | `/api/v1/children/{childId}/history` | ✅ | Historique |
| `GET` | `/api/v1/device/children/{childId}/rules` | ✅ | Règles appareil |
| `POST` | `/api/v1/device/children/{childId}/events` | ✅ | Événement appareil |
| `POST` | `/api/v1/execute` | ✅ | Exécuter commande |

---

## 🚀 Lancement du Backend en Local

```bash
# Dans le dossier du projet backend
./mvnw spring-boot:run

# Ou avec Maven installé
mvn spring-boot:run
```

Le serveur sera accessible sur `http://localhost:8080`

### Documentation Swagger

Une fois le serveur lancé, accédez à :
- **Swagger UI:** `http://localhost:8080/swagger-ui.html`
- **OpenAPI JSON:** `http://localhost:8080/v3/api-docs`
