const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const crypto = require('crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { FieldValue, getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const nodemailer = require('nodemailer');

initializeApp();

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
        console.error(`Error sending to token ${token}:`, err);
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
    console.log(`OTP email sent successfully to ${targetEmail}`);
    return { success: true };
  } catch (error) {
    console.error('Error sending OTP email:', error);
    throw new HttpsError('internal', `Failed to send email: ${error.message}`);
  }
});
