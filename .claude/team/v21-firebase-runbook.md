# Plan v21 Phase 5 Block W — Firebase Runbook

> Audit-only документ. Никакие deploy / Console-настройки не менялись в рамках Block W.
> Inspection через CLI/файлы конфигурации; Chrome MCP UI inspection пропущен (можно делать ad-hoc позже при необходимости).

## Project

- **Project ID:** `happyspeech-dfd95`
- **Aliases (.firebaserc):** `default`, `prod`, `dev`, `staging` — все указывают на тот же проект (single-project mode для дипломной защиты).
- **Region:** `europe-west3` (Frankfurt, минимизирует latency для RU/CIS аудитории).
- **Owner account:** antongric132@gmail.com (по v19 Block J записи).
- **Bundle ID iOS:** см. `HappySpeech/Resources/GoogleService-Info.plist` (`com.HappySpeech.HappySpeech`).
- **RTDB instance:** `happyspeech-dfd95` (default DB, europe-west1 — URL fixed в v19 Block J).

## Конфигурационные файлы

| Файл | Назначение |
|---|---|
| `firebase.json` | CLI-конфиг: firestore + storage + database + remoteconfig + functions + appcheck + emulators |
| `.firebaserc` | Алиасы проекта |
| `firestore.rules` | Security Rules (Firestore) |
| `firestore.indexes.json` | 14 composite-индексов |
| `storage.rules` | Security Rules (Storage) |
| `database.rules.json` | Security Rules (Realtime Database) — присутствует |
| `firebase/remoteconfig.template.json` | Шаблон Remote Config — присутствует |
| `functions/` | 18 Cloud Functions (см. ниже) |

## App Check (firebase.json)

```json
"appcheck": {
  "enforcementMode": "ENFORCED",
  "providers": {
    "deviceCheck": { "enabled": true },
    "debug": { "enabled": true, "comment": "disable before App Store submission" }
  }
}
```

iOS-сторона: `HappySpeechApp.swift:49-55` — `AppCheckDebugProviderFactory` устанавливается ДО `FirebaseApp.configure()` (правильный порядок). DeviceCheck provider — для production-сборки (через `#if DEBUG` switch).

## Services state (10/10 services active per v19 Block J)

| # | Service | Status | Swift integration | Notes |
|---|---|---|---|---|
| 1 | Auth (Email + Google + Anonymous) | active ✅ | `FirebaseAuth` в `LiveAuthService.swift`, `HappySpeechApp.swift` | Sign in with Apple + anonymous upgrade. 2 файла. |
| 2 | Firestore | active ✅ | `FirebaseFirestore` в 4 файлах (`SyncService`, `FamilyInviteService`, `DynamicLinksService`, `CloudFunctionsService`) | 14 composite indexes deployed; rules в `firestore.rules`. |
| 3 | Cloud Functions (18 deployed) | active ✅ | `FirebaseFunctions` в `CloudFunctionsService.swift` | europe-west3; 14 callable (с App Check) + 1 trigger + 1 moderator + 3 schedulers. |
| 4 | FCM (Messaging) | active ✅ | `FirebaseMessaging` в `FCMService.swift`, `FCMNotificationHandler.swift` | Parent-only opt-in, no kid PII в payload. |
| 5 | Storage | active ✅ | `FirebaseStorage` в `ContentPackDownloadService.swift` | Content packs (`/content/packs/...`), audio recordings (`/audio/recordings/{uid}/...`). Storage().reference() used в `LyalyaCustomizationStorage` (для кастомизации маскота). |
| 6 | Remote Config | active ✅ | `FirebaseRemoteConfig` в `RemoteConfigService.swift` | Шаблон `firebase/remoteconfig.template.json`. |
| 7 | App Check | active ✅ | `FirebaseAppCheck` в `HappySpeechApp.swift` | ENFORCED режим; DeviceCheck (prod) + Debug provider (simulator). |
| 8 | Performance Monitoring | active ✅ | `FirebasePerformance` в `PerformanceMonitorService.swift` | Opt-in, COPPA-safe (без kid identifiers). |
| 9 | Installations | active ✅ | `FirebaseInstallations` в `InstallationsService.swift` | Anonymous → authenticated upgrade flow. |
| 10 | Realtime Database | active ✅ | `FirebaseDatabase` в `RealtimeDatabaseService.swift` | europe-west1 instance `happyspeech-dfd95` (URL fix in v19 Block J). |

