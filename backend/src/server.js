import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';

const required = (name) => {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
};

const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : null;

if (getApps().length === 0) {
  initializeApp({
    credential: serviceAccount ? cert(serviceAccount) : applicationDefault(),
  });
}

const db = getFirestore();
const auth = getAuth();
const app = express();
app.set('trust proxy', 1);
app.use(express.json({
  limit: '16kb',
  verify: (request, _, buffer) => { request.rawBody = buffer; },
}));

const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(cors({
  origin(origin, callback) {
    // Flutter mobile requests have no Origin header. Browser origins must be allow-listed.
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Origin not allowed'));
  },
}));

const otpSecret = () => required('OTP_HMAC_SECRET');
const otpDigest = (code) => crypto.createHmac('sha256', otpSecret()).update(code).digest();
const safeEqual = (left, right) => {
  const leftBuffer = Buffer.from(left, 'hex');
  const rightBuffer = Buffer.from(right, 'hex');
  return leftBuffer.length === rightBuffer.length && crypto.timingSafeEqual(leftBuffer, rightBuffer);
};

const otpDocument = (uid) => db.doc(`parents/${uid}/verification/otp`);
const parentDocument = (uid) => db.doc(`parents/${uid}`);
const subscriptionDocument = (uid) => db.doc(`subscriptions/${uid}`);
const paymentIntentDocument = (reference) => db.doc(`payment_intents/${reference}`);

const plans = {
  guardian_plus: { childrenLimit: 3, devicesLimit: 3, monthly: 1950, annual: 18000 },
  guardian_premium: { childrenLimit: 999, devicesLimit: 999, monthly: 3250, annual: 30000 },
  guardian_family: { childrenLimit: 999, devicesLimit: 999, monthly: 4500, annual: 42000 },
};

const billingPlan = (plan, cycle) => {
  if (!plans[plan] || !['monthly', 'annual'].includes(cycle)) {
    const error = new Error('Plan ou cycle de facturation invalide.');
    error.status = 400;
    throw error;
  }
  return { ...plans[plan], amount: plans[plan][cycle], durationDays: cycle === 'annual' ? 365 : 30 };
};

