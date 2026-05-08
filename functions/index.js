const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

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
