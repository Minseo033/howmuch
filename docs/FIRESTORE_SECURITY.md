# Firestore security rules

The Flutter client does not use `cloud_firestore`; all data access goes through the Spring Boot API. The committed `firestore.rules` therefore denies every direct client read and write. Firebase Admin SDK calls from the backend bypass these rules and continue to work.

## Deployment

1. Confirm the active Firebase project with `firebase projects:list` and `firebase use`.
2. Review `firestore.rules` and deploy only the rules with `firebase deploy --only firestore:rules`.
3. In the Firebase Rules playground, confirm an unauthenticated and an authenticated client read are both denied.

The repository intentionally does not commit `.firebaserc`, so a developer cannot deploy to a production project by accident merely by cloning the repository.
