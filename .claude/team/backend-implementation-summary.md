# Backend Implementation Summary — HappySpeech
**Author:** backend-dev-api
**Task:** ph3-backend-dev-api
**Branch:** feature/backend-implementation
**Date:** 2026-04-22
**Contract source:** `.claude/team/api-contracts.md` (v1.0)

---

## 1. What was delivered

Full Firebase backend scaffold for HappySpeech: security rules, indexes, Cloud Functions with real aggregation logic, seed data, and developer tooling (emulators, tests, README).

All files live at the project root as required by the task brief.

### Files created (14 total)

| Path | Purpose |
|---|---|
| `firebase.json` | Firebase CLI config: rules/indexes/functions/emulators |
| `.firebaserc` | Project aliases: `default=happyspeech-prod`, `dev`, `staging` |
| `firestore.rules` | Firestore security rules (260 LOC, full tree coverage) |
| `firestore.indexes.json` | 9 composite indexes for history/dashboard/parent queries |
| `storage.rules` | Storage rules (content read-all-auth, recordings parent-only) |
| `functions/package.json` | Node 20, firebase-admin ^12, firebase-functions ^4.9 |
| `functions/.eslintrc.json` | Google style, 2-space indent, single quotes |
| `functions/.gitignore` | node_modules, env, runtime config |
| `functions/index.js` | 4 Cloud Functions — onCall + Firestore trigger |
| `functions/src/auth.js` | `assertAuthorized()` — owner/admin/specialist check |
| `functions/src/constants.js` | STAGES, SOUND_GROUPS, TEMPLATE_TYPES, thresholds |
| `functions/src/progress.js` | `calculateProgressForChild()` + pure helpers |
| `functions/src/reports.js` | `buildReport()` + rule-based recommendations |
| `functions/src/stats.js` | `aggregateUserStats()` across all children |
| `functions/seed.js` | Seeds `/content` (20 cards) + `/exercises` (30+) |
| `functions/tests/progress.test.js` | 6 pure-function unit tests — all passing |
| `functions/README.md` | Setup, run, deploy, troubleshoot |
| `HappySpeech/Resources/GoogleService-Info.plist.template` | Filled-out template with step-by-step instructions |

`.gitignore` updated with: `functions/node_modules/`, `firebase-debug.*.log`, `ui-debug.log`, `functions/.runtimeconfig.json`. `GoogleService-Info.plist` already excluded.

---

## 2. Cloud Functions implemented

All functions deploy to region `europe-west3`, enforce App Check, validate caller identity, and use structured logging (`firebase-functions/logger`).

| Function | Type | Input | Output |
|---|---|---|---|
| `calculateProgress` | HTTPS onCall | `{ userId, childId }` | `{ soundTargets: [{ soundTarget, stageProgress, totalSessions, totalMinutes, overallRate, childId }], updatedAt }` |
| `generateReport` | HTTPS onCall | `{ userId, childId, period: "week"\|"month"\|"all" }` | `{ reportId, period, summary, chartsData, recommendations }` — also persisted under `/users/{u}/children/{c}/reports/{reportId}` |
| `getUserStats` | HTTPS onCall | `{ userId }` | `{ userId, childrenCount, totalSessions, totalMinutes, lastActiveAt, perChild: [...] }` |
| `onSessionComplete` | Firestore `onDocumentCreated` v2 | path `users/{u}/children/{c}/sessions/{s}` | side-effect: recomputes `/progress/{targetSound}` only for that sound |

All callable functions throw typed `HttpsError` codes (`unauthenticated`, `permission-denied`, `invalid-argument`, `internal`). Errors are logged but raw exception messages are **not** returned to clients.

### Business logic placement

Following Routes → Controller → Service → Repository pattern:
- `index.js` = controllers only (validation, auth assertion, error wrapping)
- `src/progress.js`, `src/reports.js`, `src/stats.js` = services (pure where possible)
- Firestore access happens inside service files; no business logic leaks into `index.js`

---

## 3. Security rules highlights

### Firestore
- `/users/{userId}` — owner read/write; role is immutable after create; age validated 5..8
- `/users/{userId}/children/{childId}` — owner or linked specialist; age 5..8; name 1..50
- `/sessions/{sid}` — `durationSeconds > 0`, `correctAttempts ≤ totalAttempts`, required fields enforced; sessions effectively **immutable** (only admin/specialist can annotate; field ids locked)
- `/attempts/{aid}` — `asrScore ∈ [0,1]`, `pronunciationScore ∈ [0,1]`, `manualScore ∈ [-1,1]`; only specialist can write `manualScore`
- `/progress/{sound}` — client read-only; written by Cloud Functions (admin SDK) exclusively
- `/exercises`, `/content`, `/contentPacks` — read for any authenticated user; write for admins only
- `/specialists/{uid}` — self-managed; admin override
- Top-level `match /{document=**}` default-deny

### Storage
- `/content/**` — read for signed-in; admin write
- `/models/**` — read for signed-in; admin write
- `/users/{uid}/avatars/**` — owner only; ≤ 5 MB image
- `/users/{uid}/children/{cid}/recordings/**` and `/attempts/**` — parent-only; ≤ 20 MB audio
- `/users/{uid}/exports/**` — parent read; written by Functions only
- Default-deny fallback

---

## 4. Firestore indexes

9 composite indexes covering the contracted query patterns:

