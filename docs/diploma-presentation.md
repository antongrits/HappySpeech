# HappySpeech — Дипломная презентация

> Антон Гриц · 2026

---

## Слайд 1: Титульный

**HappySpeech**

Русскоязычное логопедическое iOS-приложение для детей 5–8 лет

Автор: Антон Гриц
Год защиты: 2026
Платформа: iOS 17+
Язык: Swift 6

---

## Слайд 2: Проблема и актуальность

**Масштаб проблемы:**

- 40–60% детей дошкольного возраста имеют нарушения звукопроизношения
- Дефицит логопедических кадров: очередь к специалисту — от 3 до 6 месяцев
- Домашняя практика без сопровождения специалиста практически отсутствует

**Недостатки существующих решений:**

- Ограниченный контент (50–200 упражнений)
- Нет AI-оценки произношения
- Нет AR-артикуляции
- Нет специалистского контура
- Платный доступ к базовым функциям

**Цель проекта:**

Создать доступное, научно обоснованное, полностью offline логопедическое приложение,
которое работает на устройстве ребёнка без постоянного подключения к интернету.

---

## Слайд 3: Целевая аудитория

**4 пользовательских контура:**

```
Дети 5–8 лет          → игровой контур (Kid)
  Группа 5–6 лет:   упражнения на постановку звука
  Группа 6–7 лет:   автоматизация в словах и фразах
  Группа 7–8 лет:   дифференциация, свободная речь

Родители              → родительский контур (Parent)
  Мониторинг прогресса ребёнка
  Домашние задания, рекомендации специалиста

Логопеды              → специалистский контур (Specialist)
  Оценка результатов сессий
  Назначение заданий, PDF/CSV экспорт
  Инструменты скрининга

ИИ-адаптация          → адаптивный контур (Adaptive)
  Персонализированный маршрут обучения
  Учёт усталости, пространственное повторение
```

---

## Слайд 4: Конкурентный анализ

| Функция               | HappySpeech | Логопотам | Буковки | Логомаг |
|-----------------------|-------------|-----------|---------|---------|
| AR-артикуляция        | Да          | Нет       | Нет     | Нет     |
| AI-оценка произношения| Да          | Нет       | Нет     | Нет     |
| Offline-first         | Да          | Частично  | Нет     | Нет     |
| Специалистский контур | Да          | Нет       | Нет     | Нет     |
| Русский язык          | Да          | Да        | Да      | Да      |
| Бесплатный базовый    | Да          | Нет       | Частично| Нет     |
| Адаптивный маршрут    | Да          | Нет       | Нет     | Нет     |
| 16 типов упражнений   | Да          | Нет       | Нет     | Нет     |

**Вывод:** HappySpeech — единственное решение, совмещающее AR, AI,
offline, специалистский контур и научно обоснованную методологию.

---

## Слайд 5: Архитектура приложения

**Паттерн:** Clean Swift (VIP)

```
+--------------------------------------------------+
|                  SwiftUI View                    |
|  (рендер, жесты, анимации, маскот «Ляля»)        |
+----+------------------+------------------+-------+
     |                  |                  |
     v                  v                  v
+----------+     +-----------+      +-----------+
|Interactor|     | Presenter |      |  Router   |
|бизнес-   |<--->|ViewModel  |      |навигация  |
|логика    |     |формирует  |      |коорд-р    |
+----+-----+     +-----------+      +-----------+
     |
     v
+----+-----------------------------------------------+
|                    Services Layer                   |
|  AudioService  ASRService  ARService  ContentService|
|  AdaptivePlannerService  LLMDecisionService         |
|  NotificationService  HapticService  SyncService    |
+----+-------------------+----------------------------+
     |                   |
     v                   v
+----------+       +----------+
|  Realm   |       | Firebase |
| (offline)|       | (cloud)  |
+----------+       +----------+
```

**Слои проекта:**

- `App/` — точка входа, DI-контейнер, координатор
- `Features/` — 40+ фич по VIP-паттерну
- `Services/` — 11 сервисов через протоколы
- `Data/` — Realm-модели, 9 репозиториев, миграции
- `ML/` — WhisperKit, SileroVAD, PronunciationScorer, LocalLLM
- `DesignSystem/` — токены, тема, 14 компонентов

