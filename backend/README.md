# Guardian secure API — Render

This Node.js service is the privileged backend for the Guardian parent and
child applications. It is designed to run as a Render Web Service while the
Firebase project remains on the no-cost Spark plan.

The Flutter applications keep using Firebase Authentication and Firestore,
but privileged operations are sent to this HTTPS API with a Firebase ID token
in the `Authorization: Bearer <token>` header.

## Implemented routes

### Service

- `GET /health`

### OTP

- `POST /api/v1/auth/otp/send`
- `POST /api/v1/auth/otp/verify`

### Billing

- `GET /api/v1/billing/subscription`
- `POST /api/v1/billing/checkout`
- `POST /api/v1/billing/charge`
- `GET /api/v1/billing/payments/:reference`
- `POST /api/v1/billing/webhooks/sharepay`

### Parent and child compatibility

- `POST /api/v1/family/invites`
- `POST /api/v1/family/invites/accept`
- `POST /api/v1/device/pair`
- `POST /api/v1/device/alerts`
- `POST /api/v1/device/metadata`
- `POST /api/v1/device/notifications/analyze`

The alert route writes the Firestore alert and sends the parent FCM push in the
same request. No Firestore-triggered Cloud Function is required.

## Required Render secrets

Configure these in the Render dashboard, never in Git or Flutter:

- `OTP_HMAC_SECRET`
- `FIREBASE_SERVICE_ACCOUNT` — complete Firebase service-account JSON
- `EMAILJS_SERVICE_ID`
- `EMAILJS_TEMPLATE_ID`
- `EMAILJS_PUBLIC_KEY`
- `ALLOWED_ORIGINS`

Billing-only values:

- `SHAREPAY_API_KEY`
- `SHAREPAY_WEBHOOK_SECRET`
- `BILLING_SUCCESS_URL`
- `BILLING_CANCEL_URL`

Optional analysis values:

- `GEMINI_API_KEY`
- `GEMINI_MODEL`

Without the optional Gemini values, the analysis endpoint stays available and
returns a safe, non-blocking fallback.

## Local verification

```bash
npm install
npm run check
npm start
```

Then open:

```text
http://localhost:3000/health
```

## Render configuration

For the parent monorepo:

- Root directory: `backend`
- Build command: `npm install --omit=dev`
- Start command: `npm start`
- Health check: `/health`
- Runtime: Node.js 20

## Flutter release configuration

Build both applications with the public Render URL:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<service>.onrender.com
```

The child application also has native Android background code. Supply the same
URL to Gradle while building it:

```bash
GUARDIAN_API_BASE_URL=https://<service>.onrender.com \
flutter build apk --release \
  --dart-define=API_BASE_URL=https://<service>.onrender.com
```

Never include the Firebase service-account JSON or server secrets in either APK.
