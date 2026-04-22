# Backend M1 Report

**Дата:** 2026-04-23
**Агент:** backend-developer
**Статус:** код готов, deploy ожидает выполнения

---

## Что сделано

### 1. Firestore Rules — `firestore.rules` v1.1
- `isAdmin()` читает custom claim `request.auth.token.admin == true` (primary), с fallback на `users/{uid}.role == 'admin'`
- Новый helper `isOwnerParent(userId, childId)` — specialist читает child только если linked И родитель дал согласие (`consent.specialistRead == true`)
- Добавлены коллекции: `/users/{u}/children/{c}/rewards/{id}`, `/routes/{dateStr}`, `/weekly_reports/{dateStr}`, `/specialists/{s}/assignments/{id}`, `/audits/{id}`, `/content/packs/{packId}`, `/content/manifest`
- Default deny в конце

### 2. Firestore Indexes — `firestore.indexes.json`
14 композитных индексов:
- `sessions.startedAt` (DESC) by childId
- `progress.lastPracticedAt` (DESC) by childId
- `rewards.earnedAt` (DESC) by childId
- `routes.dateStr` (DESC) by childId
- `weekly_reports.weekStartDate` (DESC) by childId
- + другие для specialists assignments, audits

### 3. Storage Rules — `storage.rules` v1.1
- `isAdmin()` через custom claim + fallback
- Пути: `/audio/{ui,lyalya,content,refs}`, `/illustrations`, `/3d`, `/animations`, `/models`, `/exports/{uid}`, `/uploads/users/{uid}/**`
- COPPA-политика `/users/{uid}/children/{cid}/recordings/**` — parent-only, audio <20MB
- mime + size validation

### 4. Cloud Functions — регион `europe-west1`, Node 20

**Существующие 4 функции сохранены** (регион изменён с `europe-west3` на `europe-west1`, `enforceAppCheck` снято до появления DeviceCheck):
- `calculateProgress` (HTTPS callable)
- `generateReport` (HTTPS callable)
- `getUserStats` (HTTPS callable)
- `onSessionComplete` (Firestore trigger)

**Новые 5:**
- `sendWeeklyReport` — scheduled `0 10 * * 0` Europe/Moscow. Cascade по всем parent → child → `buildReport('week')` → `/weekly_reports/{dateStr}`. FCM push attempt в degraded mode (silent fail без APNs — ok)
- `exportUserData` — GDPR JSON-экспорт всего дерева пользователя (+ Storage listing) в `gs://<bucket>/users/{uid}/exports/<ts>.json` + signed URL 24h + audit
- `deleteUserData` — hard cascade delete через `firestore.recursiveDelete` + Storage (`users/`, `exports/`, `uploads/users/`) + `auth().deleteUser()` + audit. Требует `confirm: "DELETE"`
- `moderateUserContent` — Firestore trigger on `attempts/{id}`, audit-лог. Placeholder для будущей moderation API
- `setAdminClaim` — bootstrap placeholder: env-secret `ADMIN_BOOTSTRAP_SECRET` или уже-admin caller

### 5. `functions/package.json`
- `firebase-functions` поднят до `^5.0.0` (нужно для `onSchedule` v2)
- Добавлен `uuid ^9.0.1`

### 6. `GoogleService-Info.plist`
Создан placeholder с правильными:
- `BUNDLE_ID=ru.happyspeech.app`
- `PROJECT_ID=happyspeech-prod`
- `STORAGE_BUCKET=happyspeech-prod.appspot.com`

`API_KEY / GOOGLE_APP_ID / GCM_SENDER_ID / CLIENT_ID / REVERSED_CLIENT_ID` — placeholder `REPLACE_WITH_...`. Файл в `.gitignore`.

---

## Что НЕ удалось сделать в сессии (blockers)

**B1 — критичный:** в Claude Code сессии не было ни MCP `mcp__firebase__*` tools, ни разрешения на `firebase` CLI в Bash (sandbox denial). Значит не выполнено:
- создание/валидация Firebase проекта через API
- enable Auth providers
- получение реального `GoogleService-Info.plist` через `firebase_get_sdk_config`
- `firebase deploy`
- `firebase firestore:rules:release --dry-run`
- `node --check`, `npm install`

**B2** — APNs auth key и DeviceCheck требуют Apple Developer Account (не существует). `sendWeeklyReport` работает в degraded mode (только Firestore), App Check в debug-only.

---

## Ручной деплой (5 команд, после замены plist)

```bash
cd /Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech
firebase login
firebase use default
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
firebase deploy --only functions
```

Ожидаемые 9 функций после деплоя: `calculateProgress`, `generateReport`, `getUserStats`, `exportUserData`, `deleteUserData`, `setAdminClaim`, `moderateUserContent`, `onSessionComplete`, `sendWeeklyReport` — все в `europe-west1`.

---

## Файлы (абсолютные пути)

### Изменены
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules`
- `functions/index.js`
- `functions/package.json`

### Созданы
- `functions/src/weeklyReport.js`
- `functions/src/export.js`
- `functions/src/delete.js`
- `functions/src/moderation.js`
- `functions/src/admin.js`
- `HappySpeech/Resources/GoogleService-Info.plist` (placeholder, в `.gitignore`)

---

## Verify checklist

- Firestore rules синтаксис (визуальный review): ✅ default deny в конце, все helpers определены, hasFields/isValidString/isValidTimestamp применены на create
- Storage rules синтаксис (визуальный review): ✅ каждый путь с owner/admin разграничением, mime+size validation
- `firestore.indexes.json` валидный JSON: ✅ 14 индексов
- `functions/index.js` импорты ↔ экспорты: ✅ проверено Grep-ом
- Все callable с input validation + `HttpsError`: ✅ никаких raw exception.messages наружу
- Все триггеры никогда не throw: ✅ только logger.error
- Apple Sign-In в коде функций отсутствует: ✅ Grep не нашёл
- Bundle ID совпадает с `project.yml`: ✅ `ru.happyspeech.app`
- Регион `europe-west1` во всех функциях: ✅
- `.gitignore` защищает `GoogleService-Info.plist`: ✅

---

*Report by backend-developer, 2026-04-23*