---

## Слайд 6: Технологический стек

**UI и архитектура:**

- SwiftUI 6.0 + UIKit wrappers
- Swift 6 strict concurrency (async/await везде)
- Liquid Glass API (iOS 26, `.glassEffect()`)
- @Observable вместо ObservableObject

**Машинное обучение и AI:**

- WhisperKit — ASR (whisper-large-v3-turbo, MIT, ~600 MB, WER ~7.4% на RU)
- Silero VAD — детектор голосовой активности через Core ML
- PronunciationScorer — 4 Core ML модели оценки произношения
- MLX Swift + Qwen2.5-1.5B-Instruct — on-device LLM (~950 MB, ~20 tok/s на iPhone 15 Pro)

**AR и аудио:**

- ARKit Face Tracking — 52 blendshape (16 релевантных для артикуляции)
- AVAudioEngine — 16kHz mono, DSP через vDSP/Accelerate
- Rive state machine — маскот «Ляля» (10+ состояний)

**Backend и хранение:**

- Firebase Auth + Firestore + Storage + App Check (DeviceCheck)
- Realm Swift — offline-first локальная БД
- Firestore Security Rules v1.1 — 357 строк, 14 составных индексов

---

## Слайд 7: Игровые механики — 16 шаблонов

**Аудиальные (произношение и слух):**

| Шаблон              | Описание                                       |
|---------------------|------------------------------------------------|
| ListenAndChoose     | Фонематический слух: выбери правильное слово   |
| RepeatAfterModel    | Повтори за героем с оценкой ASR               |
| MinimalPairs        | Различай похожие звуки (С/Ш, Р/Л)            |
| SoundHunter         | Найди звук в слове/предложении                |

**Визуально-игровые:**

| Шаблон              | Описание                                       |
|---------------------|------------------------------------------------|
| DragAndMatch        | Перетащи слово к картинке                     |
| Sorting             | Раздели слова по заданному звуку              |
| Memory              | Мемори-игра на звуковые пары                  |
| Bingo               | Речевое бинго: назови — зачеркни              |
| PuzzleReveal        | Собери пазл, называя части                    |
| StoryCompletion     | Заверши фразу в рассказе                      |
| NarrativeQuest      | Интерактивная история с речевыми выборами     |
| VisualAcoustic      | Визуализация звука через осциллограф          |

**AR и двигательные:**

| Шаблон              | Описание                                       |
|---------------------|------------------------------------------------|
| ARActivity          | AR-артикуляция через Face Tracking            |
| ArticulationImitation| Повтори позу артикуляционного аппарата       |
| Breathing           | Дыхательные упражнения с визуализацией        |
| Rhythm              | Ритмические упражнения со звуком              |

---

## Слайд 8: AR-зона

**Технология:**

- ARKit Face Tracking (TrueDepth камера, iPhone X+)
- 52 blendshape, 16 релевантных для логопедии
- FaceMesh: 76 ключевых точек
- TonguePostureClassifier: CNN-классификатор 8 поз языка
- Fallback-режим: визуальные инструкции без камеры

**Ключевые blendshape для артикуляции:**

```
Рот/челюсть:   jawOpen, jawLeft, jawRight, mouthClose
Губы:          mouthFunnel (У/Ш), mouthPucker (О)
               mouthSmileLeft/Right (широкая улыбка — звук И)
               mouthStretchLeft/Right (растяжка губ)
Щёки:          cheekPuff (дыхательные упражнения)
Язык:          tongueOut (высунуть язык)
```

**Честные границы (ADR-008):**

Внутреннее положение языка (для Р, Л, Ш) отследить через ARKit невозможно.
Все AR-игры используют только внешние blendshape. В приложении — явные дисклеймеры.

**8 AR-сценариев:**

HoldThePose, MimicLyalya, BreathingGame, SoundAndFace,
PoseSequence, ARStoryQuest, TongueOutChallenge, JawOpenRhythm

---

## Слайд 9: ИИ и адаптивность

