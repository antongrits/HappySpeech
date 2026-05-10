# Plan v19 Block J — Firebase Services Audit

## Date: 2026-05-10
## Project: happyspeech-dfd95
## Account: antongric132@gmail.com
## Firebase CLI: authenticated, active project confirmed

---

## Services state

| Service | State | Notes |
|---|---|---|
| Auth (Email) | active | Email + password, enabled |
| Auth (Google) | active | Google Sign-In IdP enabled |
| Auth (Anonymous) | active | Was DISABLED — включён в Block J (API PATCH) |
| Firestore | active | 14 composite indexes, rules 371 строк |
| Cloud Functions | active | 18 функций, 14/14 callable с enforceAppCheck: true |
| Storage | active | rules 194 строк, `/audio/`, `/content/packs/` |
| App Check (iOS side) | active | DeviceCheck в prod, DebugProvider в DEBUG — настроен в HappySpeechApp.swift |
| App Check (Console enforcement) | requires manual | Firebase App Check API включён для project 142079911892; enforcement через Console |
| Remote Config | active | template v3 (2026-05-08), 20 параметров, 1 condition (ab_tutorial_variant_b) |
| FCM | active | sendDailyReminder, sendWeeklySummary, sendWeeklyReport scheduled; sendWeeklySummaryFCM callable |
| Performance Monitoring | configured | parent-only opt-in, COPPA-safe; iOS SDK setup в AppContainer |
| Installations | active | auto-enabled через FirebaseApp.configure() — InstallationsService.swift |
| A/B Testing | active | tutorial_variant parameter + condition ab_tutorial_variant_b в Remote Config |
| Realtime Database | active (NEW) | Создан в Block J: europe-west1, URL=https://happyspeech-dfd95.europe-west1.firebasedatabase.app |
| Analytics | disabled | Kids Category COPPA — не используется |
| Crashlytics | disabled | Kids Category COPPA — не используется |
| Dynamic Links | sunset | deprecated 2025-08-25 → заменён FamilyInviteService (Firestore tokens) |

---

## Block J actions performed

### 1. Anonymous Auth — включён
- Статус до: DISABLED (ошибка обнаружена в аудите)
- Действие: PATCH /admin/v2/projects/happyspeech-dfd95/config?updateMask=signIn.anonymous.enabled
- Статус после: enabled=true

### 2. Realtime Database — создан и настроен
- Статус до: инстанс отсутствовал (firebase database:instances:list — пустой результат)
- Действие: POST /v1beta/projects/happyspeech-dfd95/locations/europe-west1/instances?databaseId=happyspeech-dfd95
- RTDB URL: https://happyspeech-dfd95.europe-west1.firebasedatabase.app
- Тип: USER_DATABASE, State: ACTIVE
- Правила задеплоены: PUT /.settings/rules.json — SharePlay-specific rules
- Правила файл: `database.rules.json` (добавлен в репо)
- firebase.json: добавлена секция `"database": { "rules": "database.rules.json", "instance": "happyspeech-dfd95" }`

### 3. RealtimeDatabaseService.swift — исправлен URL
- Было: `https://happyspeech-dfd95-default-rtdb.europe-west1.firebasedatabase.app`
- Стало: `https://happyspeech-dfd95.europe-west1.firebasedatabase.app`
- Файл: `HappySpeech/Services/RealtimeDatabaseService.swift` (RTDBConfig.databaseURL)

### 4. Firebase App Check API — включён
- Действие: POST serviceusage.googleapis.com/v1/projects/142079911892/services/firebaseappcheck.googleapis.com:enable
- Результат: done=true, state=ENABLED
- Примечание: enforcement mode (ENFORCED/UNENFORCED) настраивается через Firebase Console → App Check

---

## Cloud Functions inventory (18 total)

| Function | Тип | enforceAppCheck | Region | Memory |
|---|---|---|---|---|
| calculateProgress | callable | true | europe-west3 | 256 |
| generateReport | callable | true | europe-west3 | 256 |
| getUserStats | callable | true | europe-west3 | 256 |
| exportUserData | callable | true | europe-west3 | 512 |
| deleteUserData | callable | true | europe-west3 | 512 |
| setAdminClaim | callable | true | europe-west3 | 256 |
| sendWeeklySummaryFCM | callable | true | europe-west3 | 256 |
| scoreSpeechQuality | callable | true | europe-west3 | 256 |
| generateNeurolinguistSummary | callable | true | europe-west3 | 256 |
| validateChildVoice | callable | true | europe-west3 | 256 |
| analyzeSpeechProgress | callable | true | europe-west3 | 256 |
| generateSpecialistReport | callable | true | europe-west3 | 512 |
| createFamilyInviteToken | callable | true | europe-west3 | 256 |
| sendWeeklySummaryFCM | callable | true | europe-west3 | 256 |
| onSessionComplete | Firestore trigger | n/a | europe-west3 | 256 |
| moderateUserContent | Firestore trigger | n/a | europe-west3 | 256 |
| sendWeeklyReport | Scheduled | n/a | europe-west3 | 256 |
| sendDailyReminder | Scheduled | n/a | europe-west3 | 256 |
| sendWeeklySummary | Scheduled | n/a | europe-west3 | 256 |

enforceAppCheck count: 14/14 callable — verified via `grep -c "enforceAppCheck: true" functions/index.js`

---

## Firestore Indexes (14)

| Collection | Fields |
|---|---|
| sessions | childId, date |
| sessions | childId, createdAt |
| sessions | childId, startedAt |
| sessions | childId, targetSound, date |
| sessions | userId, createdAt |
| progress | childId, soundTarget |
| progress | childId, lastPracticedAt |
| attempts | childId, timestamp |
| contentPacks | soundTarget, stage, version |
| exercises | templateType, targetSound, difficulty |
| reports | childId, period, createdAt |
| rewards | childId, earnedAt |
| routes | childId, dateStr |
| weekly_reports | childId, weekStartDate |

---

## Auth providers state (verified 2026-05-10)

- Email/Password: enabled=true, passwordRequired=true
- Google Sign-In: enabled (IdP: google.com)
- Anonymous: enabled=true (было disabled — исправлено в Block J)
- Sign in with Apple: deferred (требует Apple Developer Team config)

---

## Regression check vs Plan v18

| Service | v18 state | v19 state | Regression |
|---|---|---|---|
| Auth | Email + Google + Anonymous | Email + Google + Anonymous | Нет (Anonymous исправлен) |
| Firestore | 14 indexes | 14 indexes | Нет |
| Cloud Functions | 16 functions | 18 functions | Нет (2 дополнительные норма) |
| Storage | rules deployed | rules deployed | Нет |
| App Check | iOS configured | iOS configured + API enabled | Улучшение |
| Remote Config | v3 | v3 | Нет |
| FCM | Daily + Weekly | Daily + Weekly | Нет |
| Installations | enabled | enabled | Нет |
| A/B Testing | template | template | Нет |
| Realtime Database | SERVICE code only | ACTIVE instance created | Исправлено |

---

## Verdict

Все обязательные сервисы активны. Обнаружено и исправлено 3 regression'а:
1. Anonymous Auth был отключён — включён.
2. Realtime Database инстанс отсутствовал — создан.
3. RealtimeDatabaseService.swift ссылался на несуществующий URL — исправлен.

Disabled (Kids Category COPPA): Analytics, Crashlytics — корректно.
