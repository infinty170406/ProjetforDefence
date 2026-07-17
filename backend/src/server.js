import crypto from 'node:crypto';
import express from 'express';
import cors from 'cors';
import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

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

async function requireUser(request, response, next) {
  const header = request.get('authorization');
  if (!header?.startsWith('Bearer ')) {
    return response.status(401).json({ error: 'Authentification requise.' });
  }

  try {
    const token = await auth.verifyIdToken(header.substring('Bearer '.length));
    if (token.firebase?.sign_in_provider === 'anonymous') {
      return response.status(403).json({ error: 'Un compte parent est requis.' });
    }
    request.user = token;
    return next();
  } catch (_) {
    return response.status(401).json({ error: 'Session invalide ou expirée.' });
  }
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
    const { plan, cycle, paymentMethod, payerAccount } = request.body ?? {};
    if (!['MTN_MOMO_CM', 'ORANGE_MONEY_CM'].includes(paymentMethod) || !/^237\d{9}$/.test(String(payerAccount))) {
      const error = new Error('Méthode ou numéro de paiement invalide.'); error.status = 400; throw error;
    }
    const definition = billingPlan(plan, cycle);
    const data = await sharePay('/pay-in/charge', { method: 'POST', body: JSON.stringify({
      amount: definition.amount, currency: 'XAF', paymentMethod, payerAccount,
      merchantReference: `guardian:${request.user.uid}:${crypto.randomUUID()}`,
      idempotencyKey: crypto.randomUUID(), description: `Abonnement ${plan}`,
    }) });
    const intent = await createPaymentIntent({ uid: request.user.uid, plan, cycle, type: 'CHARGE', data });
    return response.status(201).json({ reference: intent.reference, status: intent.status });
  } catch (error) { return next(error); }
});

app.get('/api/v1/billing/payments/:reference', requireUser, async (request, response, next) => {
  try {
    const reference = request.params.reference;
    const intent = await paymentIntentDocument(reference).get();
    if (!intent.exists || intent.data().uid !== request.user.uid) return response.status(404).json({ error: 'Paiement introuvable.' });
    const data = await sharePay(`/pay-in/check_status/${encodeURIComponent(reference)}`, { method: 'GET' });
    return response.json({ reference: data.reference, status: data.status });
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

app.use((error, _, response, __) => {
  const status = Number(error.status) || 500;
  if (status >= 500) console.error(error);
  return response.status(status).json({ error: status >= 500 ? 'Erreur de service.' : error.message });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`Guardian secure API listening on ${port}`));