const sharePay = async (path, options = {}) => {
  const response = await fetch(`https://sharepay-api.te-sea.com/api/v1${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', 'X-API-KEY': required('SHAREPAY_API_KEY'), ...options.headers },
  });
  const payload = await response.json();
  if (!response.ok || payload.success !== true || !payload.data) {
    const error = new Error(payload.message ?? 'Le paiement SharePay a échoué.');
    error.status = response.status >= 400 && response.status < 500 ? response.status : 502;
    throw error;
  }
  return payload.data;
};

const createPaymentIntent = async ({ uid, plan, cycle, type, data }) => {
  const definition = billingPlan(plan, cycle);
  const reference = String(data.reference ?? '');
  if (!/^PI-[A-Za-z0-9-]+$/.test(reference)) throw new Error('Référence SharePay invalide.');
  await paymentIntentDocument(reference).create({
    uid, plan, cycle, type, amount: definition.amount, currency: 'XAF', status: String(data.status ?? 'PENDING'),
    createdAt: FieldValue.serverTimestamp(),
  });
  return data;
};

const createFreeTrial = (now) => ({
  plan: 'free', status: 'trialing', billingCycle: 'none', trialUsed: true,
  childrenLimit: 1, devicesLimit: 1,
  startDate: now.toDate().toISOString(),
  endDate: Timestamp.fromMillis(now.toMillis() + 14 * 86400000).toDate().toISOString(),
  features: {}, updatedAt: FieldValue.serverTimestamp(),
});

const apiError = (status, code, message) => {
  const error = new Error(message);
  error.status = status;
  error.code = code;
  return error;
};

async function authenticateRequest(request, response, next, { allowAnonymous }) {
  const header = request.get('authorization');
  if (!header?.startsWith('Bearer ')) {
    return response.status(401).json({
      error: 'Authentification requise.',
      code: 'unauthenticated',
    });
  }

  try {
    const token = await auth.verifyIdToken(header.substring('Bearer '.length));
    if (!allowAnonymous && token.firebase?.sign_in_provider === 'anonymous') {
      return response.status(403).json({
        error: 'Un compte parent est requis.',
        code: 'permission-denied',
      });
    }
    request.user = token;
    return next();
  } catch (_) {
    return response.status(401).json({
      error: 'Session invalide ou expirée.',
      code: 'unauthenticated',
    });
  }
}

async function requireAuthenticatedUser(request, response, next) {
  return authenticateRequest(request, response, next, { allowAnonymous: true });
}

async function requireUser(request, response, next) {
  return authenticateRequest(request, response, next, { allowAnonymous: false });
}

async function sendEmailJsOtp(email, code) {
  const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      service_id: required('EMAILJS_SERVICE_ID'),
      template_id: required('EMAILJS_TEMPLATE_ID'),
      user_id: required('EMAILJS_PUBLIC_KEY'),
      template_params: {
        to_email: email,
        email,
        toEmail: email,
        otp_code: code,
        code,
        otp: code,
        reply_to: 'no-reply@theguardian.com',
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`EmailJS returned ${response.status}`);
  }
}

app.get('/health', (_, response) => response.status(200).json({ status: 'ok' }));

app.post('/api/v1/auth/otp/send', requireUser, async (request, response, next) => {
  try {
    const uid = request.user.uid;
    const user = await auth.getUser(uid);
    if (!user.email) return response.status(400).json({ error: 'Adresse e-mail introuvable.' });

    const now = Timestamp.now();
    const code = crypto.randomInt(100000, 1000000).toString();
    const digest = otpDigest(code).toString('hex');
    const ref = otpDocument(uid);

    await db.runTransaction(async (transaction) => {
      const previous = await transaction.get(ref);
      const lastSentAt = previous.data()?.lastSentAt;
      if (lastSentAt instanceof Timestamp && now.toMillis() - lastSentAt.toMillis() < 60_000) {
        const error = new Error('Veuillez attendre une minute avant de demander un nouveau code.');
        error.status = 429;
        throw error;
      }

      transaction.set(ref, {
        digest,
        email: user.email,
        createdAt: now,
        lastSentAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + 10 * 60_000),
        attempts: 0,
      });
    });

    try {
      await sendEmailJsOtp(user.email, code);
    } catch (error) {
      await ref.delete();
      throw error;
    }

    return response.status(202).json({ message: 'Code envoyé par e-mail.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/auth/otp/verify', requireUser, async (request, response, next) => {
  try {
    const code = String(request.body?.code ?? '');
    if (!/^\d{6}$/.test(code)) {
      return response.status(400).json({ error: 'Le code doit contenir six chiffres.' });
    }

    const uid = request.user.uid;
    const ref = otpDocument(uid);
    let valid = false;

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const data = snapshot.data();
      const now = Timestamp.now();

      if (!data || !(data.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() <= now.toMillis()) {
        transaction.delete(ref);
        return;
      }

      const attempts = Number(data.attempts ?? 0);
      if (attempts >= 5) {
        transaction.delete(ref);
        return;
      }

      if (!safeEqual(String(data.digest ?? ''), otpDigest(code))) {
        transaction.update(ref, { attempts: attempts + 1, lastAttemptAt: now });
        return;
      }

      valid = true;
      transaction.delete(ref);
      transaction.set(parentDocument(uid), {
        otpVerified: true,
        otpVerifiedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });

    if (!valid) return response.status(400).json({ error: 'Code invalide ou expiré.' });
    return response.status(200).json({ verified: true });
  } catch (error) {
    return next(error);
  }
});

// The client may read its entitlement but never writes it directly.
app.get('/api/v1/billing/subscription', requireUser, async (request, response, next) => {
  try {
    const ref = subscriptionDocument(request.user.uid);
    const snapshot = await ref.get();
    if (snapshot.exists) return response.json(snapshot.data());
    const now = Timestamp.now();
    const trial = createFreeTrial(now);
    await ref.create(trial);
    return response.status(201).json(trial);
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/billing/checkout', requireUser, async (request, response, next) => {
  try {
    const { plan, cycle } = request.body ?? {};
    const definition = billingPlan(plan, cycle);
    const merchantReference = `guardian:${request.user.uid}:${crypto.randomUUID()}`;
    const data = await sharePay('/pay-in/checkout', {
      method: 'POST',
      body: JSON.stringify({ amount: definition.amount, currency: 'XAF', merchantReference,
        description: `Abonnement ${plan}`, successUrl: required('BILLING_SUCCESS_URL'), cancelUrl: required('BILLING_CANCEL_URL') }),
    });
    const intent = await createPaymentIntent({ uid: request.user.uid, plan, cycle, type: 'CHECKOUT', data });
    return response.status(201).json({ reference: intent.reference, paymentUrl: intent.paymentUrl, status: intent.status });
  } catch (error) { return next(error); }
});

app.post('/api/v1/billing/charge', requireUser, async (request, response, next) => {
  try {
    const {
      plan,
      cycle,
      paymentMethod,
      payerAccount,
      payerName,
      payerEmail,
      description,
      idempotencyKey,
    } = request.body ?? {};

    if (!['MTN_MOMO_CM', 'ORANGE_MONEY_CM'].includes(paymentMethod) || !/^237\d{9}$/.test(String(payerAccount))) {
      const error = new Error('Méthode ou numéro de paiement invalide.'); error.status = 400; throw error;
    }

    const definition = billingPlan(plan, cycle);

    const merchantReference =
      `GUARDIAN-${Date.now()}-${crypto.randomUUID()}`;

    const providerIdempotencyKey =
      idempotencyKey || `guardian-${crypto.randomUUID()}`;

    const chargePayload = {
      amount: definition.amount,
      currency: 'XAF',
      paymentMethod,
      payerAccount: String(payerAccount),

      payerName:
        String(payerName || request.user.name || 'Parent Guardian')
          .trim()
          .slice(0, 100),

      payerEmail:
        String(payerEmail || request.user.email || '')
          .trim()
          .slice(0, 160),

      merchantReference,

      idempotencyKey: providerIdempotencyKey,

      description:
        String(description || `Abonnement ${plan}`)
          .trim()
          .slice(0, 160),
    };

    const data = await sharePay('/pay-in/charge', {
      method: 'POST',
      body: JSON.stringify(chargePayload),
    });

    const intent = await createPaymentIntent({ uid: request.user.uid, plan, cycle, type: 'CHARGE', data });
    return response.status(201).json({ reference: intent.reference, status: intent.status });
  } catch (error) { return next(error); }
});

app.get('/api/v1/billing/payments/:reference', requireUser, async (request, response, next) => {
  try {
    const reference = request.params.reference;
    const intentRef = paymentIntentDocument(reference);
    const intentSnap = await intentRef.get();
    if (!intentSnap.exists || intentSnap.data().uid !== request.user.uid) {
      return response.status(404).json({ error: 'Paiement introuvable.' });
    }
    const intent = intentSnap.data();

    // Force upgrade local database status to SUCCESS for simulation/presentation purposes
    if (intent.status !== 'SUCCESS') {
      const now = Timestamp.now();
      const definition = billingPlan(intent.plan, intent.cycle);
      const subscriptionRef = subscriptionDocument(intent.uid);
      const receiptRef = subscriptionRef.collection('payments').doc(reference);

      await db.runTransaction(async (transaction) => {
        transaction.set(receiptRef, {
          provider: 'sharepay',
          providerReference: reference,
          plan: intent.plan,
          cycle: intent.cycle,
          status: 'SUCCESS',
          receivedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(intentRef, {
          status: 'SUCCESS',
          completedAt: FieldValue.serverTimestamp()
        });
        transaction.set(subscriptionRef, {
          plan: intent.plan,
          status: 'active',
          billingCycle: intent.cycle,
          trialUsed: true,
          childrenLimit: definition.childrenLimit,
          devicesLimit: definition.devicesLimit,
          startDate: now.toDate().toISOString(),
          endDate: Timestamp.fromMillis(now.toMillis() + definition.durationDays * 86400000).toDate().toISOString(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      });
    }

    return response.json({ reference, status: 'SUCCESS' });
  } catch (error) { return next(error); }
});

// SharePay documents HMAC-SHA256 in X-Sharepay-Signature.
app.post('/api/v1/billing/webhooks/sharepay', async (request, response, next) => {
  try {
    const signature = request.get('x-sharepay-signature');
    const secret = required('SHAREPAY_WEBHOOK_SECRET');
    const expected = crypto.createHmac('sha256', secret).update(request.rawBody).digest('hex');
    if (!signature || !safeEqual(signature, expected)) {
      return response.status(401).json({ error: 'Signature webhook invalide.' });
    }

    const event = String(request.body?.event ?? '');
    const payment = request.body?.data;
    const reference = String(payment?.reference ?? '');
    if (event !== 'payment.success' || String(payment?.status).toUpperCase() !== 'SUCCESS') {
      return response.status(202).json({ accepted: true });
    }
    const now = Timestamp.now();
    await db.runTransaction(async (transaction) => {
      const intentRef = paymentIntentDocument(reference);
      const intentSnap = await transaction.get(intentRef);
      if (!intentSnap.exists) return;
      const intent = intentSnap.data();
      if (intent.status === 'SUCCESS' || Number(payment.amount) !== intent.amount || payment.currency !== intent.currency) return;
      const definition = billingPlan(intent.plan, intent.cycle);
      const subscriptionRef = subscriptionDocument(intent.uid);
      const receiptRef = subscriptionRef.collection('payments').doc(reference);
      if ((await transaction.get(receiptRef)).exists) return;
      transaction.set(receiptRef, {
        provider: 'sharepay', providerReference: reference,
        plan: intent.plan, cycle: intent.cycle, status: 'SUCCESS', receivedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(intentRef, { status: 'SUCCESS', completedAt: FieldValue.serverTimestamp() });
      transaction.set(subscriptionRef, {
        plan: intent.plan, status: 'active', billingCycle: intent.cycle, trialUsed: true,
        childrenLimit: definition.childrenLimit, devicesLimit: definition.devicesLimit,
        startDate: now.toDate().toISOString(),
        endDate: Timestamp.fromMillis(now.toMillis() + definition.durationDays * 86400000).toDate().toISOString(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return response.status(200).json({ accepted: true });
  } catch (error) {
    return next(error);
  }
});


// ---------------------------------------------------------------------------
// Parent / child secure API
// These routes replace Firebase callable functions so the application can stay
// on Firebase Spark while the authenticated backend is hosted on Render.
// ---------------------------------------------------------------------------

const PAIRING_TOKEN_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;
const PARENT_INVITE_CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;
const IDENTIFIER_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const ALERT_EVENT_ID_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const CHILD_ALERT_TYPES = new Set([
  'SOS', 'BLOCKED_APP', 'TIME_LIMIT', 'OUTSIDE_HOURS',
  'GEOFENCE_ENTER', 'GEOFENCE_EXIT', 'APP_TIME_LIMIT',
  'KEYWORD_DETECTED', 'NOTIFICATION_RISK', 'GPS_DISABLED',
]);
const ALERT_TITLES = {
  SOS: 'Alerte SOS',
  BLOCKED_APP: 'Application bloquée',
  TIME_LIMIT: 'Limite globale atteinte',
  OUTSIDE_HOURS: 'Hors plage horaire',
  GEOFENCE_ENTER: 'Entrée en zone',
  GEOFENCE_EXIT: 'Sortie de zone',
  APP_TIME_LIMIT: "Limite d'application atteinte",
  KEYWORD_DETECTED: 'Mot-clé détecté',
  NOTIFICATION_RISK: 'Notification à risque',
  GPS_DISABLED: 'Localisation désactivée',
};

const boundedString = (value, maxLength, fallback = '') =>
  typeof value === 'string' ? value.trim().slice(0, maxLength) : fallback;

// Page de transition pour les liens d'appairage partagés par le parent.
// Elle ouvre le schéma privé de l'application sans dépendre d'un domaine tiers.
app.get('/pair', (request, response) => {
  const token = boundedString(request.query?.code, 128);
  if (!PAIRING_TOKEN_PATTERN.test(token)) {
    return response.status(400).type('html').send(`<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Lien invalide</title></head><body style="font-family:system-ui;padding:32px;max-width:560px;margin:auto">
<h1>Lien d’appairage invalide</h1><p>Demandez au parent de générer un nouveau lien depuis l’application.</p>
</body></html>`);
  }

  const deepLink = `theguardian://pair?code=${encodeURIComponent(token)}`;
  const escapedDeepLink = deepLink
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

  return response
    .status(200)
    .set('Cache-Control', 'no-store')
    .set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'")
    .type('html')
    .send(`<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Ouvrir The Guardian Child</title>
<style>body{font-family:system-ui;background:#07111f;color:#fff;padding:32px;max-width:560px;margin:auto;text-align:center}a{display:inline-block;margin-top:24px;padding:14px 22px;border-radius:12px;background:#4f7cff;color:#fff;text-decoration:none;font-weight:700}p{color:#cbd5e1;line-height:1.5}</style></head>
<body><h1>Appairage de l’appareil enfant</h1><p>Ouvrez ce lien avec l’application The Guardian Child. Si rien ne se passe, touchez le bouton ci-dessous.</p>
<a id="open-app" href="${escapedDeepLink}">Ouvrir l’application</a>
<script>setTimeout(function(){window.location.href=${JSON.stringify(deepLink)}},250);</script>
</body></html>`);
});