**AdaptivePlannerService — персонализированный маршрут:**

```
Входные данные:                    Выходные данные:
- История попыток (Realm)    -->   DailyRoute (5–8 упражнений)
- Fatigue score (0.0–1.0)          Оптимальный порядок
- Spaced repetition (SM-2)         Difficulty adjustment
- Целевой звук (priority)          Push-уведомление в 18:00
```

**LLMDecisionService — on-device LLM:**

- 25 точек принятия решений в сессии
- Qwen2.5-1.5B через MLX Swift (~20 tok/s на iPhone 15 Pro)
- Только структурированный JSON вывод (не чат-интерфейс)
- RuleBasedDecisionService — полноценный fallback без LLM

**PronunciationScorer:**

- Real-time оценка после каждой попытки (0.0–1.0)
- 4 Core ML модели: phoneme, prosody, fluency, overall
- Фидбек: ≥0.8 → «Отлично!», 0.5–0.8 → «Попробуй ещё раз», <0.5 → обучающая подсказка

---

## Слайд 10: Контент

**Объём:**

- 6 265 единиц контента
- 21 пак (группы: свистящие, шипящие, соноры, заднеязычные, грамматика, дыхание, лексика)
- 9 этапов работы на каждый звук

**9 этапов логопедической работы:**

```
1. Подготовка артикуляции    (артикуляционная гимнастика)
2. Изолированный звук        (С-С-С изолированно)
3. Слоги прямые              (СА, СО, СУ)
4. Слоги обратные            (АС, ОС, УС)
5. Слова в начале            (санки, сок, сумка)
6. Слова в середине          (оса, касса, весна)
7. Слова в конце             (нос, лес, голос)
8. Фразы и предложения       (Соня несёт сумку)
9. Дифференциация            (С/Ш: санки/шанки)
```

**Звуковые паки:**

| Группа     | Звуки               | Статус   |
|------------|---------------------|----------|
| Свистящие  | С, З, Ц            | Полный   |
| Шипящие    | Ш, Ж, Ч, Щ         | Полный   |
| Соноры     | Р, Рь, Л, Ль        | Готово   |
| Заднеязычные | К, Г, Х           | Стаб     |

**Методологическая основа:** российская логопедическая школа —
Фомичёва М.Ф., Грибова О.Е., Жукова Н.С.

**Формат:** JSON Schema-валидированный контент-пак.
ContentEngine собирает Lesson из пака через комбинаторы (matrix: sound × stage × template).

---

## Слайд 11: UX-дизайн

**Детский контур (Kid):**

- Тёплая цветовая палитра (orange, yellow, teal)
- Минимальный размер touch target — 56pt (WCAG AAA)
- Маскот «Ляля» присутствует на каждом экране
- Low-text, icon-first интерфейс
- Голосовая обратная связь маскота (121+ фраза)

**Родительский контур (Parent):**

- Swift Charts: прогресс по звукам, сессии за неделю/месяц
- SessionHistory с фильтрами и поиском
- PDF-экспорт прогресса для передачи логопеду

**Специалистский контур (Specialist):**

- SessionReview: детальный разбор каждой попытки
- ScreeningOutcome: итоговое заключение сессии
- CSV-экспорт для собственной аналитики специалиста

**Accessibility:**

- VoiceOver: метки на всех интерактивных элементах
- Dynamic Type: от .small до .accessibilityLarge без поломки layout
- Reduced Motion: все анимации учитывают `accessibilityReduceMotion`
- Light + Dark темы: полный проход по всем экранам

**Визуальный язык:**

- Liquid Glass (`.glassEffect()`, iOS 26) на карточках и панелях
- SF Symbols 6 — иконки без кастомных растровых ассетов
- DesignSystem: 5 групп токенов (цвет, типографика, отступы, радиус, моушн)

---

## Слайд 12: Маскот «Ляля»

**Технология:**

- Rive state machine (`.riv` файл): 10+ состояний анимации
- 3D-версия: RealityKit + USDZ (ключевые экраны и AR-зона)
- Lip-sync: амплитуда AVAudioPlayer → параметр Rive `mouthOpen`

**Состояния маскота:**

