const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

exports.sendOtpEmail = functions.https.onCall(async (data, context) => {
  const targetEmail = data.targetEmail;
  const code = data.code;

  if (!targetEmail || !code) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with targetEmail and code."
    );
  }

  const serviceId = process.env.EMAILJS_SERVICE_ID || "service_m7f1ych";
  const templateId = process.env.EMAILJS_TEMPLATE_ID || "template_1gi1w7h";
  const publicKey = process.env.EMAILJS_PUBLIC_KEY || "DnybUAt7X_xra7xue";
  const accessToken = process.env.EMAILJS_ACCESS_TOKEN || "5fL5kY3T5hYPOjYopd5tA";

  const emailJsData = {
    service_id: serviceId,
    template_id: templateId,
    user_id: publicKey,
    accessToken: accessToken,
    template_params: {
      to_email: targetEmail,
      email: targetEmail,
      passcode: code,
      time: "15 minutes",
    },
  };

  try {
    const response = await axios.post("https://api.emailjs.com/api/v1.0/email/send", emailJsData, {
      headers: { "Content-Type": "application/json" }
    });
    
    return { success: true, message: "OTP sent successfully" };
  } catch (error) {
    console.error("EmailJS Error:", error.response ? error.response.data : error.message);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to send OTP email."
    );
  }
});

exports.onAlertCreated = functions.firestore
  .document("parents/{parentId}/children/{childId}/alerts/notifications/items/{alertId}")
  .onCreate(async (snap, context) => {
    const newAlert = snap.data();
    const parentId = context.params.parentId;
    const childId = context.params.childId;

    if (!newAlert) {
      console.log("Alert document is empty, skipping.");
      return null;
    }

    // Fallback message basé sur le type d'alerte si description absente
    const typeFallbacks = {
      "SOS":           "🆘 Alerte SOS déclenchée par votre enfant.",
      "BLOCKED_APP":   "🚫 Tentative d'accès à une application bloquée.",
      "TIME_LIMIT":    "⏰ Limite de temps d'écran atteinte.",
      "OUTSIDE_HOURS": "🌙 Utilisation en dehors des plages autorisées.",
      "WEB_SEARCH":    "🔍 Recherche web suspecte détectée.",
      "KEYWORD":       "⚠️ Mot-clé inapproprié détecté.",
      "GEOFENCE":      "📍 Votre enfant a quitté la zone autorisée.",
    };

    const alertBody =
      newAlert.detail ||
      newAlert.description ||
      newAlert.message ||
      typeFallbacks[newAlert.type] ||
      "Une nouvelle alerte a été déclenchée.";

    const alertTitle =
      newAlert.title ||
      (newAlert.type ? `Alerte – ${newAlert.type.replace(/_/g, " ")}` : "Alerte parentale");

    try {
      // 1. Récupérer le token FCM du parent
      const parentDoc = await admin.firestore().collection("parents").doc(parentId).get();
      if (!parentDoc.exists) {
        console.log(`Parent ${parentId} not found`);
        return null;
      }
      
      const parentData = parentDoc.data();
      const fcmToken = parentData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for parent ${parentId}`);
        return null;
      }

      // 2. Récupérer le prénom de l'enfant pour personnaliser le message
      let childName = "votre enfant";
      const childDoc = await admin.firestore()
        .collection("parents").doc(parentId)
        .collection("children").doc(childId).get();
        
      if (childDoc.exists && childDoc.data().displayName) {
        childName = childDoc.data().displayName;
      }

      // 3. Construire le message de notification
      const message = {
        token: fcmToken,
        notification: {
          title: `${alertTitle} – ${childName}`,
          body: alertBody,
        },
        data: {
          alertId: context.params.alertId,
          childId: childId,
          type: newAlert.type || "unknown",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
            icon: "ic_launcher",
            color: "#FF0000",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: `${alertTitle} – ${childName}`,
                body: alertBody,
              },
              sound: "default",
              badge: 1,
              contentAvailable: true,
            },
          },
        },
      };

      // 4. Envoi de la notification via FCM
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent message for type=${newAlert.type}:`, response);
      return response;
    } catch (error) {
      console.error("Error sending push notification:", error);
      return null;
    }
  });


