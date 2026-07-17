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
app.use(express.json({ limit: '16kb' }));

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
  return leftBuffer.length === right.length && crypto.timingSafeEqual(leftBuffer, right);
};

const otpDocument = (uid) => db.doc(`parents/${uid}/verification/otp`);
const parentDocument = (uid) => db.doc(`parents/${uid}`);

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

app.use((error, _, response, __) => {
  const status = Number(error.status) || 500;
  if (status >= 500) console.error(error);
  return response.status(status).json({ error: status >= 500 ? 'Erreur de service.' : error.message });
});

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => console.log(`Guardian secure API listening on ${port}`));