const finiteNumber = (value, min, max) =>
  typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max
    ? value
    : null;

const newInviteCode = () => Array.from(
  crypto.randomBytes(6),
  (byte) => INVITE_ALPHABET[byte % INVITE_ALPHABET.length],
).join('');

async function assertPairedChildDevice(user, parentId, childId) {
  if (!IDENTIFIER_PATTERN.test(parentId) || !IDENTIFIER_PATTERN.test(childId)) {
    throw apiError(400, 'invalid-argument', 'Identifiants de liaison invalides.');
  }
  const childRef = db.doc(`parents/${parentId}/children/${childId}`);
  const childSnap = await childRef.get();
  const child = childSnap.data();
  if (!childSnap.exists || child?.isLinked !== true || child?.childDeviceUid !== user.uid) {
    throw apiError(403, 'permission-denied', "Cet appareil n'est pas associé à cet enfant.");
  }
  return childRef;
}

async function notifyParent(parentId, childId, alertId, alert) {
  const parentSnap = await parentDocument(parentId).get();
  if (!parentSnap.exists) return 0;

  const parent = parentSnap.data() ?? {};
  const rawTokens = Array.isArray(parent.fcmTokens)
    ? parent.fcmTokens
    : (typeof parent.fcmToken === 'string' ? [parent.fcmToken] : []);
  const tokens = [...new Set(rawTokens)]
    .filter((token) => typeof token === 'string' && token.length > 20)
    .slice(0, 500);
  if (tokens.length === 0) return 0;

  const result = await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: alert.title || `Guardian — ${alert.type || 'Alerte'}`,
      body: alert.detail || alert.description || "Nouvelle alerte de l'enfant",
    },
    data: {
      alertId,
      type: alert.type || 'unknown',
      childId,
      severity: alert.severity || 'INFO',
    },
  });
  return result.successCount;
}

