# Firebase Production Runbook

Пошаговое развёртывание production-инфраструктуры HappySpeech в Firebase.

> **Режим HappySpeech:** Firebase используется как синхронизация user-данных (маленький трафик) + one-time download больших ассетов. НЕ ежедневный CDN. Аналитика Google **отключена** (Kids Category + COPPA).

## 0. Предусловия

- Установлен Firebase CLI: `npm -g install firebase-tools@latest` (≥ 13.x)
- Установлен `node` 20+ и `npm` 10+
- Сделан `firebase login` (учётка с ролью Owner на проекте)
- `GoogleService-Info.plist` от прод-проекта лежит в `HappySpeech/Resources/` и НЕ закоммичен
- Region: `europe-west1` (EU data locality для российской/европейской аудитории)

## 1. Firestore: rules + indexes

```bash
# Валидация rules (локально через CLI / через Firebase MCP)
firebase firestore:rules:validate firestore.rules

# Деплой rules
firebase deploy --only firestore:rules

# Деплой indexes (14 composite)
firebase deploy --only firestore:indexes
```

Актуальная схема `firestore.indexes.json`:

| Collection | Fields (desc/asc) |
|---|---|
| `users/{uid}/children/{cid}/sessions` | `startedAt desc`, `duration asc` |
| `users/{uid}/children/{cid}/progress` | `soundId asc`, `lastPracticedAt desc` |
| `users/{uid}/children/{cid}/routes` | `dateStr desc` |
| `users/{uid}/children/{cid}/rewards` | `earnedAt desc`, `type asc` |
| `specialists/{uid}/assignments` | `childId asc`, `createdAt desc` |
| `content/packs` | `version asc`, `sound asc` |

(+ 8 индексов по специфике Cloud Functions — см. `firestore.indexes.json`)

## 2. Storage: rules

```bash
firebase deploy --only storage:rules
```

Структура бакета `gs://happyspeech.appspot.com/`:

```
/audio/
  ui/*.caf                   # UI sounds, public read
  lyalya/*.m4a               # Voice brand, public read
  content/{sound}/{id}.m4a   # Озвучка 6000+ единиц, public read
  refs/{sound}/{word}.m4a    # Эталоны для scorer, public read
/models/
  whisperkit/*.zip           # On-demand, public read
  llm/qwen-1.5b-4bit.mlx     # On-demand, public read (App Check required)
  llm/qwen-3b-4bit.mlx       # On-demand, public read (App Check required)
/illustrations/{category}/*.png  # Иллюстрации уроков, public read
/3d/lyalya.usdz              # 3D маскот, public read
/animations/
  rive/*.riv                 # Rive state-machine, public read
  lottie/*.json              # Lottie, public read
/exports/{uid}/*.pdf         # User-generated отчёты, ТОЛЬКО владелец
```

Правила (`storage.rules`):
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /audio/{allPaths=**}          { allow read: if true; }
    match /illustrations/{allPaths=**}  { allow read: if true; }
    match /3d/{allPaths=**}             { allow read: if true; }
    match /animations/{allPaths=**}     { allow read: if true; }
    match /models/whisperkit/{allPaths=**} { allow read: if true; }
    match /models/llm/{allPaths=**}     { allow read: if request.app_check != null; }
    match /exports/{uid}/{file}         { allow read, write: if request.auth.uid == uid; }
  }
}
```

## 3. Cloud Functions (v2, Node 20)

```bash
cd functions
npm ci
npm run lint
npm run build
firebase deploy --only functions
```

Функции:

| Имя | Trigger | Описание |
|---|---|---|
| `calculateProgress` | onCreate `sessions/{sid}` | Агрегат per-sound progress |
| `onSessionComplete` | onUpdate `sessions/{sid}` с `isComplete=true` | Streak + reward + planner update |
| `generateReport` | callable | PDF отчёт для родителя/специалиста |
| `getUserStats` | callable | Сводная аналитика (last 30 days) |
| `sendWeeklyReport` | scheduled (`every sunday 18:00 Europe/Moscow`) | Недельный push + email |
| `moderateUserContent` | callable | Модерация user-upload (редко нужен) |
| `exportUserData` | callable | GDPR — экспорт всех данных юзера |
| `deleteUserData` | callable | GDPR — каскадное удаление |
| `setAdminClaim` | callable (admin only) | Role management |

## 4. Authentication

Включить провайдеры в `Firebase Console → Authentication`:

- ✅ **Email/Password** (с email verification)
- ✅ **Google Sign-in** (OAuth client ID в `GoogleService-Info.plist`)
- ❌ Apple Sign-in — **НЕ используется** (нет Apple Developer Account)
- ✅ **Anonymous** — для демо-режима + later link в Email/Google

Authorized domains: `happyspeech.firebaseapp.com` + `localhost` (для emulator).

## 5. App Check

```bash
# Включить enforcement в Console → App Check
#   - Firestore: Enforce
#   - Storage:   Enforce для /models/llm/**
#   - Functions: Enforce для всех callable
```

iOS side: `AppCheckProviderFactory` с `DeviceCheckProvider` в `AppDelegate.didFinishLaunching` (уже сконфигурирован в `HappySpeech/App/FirebaseBootstrap.swift`).

## 6. Remote Config

Ключи:

| Ключ | Тип | Default | Назначение |
|---|---|---|---|
| `enable_llm_tier_b` | bool | false | Включить Qwen 3B для adult (opt-in) |
| `content_pack_version` | string | "1.0.0" | Форсить обновление паков |
| `whisperkit_model` | string | "tiny" | tiny / base / small |
| `min_app_version` | string | "1.0.0" | Hard-force update |

## 7. Валидация после деплоя

```bash
# Проверить Firestore rules через emulator
firebase emulators:exec --only firestore "cd functions && npm test"

# Проверить что функции доступны
firebase functions:list

# Логи последних вызовов
firebase functions:log --only calculateProgress -n 20

# Storage — доступность sample object
gsutil stat gs://happyspeech.appspot.com/audio/ui/tap.caf
```

## 8. Откат релиза

```bash
# Найти предыдущий релиз Functions
firebase functions:list --include-versioned

# Откат одной функции
firebase functions:rollback --codebase default --function calculateProgress

# Откат rules (держим 2 прошлых версии в git)
git checkout HEAD~1 firestore.rules storage.rules
firebase deploy --only firestore:rules,storage:rules
```

## 9. Мониторинг

- Firebase Console → Functions → Health (latency, error rate, cold starts)
- Firebase Console → Firestore → Usage (reads/writes/deletes)
- Firebase Console → Storage → Usage (bandwidth)
- `Crashlytics` **не используется** (Kids Category + privacy). Вместо него — on-device `OSLog` + локальная аналитика.

## 10. Быстрая команда-развёртывание всего

```bash
firebase deploy \
  --only firestore:rules,firestore:indexes,storage:rules,functions \
  --project happyspeech-prod
```

Ожидаемое время: ~2–3 минуты (rules/indexes быстро, functions до 2 мин если build с нуля).

---

**Контактное лицо за runtime:** владелец проекта (`antongrits`).
**Инцидент-response:** см. `.claude/team/decisions.md § Incident response`.
