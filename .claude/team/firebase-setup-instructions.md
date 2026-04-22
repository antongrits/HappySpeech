# Firebase Setup Instructions

**Дата:** 2026-04-23
**Для:** разработчика (ручные действия после автоматической генерации backend-кода)

Claude Code backend-developer агент автоматически сгенерировал весь Firebase backend код (rules, functions, indexes), но финальный deploy и получение реального `GoogleService-Info.plist` требуют ручных действий пользователя через Firebase Console или CLI (из-за sandbox restrictions в текущей сессии).

---

## 1. Firebase Console setup (одноразово, ~5 мин)

### 1.1. Убедиться что проект `happyspeech-prod` существует
- Открыть https://console.firebase.google.com
- Проверить наличие проекта `happyspeech-prod`
- Если нет — создать через консоль (или `firebase projects:create happyspeech-prod`)

### 1.2. Enable Authentication providers
- Firebase Console → Authentication → Sign-in method
- Enable: **Email/Password** (обязательно)
- Enable: **Email verification** (опционально, но recommended)
- Enable: **Google** (set authorized domains)
- DO NOT enable: Apple (нет Apple Developer Account)

### 1.3. Add iOS App
- Firebase Console → Project Settings → Add app → iOS
- Bundle ID: `ru.happyspeech.app` (см. `project.yml`)
- App nickname: `HappySpeech iOS`
- App Store ID: skip (нет Apple Dev)
- Download `GoogleService-Info.plist`
- **Заменить** placeholder по пути:
  `/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech/HappySpeech/Resources/GoogleService-Info.plist`
- Файл в `.gitignore`, не коммитится

---

## 2. Local CLI setup

```bash
# Установить firebase-tools (если ещё нет)
npm install -g firebase-tools

# Логин через браузер
firebase login

# Выбрать проект
cd /Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech
firebase use default  # должен быть happyspeech-prod из .firebaserc
```

---

## 3. Deploy (5 команд)

```bash
cd /Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech

# Установить зависимости для functions
cd functions && npm install && cd ..

# Validate rules и indexes (dry-run)
firebase deploy --only firestore:rules --dry-run
firebase deploy --only storage:rules --dry-run

# Deploy поэтапно (поэтапно, чтобы на падении одного шага остальные применились)
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage:rules
firebase deploy --only functions
```

**Ожидаемые 9 Cloud Functions после деплоя (регион `europe-west1`):**
1. `calculateProgress` (HTTPS callable)
2. `generateReport` (HTTPS callable)
3. `getUserStats` (HTTPS callable)
4. `exportUserData` (HTTPS callable, GDPR)
5. `deleteUserData` (HTTPS callable, GDPR hard cascade)
6. `setAdminClaim` (HTTPS callable, bootstrap)
7. `moderateUserContent` (Firestore trigger)
8. `onSessionComplete` (Firestore trigger)
9. `sendWeeklyReport` (scheduled cron 0 10 * * 0 Europe/Moscow)

---

## 4. Verify

После деплоя проверить:
- Rules активны: Firebase Console → Firestore → Rules (совпадают с локальным `firestore.rules`)
- Storage Rules: Firebase Console → Storage → Rules
- Functions: Firebase Console → Functions (9 функций, все healthy, regio europe-west1)
- Indexes: Firebase Console → Firestore → Indexes (14 composite)

---

## 5. Что работает сразу после deploy

- ✅ Email+Password auth (iOS клиент уже готов или в работе ios-developer агента)
- ✅ Google Sign-in (после добавления authorized domains)
- ✅ Firestore sync (Realm ↔ Firestore через SyncService)
- ✅ Storage для content packs и audio
- ✅ Cloud Functions: progress calc, reports, GDPR exports/deletes
- ✅ Scheduled weekly report (запустится в ближайшее воскресенье 10:00 MSK)

## 6. Что НЕ работает (требует Apple Developer Account)

- ❌ APNs push notifications на iOS (FCM attempt будет silent fail)
- ❌ App Check через DeviceCheck (debug token только для dev)
- ❌ TestFlight / App Store submission

Для получения этих возможностей нужно оформить Apple Developer Program ($99/год). Пока используется degraded mode: local notifications через `UNUserNotificationCenter` + in-app weekly report badge из Firestore.

---

## 7. Smoke test после deploy

```bash
# Вызвать callable function (из терминала через curl или через iOS приложение)
curl -X POST https://europe-west1-happyspeech-prod.cloudfunctions.net/getUserStats \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FIREBASE_AUTH_TOKEN" \
  -d '{"data": {}}'

# Expected: { "result": { "totalSessions": 0, ... } }
```

Или через Firebase Emulator Suite (локальный тест без деплоя):
```bash
firebase emulators:start --only auth,firestore,storage,functions
# → Emulator UI: http://localhost:4000
```

---

*Если что-то сломалось — откатиться можно через Firebase Console → Rules history или `firebase firestore:rules:get` для diff.*