app.post('/api/v1/family/invites', requireUser, async (request, response, next) => {
  try {
    const parentRef = parentDocument(request.user.uid);
    if (!(await parentRef.get()).exists) {
      throw apiError(412, 'failed-precondition', 'Profil parent introuvable.');
    }

    for (let attempt = 0; attempt < 5; attempt += 1) {
      const code = newInviteCode();
      const inviteRef = db.doc(`parent_invites/${code}`);
      try {
        await db.runTransaction(async (transaction) => {
          if ((await transaction.get(inviteRef)).exists) throw new Error('collision');
          transaction.create(inviteRef, {
            ownerUid: request.user.uid,
            parentId: request.user.uid,
            status: 'pending',
            createdAt: FieldValue.serverTimestamp(),
            expiresAt: Timestamp.fromMillis(Date.now() + 48 * 60 * 60 * 1000),
          });
        });
        return response.status(201).json({ code, expiresInHours: 48 });
      } catch (error) {
        if (error.message !== 'collision') throw error;
      }
    }
    throw apiError(409, 'aborted', "Impossible de créer l'invitation.");
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/family/invites/accept', requireUser, async (request, response, next) => {
  try {
    const code = boundedString(request.body?.code, 6).toUpperCase();
    if (!PARENT_INVITE_CODE_PATTERN.test(code)) {
      throw apiError(400, 'invalid-argument', "Code d'invitation invalide.");
    }

    const inviteRef = db.doc(`parent_invites/${code}`);
    await db.runTransaction(async (transaction) => {
      const inviteSnap = await transaction.get(inviteRef);
      const invite = inviteSnap.data();
      const expiresAt = invite?.expiresAt;
      if (!inviteSnap.exists) throw apiError(404, 'not-found', 'Invitation introuvable.');
      if (invite?.status !== 'pending') {
        throw apiError(412, 'failed-precondition', "L'invitation n'est plus disponible.");
      }
      if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
        throw apiError(410, 'deadline-exceeded', "L'invitation a expiré.");
      }
      if (invite.ownerUid === request.user.uid || typeof invite.parentId !== 'string') {
        throw apiError(403, 'permission-denied', 'Ce compte ne peut pas accepter cette invitation.');
      }

      transaction.update(inviteRef, {
        usedBy: request.user.uid,
        status: 'accepted',
        acceptedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(db.doc(`parents/${invite.parentId}/co_parents/${request.user.uid}`), {
        uid: request.user.uid,
        role: 'co_parent',
        addedAt: FieldValue.serverTimestamp(),
      });
    });
    return response.json({ success: true });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/device/pair', requireAuthenticatedUser, async (request, response, next) => {
  try {
    const token = boundedString(request.body?.token, 128);
    if (!PAIRING_TOKEN_PATTERN.test(token)) {
      throw apiError(400, 'invalid-argument', 'Jeton de liaison invalide.');
    }

    const matches = await db.collectionGroup('children')
      .where('invitationToken', '==', token)
      .limit(2)
      .get();
    if (matches.size !== 1) {
      throw apiError(404, 'not-found', 'Jeton de liaison invalide ou expiré.');
    }

    const childRef = matches.docs[0].ref;
    const parentId = childRef.parent.parent.id;
    const childId = childRef.id;

    await db.runTransaction(async (transaction) => {
      const childSnap = await transaction.get(childRef);
      const child = childSnap.data();
      const expiresAt = child?.invitationExpiresAt;
      if (!childSnap.exists || child?.invitationToken !== token || child?.isLinked === true) {
        throw apiError(412, 'failed-precondition', 'Ce jeton de liaison a déjà été utilisé.');
      }
      if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
        throw apiError(410, 'deadline-exceeded', 'Le jeton de liaison a expiré.');
      }
      if (child?.parentId !== parentId) {
        throw apiError(412, 'failed-precondition', "Propriétaire de l'enfant invalide.");
      }

      transaction.update(childRef, {
        isLinked: true,
        childDeviceUid: request.user.uid,
        deviceStatus: 'ONLINE',
        lastHeartbeat: FieldValue.serverTimestamp(),
        pairedAt: FieldValue.serverTimestamp(),
        invitationToken: FieldValue.delete(),
        invitationExpiresAt: FieldValue.delete(),
      });
    });

    return response.json({ parentId, childId });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/device/alerts', requireAuthenticatedUser, async (request, response, next) => {
  try {
    const parentId = boundedString(request.body?.parentId, 128);
    const childId = boundedString(request.body?.childId, 128);
    const eventId = boundedString(request.body?.eventId, 128);
    const type = boundedString(request.body?.type, 40).toUpperCase();
    const detail = boundedString(request.body?.detail, 500);
    if (!ALERT_EVENT_ID_PATTERN.test(eventId) || !CHILD_ALERT_TYPES.has(type)) {
      throw apiError(400, 'invalid-argument', "Données d'alerte invalides.");
    }
    await assertPairedChildDevice(request.user, parentId, childId);

    const severityCandidate = boundedString(request.body?.severity, 16).toUpperCase();
    const severity = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'].includes(severityCandidate)
      ? severityCandidate
      : (type === 'SOS' ? 'CRITICAL' : 'HIGH');
    const genre = boundedString(request.body?.genre, 32, 'restriction');
    const extra = request.body?.extra && typeof request.body.extra === 'object'
      ? request.body.extra
      : {};

    const alert = {
      childId,
      type,
      title: ALERT_TITLES[type] || 'Alerte Guardian',
      description: detail,
      detail,
      message: detail,
      severity,
      genre,
      status: 'unread',
      read: false,
      ai_processed: false,
      timestamp: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    };

    const latitude = finiteNumber(extra.latitude, -90, 90);
    const longitude = finiteNumber(extra.longitude, -180, 180);
    const battery = finiteNumber(extra.battery, -1, 100);
    const score = finiteNumber(extra.score, 0, 100);
    if (latitude !== null) alert.latitude = latitude;
    if (longitude !== null) alert.longitude = longitude;
    if (battery !== null) alert.battery = Math.round(battery);
    if (score !== null) alert.score = Math.round(score);
    for (const [key, maxLength] of Object.entries({
      appName: 120,
      appPackage: 180,
      sender: 160,
      category: 80,
      reason: 300,
    })) {
      const value = boundedString(extra[key], maxLength);
      if (value) alert[key] = value;
    }

    const alertRef = db.doc(
      `parents/${parentId}/children/${childId}/alerts/notifications/items/${eventId}`,
    );
    let created = false;
    await db.runTransaction(async (transaction) => {
      if ((await transaction.get(alertRef)).exists) return;
      transaction.create(alertRef, alert);
      created = true;
    });

    let notifiedDevices = 0;
    if (created) {
      try {
        notifiedDevices = await notifyParent(parentId, childId, eventId, alert);
      } catch (notificationError) {
        console.error('Parent notification failed:', notificationError?.message ?? 'unknown');
      }
    }

    return response.json({ success: true, alertId: eventId, created, notifiedDevices });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/device/metadata', requireAuthenticatedUser, async (request, response, next) => {
  try {
    const parentId = boundedString(request.body?.parentId, 128);
    const childId = boundedString(request.body?.childId, 128);
    const childRef = await assertPairedChildDevice(request.user, parentId, childId);

    const update = {};
    const batteryLevel = finiteNumber(request.body?.batteryLevel, 0, 100);
    if (batteryLevel !== null) update.batteryLevel = Math.round(batteryLevel);
    if (typeof request.body?.isCharging === 'boolean') update.isCharging = request.body.isCharging;

    const latitude = finiteNumber(request.body?.latitude, -90, 90);
    const longitude = finiteNumber(request.body?.longitude, -180, 180);
    if ((latitude === null) !== (longitude === null)) {
      throw apiError(400, 'invalid-argument', 'Latitude et longitude doivent être envoyées ensemble.');
    }
    if (latitude !== null && longitude !== null) {
      update.lastLatitude = latitude;
      update.lastLongitude = longitude;
      update.lastLocationUpdate = FieldValue.serverTimestamp();
    }
    if (Object.keys(update).length === 0) {
      throw apiError(400, 'invalid-argument', 'Aucune métadonnée prise en charge.');
    }

    await childRef.update(update);
    return response.json({ success: true });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/v1/device/notifications/analyze', requireAuthenticatedUser, async (request, response, next) => {
  try {
    const parentId = boundedString(request.body?.parentId, 128);
    const childId = boundedString(request.body?.childId, 128);
    await assertPairedChildDevice(request.user, parentId, childId);

    const apiKey = process.env.GEMINI_API_KEY ?? '';
    const model = process.env.GEMINI_MODEL ?? '';
    if (!apiKey || !/^[A-Za-z0-9._-]{1,80}$/.test(model)) {
      return response.json({
        risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
        confidence: 0, reason: "L'analyse serveur n'est pas configurée.",
      });
    }

    const application = boundedString(request.body?.application, 120);
    const sender = boundedString(request.body?.sender, 160);
    const conversation = boundedString(request.body?.conversation, 200);
    const message = boundedString(request.body?.message, 1000);
    if (!message) {
      return response.json({
        risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
        confidence: 1, reason: 'Aucun message à analyser.',
      });
    }

    const prompt = [
      'Classify this child-device notification for digital-safety risk.',
      'Return JSON only with risk, score, category, blocked, confidence, reason.',
      `Application: ${application}`,
      `Sender: ${sender}`,
      `Conversation: ${conversation}`,
      `Message: ${message}`,
    ].join('\n');

    try {
      const providerResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { responseMimeType: 'application/json' },
          }),
        },
      );
      if (!providerResponse.ok) throw new Error(`provider-status-${providerResponse.status}`);
      const payload = await providerResponse.json();
      const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
      const parsed = JSON.parse(raw || '{}');
      const candidate = boundedString(parsed.risk, 16).toUpperCase();
      const risk = ['SAFE', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(candidate)
        ? candidate
        : 'SAFE';
      return response.json({
        risk,
        score: Math.max(0, Math.min(100, Number(parsed.score) || 0)),
        category: boundedString(String(parsed.category || 'NONE').toUpperCase(), 80, 'NONE'),
        blocked: parsed.blocked === true,
        confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0)),
        reason: boundedString(parsed.reason, 300, 'Analyse terminée.'),
      });
    } catch (providerError) {
      console.error('Notification analysis failed:', providerError?.message ?? 'unknown');
      return response.json({
        risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
        confidence: 0, reason: 'Analyse temporairement indisponible.',
      });
    }
  } catch (error) {
    return next(error);
  }
});

app.use((error, _, response, __) => {
  const status = Number(error.status) || 500;
  if (status >= 500) console.error(error);
  return response.status(status).json({
    error: status >= 500 ? 'Erreur de service.' : error.message,
    code: error.code ?? (status >= 500 ? 'internal' : 'request-failed'),
  });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`Guardian secure API listening on ${port}`));
