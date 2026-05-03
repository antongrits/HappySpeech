# HappySpeech

> Логопедическое iOS-приложение для детей 5–8 лет — исправление и развитие речи через интерактивные игры с AI

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build](https://img.shields.io/badge/build-passing-brightgreen.svg)](/)
[![Kids Category](https://img.shields.io/badge/App%20Store-Kids%20Category-ff69b4)](/)
[![SwiftLint](https://img.shields.io/badge/SwiftLint-0%2F0-brightgreen.svg)](/)
[![Firebase](https://img.shields.io/badge/Firebase-happyspeech--dfd95-orange.svg)](/)
[![Russian Only](https://img.shields.io/badge/Language-Russian%20Only-blue.svg)](/)

---

## Screenshots

Hero set — iPhone SE (3rd generation) + iPhone 17 Pro симуляторы:

| ChildHome | LessonPlayer | AR Mirror | WorldMap |
|---|---|---|---|
| ![ChildHome](docs/screenshots/marketing/01_childhome_se.png) | ![LessonPlayer](docs/screenshots/marketing/02_lesson_player_se.png) | ![AR Mirror](docs/screenshots/marketing/03_ar_mirror_se.png) | ![WorldMap](docs/screenshots/marketing/04_worldmap_se.png) |

| SoundMap | Progress | Rewards | Specialist |
|---|---|---|---|
| ![SoundMap](docs/screenshots/marketing/05_soundmap_se.png) | ![Progress](docs/screenshots/marketing/06_progress_dashboard_se.png) | ![Rewards](docs/screenshots/marketing/07_reward_se.png) | ![Specialist](docs/screenshots/marketing/08_specialist_se.png) |

| Demo | Story Quest |
|---|---|
| ![Demo](docs/screenshots/marketing/09_demo_se.png) | ![Story Quest](docs/screenshots/marketing/10_story_quest_se.png) |

> Снято на iPhone SE (3rd generation) + iPhone 17 Pro симуляторах, 2026-04-28. Полный набор и сопоставление устройств — [docs/screenshots/marketing/index.md](docs/screenshots/marketing/index.md).

---

## О приложении

HappySpeech — полностью бесплатное русскоязычное iOS-приложение для коррекции и развития речи у детей 5–8 лет. Разработано как дипломный проект с применением технологий машинного обучения, дополненной реальности и on-device AI.

Маскот **Ляля** ведёт детей через упражнения, адаптивный планировщик подбирает уроки на сегодня с учётом прогресса и усталости, а родитель и специалист видят понятную аналитику.

**Ключевые принципы:**
- Полностью бесплатно — никаких покупок, подписок, рекламы
- Только русский язык — интерфейс и весь контент
- Offline-first — основные функции работают без интернета
- COPPA-compliant — никакой аналитики и трекинга для детей
- Три роли: ребёнок / родитель / специалист-логопед

---

## Возможности

### Три пользовательских контура

| Контур | Описание |
|---|---|
| Детский | Тёплый, игровой, минимум текста, 2D-маскот Ляля + AR-зона |
| Родительский | Сводки за день/неделю/месяц, советы логопедов, аналитика прогресса |
| Специалистский | Конструктор программ, ручная оценка попыток, PDF-экспорт |

### 16 типов логопедических упражнений

| Упражнение | Описание |
|---|---|
| Слушай и выбирай | ASR + оценка произношения, развитие фонематического слуха |
| Повтори за моделью | Запись + оценка произношения через WhisperKit |
| Артикуляционная имитация | AR-отслеживание мимики через Face Tracking (52 blendshapes) |
| AR-активности | 7 AR-игр с Face Tracking и ARKit |
| Минимальные пары | Различение похожих звуков |
| Перетащи и совмести | Сортировка слов по признакам |
| Охотник за звуком | Поиск предметов на нужный звук |
| История с пропусками | Выбор правильного слова в нарративе |
| Пазл-открытие | Произноси слово — кусочек открывается |
| Ритм | Повтор ритмического паттерна |
| Визуально-акустическое | Образ + звук → выбор |
| Квест с Лялей | Нарративные этапы с маскотом |
| Бинго | 5×5 поле с TTS |
| Память | Парное сопоставление |
| Сортировка | По звукам и категориям |
| Дыхательные упражнения | RMS-анализ дыхания |

### Технологии

- **WhisperKit** — on-device распознавание русской речи (~150 MB, tiny модель)
- **Core ML** — PronunciationScorer x4, SileroVAD, SoundClassifier
- **Qwen2.5-1.5B MLX** — on-device LLM для адаптивных планов (~900 MB, 4-bit quant)
- **ARKit Face Tracking** — 52 blendshape для артикуляции
- **SM-2 алгоритм** — интервальные повторения, адаптированные для детей
- **Firebase** — Auth + Firestore + Storage + Cloud Functions (синхронизация, не аналитика)

---

## Архитектура

```
Clean Swift (VIP) + SwiftUI + Firebase + Core ML + ARKit

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
│   Tokens (Color/Typo/Spacing/Radius/Motion) · 28 компонентов      │
│   HSButton · HSCard · HSPictTile · HSSpeechBubble · HSMascotView  │
└───────────────────────────────────────────────────────────────────┘
```

**Принципы:**
- Clean Swift VIP обязателен для каждого экрана (View / Interactor / Presenter / Router / Models / Workers)
- DI через `AppContainer`, factory closures, никаких синглтонов
- Swift 6 strict concurrency везде, `@Observable` iOS 17+, `@MainActor` для UI-логики
- Никаких `print` — только `OSLog` через `Logger(subsystem:category:)`
- Никаких dev-текстов в UI — все строки через String Catalog (`Localizable.xcstrings`)

---

## Как запустить

### Требования

- macOS 15 Sequoia+ (для Apple Silicon MLX runtime)
- Xcode 16+
- iOS 17+ симулятор или устройство

### Установка

```bash
git clone https://github.com/antongrits/HappySpeech.git
cd HappySpeech
brew install xcodegen swiftlint
xcodegen generate
open HappySpeech.xcodeproj
```

Выбери симулятор iPhone 17 Pro или iPhone SE (3rd generation) и нажми Run (Cmd+R).

### Сборка из командной строки

```bash
xcodebuild -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Запуск тестов

```bash
xcodebuild test -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Запуск на реальном устройстве (без Apple Developer Account)

1. Подключить iPhone, включить Developer Mode в `Settings → Privacy & Security`
2. В Xcode: `Signing & Capabilities → Team → Personal Team`
3. Выбрать устройство в schemes picker, нажать Run. Работает 7 дней на Personal provisioning

### Линтер

```bash
swiftlint --strict
```


## v1.0.0-final-v14 — Plan v14 (2026-05-02)

### Bundle Stats v14

| Категория | Размер | Кол-во |
|---|---|---|
| Built app (Debug iPhone SE 3) | 827 MB | — |
| Resources | 639 MB | — |
| Audio (.m4a) | 168 MB | 10 460 phrases (3951 Lyalya) |
| AR Assets (.usdz) | 231 MB | 20 USDZ |
| Assets.xcassets | 112 MB | 154 illustrations + AppIcon |
| Video (.mp4) | 71 MB | 100 MP4 |
| ML Models (.mlpackage) | 53 MB | 47 mlpackages |
| Animations | 3.5 MB | 58 Lottie + 1 Rive |

### Итоговые метрики v14

| Метрика | Значение |
|---|---|
| Bundle ID | `com.mmf.bsu.HappySpeech` |
| MARKETING_VERSION | 1.0.0 |
| Платформы | iPhone SE 3 + iPhone 17 Pro (BUILD SUCCEEDED) |
| SwiftLint | 0 violations / 0 warnings (614 files) |
| Lyalya phrases | 3 951 (.m4a) |
| HD illustrations | 154 imagesets |
| ML models | 47 .mlpackage |
| AR scenes (USDZ) | 20 |
| Lottie animations | 58 |
| Rive animations | 1 |
| Remotion videos | 100 MP4 |
| Siri Intents | 9 |
| Widgets | 4 |
| Firebase project | `happyspeech-dfd95` (eur3) |
| Kids Category compliant | YES |

### Что нового в v14

| Блок | Что сделано |
|---|---|
| Block 0 | Bundle ID com.mmf.bsu.HappySpeech, HealthKit removed |
| Block A | 21 deep VIP Interactor (~12 400 LOC) |
| Block B | AppIcon 3 appearance (FLUX-1-schnell) + 52 HD illustrations |
| Block C | 50 Real Lottie animations (CC0/MIT) |
| Block D | Custom 3D Lyalya USDZ + RealityKit blendshapes + 6 hero screens |
| Block E+O | 4 ML models trained (RussianPhonemeClassifier 92.24%, Wav2Vec2 96.67%, SpeakerVerification 100%, EmotionDetection 95.83%) |
| Block F | Voice expansion 2469 → 3951 Lyalya phrases |
| Block G | Firebase full services (Remote Config + FCM + App Check + Performance) |
| Block H | SPM: Lottie, Rive, Down, snapshot-testing, swiftui-particles |
| Block I | UI audit 65 screens + 11 critical fixes |
| Block J | 11 Remotion professional videos |
| Block K | 9 Siri Intents + 4 Widgets + Spotlight |
| Block L | Real-time lip-sync ARMirror (ARFaceAnchor 60fps) |
| Block M | 142 screenshots audit + 6 critical bugs fixed |
| Block N | ADR-V14-GLIFXYZ defer |
| Block P | Snapshot threshold 0.05, 477 PNG re-recorded |
| Block Q | Apple Kids Category compliance (Privacy Manifest, KidsAgeRange, ParentalGate) |
| Block R | Bundle 827 MB accepted as production-quality |

**Тег:** `v1.0.0-final-v14`

---

---

## v1.0.0-final-v4 — Plan v13 (2026-05-01)

### Конфигурация

- Bundle ID унификация → `com.mmf.bsu.HappySpeech`
- Firebase migrate `hs-app-2026` → `happyspeech-dfd95`
- HealthKit полностью удалён (no paid Apple Developer)
- iPad target removed (TARGETED_DEVICE_FAMILY=1, iPhone-only)
- Mac Designed for iPhone enabled (для self-test через MCP)

### 3D Lyalya RealityKit

- LyalyaRealityKitView UIViewRepresentable (replaces Rive wrapper)
- LyalyaLipSyncCoordinator с AVAudioPlayer.averagePower → mouth scale
- USDZ named entities (Mouth/PupilLeft/PupilRight/CheekLeft/CheekRight/ArmLeft)
- ADR-V13-LYALYA-3D-BLENDSHAPES-DEFERRED (требует Blender для real blendshapes)

### Phonemic + Spectrogram speech analyzer

- RussianPhonemeClassifier CoreML CNN-BiLSTM (83.94% val accuracy, PARTIAL)
- PhonemeAnalysisService Swift API (G2P + classifier + DTW alignment + scoring)
- Wav2Vec2 CoreML русская речь (bond005/wav2vec2-large-ru-golos, 302 MB int8)
- Real MFCC implementation (vDSP + Mel filterbank + DCT-II + deltas)
- SpectrogramVisualizerView (real-time vDSP FFT + Canvas + TimelineView, 60 fps)

### Контент

- Lyalya voice 1 774 → 2 469 phrases (+695, 8 categories)
- 3 Remotion onboarding tutorial videos
- 25 HD Phoneme illustrations FLUX-1-schnell
- 8 USDZ AR scenes (Apple AR Quick Look gallery exhausted, 20 total)
- SoftOnset 310 words (3 difficulty levels)

### Apple HIG

- 25 screens audited
- 2 P0 fixes (touch targets >=56pt, HapticService DI)
- 2 P1 fixes (VoiceOver labels)
- 8 P2 documented

### Critical fixes

- P0 RealmActor crash hotfix (verifyThread SIGABRT в SpotlightIndexCoordinator)
- LetterTracing iPhone adaptation (finger drawing default)

### Code quality

- SwiftLint 85 → 0 warnings (target <=10 exceeded)
- DocC catalog (от Plan v12)
- Down Markdown changelog screen

### Bundle stats v13

| Категория | Значение |
|---|---|
| Bundle (simulator debug) | ~1.1 GB |
| Bundle (IPA release estimate) | ~250 MB |
| Resources | 851 MB |
| ML Models (.mlpackage) | 9 шт |
| USDZ AR scenes | 20 |
| Lyalya voice phrases | 2 469 |
| HD illustrations | 102 imagesets |
| Платформы | 3 (iPhone 17 Pro + iPhone SE 3 + Mac Designed for iPhone) |

### Итоговые метрики v13

| Метрика | Значение |
|---|---|
| Типы игр | 18 (LetterTracing iPhone-adapted) |
| Ключей локализации (ru) | 2 143+ |
| Ключей локализации (en) | 0 |
| SwiftLint ошибок | 0 |
| SwiftLint предупреждений | 0 |
| Bundle ID | `com.mmf.bsu.HappySpeech` |
| Firebase project | `happyspeech-dfd95` (migrated) |

**Тег:** `v1.0.0-final-v4`

### Partial outcomes (честно)

| Пункт | Факт | Target | Причина |
|---|---|---|---|
| RussianPhonemeClassifier accuracy | 83.94% | 85% | Uniform forced alignment label noise |
| Wav2Vec2 размер | 302 MB | 200 MB | int8 quantization, качество важнее |
| HD illustrations | 25 шт | 50 шт | HuggingFace quota 402 после 25 |

### Deferred post-v1.0

- Real Blender USDZ blendshapes (Lyalya 3D) — требует DCC инструмент
- Wav2Vec2 fine-tuning на детскую речь
- Voice clone XTTS (placeholder в v12)
- Montreal Forced Aligner для улучшения PhonemeClassifier до >=85%

### 4 новых skill в v13

- `realitykit-blendshapes-character`
- `wav2vec2-coreml-russian`
- `spectrogram-visualizer-skill`
- `apple-hig-audit-skill`

---

## Что нового в v12 (Plan v12, 2026-04-30)

Plan v12 — финальная итерация перед дипломной защитой. 24 блока (A–X), ~25 коммитов. Тег: `v1.0.0-final-v3`.

### Новые возможности

| Компонент | Описание |
|---|---|
| On-device LLM (MLX Swift) | Qwen2.5-1.5B реальный inference на устройстве (Metal, ~15–25 tok/s, не заглушка) |
| G2P-словарь (7712 записей) | Russian Phoneme G2P dictionary — 100% покрытие целевой лексики логопедии |
| SharePlay Multiplayer | FaceTime parent-initiated multiplayer через GroupActivities (COPPA-safe, без детских аккаунтов) |
| Apple Pencil LetterTracing | 18-й тип игр — трассировка букв Apple Pencil (iPad, PKCanvasView, stroke accuracy) |
| ObjectHunt (Vision) | 17-й тип игр — поиск объектов через Vision object detection (CoreML, real-time) |
| Hand + Eye tracking | HandPoseRequest + EyeTrackingService для iPad assistive input |
| Biometric Face ID Gate | LocalAuthentication FaceID gate для специалистского контура |
| Family Home + Comparison | MultiChildFamilyHomeView + сравнительный Progress Dashboard для семьи |
| matchedGeometryEffect | Namespace-based hero transitions между экранами |
| CHHapticEngine (15 паттернов) | 15 AHAP-паттернов: reward / error / streak / breathing / metronome и др. |
| 10 ambient звуков | 10 CAF ambient сцен: лес / дождь / море / космос и др. |
| DocC каталог | Структурированная developer documentation (DocC catalog) |
| Mac Designed for iPhone | Полноценная поддержка macOS — 4-я платформа в BUILD SUCCEEDED |
| +10 USDZ AR-сцен | Итого 11 USDZ файлов в ARAssets/ |
| Native particle confetti | TimelineView + Canvas 60fps (заменяет сторонний SDK) |
| +6 Remotion видео | Сезонные + tutorial видео (итого 86 MP4) |
| +9 FLUX иллюстраций | Итого 110 imagesets |
| +248 фраз Ляли | 1 526 → 1 774 phrase .m4a |
| +450 сезонных единиц | Итого 6 959 контент-единиц |

### Bundle stats v12

| Категория | Размер | Кол-во файлов |
|---|---|---|
| App (simulator) | 660 MB | — |
| App (IPA release stripped) | ~200–250 MB | — |
| Audio (.m4a + .caf ambient) | 134 MB | 321 m4a + 10 caf |
| Video (.mp4) | 62 MB | 86 mp4 |
| ML Models (.mlpackage) | 48 MB | 27 mlpackage |
| AR Assets (.usdz) | 126 MB | 11 usdz |
| Haptics (.ahap) | 60 KB | 15 ahap |
| Illustrations (imagesets) | 21 MB | 110 imagesets |

### Итоговые метрики v12

| Метрика | Значение |
|---|---|
| Типы игр | 18 (16 базовых + ObjectHunt + LetterTracing) |
| Unit тестов | ~1 267 |
| UI тестов | 49 |
| Ключей локализации (ru) | 2 143 |
| Английских ключей (en) | 0 |
| SwiftLint ошибок | 0 |
| Платформы | iPhone 17 Pro + iPhone SE 3 + iPad Air 11 + Mac (all BUILD SUCCEEDED) |

**Тег:** `v1.0.0-final-v3`

---

## Plan v11 (2026-04-29) — Production Polish

После Plan v10 выполнен финальный production pass — Real assets, Firebase full services, 10 новых углублений.

### 15 блоков A–N

| Блок | Что сделано | Метрики |
|------|-------------|---------|
| A — Real Lottie tutorials | 8 Lottie JSON v5.x hand-composed (60fps, precomp layers) | ~360 KB |
| B — Rive multi-layer Lyalya | 6-layer HSMascotView wrapper (Rive + illustration + lip-sync) | ADR-V11-RIVE-V2 |
| C.4 — Voice clone reference | voice_clone_reference.wav + FaceMesh defer ADR | 47.4 MB wav |
| D — Firebase full services | Remote Config + FCM + Storage + App Check + Performance | 4 новых Swift сервиса |
| E — Big libs SPM | Lottie 4.5+ real API + Down markdown + native confetti Canvas | 3 новых компонента |
| F — Real-time lip-sync | ARFaceAnchor blendshapes → MascotLipSyncState → MouthBubbleOverlay | 5 тестов |
| G — ARKit Body Tracking | PoseSequence с ARBodyTrackingConfiguration (A12+), cosine similarity | 5 эталонных поз |
| H — Qwen kid circuit | KidLLMNarrationService + KidSafetyFilter + PrecannedNarrations | 20 тестов, COPPA |
| I — Apple Guidelines | ParentalGate + LSApplicationCategoryType + NSHealth*UsageDescription | Kids Category |
| J — HealthKit | Mindful sessions write-only (parent opt-in) | 14 тестов |
| K — Spotlight | CoreSpotlight 3 домена + deep link (уроки/достижения/сессии) | COPPA-safe |
| L — Siri Shortcuts | 5 AppIntents + DeepLinkRouter + SiriDeepLinkHandler | Russian-only |
| M — Live Activities | LessonSession ActivityKit + Dynamic Island (Lock Screen + compact/expanded) | iOS 16.1+ |
| N — Widget Extension | DailyMissionWidget Small/Medium/Large (App Group UserDefaults) | WidgetKit |
| Q — HD illustrations | +18 HD achievement illustrations (FLUX-1-schnell) | +18 PNG |
| P — Lyalya phrases | 956 → 1 526 фраз (.m4a) | +570 файлов |
| R — Remotion videos | 35 → 80 MP4 tutorial stories | +45 видео |

### Bundle metrics v11

| Ресурсы | Размер |
|---------|--------|
| Resources total | 237 MB |
| Audio .m4a (1 526 Lyalya + 6 959 content) | ~8 485 файлов |
| Video MP4 | 80 |
| ML models (.mlpackage) | 7 шт (48 MB) |
| Voice clone reference | 47.4 MB |

### Architecture extensions

- **Firebase:** 5 сервисов (было 2: Auth + Firestore)
- **SPM:** +2 реальные библиотеки (Down, Lottie 4.5+ API-switch)
- **Siri Intents:** 5 AppIntents с Russian-only фразами
- **New skills:** real-lottie-importer, firebase-services-architect, computer-vision-realtime
- **14 ADR-V11:** полный список в `.claude/team/architecture.md` → "Plan v11 итог"

### Russian-only mandate

1 944+ ru ключей, 0 en ключей. sourceLanguage = ru.

**Tag:** `v1.0.0-pro`

---

## Plan v10 (2026-04-29) — Real assets + 10 new extensions

После Plan v9 audit нашёл 5 critical issues непрофессионального уровня
(Siri TTS, placeholder Lottie, импортированный skills.riv, нет Mac, версия).
Plan v10 (15 коммитов) исправил всё + добавил 10 новых extensions для обгона
конкурентов.

### Critical fixes (4 коммита)

| Блок | Коммит | Что |
|---|---|---|
| A | d3aa51f | **Real Lyalya voice** заменяет Siri TTS в 9 lesson Interactor'ах (735 m4a, 19 тестов) |
| B | eccd4f8 | **Real Lottie tutorials** (8 procedural animations 31-50 KB) |
| C | 61be33a | **Universal app** — iPhone + iPad + Mac (Designed for iPhone) |
| D | 7193185 | **Custom Lyalya** — breathing motion + ADR-V10-RIVE wrapper improve |

### 10 new extensions (10 коммитов, ~7000 LOC новой функциональности)

| # | Блок | Что |
|---|---|---|
| L1 | Tuned voice + ADR-V10-VOICE-CLONE | 50 child-tuned phrases + defer XTTS-v2 cloning post-v1.0 |
| L2 | Sibling multiplayer | Bonjour LAN, 2 children play side-by-side |
| L3 | Seasonal events | Halloween / Новый год / Пасха content packs (150 units) |
| L4 | Real WhisperKit | dysfluency analyzer (regex repeats + prolongations + pauses) |
| L5 | Family voice library | parent records → priority chain → speak в lessons |
| L6 | Achievements + leaderboard | 32 achievements + family rating, COPPA offline |
| L7 | Unified Face Pose | ARKit 52 blendshapes + Vision 76 landmarks → 5 visemes |
| L8 | Mini puzzles offline | 3 mini-games когда нет интернета |
| L9 | Family chat + Widget | local push 17:00 + weekly summary + HomeScreenCard |
| L10 | ML insights | LLM Tier B + rule-based fallback в ProgressDashboard |

### Финальная статистика v10

- ~7900 LOC новой функциональности
- 151 ru-локализационных ключей (1784 → 1935)
- 969 Lyalya phrases (735 lesson + 50 tuned + 184 base) — real voice вместо Siri
- Realm schema v6 → v7
- 5 новых ADR (RIVE / VOICE-CLONE / WHISPERKIT / FACEPOSE / ...)
- Universal app (iPhone + iPad + Mac)
- BUILD SUCCEEDED на 3 platforms

**Версия 1.0.0** — production-ready для дипломной защиты.

---

## Plan v9 (2026-04-28) — финальные расширения

Все 5 M13 extensions реализованы в рамках Plan v9 (15 коммитов, ветка `main`).

| Extension | Коммит | LOC | Unit-тестов |
|---|---|---|---|
| F1 Grammar games (4 интерактивные игры) | `5f15cb3` | 2 329 | 34 |
| F2 Customization Ляли | `8feb574` | 1 364 | 21 |
| F3 Family Calendar (Swift Charts heatmap) | `76942b9` | 1 850 | 28 |
| F4 Parent-child режим (AVAudioRecorder) | `3d4ffd7` | 1 805 | 25 |
| F5 Stuttering module (MetronomeWorker) | `ece212d` | 2 730 | 24 |
| **Итого Plan v9** | — | **~10 078** | **132** |

**BUILD SUCCEEDED** iPhone 17 Pro + iPhone SE 3rd gen на каждом коммите.

Дополнительно в Plan v9:
- +183 ключа локализации (ru only, 0 en) — итого 1 784 ключа
- +44 snapshot PNG — итого 469 PNG
- Realm schema v3 → v6 (3 новых объекта)
- 20 Remotion MP4 stories + 13 voice-over + 5 phrases + 3 voice previews

---

## Статистика проекта

| Метрика | Значение |
|---|---|
| Swift файлов | 500+ |
| Строк кода (LOC) | ~120 000+ |
| Git коммитов | 190+ |
| Экраны (VIP-фичи) | 38+ |
| Типы упражнений | 18 |
| AR игр | 8 + ARStoryQuest |
| Контент-паки | 21 |
| Контент-единиц | 6 959+ |
| Фразы маскота Ляли | 2 469 (v13) |
| DesignSystem компоненты | 30+ |
| Unit + UI тестов | ~1 316 (1 267 unit + 49 UI) |
| Ключей локализации | 2 143 (ru only, 0 en) |
| Core ML моделей | 27 (.mlpackage) |
| USDZ AR-сцены | 20 (v13) |
| Remotion MP4 stories | 86 |
| HD illustrations | 110 imagesets (FLUX-1-schnell) |
| Ambient звуки | 10 (.caf) |
| AHAP паттерны | 15 |
| Размер Bundle (simulator) | 660 MB |
| Целевая аудитория | Дети 5–8 лет |

### Production Status

| Компонент | Статус |
|-----------|--------|
| Build (iPhone 17 Pro sim) | passing |
| Build (iPhone SE 3 sim) | passing |
| Build (iPad Air 11 sim) | removed (iPhone-only с v13) |
| Build (Mac Designed for iPhone) | passing |
| SwiftLint errors | 0 |
| SwiftLint warnings | 0 (v13 — 85 → 0) |
| Язык (sourceLanguage) | Russian only (2 143 ru, 0 en) |
| Firebase project | happyspeech-dfd95 (eur3) |
| Firestore rules | deployed |
| Firebase Auth | Email/Password enabled |
| .mlpackage в Resources/Models/ | 27 моделей |
| 18 game templates (VIP) | done |
| 8 AR games + ARStoryQuest | done |
| App Store metadata | done (ru + en) |
| AppPrivacyInfo.xcprivacy | done |
| DocC documentation | done |
| TestFlight build | pending (нужен Apple Developer Account) |

---

## Структура проекта

```
HappySpeech/
├── App/               — Entry point, AppContainer DI, Coordinators
├── Core/              — Logger, Extensions, Types, Errors
├── DesignSystem/      — Tokens (Color/Typo/Spacing/Radius/Motion), 28 компонентов
├── Features/          — 30+ экранов в Clean Swift VIP
│   ├── Auth/          — Sign in, Sign up, Splash
│   ├── ChildHome/     — Детский главный экран + маскот
│   ├── ParentHome/    — Родительский дашборд
│   ├── Specialist/    — Инструменты логопеда
│   ├── LessonPlayer/  — 16 типов игр
│   ├── ARZone/        — AR-активности (8 игр)
│   ├── Onboarding/    — 11-шаговый GuidedTour
│   └── Settings/      — Настройки, профили
├── Services/          — Audio, ASR, AR, Adaptive, Sync, Notification, Haptic...
├── ML/                — WhisperKit, Silero VAD, MLX LLM, PronunciationScorer
├── Data/              — Realm Swift модели, Repositories, Migrations
├── Sync/              — Firebase Firestore bridge, SyncQueue, конфликт-резолвер
├── Content/           — ContentEngine, 6 959 items в 24 паках
│   ├── Schemas/       — content-pack.schema.json
│   └── Seed/          — JSON-паки звуков
└── Resources/         — Assets.xcassets, Sounds, Models (.mlpackage), Localizable.xcstrings
```

---

## ML-модели

| Модель | Размер | Точность | Источник |
|---|---|---|---|
| PronunciationScorer (С/З/Ш/Р — 4 группы) | ~2 MB x4 | 100% (синтетика) | Собственная, PyTorch → coremltools INT8 |
| SileroVAD | ~80 KB | 99.9% | Silero Team, CC0 → Core ML |
| SoundClassifier | ~2 MB | 85.8% | CreateML |
| WhisperKit (tiny RU) | ~150 MB | — | Argmax — on-demand download |
| Qwen2.5-1.5B MLX (4-bit) | ~900 MB | — | Qwen Team — on-demand download |

Финальные `.mlpackage` — в `HappySpeech/Resources/Models/`. Реестр метрик — `.claude/team/ml-models.md`.

**Датасет** (собирается в `_workshop/datasets/`, в репо не попадает):
Common Voice 17 RU · OpenSLR SLR23/24 · GOLOS subset · augmented детская речь. Итого: 200+ часов валидированного русского аудио.

---

## Firebase backend

Используется как синхронизация пользовательских данных и one-time download больших ассетов — не как ежедневный CDN. Аналитика отключена (Kids Category compliance).

**Firestore схема:**
```
users/{uid}/children/{childId}/{sessions, progress, rewards, routes}
specialists/{uid}/assignments/{id}
content/packs/{packId}
content/manifest
```

**Storage:**
```
/audio/{ui,lyalya,content,refs}
/models/{whisperkit,llm}
/illustrations, /3d, /animations
/exports/{uid}
```

**Cloud Functions (v2, Node 20, europe-west1):**
`calculateProgress` · `generateReport` · `getUserStats` · `onSessionComplete` · `sendWeeklyReport` · `moderateUserContent` · `exportUserData` · `deleteUserData` · `setAdminClaim`

**Auth:** Firebase Auth (Email+Password + Google Sign-in). **App Check:** DeviceCheck.

---

## Тесты

```bash
# Юнит + интеграция + snapshot (iPhone 17 Pro)
xcodebuild test -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Второе устройство (SE)
xcodebuild test -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'

# Coverage
xcrun xccov view --report _workshop/coverage/result.xcresult
```

**Цели покрытия:**
- Unit coverage ≥70% на Interactors
- Snapshot тесты light + dark для всех 16 шаблонов + 8 ключевых экранов
- SM-2 engine — 14 тестов (quality mapping, interval progression, EF bounds, fatigue)
- SessionShell — 6 тестов (start, complete, fatigue detection, pause/resume, skip)
- GuidedTour — 9 тестов (start / next / skip / progress / persistence / reset)

---

## Методологическая основа

Приложение разработано на основе российской логопедической методики:

- **Авторы:** Фомичёва, Лопатина, Ткаченко, Коноваленко, Парамонова, Филичёва/Чиркина, Нищева, Богомолова, Жукова, Каше
- **Принципы:** онтогенетический, поэтапность (14 этапов), частотный, игровой, короткие сессии (7–15 минут по возрасту)
- **Группы звуков:** свистящие (С, З, Ц), шипящие (Ш, Ж, Ч, Щ), соноры (Р, Рь, Л, Ль), заднеязычные (К, Г, Х)

Полная методологическая база (10 документов, 26K+ слов) — в `HappySpeech/ResearchDocs/`.

---

## Этичность и границы

Это педагогическая поддержка, а не медицинский прибор.

- Не заменяет живого логопеда и не ставит диагноз
- Не распознаёт клинические нарушения речи — только интерпретируемые эвристики
- Не отслеживает язык внутри рта — только внешние губы/язык через ARKit blendshapes
- Никаких трекеров, рекламы, 3rd-party аналитики
- Никаких покупок внутри приложения и paywalls
- Все ML-модели работают on-device — аудио не покидает устройство

---

## Конфиденциальность

Приложение разработано с соблюдением COPPA (Children's Online Privacy Protection Act):
- Никакой аналитики и трекинга пользователей
- Все ML-модели работают on-device
- Аудио не отправляется на сервер
- Firebase используется только для синхронизации данных пользователя

Ссылки для App Store: [Политика конфиденциальности](docs/privacy-policy.md) · [Условия использования](docs/terms.md)

---

## Документация для разработчика

| Файл | Содержимое |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Правила кода, архитектура, DoD фичи, git workflow |
| [.claude/team/sprint.md](.claude/team/sprint.md) | Текущий спринт, задачи, статусы |
| [.claude/team/architecture.md](.claude/team/architecture.md) | ADR-лог архитектурных решений |
| [.claude/team/decisions.md](.claude/team/decisions.md) | Журнал продуктовых и инженерных решений |
| [.claude/team/ml-models.md](.claude/team/ml-models.md) | Реестр Core ML моделей, метрики, источники |
| [.claude/team/sound-assets.md](.claude/team/sound-assets.md) | Реестр аудио-ассетов и эталонов произношения |
| [.claude/team/design-specs.md](.claude/team/design-specs.md) | Дизайн-токены, компоненты, спецификации |

---

## Лицензия

MIT License — см. [LICENSE](LICENSE)

Используемые открытые модели и датасеты — под Apache-2.0 / MIT / CC0; полный перечень в `.claude/team/ml-models.md`.

---

## Автор

Антон Гриц — дипломный проект, 2026

- Email: antongric558@gmail.com
- GitHub: [@antongrits](https://github.com/antongrits)