- `sessions` (childId ASC + date DESC) — collection group, for history
- `sessions` (childId ASC + createdAt DESC) — collection, for history (createdAt variant)
- `sessions` (childId ASC + targetSound ASC + date DESC) — collection group
- `sessions` (userId ASC + createdAt DESC) — parent view
- `progress` (childId ASC + soundTarget ASC) — dashboard
- `attempts` (childId ASC + timestamp DESC) — collection group
- `contentPacks` (soundTarget ASC + stage ASC + version DESC)
- `exercises` (templateType ASC + targetSound ASC + difficulty ASC)
- `reports` (childId ASC + period ASC + createdAt DESC) — collection group

---

## 5. Seed data

`functions/seed.js` populates:
- **20 word cards** in `/content/` across sounds Р, Л, С, Ш, З with init/med/final positions and difficulty 1–2
- **30+ exercises** across 3 template types (`listen-and-choose`, `repeat-after-model`, `sorting`) and 5 sounds at multiple stages

Run against the emulator:
```bash
FIRESTORE_EMULATOR_HOST=localhost:8080 \
GOOGLE_CLOUD_PROJECT=happyspeech-prod \
npm run seed --prefix functions
```

Per the brief (≥10 exercises per template): `listen-and-choose` has 10, `repeat-after-model` has 10, `sorting` has 10. Template catalog in `src/constants.js` lists all 16 supported template types from the spec; the seed exercises the most commonly-used three.

---

## 6. Emulator configuration (firebase.json)

| Service | Port |
|---|---|
| Auth | 9099 |
| Functions | 5001 |
| Firestore | 8080 |
| Storage | 9199 |
| UI | 4000 |

Start with `firebase emulators:start` from project root.

---

## 7. Tests

`functions/tests/progress.test.js` — **6 passing tests** using Node.js built-in `node:test` runner (no Jest dependency):

```
✔ emptyStageProgress returns all stages with rate 0
✔ groupSessionsBySound aggregates attempts per sound
✔ buildDailySeries groups by day and computes accuracy
✔ buildSoundBreakdown produces per-sound aggregates
✔ buildRecommendations returns starter tip when empty
✔ buildRecommendations flags weakest sound
tests 6, pass 6, fail 0
```

Run: `npm test` (from `functions/`). No `npm install` needed — firebase-admin is lazy-required inside functions that actually touch Firestore, so pure-function tests run standalone.

---

## 8. How the iOS client should use this

### SDK-only contract (no REST)

Per ADR in `architecture.md` and `api-contracts.md` §Architecture Note, iOS never makes custom HTTP requests to these functions directly. It uses:

- `Firebase Auth SDK` — login (Apple Sign-In + email)
- `Firestore iOS SDK` — document read/write/listen
- `Firebase Storage iOS SDK` — audio upload/download
- `Firebase Functions iOS SDK` — call `calculateProgress`, `generateReport`, `getUserStats` via `Functions.functions().httpsCallable(...)`

### Trigger pattern

iOS writes a `session` document via the Firestore SDK → `onSessionComplete` fires server-side → `/progress/{sound}` is automatically updated. The iOS client only needs to **listen** to `/progress` to reflect updated stage bars in the UI.

### Call sites on iOS side (suggested)

| Feature | Function |
|---|---|
| `ProgressDashboard` | listen on `/progress`; call `calculateProgress` as "refresh" button |
| `SessionHistory` / `ParentHome` | call `getUserStats` |
| `ParentGuide` (weekly) | call `generateReport` with `period:"week"` |
| `Specialist` view | call `generateReport` with `period:"month"` |

---

## 9. How to get GoogleService-Info.plist

Template at `HappySpeech/Resources/GoogleService-Info.plist.template` contains full step-by-step instructions:

1. Firebase Console → create project `happyspeech-prod` (or dev/staging)
2. Add iOS app with bundle id `com.happyspeech.app` (matches project.yml)
3. Download `GoogleService-Info.plist`
4. Place at `HappySpeech/Resources/GoogleService-Info.plist`
5. Add to Xcode target "HappySpeech" (Target Membership)
6. Verify `.gitignore` excludes the real file (already done)

CI tip: keep the plist in Base64 CI secret and decode at build time.

Enable in Firebase Console: **Authentication** (Apple + Email), **Firestore**, **Storage**, **App Check** (DeviceCheck).

---

## 10. Deployment runbook

```bash
# one-time
firebase login
firebase use --add          # bind to happyspeech-dev or -prod

# ongoing
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only functions

# all at once
firebase deploy
```

---

## 11. What was NOT delivered (intentional, out of scope)

- No custom REST server (by contract — Firebase SDK only).
- No Firebase Analytics / Crashlytics integration (Kids Category compliance — see ADR-004).
- No Admin UI (admin role is set manually via Firestore console).
- No Claude API proxy (section 21.3 of master-plan-v2 — online-only parent feature, out of scope for ph3).
- No automatic backup/restore Cloud Function (scheduled export can be added later).
- Only 3 of 16 template types have seeded exercises — the remaining 13 templates are listed in `src/constants.js` and can be seeded by extending `seed.js`.

---

## 12. Verification checklist (all ✓)

- [x] JSON syntax valid: `firebase.json`, `.firebaserc`, `firestore.indexes.json`, `functions/package.json`, `functions/.eslintrc.json`
- [x] JS syntax valid: all 7 `.js` files (`node -c`)
- [x] Plist template valid: `plutil -lint` OK
- [x] Unit tests: 6 pass, 0 fail (`npm test`)
- [x] Security rules cover all collections from `api-contracts.md` §2
- [x] Storage paths match `api-contracts.md` §4
- [x] No secrets committed; real plist gitignored
- [x] No business logic in `index.js` controllers
- [x] Typed errors — never raw exceptions to clients
- [x] README covers setup, emulators, tests, deploy, troubleshooting
