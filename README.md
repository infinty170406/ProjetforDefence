# The Guardian V1 - Execution Engine (Backend)

The Guardian V1 is a robust parental control backend system designed to manage and enforce digital safety rules for children. It features a dual-security model for human interacton (parents) and automated systems (like n8n).

## 🚀 Key Features

- **Parent Management**: Secure registration and authentication.
- **Email OTP Verification**: Mandatory account activation via email-based One-Time Passwords.
- **Child & Profile Management**: Manage multiple children and their associated parental profiles.
- **Rule Enforcement**:
  - **Content Rules**: Category-based filtering (Adult, Gaming, Social, etc.).
  - **Schedule Rules**: Time-based access controls for specific windows.
  - **Keyword Filtering**: Block content based on specific keywords with various match types (Contains, Exact, etc.).
- **Dual Security Model**:
  - **JWT Authorization**: For parent and mobile application interactions.
  - **API Key Authorization**: Dedicated `X-EXECUTE-KEY` for automated rule updates (e.g., from n8n workflows).
- **Swagger UI**: Interactive API documentation for easy integration.

## 🛠️ Tech Stack

- **Languge**: Java 17
- **Framework**: Spring Boot 3.3.2
- **Database**: PostgreSQL
- **Security**: Spring Security + JJWT (JSON Web Token)
- **Email**: Spring Boot Starter Mail (SMTP)
- **Documentation**: Springdoc OpenAPI (Swagger UI)
- **Build Tool**: Maven

## ⚙️ Configuration

The application is configured via `src/main/resources/application.yml`. 

### 1. Database Setup
Ensure you have a PostgreSQL instance running and a database named `the_guardian_v1`.
```yaml
spring:
  datasource:
    url: jdbc:postgresql://127.0.0.1:5432/the_guardian_v1
    username: postgres
    password: YOUR_PASSWORD
```

### 2. Email (SMTP) Setup
Currently configured for Gmail. Replace with your credentials or application password.
```yaml
spring:
  mail:
    host: smtp.gmail.com
    username: your-app@gmail.com
    password: your-app-password
```

### 3. Security Keys
**Important**: Change these keys for production environments.
```yaml
the_guardian:
  jwt:
    secret: "YOUR_SUPER_SECRET_KEY_AT_LEAST_32_CHARS"
  execute:
    apiKey: "YOUR_SECURE_EXECUTE_API_KEY"
```

## 🏃 Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/infinty170406/ProjetforDefence.git
   ```
2. **Build and Run**:
   ```bash
   mvn clean install
   mvn spring-boot:run
   ```
3. **API Documentation**:
   Once running, access Swagger UI at:
   `http://localhost:8081/swagger-ui/index.html`

## 📖 Security & API Usage

### Parent Auth (JWT)
Most endpoints under `/api/v1/parent/**` and `/api/v1/parental/**` require a JWT token:
`Authorization: Bearer <your_token>`

### Execution Engine (API Key)
Endpoints under `/api/v1/execute/**` are designed for system integrations (like n8n) and require:
`X-EXECUTE-KEY: <your_api_key>`

#### Example Execute Payload (Upsert Rule):
```json
{
  "requestId": "req-001",
  "childId": "uuid-of-child",
  "intent": "UPSERT_CONTENT_POLICY",
  "parameters": {
    "category": "ADULT",
    "action": "BLOCK",
    "enabled": true,
    "keywords": ["blocked_term"]
  },
  "source": "N8N",
  "timestamp": "2026-01-16T12:00:00Z"
}
```

## 📝 License
This project is private and for educational/defense purposes.
