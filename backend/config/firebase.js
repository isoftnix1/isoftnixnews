const { initializeApp, getApps, cert } = require('firebase-admin/app');

const hasApp = getApps().length > 0;

let app;

if (!hasApp) {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY
      ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
      : null;

    const firebaseConfig = {
      projectId,
    };

    if (clientEmail && privateKey) {
      firebaseConfig.credential = cert({
        projectId,
        clientEmail,
        privateKey,
      });
    }

    app = initializeApp(firebaseConfig);
  } catch (error) {
    if (process.env.ENABLE_FCM === 'true') {
      console.error('❌ FATAL ERROR: Firebase initialization failed, but ENABLE_FCM is true. Missing or invalid credentials.', error.message);
      process.exit(1);
    } else {
      console.warn('Firebase admin initialization skipped:', error.message);
    }
  }
} else {
  app = getApps()[0];
}

module.exports = app;
