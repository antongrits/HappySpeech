# HappySpeech

> Русскоязычное логопедическое iOS-приложение для детей 5–8 лет.
> 6000+ уроков, on-device ASR + pronunciation scoring, AR-артикуляция, адаптивный планировщик SM-2.
> Offline-first, child-safe, без сторонних трекеров, без платных API для пользователя.

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)](#)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](#лицензия)
[![Kids Category](https://img.shields.io/badge/App%20Store-Kids%20Category-ff69b4)](#этичность-и-границы)

---

## Что это

HappySpeech — логопедический «дом на планшете» для ребёнка 5–8 лет.
Маскот **Ляля** ведёт детей через упражнения, адаптивный планировщик подбирает
уроки на сегодня с учётом прогресса и усталости, а родитель и специалист
видят понятную аналитику.

Три контура в одном приложении:

- 👶 **Детский** — тёплый, игровой, минимум текста, 2D-маскот + AR.
- 👨‍👩‍👧 **Родительский** — сводки за день/неделю/месяц, советы логопедов.
- 🎓 **Специалистский** — конструктор программ, ручная оценка попыток, PDF-экспорт.

---

## Ключевые возможности

| Блок | Детали |
|---|---|
| Контент | 20 content-паков (свистящие, шипящие, соноры, заднеязычные, Й, дифференциация, артикуляционная гимнастика, дыхание, фонематический слух, нарратив, лексика), 4 664+ единиц |
| Игровые шаблоны | 16 шаблонов VIP (ListenAndChoose, RepeatAfterModel, MinimalPairs, DragAndMatch, Memory, Bingo, Breathing, Rhythm, Sorting, PuzzleReveal, SoundHunter, NarrativeQuest, VisualAcoustic, StoryCompletion, ArticulationImitation, ARActivity) |
| ASR + scoring | WhisperKit tiny (on-device) + PronunciationScorer (Core ML, 4 группы звуков) + Silero VAD |
| LLM | Qwen2.5-1.5B через MLX Swift (детский контур) + Qwen2.5-3B (взрослый, по запросу) + rule-based fallback. 25+ decision points |
| AR | ARKit Face Tracking (52 blendshapes) + Apple Vision (76 точек) + MediaPipe Face Mesh Core ML (478 точек) + кастомный TonguePostureClassifier (11 поз) |
| Адаптивный движок | SM-2 spaced repetition, адаптированный для детей (cap 14 дней, fatigue detection, `needsSpecialistReview` ниже EF 1.5) |
| Offline | Realm — source of truth. Firebase sync только для user-данных (Firestore) + one-time content packs (Storage). После первого download приложение работает полностью offline. |
| Доступность | WCAG AA, Dynamic Type Small → AccessibilityLarge, VoiceOver, Reduced Motion, Light / Dark, iPhone SE 3 gen → iPhone 17 Pro |
| Интерактивный туториал | 11-шаговый GuidedTour с spotlight + Lyalya voice-over + авто-advance |

---

## Быстрый старт

```bash
# 1. Инструменты (один раз)
brew install xcodegen swiftlint firebase-cli
npm -g install firebase-tools@latest

# 2. Клонировать и открыть
git clone https://github.com/antongrits/HappySpeech.git
cd HappySpeech
xcodegen generate
open HappySpeech.xcodeproj

# 3. Выбрать симулятор iPhone 17 Pro или iPhone SE (3 gen), нажать ▶︎
```

**Требования:** Xcode 16+, iOS 17 SDK, macOS 15 Sequoia+ (для Apple Silicon MLX runtime).

### Запуск на реальном устройстве (без Apple Developer Account)

1. Подключить iPhone, включить Developer Mode в `Settings → Privacy & Security`.
2. В Xcode: `Signing & Capabilities → Team → Personal Team`.
3. Выбрать устройство в schemes picker, нажать ▶︎. Работает 7 дней на Personal provisioning.

---

## Архитектура

```
┌───────────────────────────────────────────────────────────────────┐
│                         Features (Clean Swift VIP)                 │
│  ChildHome · ParentHome · Auth · Onboarding · Demo · GuidedTour   │
│  LessonPlayer(16) · SessionShell · AR(8) · Specialist · Settings   │
└─────────────────────────┬─────────────────────────────────────────┘
                          │ protocols (DI через AppContainer)
┌─────────────────────────▼─────────────────────────────────────────┐
│   Services    │   ML       │   Data       │   Sync      │ Content │
│   Audio/ASR   │  Whisper   │  RealmActor  │  SyncQueue  │ Engine  │
│   Haptic      │  MLX LLM   │  Repositories│  Firestore  │ Packs   │
│   Adaptive    │  Scorer    │  Migrations  │  Storage    │ Matrix  │
│   Auth/Sync   │  VAD       │              │  App Check  │ (6000+) │
└───────────────┴────────────┴──────────────┴─────────────┴─────────┘
                          │
┌─────────────────────────▼─────────────────────────────────────────┐
│                         DesignSystem                               │
│   Tokens (Color/Typo/Spacing/Radius/Motion) · 21 компонент        │
│   HSButton · HSCard · HSPictTile · HSSpeechBubble · HSMascotView  │
└───────────────────────────────────────────────────────────────────┘
```

**Принципы:**

- Clean Swift VIP обязателен для каждого экрана (View / Interactor / Presenter / Router / Models / Workers).
- DI через `AppContainer`, factory closures, никаких синглтонов.
- Swift 6 strict concurrency везде, `@Observable` iOS 17+, `@MainActor` для UI-логики.
- Никаких `print` — только `OSLog` через `Logger(subsystem: "ru.happyspeech", category: ...)`.
- Никаких dev-текстов в UI — все строки через String Catalog.

Подробнее — [CLAUDE.md](CLAUDE.md).

---

## ML-слой

| Модель | Размер | Источник |
|---|---|---|
| WhisperKit tiny (RU) | ~150 MB | Argmax — on-demand download |
| PronunciationScorer × 4 группы | ~2 MB × 4 | Собственная, PyTorch → coremltools (INT8) |
| Silero VAD | ~1 MB | Silero Team, CC0 |
| TonguePostureClassifier | ~5 MB | Собственная CNN поверх MediaPipe + ARKit features |
| MLX Qwen2.5-1.5B (quantized 4-bit) | ~900 MB | Apple MLX, on-demand download |

**Датасет** (собирается в `_workshop/datasets/`, в репо не попадает):
Common Voice 17 RU · OpenSLR SLR23/24 · GOLOS subset · augmented детская речь.
Итого: 200+ часов валидированного русского аудио.

Скрипты сбора/валидации/обучения/конвертации: `_workshop/scripts/{collect_datasets.sh, validate_datasets.py, train_scorer.py, convert_to_coreml.py}`.

---

## Firebase backend

Используется как синхронизация пользовательских данных и one-time download больших ассетов — НЕ как ежедневный CDN. Аналитика **отключена** (Kids Category).

**Firestore** — `users/{uid}/children/{childId}/{sessions, progress, rewards, routes}` + `specialists/{uid}/assignments/{id}` + публичный `content/packs/{packId}` + `content/manifest`.

**Storage** — `/audio/{ui,lyalya,content,refs}`, `/models/{whisperkit,llm}`, `/illustrations`, `/3d`, `/animations`, `/exports/{uid}`.

**Cloud Functions (v2, Node 20, europe-west1):**
`calculateProgress` · `generateReport` · `getUserStats` · `onSessionComplete` · `sendWeeklyReport` · `moderateUserContent` · `exportUserData` · `deleteUserData` · `setAdminClaim`.

**App Check:** DeviceCheck. **Auth:** Email+Password + Google Sign-in (без Apple Sign-in).

Деплой — см. [docs/firebase-runbook.md](docs/firebase-runbook.md).

---

## Тесты

```bash
# Юнит + интеграция + snapshot
xcodebuild test -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Второе устройство
xcodebuild test -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'

# Coverage
xcrun xccov view --report _workshop/coverage/result.xcresult
```

Стек тестов: **XCTest** + **Swift Testing** + кастомные snapshot-рендеры (иконки, тур-шаги, компоненты DesignSystem × 2 темы × 2 устройства).

Цели:
- ≥90 % line coverage на ViewModels и Services
- Все 16 игровых Interactor'ов покрыты сценариями happy-path и fatigue
- SM-2 engine — 14 тестов (quality mapping, interval progression, EF bounds, specialist flag, nextReviewDate)
- SessionShell — 6 тестов (startSession, completeActivity, fatigue detection, pause/resume, skip)
- GuidedTour — 9 тестов (start / next / skip / progress / persistence / force / reset)

---

## Этичность и границы

Это **педагогическая поддержка**, а не медицинский прибор.

- ❌ Не заменяет живого логопеда и не ставит диагноз.
- ❌ Не распознаёт клинические нарушения речи.
- ❌ Не отслеживает язык внутри рта — только внешние губы/язык через камеру.
- ❌ Никаких трекеров, рекламы, 3rd-party аналитики.
- ❌ Никаких покупок внутри приложения и paywalls.

Полный список — [CLAUDE.md § «Что НЕ делает приложение»](CLAUDE.md).

---

## Лицензия

MIT © Anton Grits.

Используемые открытые модели и датасеты — под Apache-2.0 / MIT / CC0; полный перечень в `.claude/team/ml-models.md`.

---

## Документация для разработчика

| Файл | Зачем |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Главная — правила кода, архитектура, DoD фичи, git workflow |
| [.claude/team/sprint.md](.claude/team/sprint.md) | Текущий спринт, задачи, кто делает что |
| [.claude/team/architecture.md](.claude/team/architecture.md) | ADR-лог архитектурных решений |
| [.claude/team/decisions.md](.claude/team/decisions.md) | Журнал продуктовых и инженерных решений |
| [.claude/team/ml-models.md](.claude/team/ml-models.md) | Реестр Core ML моделей, метрики, источники |
| [.claude/team/sound-assets.md](.claude/team/sound-assets.md) | Реестр аудио-ассетов и эталонов произношения |
| [docs/firebase-runbook.md](docs/firebase-runbook.md) | Развёртывание Firestore / Storage / Functions / App Check |
| `HappySpeech/ResearchDocs/speech-methodology.md` | Логопедическая база: этапы, звуки, упражнения, фидбек |

---

## Автор

Антон Гриц · дипломная работа по направлению iOS-разработка, 2026.
Все ассеты и контент разработаны автором; иллюстрации — SF Symbols + custom SVG + CC0 pool.
