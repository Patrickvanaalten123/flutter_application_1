# Firebase rules (reference)

This app uploads profile pictures to Firebase Storage at:

`userphotos/{uid}.jpg`

If you see errors like `firebase_storage/unauthorized` or `permission-denied`, update your Firebase Storage rules accordingly.

- Storage rules example: `boetepot/firebase/storage.rules`

Where to apply:
- Firebase Console → **Storage** → **Rules** → paste the contents of `boetepot/firebase/storage.rules` → **Publish**.

If the error mentions Firestore (e.g. `cloud_firestore/permission-denied`), your Firestore rules likely don’t allow updating `users/{uid}.photoURL`.

## Payment round notifications

Goal: when a payment round starts, all members of that BoetePot (group) receive a push notification.
Also: when a user gets assigned a boete, that user receives a push notification.

What’s needed on Firebase:
- **Firebase Cloud Messaging (FCM)** enabled (default for most projects).
- A backend sender (recommended: **Cloud Functions**). No extension is required.

Implementation in this repo:
- Clients subscribe to topic `boetepot_{groupId}` when selecting a group.
- A Firestore-triggered Cloud Function sends to that topic when a doc is created in `paymentRounds/*`: `boetepot/functions/index.js`.
- Clients also subscribe to topic `boetepot_user_{uid}` (per user) for boete notifications.
- A Firestore-triggered Cloud Function sends to that topic when a doc is created in `boetes/*`: `boetepot/functions/index.js`.

Firebase setup steps (one-time):
- Firebase Console → **Project settings** → **Cloud Messaging**:
  - iOS: upload an **APNs Auth Key** (or certificates).
- Deploy the function (requires Firebase CLI):
  - `cd boetepot/functions && npm i`
  - `firebase init functions` (if you don’t have it yet in your Firebase project folder)
  - Deploy: `firebase deploy --only functions:onPaymentRoundCreated,functions:onBoeteCreated`

If deploy fails with Eventarc/IAM errors, an Owner/IAM Admin may need to grant:
- `roles/eventarc.serviceAgent` to `service-<PROJECT_NUMBER>@gcp-sa-eventarc.iam.gserviceaccount.com`
- `roles/iam.serviceAccountTokenCreator` to `service-<PROJECT_NUMBER>@gcp-sa-pubsub.iam.gserviceaccount.com`
- `roles/run.invoker` and `roles/eventarc.eventReceiver` to `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`

Client setup notes:
- Add the dependency: `firebase_messaging` (already added in `boetepot/pubspec.yaml`).
- iOS: in Xcode, enable **Push Notifications** capability (Runner target).

## Account verwijderen (Play Store policy)

De app heeft een ingebouwde optie om je account te verwijderen (Profiel → Profiel & Instellingen → **Account permanent verwijderen**).

Wat dit doet (server-side via Cloud Functions):
- Verwijdert `users/{uid}` en `userGroups/{uid}/groups/*`
- Verwijdert de gebruiker uit alle `groups/*` (en zorgt dat er minimaal 1 admin overblijft)
- Verwijdert profielfoto `userphotos/{uid}.jpg` (best-effort)
- Verwijdert payment-obligations `paymentRounds/{roundId}/payments/{uid}` (best-effort)
- Anonimiseert historische e-mailvelden in `boetes`/`boeteTemplates` (best-effort)
- Verwijdert de Firebase Auth user

Deploy:
- `firebase deploy --only functions:deleteMyAccount,functions:onAccountDeletionRequested`

## Mollie betalingen (betaalronde)

De app kan per gebruiker een Mollie checkout starten voor een openstaande betaling in een betaalronde.

Let op: Mollie UI staat in de app standaard uit (feature-flag), zodat je het later eenvoudig kunt activeren zonder dat het nu zichtbaar is.

Feature flags (Firestore `groups/{groupId}`):
- Pro (betaallink zichtbaar/instelbaar): zet `billing.plan` op `"pro"` (of `isPro: true`).
- Mollie UI zichtbaar: zet `features.molliePaymentsEnabled` op `true`.

Concept:
- Boetepot admin koppelt Mollie (Connect/OAuth) aan een BoetePot.
- In de betaalronde kan ieder lid zijn eigen betaling starten via **Betaal nu**.
- Servicekosten worden bovenop het bedrag gerekend:
  - `>= €100` → `1%`
  - anders → `3%`
  - minimum `€1`
- Webhook zet de betaling automatisch op `paid` in Firestore.

Benodigde Functions:
- `startMollieConnect` (callable)
- `mollieOAuthCallback` (https)
- `createMolliePaymentForRound` (callable)
- `mollieWebhook` (https)

Benodigde env vars (Cloud Functions):
- `MOLLIE_CLIENT_ID`
- `MOLLIE_CLIENT_SECRET`
- `MOLLIE_REDIRECT_URL` (moet matchen met je Mollie OAuth app)
- `MOLLIE_PAYMENT_REDIRECT_URL` (waar Mollie na betaling terugkomt)
- `MOLLIE_WEBHOOK_URL` (de `mollieWebhook` endpoint URL)

Deploy (Functions):
- `firebase deploy --only functions:startMollieConnect,functions:mollieOAuthCallback,functions:createMolliePaymentForRound,functions:mollieWebhook`