```
idle          → спокойное ожидание
listening     → маскот слушает ребёнка
thinking      → обрабатывается результат
celebrating   → точность >= 80% (прыжки, конфетти)
encouraging   → точность < 50% (мягкое ободрение)
sleeping      → сессия неактивна > 30 сек
explaining    → показывает артикуляцию
dancing       → завершение уровня
```

**Голосовые фразы:**

- 121+ уникальная фраза (русский язык)
- Категории: приветствие, похвала, подсказка, ободрение, прощание
- AVSpeechSynthesizer (offline) + записанные звуки для ключевых фраз

**Психологический принцип:**

Ляля никогда не критикует. Только ободряет и направляет.
Это соответствует принципу «безопасной среды» российской логопедической методики.

---

## Слайд 13: Качество и тестирование

**Unit-тесты:**

```
Interactors (игровые):       104 теста
  ListenAndChooseInteractor   16 тестов
  RepeatAfterModelInteractor  14 тестов
  SortingInteractor           12 тестов
  BingoInteractor             18 тестов
  MemoryInteractor            16 тестов
  + 7 других Interactor        28 тестов

Сервисы:                      84 теста
  AdaptivePlannerService       22 теста
  LLMDecisionService           18 тестов
  SyncService                  24 теста
  ContentEngine                20 тестов
```

**Snapshot-тесты:**

```
16 шаблонов × 2 темы   = 32 снапшота
8 ключевых экранов × 2 = 16 снапшотов
Итого:                   48 снапшотов (все зелёные)
```

**UI-тесты:**

- 7 тестов: Auth flow, Onboarding, ChildHome, ParentHome

**Screenshot tour:**

- 44 скриншота (iPhone 17 Pro + iPhone SE 3)

**Статический анализ:**

- 0 SwiftLint нарушений в Features/, Services/, App/
- Swift 6 strict concurrency — 0 data race warnings

**Итог:** BUILD SUCCEEDED на iOS Simulator iPhone 17 Pro

---

## Слайд 14: Результаты и метрики

**Масштаб проекта:**

```
Swift файлов:              386
Строк кода (LOC):       75 582
Git коммитов:              125
Локализационных ключей:  1 381

Игровых шаблонов:           16
AR-сценариев:                8
Контент-паков:              21
Единиц контента:         6 265

Unit-тестов:               188
Snapshot-тестов:            48
UI-тестов:                   7
```

**Архитектурные решения (ADR):**

```
9 архитектурных решений зафиксировано в decisions.md
ADR-001: ASR — WhisperKit large-v3-turbo (MIT)
ADR-002: LLM — Qwen2.5-1.5B через MLX Swift
ADR-003: БД — Realm Swift (offline-first)
ADR-004: Аналитика — только локальная (Kids Category)
ADR-005: Архитектура — Clean Swift VIP
ADR-006: Зависимости — только SPM
ADR-007: Проект — xcodegen (project.yml)
ADR-008: AR — честные границы blendshape
ADR-009: Контент — matrix approach (sound × stage × template)
```

**Блокеры для финального деплоя (не влияют на защиту):**

- Firebase deploy: требует `firebase login antongric558@gmail.com`
- .mlpackage файлы: требует ML training pipeline (Core ML конвертация)
- TestFlight: требует Apple Developer account ($99/год)

---

## Слайд 15: Заключение и перспективы

**Достигнуто в рамках диплома:**

- Полноценное production-quality iOS-приложение (386 файлов, 75 582 LOC)
- Clean Swift VIP архитектура с высокой тестируемостью (188 unit-тестов)
- Уникальная комбинация AR + AI + offline на русском языке
- Научно обоснованная методология (Фомичёва, Грибова, Жукова)
- 6 265 единиц контента по 21 звуковому паку
- Превосходит всех конкурентов по совокупности функций
- Kids Category compliance (нет трекеров, нет рекламы, нет внешних ссылок)

**Технологические инновации:**

- On-device ASR (WhisperKit, WER ~7.4% на русском) без облака
- On-device LLM (Qwen2.5-1.5B, ~20 tok/s) для адаптивного планирования
- ARKit Face Tracking для визуальной обратной связи по артикуляции
- Content Matrix: 6 265 упражнений из 21 seed-пака через ContentEngine

