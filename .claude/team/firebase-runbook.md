# Firebase Runbook — HappySpeech

Проект: `happyspeech-dfd95` (регион Cloud Functions: `europe-west3`,
Realtime Database: `europe-west1`)

---

## Firebase services state (verified 2026-05-08, после Plan v18 Block U)

| Service | Status | Last verified | Notes |
|---|---|---|---|
| Auth (Email + Google + Anonymous) | Active | 2026-05-08 | Sign in with Apple deferred |
| Firestore | Active | 2026-05-08 | rules + 14 indexes deployed |
| Cloud Functions | Active | 2026-05-08 | 16 функций (10 baseline + 6 NEW v18 callable) |
| Storage | Active | 2026-05-08 | rules deployed |
| App Check (DeviceCheck) | Active | 2026-05-08 | enforce production, debug provider в DEBUG |
| Remote Config | Active | 2026-05-08 | template v3 — 19 параметров + 1 condition |
| FCM | Active | 2026-05-08 | parent-only opt-in |
| Performance Monitoring | Active | 2026-05-08 | parent-only opt-in COPPA-safe |
| **Installations** | Active (verified) | 2026-05-08 | Block U.3 v18 — auto-enabled через FirebaseApp.configure(). Service: `InstallationsService.swift`. См. ADR-V18-U-INSTALLATIONS-VERIFIED. |
| **A/B Testing** | Active (template) | 2026-05-08 | Block U.5 v18 — `tutorial_variant` parameter + condition `ab_tutorial_variant_b`. Console activation deferred. |
| **Realtime Database** | Active (service) | 2026-05-08 | Block U.6 v18 — `RealtimeDatabaseService.swift`. Region `europe-west1` (closest для eur3). Used by SharePlay sync. |
| **Family Invites** (replaces Dynamic Links) | Active (service) | 2026-05-08 | Block U.4 v18 — Apple Universal Links + Firestore tokens. См. ADR-V18-U-DYNAMICLINKS-REPLACE. |
| ~~Dynamic Links~~ | DEPRECATED | 2025-08-25 | Sunset Google. Заменён на FamilyInviteService. Legacy `DynamicLinksService.swift` остался как stub для DI compatibility. |

---

## Cloud Functions inventory (16 total после Block U.1)

### Baseline (10) — Sprint 12 / M1.3

| Function | Тип | App Check | Description |
|---|---|---|---|
| `calculateProgress` | onCall | false | Aggregation per child |
| `generateReport` | onCall | false | Parent summary report |
| `getUserStats` | onCall | false | User-wide stats |
| `exportUserData` | onCall | false | GDPR JSON export |
| `deleteUserData` | onCall | false | GDPR hard delete |
| `setAdminClaim` | onCall | false | Admin bootstrap |
| `sendWeeklySummaryFCM` | onCall | false | On-demand FCM push |
| `onSessionComplete` | Firestore trigger | n/a | Recompute progress |
| `moderateUserContent` | Firestore trigger | n/a | Audit attempts (placeholder) |
| `sendWeeklyReport` | Scheduled | n/a | Sundays 10:00 MSK |
| `sendDailyReminder` | Scheduled | n/a | Every day 17:00 UTC |
| `sendWeeklySummary` | Scheduled | n/a | Sundays 19:00 UTC |

### NEW v18 (6) — Block U.1

| Function | Тип | App Check | Description |
|---|---|---|---|
| `scoreSpeechQuality` | onCall | **true** | Server-side scoring stub (real ML on-device через Wav2Vec2RuChild 302 MB) |
| `generateNeurolinguistSummary` | onCall | **true** | Fixed-text summary stub (Vertex AI deferred post-v1.0) |
| `validateChildVoice` | onCall | **true** | Always returns isChildVoice=true (real verification on-device) |
| `analyzeSpeechProgress` | onCall | **true** | Neurolinguist trends stub (vs calculateProgress = aggregation) |
| `generateSpecialistReport` | onCall | **true** | PDF stub (downloadUrl=null, on-device via SpecialistExportService) |
| `createFamilyInviteToken` | onCall | **true** | Firestore-based invite tokens (replaces deprecated Dynamic Links) |