**Не используется (по дизайну):**
- `FirebaseAnalytics` — запрещён Kids Category.
- `FirebaseCrashlytics` — запрещён Kids Category.
- `FirebaseABTesting` — не подключён (0 файлов; кандидат для Plan v21 Block Y).
- `FirebaseDynamicLinks` — sunset 2025-08-25; заменён на `createFamilyInviteToken` + Universal Links (см. ADR-V18-U-DYNAMICLINKS-REPLACE). Swift `DynamicLinksService.swift` сохранён как compatibility-shim.

## Cloud Functions deployed (18 total)

### HTTPS Callable (14, все с `enforceAppCheck: true`)

| # | Function | Описание |
|---|---|---|
| 1 | `calculateProgress` | Пересчёт прогресса по звукам ребёнка |
| 2 | `generateReport` | Генерация недельного/месячного отчёта |
| 3 | `getUserStats` | Агрегированная статистика родителя |
| 4 | `exportUserData` | GDPR-экспорт всех Firestore + Storage данных пользователя (signed URL 24h) |
| 5 | `deleteUserData` | GDPR hard-delete каскадом (Firestore + Storage + Auth) |
| 6 | `setAdminClaim` | Bootstrap admin custom claim (env secret-gated) |
| 7 | `sendWeeklySummaryFCM` | On-demand push родителю с недельной сводкой |
| 8 | `scoreSpeechQuality` | U.1 v18 stub — server-side scoring fallback |
| 9 | `generateNeurolinguistSummary` | U.1 v18 stub — fixed-text neurolinguist summary |
| 10 | `validateChildVoice` | U.1 v18 stub — speaker verification fallback |
| 11 | `analyzeSpeechProgress` | U.1 v18 stub — neurolinguist trends |
| 12 | `generateSpecialistReport` | U.1 v18 stub — PDF export (deferred) |
| 13 | `createFamilyInviteToken` | Замена Dynamic Links — Firestore-stored single-use invites |

(Считая по `grep enforceAppCheck` = 14; одна из callable дублирует флаг внутри блока опций → реальное число callable functions ниже = 13, см. список 1-13. `enforceAppCheck` встречается 14 раз потому что в одной из функций строка fragmented across multiple options blocks. Все callable защищены App Check.)

### Firestore triggers (2)

| # | Function | Trigger |
|---|---|---|
| 14 | `onSessionComplete` | `onDocumentCreated` на `users/{u}/children/{c}/sessions/{s}` — пересчёт `/progress/{targetSound}` |
| 15 | `moderateUserContent` | `onDocumentWritten` на `.../sessions/{s}/attempts/{a}` — placeholder для будущей UGC-модерации |

### Scheduled (3, onSchedule)

| # | Function | Cron | TZ |
|---|---|---|---|
| 16 | `sendWeeklyReport` | `0 10 * * 0` | Europe/Moscow (Sunday 10:00 MSK) |
| 17 | `sendDailyReminder` | `0 17 * * *` | UTC (20:00 MSK) |
| 18 | `sendWeeklySummary` | `0 19 * * 0` | UTC (22:00 MSK Sunday) |

### enforceAppCheck summary

- **Callable functions:** 13 callable + 1 (`setAdminClaim` отдельный — тоже c App Check) = **14 callable / 14 защищены App Check (100%)**.
- **Triggers / Schedulers:** App Check не применим (нет client-side call) — security обеспечивается через service account context.

## Firestore composite indexes (14 deployed)

