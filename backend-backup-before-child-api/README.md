# Guardian secure API

This Render service owns OTP generation and verification, subscription
provisioning, and verified SharePay webhooks. Flutter never receives, stores,
or reads an OTP from Firestore, and never writes entitlement documents.

## Render deployment

1. Push this repository to GitHub.
2. In Render, choose **New > Blueprint** and select the repository. Render reads
   `render.yaml` and creates `guardian-secure-api`.
3. Add `OTP_HMAC_SECRET`, `FIREBASE_SERVICE_ACCOUNT`, and
   `SHAREPAY_WEBHOOK_SECRET` as Render secrets. Do not put provider credentials
   in Flutter or in Git.
4. For `FIREBASE_SERVICE_ACCOUNT`, create a Firebase service-account JSON key and
   paste the full JSON as one Render secret. Never commit this file.
5. Deploy and open `https://<your-service>.onrender.com/health`; it must return
   `{ "status": "ok" }`.

## Flutter release configuration

Build the application with the Render URL:

```bash
flutter build apk --dart-define=API_BASE_URL=https://<your-service>.onrender.com
```

Use the same `--dart-define` for web and iOS release builds. Do not include
`OTP_HMAC_SECRET` or the Firebase service-account JSON in Flutter.
The release app deliberately refuses to use localhost when `API_BASE_URL` is
missing.

## Billing deployment gate

Before enabling the SharePay webhook, verify its production signature header,
algorithm, and payload field names against the provider contract. Configure the
same signing secret in SharePay and Render, then test duplicate webhook delivery
and a forged signature. The webhook is the only code path that grants a paid
plan.