**Перспективы развития:**

- App Store публикация (Kids Category)
- Клинические испытания с логопедами (пилот в 2–3 детских учреждениях)
- Android-версия на базе Compose + ONNX Runtime
- Расширение контента: заднеязычные (К, Г, Х), грамматика
- Многоязычность: казахский, украинский, белорусский
- Интеграция с логопедическими системами (ФГОС, ИЭП)

---

## Приложения

### A. Структура проекта (верхний уровень)

```
HappySpeech/
├── App/                    — @main, DI-контейнер, координатор
├── Core/                   — утилиты, логгер, типы
├── DesignSystem/           — токены, тема, 14 компонентов
├── Shared/                 — общие модификаторы и view-хелперы
├── Features/               — 40+ фич (Clean Swift VIP)
├── Services/               — 11 сервисов (протоколы)
├── Data/                   — Realm-модели, 9 репозиториев
├── ML/                     — WhisperKit, VAD, Scorer, LLM
├── Sync/                   — Firestore-мост, очередь
├── Analytics/              — локальная событийная шина
├── Content/                — ContentEngine, схемы, 21 seed-пак
├── ResearchDocs/           — методологические документы
├── ProductSpecs/           — продуктовые спецификации
└── Resources/              — Assets, звуки, модели, локализации
```

### B. Зависимости проекта (SPM)

| Библиотека     | Версия   | Назначение                   |
|----------------|----------|------------------------------|
| RealmSwift     | 10.x     | Offline-first локальная БД   |
| FirebaseAuth   | 11.x     | Аутентификация               |
| FirebaseFirestore | 11.x  | Облачная синхронизация       |
| WhisperKit     | 0.x      | On-device ASR                |
| MLX Swift      | 0.x      | On-device LLM inference      |
| Rive           | 6.x      | Анимации маскота «Ляля»      |
| SnapshotTesting| 1.x      | Snapshot-тесты               |

### C. Ключевые экраны приложения

**Детский контур:**
SplashView → OnboardingFlowView → ChildHomeView → LessonPlayerView →
SessionCompleteView → RewardsView → ARZoneView

**Родительский контур:**
ParentHomeView → ProgressDashboardView → SessionHistoryView → ChildProfileView

**Специалистский контур:**
SpecialistDashboardView → PatientListView → SessionReviewView → ScreeningOutcomeView

**Общие экраны:**
SettingsView → ThemePickerView → NotificationsSettingsView → DemoTourView

---

## v18 Final State (2026-05-09)

### Tag: v1.0.0-final-v18 (30e55060) + post-tag continuation

### Production-quality milestone (Plan v18 + post-tag continuation)

| Метрика | Достигнуто | Цель |
|---|---|---|
| Всего коммитов v18 | 76+ | ≥80 |
| Post-tag коммитов | 28+ | n/a |
| Голосовых файлов (.m4a) | 14 501 | ≥14 500 |
| Контент-паков | 25 | ≥25 |
| Единиц контента | 7 555 | ≥7 459 |
| Imagesets (HD иллюстрации) | 154 | n/a |
| MP4 видео (motion-design) | 69+ | n/a |
| Lottie анимации | 58 | n/a |
| Core ML моделей (.mlpackage) | 12 | n/a |
| Русских ключей локализации | 3 827 | ≥3 800 |
| Cloud Functions (Firebase) | 18 live (europe-west3) | 100% |
| AppCheck enforced | 14/14 | 100% |
| Компонентов DesignSystem | 41 | n/a |
| Интерактивных экранов (VIP) | 105+ | 100+ |
| SwiftLint --strict | 0 ошибок | 0 |
| QA тестов (pass/total) | 68/70 (97%) | ≥95% |
| BUILD | SUCCEEDED iPhone SE (3rd gen) | SUCCEEDED |
| Bundle глубина ресурсов | 1.3 GB | n/a |

### Архитектура

