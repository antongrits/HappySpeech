# HappySpeech

**HappySpeech** — русскоязычное iOS-приложение для коррекции и развития речи у
детей 5–8 лет. Полностью offline-first, выпущен под Apple Kids Category,
методически основан на классической российской логопедии (Филичёва, Чиркина,
Ткаченко, Картушина).

> Дипломный проект, факультет MMF БГУ, 2026.

---

## Содержание

- [Краткий обзор](#краткий-обзор)
- [Целевая аудитория](#целевая-аудитория)
- [Возможности](#возможности)
- [Технологический стек](#технологический-стек)
- [Архитектура](#архитектура)
- [ML-модели](#ml-модели)
- [Требования к окружению](#требования-к-окружению)
- [Установка и сборка](#установка-и-сборка)
- [Запуск тестов](#запуск-тестов)
- [Структура репозитория](#структура-репозитория)
- [Контент-движок](#контент-движок)
- [Локализация](#локализация)
- [Доступность](#доступность)
- [Конфиденциальность и COPPA](#конфиденциальность-и-coppa)
- [Что приложение НЕ делает](#что-приложение-не-делает)
- [Лицензия](#лицензия)

---

## Краткий обзор

HappySpeech помогает ребёнку 5–8 лет:

- ставить и автоматизировать звуки русского языка;
- развивать фонематический слух;
- расширять предметный, глагольный и признаковый словарь;
- работать над просодией, темпо-ритмом речи, дыханием;
- тренировать пересказ и связную речь.

Родители получают аналитику прогресса, рекомендации, дневник речевого роста,
дневной лимит времени в приложении. Логопеды-специалисты имеют отдельный
интерфейс для скрининга и формального оценивания.

Приложение спроектировано так, чтобы работать **полностью без интернета** —
содержимое (текст, аудио, изображения, ML-модели) встроено в bundle. Firebase
используется для синхронизации прогресса между устройствами родителя и
ребёнка, но необязателен для базовой работы.

---

## Целевая аудитория

| Контур         | Кто пользуется         | Тон UI                                |
| -------------- | ---------------------- | ------------------------------------- |
| **Детский**    | Ребёнок 5–8 лет        | Игровой, тёплый, минимум текста       |
| **Родительский** | Родитель / опекун    | Спокойный, структурированный          |
| **Специалистский** | Логопед, дефектолог | Аналитический, с инструментами оценки |

Адаптивный планировщик (`AdaptivePlannerService`) собирает дневной маршрут
упражнений с учётом усталости ребёнка и интервального повторения.

---

## Возможности

### Звукопроизношение

- 4 группы звуков (свистящие, шипящие, соноры, заднеязычные) × 14 этапов
  коррекции от артикуляции до свободной речи.
- 4 модели `PronunciationScorer` (по группам) для оценки качества произнесённого
  звука прямо на устройстве.
- 12 шаблонов упражнений: `listen-and-choose`, `repeat-after-model`,
  `drag-and-match`, `puzzle-reveal`, `minimal-pairs`, `narrative-quest`,
  `articulation-imitation` и др.

### Лексика и грамматика

- 20 лексических тем × 60–105 слов = **1695 слов** (1680 уникальных) с
  предметным + глагольным + признаковым словарём (методика Филичёвой/Чиркиной).
- `GrammarGame` — согласование падежей, числа, рода.
- `LexicalThemes` — изучение тем «Овощи», «Дикие животные», «Профессии» и т.д.
- `SyllableConstructor` — сборка слов из слогов.
- `WordBank` — личный словарь ребёнка.

### Связная речь

- `Retelling` — пересказ по картинкам и плану.
- `Storytelling` — сочинение рассказа по серии картинок.
- `OralStoryCreator` — устный рассказ по 3 случайным картинкам с
  ASR-транскрипцией и оценкой лексического разнообразия (TTR).
- `ObjectDescriptionMap` — описание предмета по план-схеме из 6–8 пиктограмм
  (методика Ткаченко); ASR + DescriptionCoverageAnalyzer считает покрытие
  пунктов плана.
- `ComprehensionDetective` — игра на понимание услышанного.

### Просодия и темпо-ритм

- `Prosody` — интонация (вопросительная / повествовательная).
- `SpeechTempo` — медленный / быстрый темп.
- `BreatheAndSpeak` — дыхательные упражнения с визуальным метрономом.
- `Logorhythmics` — логоритмика по Картушиной: ребёнок чанает рифмы под
  программный метроном, акселерометр iPhone детектирует тапы/топот, считается
  F1-метрика совпадения с beat-паттерном.
- `KaraokePitch` — пение под эталонный pitch-контур, YIN pitch tracker оценивает
  попадание в ноту.

### Фонематический слух

- `PhonemicListening` — упражнения на различение оппозиционных фонем.
- `SoundTrafficLight` — различение минимальных пар (С/Ш, Р/Л, З/Ж и др.).
- `MinimalPairs` шаблон через `LessonPlayer`.

### Особые модули

- `FingerPlay` («Пальчики-говоруны») — Vision `VNDetectHumanHandPoseRequest`
  распознаёт позу руки ребёнка для пальчиковых игр.
- `LetterTrace` — обводка букв с PencilKit (iPad + Apple Pencil или палец).
- `ARFaceFilter` — ARKit Face Tracking как зеркало для тренировки артикуляции.
- `StutteringModule` — модуль для работы с заиканием (5 техник).
- `SpeechVisualization` — спектрограмма голоса в реальном времени (vDSP FFT).

### Родительский контур

- `ParentHome` — обзор прогресса всех детей в семье.
- `ProgressDashboard` — графики по звукам, неделям, рейтингу.
- `NeurolinguistInsights` — еженедельный отчёт с интерпретацией результатов.
- `SpeechGrowthDiary` — зашифрованный (AES-GCM-256, ключ в Keychain)
  видео-дневник речевых проб ребёнка.
- `ParentVoiceNote` — голосовые заметки родителя ребёнку.
- `ParentGuide` — образовательные карточки о развитии речи.
- `SpeechNormsEncyclopedia` — нормы речевого развития по возрасту.
- `DailyTimeCap` — настраиваемый дневной лимит времени в приложении (без
  Family Controls — внутренний accumulator).

### Специалистский контур

- `Specialist` — рабочее место логопеда.
- `SpecialistAssessment` — формальный скрининг (10 вопросов по Левиной/Архиповой).
- `Screening` — быстрая первичная оценка.
- `LogopedistChat` — текстовый канал «родитель ↔ специалист» (Firebase).

### Семейные и социальные

- `Family`, `FamilyCalendar`, `FamilyLeaderboard`, `FamilyAchievements`,
  `FamilyAwardsCabinet` — многопользовательская семейная модель.
- `SharePlay` — совместное прохождение урока через FaceTime (iOS 15+).
- `SiblingMultiplayer` — игра вдвоём (брат/сестра) на одном устройстве.
- `WeeklyChallenge`, `DailyChallenge`, `DailyStreak` — геймификация.

### Геймификация

- `Rewards`, `RewardShop`, `WorldMap` — персонажи, награды, карта мира.
- `LessonPlayer` — единый движок уроков с маскотом «Ляля».
- Push-уведомления через `UNUserNotificationCenter` и Live Activities через
  `ActivityKit` для долгих уроков.

Подробнее по каждой фиче — в `HappySpeech/Features/<FeatureName>/`.

---

## Технологический стек

| Слой              | Технология                                              |
| ----------------- | ------------------------------------------------------- |
| UI                | SwiftUI 6 + UIKit-обёртки для PencilKit, AR, Camera     |
| Архитектура       | Clean Swift (VIP) + протокол-ориентированный DI         |
| Concurrency       | Swift 6 strict concurrency, async/await везде           |
| Локальная БД      | Realm Swift (schema v12, миграции в `Data/Migrations`)  |
| Облако            | Firebase Auth, Firestore, Storage, App Check, Functions, Performance, Messaging |
| Аутентификация    | Sign in with Apple + Google Sign-In                     |
| Распознавание речи (ASR) | WhisperKit (bundled `whisper-base` русская) + iOS 26 SpeechAnalyzer fallback |
| Голосовая активность (VAD) | SileroVAD (Core ML) + energy-based fallback        |
| AR / Computer Vision | ARKit Face Tracking, Vision Hand Pose, ARFaceAnchor blendshapes |
| Аудио             | AVAudioEngine (16 kHz mono), AVAudioRecorder, AVSpeechSynthesizer |
| DSP               | Accelerate / vDSP (FFT, MFCC, YIN pitch detection)      |
| ML                | Core ML 7 + MLX Swift (Qwen2.5-1.5B-Instruct-4bit, on-device LLM, 839 MB) |
| 3D                | RealityKit (mascot «Ляля» как USDZ + blendshapes)        |
| Анимация          | Lottie (через SwiftPM) + SwiftUI native                  |
| Particles         | SwiftuiParticles (для reward-эффектов)                   |
| Логи              | OSLog (никаких `print` в коде)                           |
| Тесты             | XCTest + Swift Testing + SnapshotTesting                 |
| Линтер            | SwiftLint (`--strict`)                                   |
| Проект            | XcodeGen (`project.yml` → `.xcodeproj`)                  |
| Хранение секретов | KeychainAccess (AES-GCM-256 ключи шифрования контента)   |

### Запрещённые зависимости

- Сторонние трекеры, реклама, Firebase Analytics, Crashlytics — несовместимы с
  Apple Kids Category и COPPA.

---

## Архитектура

Каждая фича — **отдельный модуль по Clean Swift (VIP)**:

```
Features/<FeatureName>/
├── <Feature>View.swift          SwiftUI root (без бизнес-логики)
├── <Feature>Interactor.swift    Бизнес-логика, dispatch запросов
├── <Feature>Presenter.swift     Формирование ViewModel из Response
├── <Feature>Router.swift        Навигация (через AppCoordinator)
├── <Feature>Models.swift        Request / Response / ViewModel
├── <Feature>DisplayLogic.swift  Protocol для View ↔ Presenter
└── Workers/                     Изолированные сервисные вызовы
```

Слои проекта:

```
App/                  @main, AppCoordinator, DI-контейнер AppContainer
Core/                 Базовые утилиты, Logger, Errors, Extensions
DesignSystem/         Tokens (Color/Typography/Spacing/Radius/Shadow/Motion) + 41 HS*-компонент
Shared/               Переиспользуемые view-модификаторы
Features/             83 фичи по Clean Swift VIP
Services/             AudioService, ASRService, ARService, PermissionService,
                      NotificationService, HapticService, SyncService,
                      ContentService, AdaptivePlannerService, AnalyticsService,
                      NetworkMonitor, DailyUsageTracker и др.
Data/                 Realm-модели, репозитории, миграции (schema v12)
Content/              ContentEngine, схемы пакетов, seed-паки JSON
ML/                   Обёртки над WhisperKit / SileroVAD / PronunciationScorer / LocalLLM
Sync/                 Firestore-мост, очередь синхронизации, конфликт-резолвер
Analytics/            Локальная событийная шина (без внешних SDK)
Resources/            Assets.xcassets, звуки, Core ML модели, локализации
```

Правила импорта:

```
Features ─→ DesignSystem, Shared, Core, Services (через протоколы)
Services ─→ Data, ML, Sync, Core
Data      ─→ Core
Sync      ─→ Data, Core
ML        ─→ Core
DesignSystem ─→ Core
```

Features **никогда** не импортируют напрямую `Data`, `ML`, `Sync` — только через
протоколы сервисов из `AppContainer`.

---

## ML-модели

Все модели — bundled, размещены в `HappySpeech/Resources/Models/`. Никаких
runtime-загрузок с сети.

| Модель                                    | Назначение                                   |
| ----------------------------------------- | -------------------------------------------- |
| `PronunciationScorer_hissing.mlpackage`   | Оценка шипящих (Ш, Ж, Ч, Щ)                  |
| `PronunciationScorer_whistling.mlpackage` | Оценка свистящих (С, З, Ц)                   |
| `PronunciationScorer_sonants.mlpackage`   | Оценка соноров (Р, Рь, Л, Ль)                |
| `PronunciationScorer_velar.mlpackage`     | Оценка заднеязычных (К, Г, Х)                |
| `RussianPhonemeClassifier.mlpackage`      | Классификация 42 русских фонем               |
| `Wav2Vec2RuChild.mlpackage`               | Wav2Vec2 fine-tune под детский голос         |
| `SileroVAD.mlpackage`                     | Voice Activity Detection                     |
| `SoundClassifier.mlpackage`               | Классификация звукового окружения            |
| `SpeakerVerification.mlpackage`           | Распознавание «голос ребёнка vs голос родителя» |
| `EmotionDetection.mlpackage`              | Распознавание эмоций ребёнка по голосу       |
| `TonguePostureClassifier.mlpackage`       | Классификация поз языка (по ARKit blendshapes) |
| `LLM/` (Qwen2.5-1.5B-Instruct-4bit)       | On-device LLM через MLX Swift (839 MB)       |
| `Whisper/`                                | WhisperKit русская base-модель               |

---

## Требования к окружению

- macOS 14+
- Xcode 16+ (используется Swift 6)
- iOS 17.0+ (целевая платформа)
- Тестовые симуляторы: iPhone SE (3rd generation), iPhone 17 Pro
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)
- [Pillow](https://pillow.readthedocs.io/) для обработки ассетов (`pip install Pillow`)
- Node.js 20+ (для Firebase Cloud Functions, опционально)

---

## Установка и сборка

```bash
# Склонировать
git clone git@github.com:antongrits/HappySpeech.git
cd HappySpeech

# Сгенерировать .xcodeproj из project.yml
xcodegen generate

# Открыть в Xcode
open HappySpeech.xcodeproj

# Или собрать из командной строки на симуляторе:
xcodebuild \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  build
```

### Firebase (опционально)

Если нужна синхронизация с облаком:

1. Создайте проект в [Firebase Console](https://console.firebase.google.com/).
2. Добавьте iOS-приложение с bundle ID `com.mmf.bsu.HappySpeech`.
3. Скачайте `GoogleService-Info.plist` и положите в `HappySpeech/Resources/`.
   Файл в `.gitignore` — у каждого разработчика свой.
4. Без `GoogleService-Info.plist` приложение работает в offline-режиме без
   синхронизации.

### SwiftLint

```bash
swiftlint --strict
```

Все Swift-файлы должны проходить `--strict` без нарушений. Pre-commit hook
автоматически запускает SwiftLint на изменённых файлах.

---

## Запуск тестов

```bash
# Все тесты на iPhone 17 Pro
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Конкретный класс
xcodebuild test \
  -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:HappySpeechTests/LogorhythmicsTests
```

В проекте ~405 тестов: unit на Presenter/Interactor/Worker'ы + integration на
сервисы + UI-тесты на ключевые экраны + snapshot-тесты на компоненты
DesignSystem.

---

## Структура репозитория

```
HappySpeech/
├── HappySpeech/                       Основное iOS-приложение
│   ├── App/                           @main, AppCoordinator, DI
│   ├── Core/                          Базовые утилиты, Logger, Errors
│   ├── DesignSystem/                  Tokens + 41 HS*-компонент
│   ├── Shared/                        Переиспользуемые модификаторы
│   ├── Features/                      83 фичи (Clean Swift VIP)
│   ├── Services/                      ~25 сервисов
│   ├── Data/                          Realm-модели, миграции, репозитории
│   ├── Content/                       ContentEngine, JSON-паки
│   ├── ML/                            Обёртки над Core ML / WhisperKit / MLX
│   ├── Sync/                          Firebase-мост, очередь, конфликт-резолвер
│   ├── Analytics/                     Локальная событийная шина
│   └── Resources/                     Assets, audio, ML-модели, локализации
├── HappySpeechTests/                  Unit-тесты
├── HappySpeechUITests/                UI-тесты
├── HappySpeechWidgetExtension/        Виджеты экрана «Сегодня»
├── functions/                         Firebase Cloud Functions (TypeScript)
├── docs/                              Документация (privacy, App Store metadata)
├── scripts/                           Build-скрипты
├── project.yml                        XcodeGen конфигурация
├── README.md                          Этот файл
└── CLAUDE.md                          Внутренние инструкции для разработки
```

---

## Контент-движок

- **Схема:** `HappySpeech/Content/Schemas/content-pack.schema.json`
- **Seed-паки:** `HappySpeech/Content/Seed/pack_*.json` (овощи, фрукты,
  животные, профессии, ягоды, деревья, цветы, рыбы, логоритмика, объекты для
  описания, finger play, story creator stimuli и др.)
- **Сборка уроков:** `ContentEngine.swift` собирает `Lesson` из пака через
  комбинаторы шаблонов упражнений.
- **Шаблоны:** 16 шаблонов упражнений, описанных в код-перечислении
  `ExerciseTemplate`.

Все паки бандлятся в `Resources/Audio/Content/` + `Resources/Content/`.

---

## Локализация

Приложение русскоязычное. Все строки — через `String(localized: ...)` со
`String Catalog` (`Localizable.xcstrings`).

Английская локализация присутствует как placeholder для App Store metadata, но
интерфейс ребёнка/родителя пока только русский. Билингвальный модуль
(`BilingualMode`) позволяет ребёнку видеть переводы базовых слов на белорусском
(be-BY) и английском (en-US) через `AVSpeechSynthesizer`.

---

## Доступность

- **Dynamic Type** — поддерживается от `.small` до `.accessibilityLarge`. Каждая
  CTA имеет `.lineLimit(nil)` + `.minimumScaleFactor(0.85)`.
- **Reduce Motion** — анимации заменяются на статичные при
  `@Environment(\.accessibilityReduceMotion) == true`.
- **VoiceOver** — labels и hints на всех интерактивных элементах.
- **WCAG AA contrast** — все цвета DesignSystem проходят 4.5:1 для текста.
- **Haptics** — кастомные паттерны через `CHHapticEngine` для feedback.
- **Touch targets** — ≥56 pt для Kids Category (HIG для детских приложений).

---

## Конфиденциальность и COPPA

- Все звуковые записи ребёнка обрабатываются **только на устройстве**, никуда
  не отправляются.
- Видео-дневник речевого роста шифруется AES-GCM-256, ключ хранится в Keychain
  с access-флагом `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Никаких сторонних трекеров, рекламы, аналитики 3rd-party.
- Все внешние ссылки скрыты за parental gate.
- Дневной лимит времени в приложении настраивается родителем (без iOS Screen
  Time API — внутренний accumulator).
- Apple Kids Category compliant.

---

## Что приложение НЕ делает

Честные границы — критично для App Store и этики продукта:

- ❌ Медицинская диагностика (это педагогическая поддержка).
- ❌ Клиническое распознавание нарушений речи (это интерпретируемые эвристики).
- ❌ Полное tongue-tracking внутри рта (ARKit даёт только внешние blendshapes).
- ❌ Гарантия клинических результатов.
- ❌ Замена живого логопеда.
- ❌ Сторонние трекеры и аналитика.
- ❌ Реклама и 3rd-party in-app покупки.
- ❌ Открытые внешние ссылки без parental gate.

---

## Лицензия

Дипломный проект. Все права принадлежат автору. Использование исходного кода
вне рамок академической работы — по согласованию.
