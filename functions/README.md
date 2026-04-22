# HappySpeech Firebase Backend

This directory contains the Firebase Cloud Functions, seed scripts, and unit tests for the HappySpeech backend.

Implements the contracts defined in `.claude/team/api-contracts.md`.

---

## 1. Prerequisites

Install once globally:

```bash
# Firebase CLI
npm install -g firebase-tools

# Node.js 20 (matches functions engines)
# macOS (Homebrew):
brew install node@20
```

Install function dependencies:

```bash
cd functions
npm install
```

---

## 2. Project structure

```
functions/
├── index.js              Cloud Functions entry point (onCall + Firestore trigger)
├── package.json          Node 20, firebase-admin ^12, firebase-functions ^4
├── .eslintrc.json        Google style + 2-space indent
├── seed.js               Seeds /exercises and /content
├── src/
│   ├── auth.js           assertAuthorized() — owner | admin | linked specialist
│   ├── constants.js      STAGES, SOUND_GROUPS, TEMPLATE_TYPES, thresholds
│   ├── progress.js       calculateProgressForChild()
│   ├── reports.js        buildReport() + rule-based recommendations
│   └── stats.js          aggregateUserStats() across all children
└── tests/
    └── progress.test.js  Pure-function unit tests (Node built-in test runner)
```

---

## 3. Cloud Functions exported

| Name                 | Type                 | Purpose |
|----------------------|----------------------|---------|
| `calculateProgress`  | HTTPS onCall         | Recompute per-phoneme progress for one child |
| `generateReport`     | HTTPS onCall         | Build structured {summary, chartsData, recommendations} and persist under `/reports` |
| `getUserStats`       | HTTPS onCall         | Aggregate stats across all children of a parent |
| `onSessionComplete`  | Firestore trigger v2 | `onCreate` of `/users/{u}/children/{c}/sessions/{s}` → calls `calculateProgress` |

All HTTPS-callable functions:
- require authenticated caller (`request.auth.uid`);
- enforce App Check (`enforceAppCheck: true`);
- deny cross-user access except for admin / linked specialist.

Region: `europe-west3`.

---

## 4. Running the emulators

From the **project root** (where `firebase.json` lives):

```bash
firebase emulators:start
```

Ports (see `firebase.json`):

| Service   | Port |
|-----------|------|
| Auth      | 9099 |
| Functions | 5001 |
| Firestore | 8080 |
| Storage   | 9199 |
| UI        | 4000 |

Open the Emulator UI at `http://localhost:4000`.

### Seed data into the emulator

```bash
cd functions
FIRESTORE_EMULATOR_HOST=localhost:8080 \
GOOGLE_CLOUD_PROJECT=happyspeech-prod \
npm run seed
```

---

## 5. Running unit tests

```bash
cd functions
npm test
```

Uses Node's built-in `node:test` runner — no Jest needed. Tests cover pure
aggregation helpers (`groupSessionsBySound`, `buildDailySeries`,
`buildSoundBreakdown`, `buildRecommendations`, `emptyStageProgress`).

For E2E tests against the Firestore emulator use `firebase emulators:exec`:

```bash
firebase emulators:exec --only firestore,functions "cd functions && npm test"
```

---

## 6. Testing functions manually

### calculateProgress (HTTPS callable)

Callable functions are invoked via the Firebase SDK on the client, not via
raw curl. The emulator exposes an HTTP endpoint for the v2 functions runtime:

```
POST http://localhost:5001/happyspeech-prod/europe-west3/calculateProgress
Content-Type: application/json

{
  "data": {
    "userId": "test-parent-uid",
    "childId": "test-child-uuid"
  }
}
```

With curl (requires a test ID token from the auth emulator):

```bash
TOKEN="your-emulator-id-token"
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"userId":"test-parent-uid","childId":"test-child-uuid"}}' \
  http://localhost:5001/happyspeech-prod/europe-west3/calculateProgress
```

### generateReport

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"userId":"test-parent-uid","childId":"test-child-uuid","period":"week"}}' \
  http://localhost:5001/happyspeech-prod/europe-west3/generateReport
```

### getUserStats

```bash
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data":{"userId":"test-parent-uid"}}' \
  http://localhost:5001/happyspeech-prod/europe-west3/getUserStats
```

### onSessionComplete

Trigger it by writing a session document in the Firestore Emulator UI:

```
/users/test-parent-uid/children/test-child-uuid/sessions/new-session-1
{
  "id": "new-session-1",
  "childId": "test-child-uuid",
  "date": <serverTimestamp>,
  "templateType": "listen-and-choose",
  "targetSound": "Р",
  "stage": "wordInit",
  "durationSeconds": 300,
  "totalAttempts": 10,
  "correctAttempts": 8
}
```

The function will automatically recompute `/progress/Р`.

---

## 7. Deployment

### Dev deployment (first time)

```bash
# pick the target project
firebase use dev              # requires .firebaserc entry

# deploy everything
firebase deploy

# or incrementally
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only functions
```

### Production deployment

```bash
firebase use default          # → happyspeech-prod
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

---

## 8. Environment setup (one-time per project)

1. Log in to Firebase:

   ```bash
   firebase login
   ```

2. Link local code to a Firebase project:

   ```bash
   firebase use --add
   ```

3. Update `.firebaserc` if you use different project IDs (currently placeholders
   `happyspeech-prod`, `happyspeech-dev`, `happyspeech-staging`).

4. Enable the following in Firebase Console:
   - Authentication → Sign-in method → Email/Password, Apple
   - Firestore Database → Create database (production mode)
   - Storage → Get started (production mode)
   - App Check → Register app → DeviceCheck (iOS)

---

## 9. Security notes

- All Firestore/Storage writes go through the rules in `firestore.rules`
  and `storage.rules`.
- Only authenticated users can read `/exercises` and `/content`.
- Only `users/{uid}.role == 'admin'` can write to `/contentPacks`,
  `/exercises`, `/content`, and persist reports.
- Child data (`/users/{userId}/children/**`) is readable by: the owning
  parent, admins, and specialists linked via
  `specialists/{uid}.linkedChildIds`.
- Recordings in Storage (`/users/{uid}/children/**/recordings/**`) are
  **parent-only** by design (COPPA).
- Max audio upload: 20 MB (`audio/*` only).
- Max avatar upload: 5 MB (`image/(png|jpeg|jpg|webp)`).

---

## 10. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission-denied` from callable | Check `request.auth.uid` matches `userId` or role=admin or specialist-linked |
| `enforceAppCheck` blocks local calls | On emulator, disable App Check in iOS debug build or use debug token |
| `unauthenticated` in emulator | Make sure you signed into the Auth emulator first and pass ID token |
| Trigger doesn't fire | Verify region matches (`europe-west3`) and Firestore emulator is running |
| Seed script fails with `FIRESTORE_EMULATOR_HOST not set` | Export env vars before running `node seed.js` |
