const admin = require('firebase-admin');
const serviceAccount = require('./howmuch_backend/src/main/resources/firebase-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();
db.collection('users').doc('4943103198').delete().then(() => {
  console.log('Success!');
  process.exit(0);
}).catch((err) => {
  console.error(err);
  process.exit(1);
});
