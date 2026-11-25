// Shows phone notifications when the app is closed or in the background.
//
// Firebase Cloud Messaging looks for this exact file name at the root of the site.
// The values below are the app's public web settings (the same ones that are in
// lib/firebase_options.dart); they are not secrets. The SDK version matches the
// one the Flutter plugin uses.
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAz5GdjyHbtf7SBVoQpA1DJ8Ra6POFXNd0',
  authDomain: 'kasonde-bbuku.firebaseapp.com',
  projectId: 'kasonde-bbuku',
  storageBucket: 'kasonde-bbuku.firebasestorage.app',
  messagingSenderId: '663921871682',
  appId: '1:663921871682:web:87331e6d9f7e4c7ac9d6db',
});

const messaging = firebase.messaging();

// The server sends "notification" messages, which the browser shows by itself and
// which open the link we attach when tapped. This is only a safety net for a
// message that arrives with data and no notification part.
messaging.onBackgroundMessage((payload) => {
  if (payload.notification) return;
  const data = payload.data || {};
  if (!data.title) return;
  self.registration.showNotification(data.title, {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    data: { url: data.link || '/' },
  });
});

self.addEventListener('notificationclick', (event) => {
  const url = (event.notification.data && event.notification.data.url) || '/';
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if ('focus' in c) return c.focus();
      }
      return clients.openWindow(url);
    }),
  );
});
