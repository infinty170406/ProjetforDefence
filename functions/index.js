const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const nodemailer = require('nodemailer');

initializeApp();

const geminiApiKey = defineSecret('GEMINI_API_KEY');
const geminiModel = defineString('GEMINI_MODEL');

const PAIRING_TOKEN_PATTERN = /^[A-Za-z0-9_-]{32,128}$/;
const PARENT_INVITE_CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;
const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function newInviteCode() {
  return Array.from(crypto.randomBytes(6), byte => INVITE_ALPHABET[byte % INVITE_ALPHABET.length]).join('');
}

exports.createParentInvite = onCall(async (request) => {
  if (!request.auth || request.auth.token.firebase?.sign_in_provider === 'anonymous') {
    throw new HttpsError('unauthenticated', 'A parent account is required.');
  }
  const db = getFirestore();
  const parentRef = db.doc(`parents/${request.auth.uid}`);
  if (!(await parentRef.get()).exists) throw new HttpsError('failed-precondition', 'Parent profile not found.');
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = newInviteCode();
    const inviteRef = db.doc(`parent_invites/${code}`);
    try {
      await db.runTransaction(async (transaction) => {
        if ((await transaction.get(inviteRef)).exists) throw new Error('collision');
        transaction.create(inviteRef, {
          ownerUid: request.auth.uid, parentId: request.auth.uid, status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
          expiresAt: Timestamp.fromMillis(Date.now() + 48 * 60 * 60 * 1000),
        });
      });
      return { code, expiresInHours: 48 };
    } catch (error) {
      if (error.message !== 'collision') throw error;
    }
  }
  throw new HttpsError('aborted', 'Unable to create invitation.');
});

/**
 * Consumes a one-time child pairing token without exposing child documents to
 * collectionGroup reads. The Admin SDK transaction also prevents a replay.
 */
exports.activateChildDevice = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const token = typeof request.data?.token === 'string'
    ? request.data.token.trim()
    : '';
  if (!PAIRING_TOKEN_PATTERN.test(token)) {
    throw new HttpsError('invalid-argument', 'Invalid pairing token.');
  }

  const db = getFirestore();
  const matches = await db.collectionGroup('children')
    .where('invitationToken', '==', token)
    .limit(2)
    .get();
  if (matches.size !== 1) {
    throw new HttpsError('not-found', 'Pairing token is invalid or expired.');
  }

  const childRef = matches.docs[0].ref;
  const parentId = childRef.parent.parent.id;
  const childId = childRef.id;

  await db.runTransaction(async (transaction) => {
    const childSnap = await transaction.get(childRef);
    const child = childSnap.data();
    const expiresAt = child?.invitationExpiresAt;

    if (!childSnap.exists || child?.invitationToken !== token || child?.isLinked === true) {
      throw new HttpsError('failed-precondition', 'Pairing token has already been used.');
    }
    if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('deadline-exceeded', 'Pairing token has expired.');
    }
    if (child?.parentId !== parentId) {
      throw new HttpsError('failed-precondition', 'Invalid child ownership.');
    }

    transaction.update(childRef, {
      isLinked: true,
      childDeviceUid: request.auth.uid,
      deviceStatus: 'ONLINE',
      lastHeartbeat: FieldValue.serverTimestamp(),
      pairedAt: FieldValue.serverTimestamp(),
      invitationToken: FieldValue.delete(),
      invitationExpiresAt: FieldValue.delete(),
    });
  });

  return { parentId, childId };
});