> **Note:** baseline функции имеют `enforceAppCheck: false` исторически (M1
> установил это до того как App Check был полностью enforce'd). Для миграции
> baseline к App Check enforce — см. backlog item.

---

## Деплой

```bash
# Только rules
firebase deploy --only firestore:rules --project happyspeech-dfd95

# Только indexes
firebase deploy --only firestore:indexes --project happyspeech-dfd95

# Только functions
firebase deploy --only functions --project happyspeech-dfd95

# Только Remote Config (включая v18 tutorial_variant)
firebase deploy --only remoteconfig --project happyspeech-dfd95

# Только Storage
firebase deploy --only storage --project happyspeech-dfd95

# Всё сразу
firebase deploy --project happyspeech-dfd95

# Dry-run (только синтаксис rules)
firebase deploy --only firestore:rules --dry-run --project happyspeech-dfd95
```

### Деплой только новых v18 функций

```bash
firebase deploy --only \
  functions:scoreSpeechQuality,\
functions:generateNeurolinguistSummary,\
functions:validateChildVoice,\
functions:analyzeSpeechProgress,\
functions:generateSpecialistReport,\
functions:createFamilyInviteToken \
  --project happyspeech-dfd95
```

---

## Realtime Database setup (Block U.6)

База создаётся через Console: Build → Realtime Database → Create Database
(region: `europe-west1`).

### Rules

```json
{
  "rules": {
    "shareplay_sessions": {
      "$sessionId": {
        ".read": "auth != null",
        ".write": "auth != null && (data.child('hostUid').val() == auth.uid || newData.child('hostUid').val() == auth.uid)"
      }
    }
  }
}
```

> Rules файл размещается отдельно от Firestore rules — у RTDB свой формат.
> При первом деплое RTDB через `firebase init database`.

---

## Family Invite tokens (Block U.4)

Заменяет deprecated Firebase Dynamic Links.

**Firestore схема:**
```
/family_invites/{token}     // primary key = 32-char hex token
  parentId: string          // owner uid (auth.uid)
  role: "secondary" | "observer"
  token: string             // duplicate of doc id
  shortCode: string         // 6-char base32, no ambiguous chars
  createdAt: serverTimestamp
  expiresAt: Timestamp      // TTL 1-168 hours
  consumed: boolean         // false → true after redemption
  consumedBy: string | null // redeemer uid
  consumedAt: serverTimestamp | null
```

**Universal Link format:**
```
https://happyspeech.mmf.bsu.app/invite?token=<hex>&code=<short>
```

**TODO для production deploy:**
1. Размещение `apple-app-site-association` файла на `https://happyspeech.mmf.bsu.app/.well-known/`
2. Associated Domains entitlement (`applinks:happyspeech.mmf.bsu.app`)
3. Firestore index на `family_invites` (`shortCode ASC, consumed ASC`) для быстрых short-code lookup'ов

---

## A/B Testing (Block U.5)

**Template parameters:**
- `tutorial_variant` (STRING, default "A", conditional "B" под `ab_tutorial_variant_b`)
- `tutorial_variant_rollout_percent` (NUMBER, default 50)

**Console activation** (через UI, не CLI):
1. Firebase Console → A/B Testing → Create experiment
2. Type: Remote Config
3. Targeting: User in random percentile (matches `ab_tutorial_variant_b` condition)
4. Activation event: `app_first_open`
5. Goal metric: `tutorial_completion_rate` (custom event, нужно реализовать)
6. Variant A: 50% control (use default value "A")
7. Variant B: 50% treatment (override `tutorial_variant` = "B")

> Custom event `tutorial_completion_rate` пока не реализован — нужно добавить
> аналитический emit в TutorialView после завершения.

---

## Customization Ляли (Plan v9 F2)

- Коллекция: `users/{uid}/customization/{document}`
- Схема документа: `skin`, `color`, `voice`, `updatedAt`
- Auth-guard: только аутентифицированный не-анонимный пользователь (`sign_in_provider != 'anonymous'`)
- Enum-валидация при write:
  - `skin`: `classic | princess | scientist | athlete | artist`
  - `color`: `warm | cool | nature`
  - `voice`: `classic | soft | cheerful`
- Индекс: не требуется (single document per user, без range queries)
- Cloud Function: не требуется на текущем этапе

Реализовано в `firestore.rules` v1.2 (2026-04-28).

---

## Версии rules

| Версия | Дата       | Изменения                                      |
|--------|------------|------------------------------------------------|
| 1.0    | 2026-04-22 | Базовые правила (M1, sprint backend-dev-infra) |
| 1.1    | 2026-04-22 | isAdmin custom claim, specialist consent, rewards, routes, weekly_reports, assignments, content packs, audits |
| 1.2    | 2026-04-28 | Customization Ляли — Plan v9 F2                |

---

## Версии Remote Config template

| Версия | Дата       | Изменения                                      |
|--------|------------|------------------------------------------------|
| 1      | 2026-04-28 | Initial — feature flags + UI/notifications     |
| 2      | 2026-05-04 | Block D v13 expansion (PhonemeAnalysis flags)  |
| 3      | 2026-05-08 | Block U.5 v18 — `tutorial_variant` A/B         |

---

## Emulator

```bash
firebase emulators:start --only firestore,functions --project happyspeech-dfd95
```

UI: http://localhost:4000

---

## Smoke-тест после деплоя

1. `firebase_get_security_rules` — правила совпадают с `firestore.rules`
2. `firestore_list_indexes` — все 14 индексов в статусе READY
3. `functions_list_functions` — 16 функций в `europe-west3`:
   - 10 baseline + 6 v18 callable (scoreSpeechQuality, generateNeurolinguistSummary,
     validateChildVoice, analyzeSpeechProgress, generateSpecialistReport,
     createFamilyInviteToken)
4. `firebase functions:log` — проверить логи без PII в payloads
5. Запустить `functions/seed.js` в окружении `dev`, убедиться что данные появились
6. Проверить Realtime Database: `https://happyspeech-dfd95-default-rtdb.europe-west1.firebasedatabase.app/.json`

---

## Deferred deploy items (см. ADR-V18-U-DEPLOY-DEFER если применимо)

- [ ] Realtime Database initial deploy через `firebase init database`
- [ ] App Universal Links infrastructure:
  - apple-app-site-association на `happyspeech.mmf.bsu.app/.well-known/`
  - Associated Domains entitlement в project.yml
- [ ] Firestore index `family_invites` (shortCode + consumed)
- [ ] Console A/B Testing experiment activation для `tutorial_variant`
- [ ] Custom event `tutorial_completion_rate` emit в TutorialView (для goal metric)
- [ ] Migration baseline Cloud Functions (M1.3) на `enforceAppCheck: true`