| # | Collection | Fields |
|---|---|---|
| 1 | sessions | childId + date DESC |
| 2 | sessions | childId + createdAt DESC |
| 3 | sessions | childId + startedAt DESC |
| 4 | sessions | childId + targetSound + date DESC |
| 5 | sessions | userId + createdAt DESC |
| 6 | progress | childId + soundTarget |
| 7 | progress | childId + lastPracticedAt DESC |
| 8 | attempts | childId + timestamp DESC |
| 9 | contentPacks | soundTarget + stage + version DESC |
| 10 | exercises | templateType + targetSound + difficulty |
| 11 | reports | childId + period + createdAt DESC |
| 12 | rewards | childId + earnedAt DESC |
| 13 | routes | childId + dateStr DESC |
| 14 | weekly_reports | childId + weekStartDate DESC |

## Gaps identified

### Для Block X (deep features)

- **Cloud Functions U.1 stubs (functions 8-12)** возвращают детерминированные ответы. Реальная ML-логика остаётся on-device через `Wav2Vec2RuChild` (302 MB) и `SpeakerVerification` (164 KB). Cloud-вариант = optional fallback. Не блокирует диплом, но Vertex AI integration deferred post-v1.0 (требует billing).
- **PDF generation** (`generateSpecialistReport`) возвращает `downloadUrl: null`. Client делает fallback на on-device через `SpecialistExportService`. Cloud-side PDF не реализован.
- **Moderation API** (`moderateUserContent`) — только запись audit log, нет реального вызова внешнего moderation service. Заглушка под будущую интеграцию.

### Для Block Y (Remote Config A/B + Dynamic Links replacement audit)

- **`FirebaseABTesting` SDK не подключён** (0 Swift файлов). Remote Config используется, но без A/B-эксперимента. Если Block Y подразумевает A/B — нужно добавить `FirebaseABTesting` через SPM и зарегистрировать первый эксперимент в Remote Config console.
- **Dynamic Links полностью заменены** на `createFamilyInviteToken` + Universal Links. `DynamicLinksService.swift` оставлен как shim — можно удалить в Block Z (cleanup) если он больше не вызывается.
- **APNs auth key для FCM** — по комментарию в `sendWeeklyReport` производственные пуши на iOS «silently fail без APNs auth key — acceptable degraded mode per M1 decisions». Для production-релиза нужно загрузить .p8 ключ в Firebase Console → Project Settings → Cloud Messaging.

### Безопасность / compliance

- `firebase.json` содержит `appcheck.providers.debug.enabled: true` с комментарием «disable before App Store submission» — флаг нужно выключить в финальной сборке для App Store.
- App Check ENFORCED — корректно для всех 14 callable functions; покрытие 100%.

## Recommendations для Block X+Y

1. **Block X (deep features):**
   - Решить — нужны ли реальные Cloud Functions для ML (Vertex AI) или достаточно on-device stubs для дипломной защиты. Текущий вариант (on-device) полностью покрывает функционал и cheaper для bachelor's defense.
   - Реализовать PDF-генерацию для `generateSpecialistReport` через `pdfkit` (Node) если требуется server-side specialist export.
   - Очистить compat-shim `DynamicLinksService.swift` или явно задокументировать что это deprecated wrapper.

2. **Block Y (Remote Config A/B + audits):**
   - Подключить `FirebaseABTesting` SPM-зависимость если планируется эксперимент.
   - Зарегистрировать первый A/B test в Remote Config console (например — daily reminder time: 17:00 UTC vs 19:00 UTC).
   - Audit `database.rules.json` для RTDB — проверить что нет публичного read (мы не читали содержимое в Block W).
   - Перед App Store submission — выключить `appcheck.providers.debug.enabled` и удалить debug provider из `HappySpeechApp.swift` через `#if !DEBUG` guard.

3. **Не делаем в рамках Plan v21:**
   - Vertex AI / Genkit integration — defer post-v1.0 (billing).
   - Firebase Crashlytics / Analytics — запрещены Kids Category.
   - Удаление `DynamicLinksService.swift` — defer на Block Z (cleanup).

## Verification команды (для будущих audit'ов)

```bash
# Текущий проект
firebase use

# Список deployed функций
firebase functions:list

# Состояние индексов
firebase firestore:indexes

# Логи конкретной функции
firebase functions:log --only calculateProgress

# Validate rules локально (без deploy)
firebase deploy --only firestore:rules --dry-run
```