/** Consumes a co-parent invitation server-side so invite documents stay private. */
exports.acceptParentInvite = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const code = typeof request.data?.code === 'string'
    ? request.data.code.trim().toUpperCase()
    : '';
  if (!PARENT_INVITE_CODE_PATTERN.test(code)) {
    throw new HttpsError('invalid-argument', 'Invalid invitation code.');
  }

  const db = getFirestore();
  const inviteRef = db.collection('parent_invites').doc(code);
  await db.runTransaction(async (transaction) => {
    const inviteSnap = await transaction.get(inviteRef);
    const invite = inviteSnap.data();
    const expiresAt = invite?.expiresAt;
    if (!inviteSnap.exists) throw new HttpsError('not-found', 'Invitation not found.');
    if (invite?.status !== 'pending') throw new HttpsError('failed-precondition', 'Invitation is no longer available.');
    if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('deadline-exceeded', 'Invitation has expired.');
    }
    if (invite.ownerUid === request.auth.uid || typeof invite.parentId !== 'string') {
      throw new HttpsError('permission-denied', 'Invitation cannot be accepted by this account.');
    }

    transaction.update(inviteRef, {
      usedBy: request.auth.uid,
      status: 'accepted',
      acceptedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(db.doc(`parents/${invite.parentId}/co_parents/${request.auth.uid}`), {
      uid: request.auth.uid,
      role: 'co_parent',
      addedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});


const CHILD_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;
const ALERT_EVENT_ID_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
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

function boundedString(value, maxLength, fallback = '') {
  if (typeof value !== 'string') return fallback;
  return value.trim().slice(0, maxLength);
}

function finiteNumber(value, min, max) {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max
    ? value
    : null;
}

async function assertPairedChildDevice(request, parentId, childId) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  if (!CHILD_ID_PATTERN.test(parentId) || !CHILD_ID_PATTERN.test(childId)) {
    throw new HttpsError('invalid-argument', 'Invalid pairing identifiers.');
  }

  const childRef = getFirestore().doc(`parents/${parentId}/children/${childId}`);
  const childSnap = await childRef.get();
  const child = childSnap.data();
  if (!childSnap.exists || child?.isLinked !== true || child?.childDeviceUid !== request.auth.uid) {
    throw new HttpsError('permission-denied', 'This device is not paired with the requested child.');
  }
  return childRef;
}

/**
 * Receives a child-generated alert without granting the child direct write
 * access to the parent notification collection. The client event id makes
 * retries idempotent.
 */
exports.reportChildAlert = onCall(async (request) => {
  const parentId = boundedString(request.data?.parentId, 128);
  const childId = boundedString(request.data?.childId, 128);
  const eventId = boundedString(request.data?.eventId, 128);
  const type = boundedString(request.data?.type, 40).toUpperCase();
  const detail = boundedString(request.data?.detail, 500);

  if (!ALERT_EVENT_ID_PATTERN.test(eventId) || !CHILD_ALERT_TYPES.has(type)) {
    throw new HttpsError('invalid-argument', 'Invalid alert payload.');
  }
  await assertPairedChildDevice(request, parentId, childId);

  const severity = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO']
    .includes(String(request.data?.severity || '').toUpperCase())
    ? String(request.data.severity).toUpperCase()
    : (type === 'SOS' ? 'CRITICAL' : 'HIGH');
  const genre = boundedString(request.data?.genre, 32, 'restriction');
  const extra = request.data?.extra && typeof request.data.extra === 'object'
    ? request.data.extra
    : {};

  const data = {
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
  if (latitude !== null) data.latitude = latitude;
  if (longitude !== null) data.longitude = longitude;
  if (battery !== null) data.battery = Math.round(battery);
  if (score !== null) data.score = Math.round(score);

  for (const [key, maxLength] of Object.entries({
    appName: 120,
    appPackage: 180,
    sender: 160,
    category: 80,
    reason: 300,
  })) {
    const value = boundedString(extra[key], maxLength);
    if (value) data[key] = value;
  }

  const alertRef = getFirestore().doc(
    `parents/${parentId}/children/${childId}/alerts/notifications/items/${eventId}`,
  );
  await getFirestore().runTransaction(async (transaction) => {
    if ((await transaction.get(alertRef)).exists) return;
    transaction.create(alertRef, data);
  });

  return { success: true, alertId: eventId };
});

/** Updates parent-visible device metadata after verifying the paired child. */
exports.updateChildDeviceMetadata = onCall(async (request) => {
  const parentId = boundedString(request.data?.parentId, 128);
  const childId = boundedString(request.data?.childId, 128);
  const childRef = await assertPairedChildDevice(request, parentId, childId);

  const update = {};
  const batteryLevel = finiteNumber(request.data?.batteryLevel, 0, 100);
  if (batteryLevel !== null) update.batteryLevel = Math.round(batteryLevel);
  if (typeof request.data?.isCharging === 'boolean') {
    update.isCharging = request.data.isCharging;
  }

  const latitude = finiteNumber(request.data?.latitude, -90, 90);
  const longitude = finiteNumber(request.data?.longitude, -180, 180);
  if ((latitude === null) !== (longitude === null)) {
    throw new HttpsError('invalid-argument', 'Latitude and longitude must be provided together.');
  }
  if (latitude !== null && longitude !== null) {
    update.lastLatitude = latitude;
    update.lastLongitude = longitude;
    update.lastLocationUpdate = FieldValue.serverTimestamp();
  }

  if (Object.keys(update).length === 0) {
    throw new HttpsError('invalid-argument', 'No supported metadata was provided.');
  }
  await childRef.update(update);
  return { success: true };
});

/**
 * Optional server-side notification classification. Provider credentials stay
 * in the Functions environment and are never distributed to child devices.
 */
exports.analyzeChildNotification = onCall({ secrets: [geminiApiKey] }, async (request) => {
  const parentId = boundedString(request.data?.parentId, 128);
  const childId = boundedString(request.data?.childId, 128);
  await assertPairedChildDevice(request, parentId, childId);

  const apiKey = geminiApiKey.value();
  const model = geminiModel.value();
  if (!apiKey || !model || !/^[A-Za-z0-9._-]{1,80}$/.test(model)) {
    return {
      risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
      confidence: 0, reason: 'Server-side analysis is not configured.',
    };
  }

  const application = boundedString(request.data?.application, 120);
  const sender = boundedString(request.data?.sender, 160);
  const conversation = boundedString(request.data?.conversation, 200);
  const message = boundedString(request.data?.message, 1000);
  if (!message) {
    return {
      risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
      confidence: 1, reason: 'No message content to analyze.',
    };
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
    const response = await fetch(
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
    if (!response.ok) throw new Error(`provider-status-${response.status}`);
    const payload = await response.json();
    const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
    const parsed = JSON.parse(raw || '{}');
    const risk = ['SAFE', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
      .includes(String(parsed.risk || '').toUpperCase())
      ? String(parsed.risk).toUpperCase()
      : 'SAFE';
    return {
      risk,
      score: Math.max(0, Math.min(100, Number(parsed.score) || 0)),
      category: boundedString(String(parsed.category || 'NONE').toUpperCase(), 80, 'NONE'),
      blocked: parsed.blocked === true,
      confidence: Math.max(0, Math.min(1, Number(parsed.confidence) || 0)),
      reason: boundedString(parsed.reason, 300, 'Analysis completed.'),
    };
  } catch (error) {
    console.error('analyzeChildNotification failed:', error?.message || 'unknown');
    return {
      risk: 'SAFE', score: 0, category: 'NONE', blocked: false,
      confidence: 0, reason: 'Server-side analysis is temporarily unavailable.',
    };
  }
});

exports.notifyParentOnAlert = onDocumentCreated('parents/{parentId}/children/{childId}/alerts/notifications/items/{alertId}', async (event) => {
  const alert = event.data.data();
  const { parentId, childId, alertId } = event.params;

  if (!alert) return;

  try {
    // Récupérer le document parent pour les tokens FCM     
    const parentDoc = await getFirestore().doc(`parents/${parentId}`).get();
    if (!parentDoc.exists) {
      console.log(`Parent ${parentId} not found`);
      return;
    }

    const parentData = parentDoc.data();
    // Supporte à la fois fcmToken (ancien) et fcmTokens (nouveau tableau)
    let tokens = [];
    if (parentData.fcmTokens && Array.isArray(parentData.fcmTokens)) {
      tokens = parentData.fcmTokens;
    } else if (parentData.fcmToken) {
      tokens = [parentData.fcmToken];
    }

    if (tokens.length === 0) {
      console.log(`No FCM tokens for parent ${parentId}`);
      return;
    }

    // Envoyer la notification push à tous les tokens actifs
    const message = {
      notification: {
        title: alert.title || `Guardian — ${alert.type || 'Alerte'}`,
        body: alert.detail || alert.description || 'Nouvelle alerte de votre enfant',
      },
      data: {
        alertId: alertId,
        type: alert.type || 'unknown',
        childId: childId,
        severity: alert.severity || 'INFO',
      },
    };

    const responses = await Promise.all(tokens.map(token => 
      getMessaging().send({ ...message, token }).catch(err => {
        console.error('Error sending parent notification:', err?.message || 'unknown');
        return null;
      })
    ));

    const successCount = responses.filter(r => r !== null).length;
    console.log(`Notification sent to ${successCount}/${tokens.length} devices for parent ${parentId}`);
  } catch (error) {
    console.error('Error in notifyParentOnAlert:', error);
  }
});

exports.sendOtpEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const targetEmail = typeof request.data?.targetEmail === 'string'
    ? request.data.targetEmail.trim().toLowerCase()
    : '';
  const code = typeof request.data?.code === 'string' ? request.data.code : '';

  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError('invalid-argument', 'The OTP code must contain six digits.');
  }

  const user = await getAuth().getUser(request.auth.uid);
  if (!user.email || user.email.toLowerCase() !== targetEmail) {
    throw new HttpsError('permission-denied', 'OTP emails can only be sent to the authenticated user.');
  }

  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
  const smtpPort = parseInt(process.env.SMTP_PORT || '465');
  const smtpSecure = process.env.SMTP_SECURE !== 'false';

  if (!smtpUser || !smtpPass) {
    console.error('SMTP_USER or SMTP_PASS environment variables are not set.');
    throw new HttpsError('failed-precondition', 'Email delivery is not configured.');
  }

  const transporter = nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });

  const mailOptions = {
    from: `"The Guardian" <${smtpUser}>`,
    to: targetEmail,
    subject: 'Votre code de vérification OTP - The Guardian',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #4A154B; text-align: center;">The Guardian - Sécurité</h2>
        <p>Bonjour,</p>
        <p>Pour finaliser votre connexion et sécuriser votre compte, veuillez utiliser le code de vérification à 6 chiffres suivant :</p>
        <div style="background-color: #f4f4f4; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #4A154B; border-radius: 5px; margin: 20px 0;">
          ${code}
        </div>
        <p>Ce code est valide pendant 10 minutes. Ne le partagez avec personne.</p>
        <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail en toute sécurité.</p>
        <br>
        <hr style="border: 0; border-top: 1px solid #e0e0e0;">
        <p style="font-size: 12px; color: #777777; text-align: center;">Cet e-mail a été envoyé automatiquement par The Guardian. Ne pas répondre.</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log('OTP email sent successfully.');
    return { success: true };
  } catch (error) {
    console.error('Error sending OTP email:', error);
    throw new HttpsError('internal', `Failed to send email: ${error.message}`);
  }
});