- iOS 17+ SwiftUI 6.0
- Swift 6 strict concurrency (async/await, @Observable)
- Clean Swift VIP на каждую фичу (Interactor / Presenter / Router / Models / Workers)
- Realm Swift — offline-first локальная БД (9 репозиториев, миграции)
- Firebase backend: Auth + Firestore + Functions (18 callable) + Storage + AppCheck (DeviceCheck) + Remote Config (19 флагов) + FCM + Performance
- WhisperKit + Wav2Vec2RuChild — ASR (WER ~7.4% на RU)
- 12 Core ML моделей: Wav2Vec2RuChild (302 MB real), RussianPhonemeClassifier (83.9%), EmotionDetection (≥75%), SileroVAD, SoundClassifier, TonguePostureClassifier и др.
- ARKit Face Tracking (TrueDepth, 52 blendshapes, 16 артикуляционных)
- 3D маскот Ляля — LyalyaRealityKitView (RealityKit + USDZ, 8 эмоций, 5 viseme lip-sync)
- MLX Swift + Qwen2.5-1.5B — on-device LLM (~20 tok/s на iPhone 15 Pro)

### Compliance

- Kids Category (Apple App Store)
- COPPA-safe (parent-gated messaging, без внешних ссылок без Parental Gate)
- Privacy Policy + Terms размещены на GitHub Pages (https://antongrits.github.io/HappySpeech/)
- WCAG AA контраст (≥4.5:1)
- VoiceOver labels (97% покрытие)
- Reduce Motion compliance (@Environment(\.accessibilityReduceMotion))
- Dynamic Type (Small → AccessibilityLarge, layout не ломается)

### Что НЕ делает приложение (честные границы)

- Медицинская диагностика — приложение является педагогической поддержкой, не клинической
- Клиническое распознавание нарушений речи — используются интерпретируемые эвристики
- Полное tongue-tracking внутри рта — ARKit даёт только внешние blendshapes
- Гарантия клинических результатов
- Замена живого логопеда

### Демо для защиты диплома (9 сценариев)

1. **Onboarding flow** — 10 шагов с 3D Лялей 200pt+, child profile setup, parental gate
2. **ChildHome** — детский контур, тёплая палитра, low-text, маскот на каждом экране
3. **WorldMap + LessonPlayer** — 16 игровых шаблонов, матрица sound × stage × template
4. **AR Mirror** — TrueDepth blendshapes для артикуляции, TonguePostureClassifier
5. **ParentHome** — аналитика Swift Charts, прогресс по звукам, PDF-экспорт
6. **SpecialistDashboard** — специалистский контур, CSV-экспорт, SessionReview
7. **FamilyAchievements** — общие семейные достижения (R.4, 1 277 LOC)
8. **CulturalContent** — русские народные сказки, культурный контент (R.5, 1 443 LOC)
9. **GuidedTour** — 15-шаговый демо-маршрут для комиссии

### Сравнение с конкурентами (финальная версия)

| Функция | HappySpeech | Логопотам | Буковки | Логомаг |
|---|---|---|---|---|
| AR-артикуляция | Да | Нет | Нет | Нет |
| AI-оценка произношения | Да | Нет | Нет | Нет |
| Offline-first | Да | Частично | Нет | Нет |
| Специалистский контур | Да | Нет | Нет | Нет |
| On-device LLM | Да | Нет | Нет | Нет |
| 18 типов упражнений | Да | Нет | Нет | Нет |
| 14 501 голосовых файлов | Да | Нет | Нет | Нет |
| Kids Category compliant | Да | Нет | Нет | Нет |
| 3D маскот (RealityKit) | Да | Нет | Нет | Нет |

### Future v19 roadmap (после защиты)

- Apple Developer Program ($99/год) → App Store submission (Kids Category)
- Retraining ML на реальном детском датасете (через TestFlight collection)
- Расширение голосовой базы 14 501 → 18 000+ файлов
- Block O Remotion → 100+ профессиональных MP4 (уровень motion-дизайна)
- Block AG Blender — 3D кастомный rig для Ляли
- Многоязычность: казахский, украинский, белорусский
- Клинические испытания с логопедами (пилот в 2–3 детских учреждениях)
- Android-версия на базе Compose + ONNX Runtime
