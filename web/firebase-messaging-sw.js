importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCV_rdZoHo-yV2Ozr3okVjuwqswabYnv6w",
  authDomain: "control-parental-5f115.firebaseapp.com",
  projectId: "control-parental-5f115",
  storageBucket: "control-parental-5f115.firebasestorage.app",
  messagingSenderId: "638981354516",
  appId: "1:638981354516:web:d27d53086eb293df3a6301"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message: ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/favicon.png"
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
