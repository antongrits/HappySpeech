# HappySpeech

> Русскоязычное офлайн-приложение для коррекции и развития речи у детей 5–8 лет.
> A Russian-language, offline-first iOS app for speech correction and language
> development in children aged 5–8.

[Русский](#happyspeech--русский) · [English](#happyspeech--english)

---

# HappySpeech — Русский

**HappySpeech** — детское логопедическое iOS-приложение (Apple Kids Category, offline-first).
Методическая основа — классическая русская логопедия (Филичева, Чиркина, Ткаченко,
Картушина). Приложение помогает ребёнку поставить и автоматизировать звуки русского языка,
развить фонематический слух, расширить словарь, поработать над просодикой и дыханием и
перейти к связной речи — **полностью без подключения к интернету**.

Весь обучающий контент — тексты, аудио, иллюстрации, ML-модели — вшит в приложение при
сборке, поэтому ядро работает офлайн. Firebase используется только для опциональной
синхронизации прогресса между устройствами родителя и ребёнка.

Три контура: **детский** (игровой, с маскотом «Ляля»), **родительский** (аналитика
прогресса, дневник речи) и **специалистский** (скрининг, оценка, отчёты). Скрытый
`AdaptivePlannerService` собирает дневной маршрут упражнений с учётом усталости и
интервальных повторений.

## Возможности
- **Постановка звуков:** 4 группы (свистящие С/З/Ц, шипящие Ш/Ж/Ч/Щ, соноры Р/Рь/Л/Ль,
  заднеязычные К/Г/Х) × 14 этапов; on-device оценка качества звука (Core ML PronunciationScorer).
- **30+ игровых механик:** «Слушай и выбирай», минимальные пары, бинго, ритм, дыхание,
  слоговая улитка, звуковой детектив, словообразование, «Чей хвост», «Четвёртый лишний» и др.
- **Словарь и грамматика:** 20 лексических тем, согласование рода/числа/падежа, конструктор слогов.
- **Связная речь:** пересказ, рассказ по картинкам, описание по плану-схеме (Ткаченко), ASR-оценка.
- **Просодика и дыхание:** интонация, темп, логоритмика (CoreMotion), караоке-питч (YIN),
  спектрограмма в реальном времени (vDSP FFT) — ребёнок «видит» свой звук.
- **AR-артикуляция:** ARKit Face Tracking — внешние блендшейпы для тренировки уклада.
- **Распознавание речи:** WhisperKit + ансамбль, подстройка под детский голос.
- **Родитель:** аналитика прогресса (Swift Charts), дневник речи (шифрование AES-GCM),
  чат со специалистом, семейные голосовые записи.
- **Специалист:** скрининг, формальная оценка (Левина/Архипова), отчёты.
- Маскот «Ляля» с профессиональной озвучкой (GCP Chirp3-HD); обучающие видео-мультики.

## Технологии
SwiftUI 6 · Swift 6 (strict concurrency) · Clean Swift (VIP) · Realm · Firebase
(Auth/Firestore/Storage/App Check/Functions/Remote Config/FCM) · WhisperKit · Core ML ·
MLX (Qwen2.5-1.5B on-device) · ARKit · Accelerate/vDSP · Swift Charts · Pow.

## Архитектура
`App` (DI-контейнер, координатор) · `Core` · `DesignSystem` (токены + компоненты) ·
`Features` (Clean Swift VIP) · `Services` · `Data` (Realm) · `Content` (контент-движок) ·
`ML` · `Sync` · `Resources`. Фичи обращаются к данным/ML только через протоколы сервисов.

## Сборка и запуск
```bash
brew install xcodegen swiftlint
xcodegen generate
open HappySpeech.xcodeproj
# или из командной строки:
xcodebuild -project HappySpeech.xcodeproj -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Тесты
```bash
xcodebuild test -project HappySpeech.xcodeproj -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```
Юнит (XCTest/Swift Testing), snapshot (light+dark), UI-тесты (XCUITest).

## Приватность и COPPA
Offline-first; никаких сторонних трекеров, рекламы и аналитических SDK. Детское аудио
обрабатывается **на устройстве** и не загружается на сервер. Внешние ссылки — только за
parental gate. Приложение — педагогическая поддержка, не медицинская диагностика.

---

# HappySpeech — English

**HappySpeech** is a Russian-language, offline-first iOS app for speech correction and
language development in children aged 5–8. Built for the Apple Kids Category and grounded
in classical Russian speech-therapy methodology (Filicheva, Chirkina, Tkachenko,
Kartushina). It helps a child set and automate the sounds of Russian, develop phonemic
hearing, expand vocabulary, work on prosody and breathing, and move to connected speech —
**entirely without an internet connection**.

All learning content — text, audio, illustrations, and ML models — is bundled at build
time, so the core experience runs offline. Firebase is used only for optional cross-device
progress sync between a parent's and a child's device.

Three circuits: **child** (playful, with the «Lyalya» mascot), **parent** (progress
analytics, speech-growth diary), and **specialist** (screening, assessment, reports). A
hidden `AdaptivePlannerService` composes each child's daily route with fatigue awareness
and spaced repetition.

## Features
- **Sound production:** 4 groups (whistling, hissing, sonorant, velar) × 14 stages;
  on-device sound-quality scoring (Core ML PronunciationScorer).
- **30+ game mechanics:** listen-and-choose, minimal pairs, bingo, rhythm, breathing,
  syllable snail, sound detective, word formation, «Whose tail», «Odd one out», and more.
- **Vocabulary & grammar:** 20 lexical themes, case/number/gender agreement, syllable builder.
- **Connected speech:** retelling, picture stories, plan-schema description (Tkachenko), ASR scoring.
- **Prosody & breathing:** intonation, tempo, logorhythmics (CoreMotion), karaoke pitch (YIN),
  real-time spectrogram (vDSP FFT) — the child *sees* their sound.
- **AR articulation:** ARKit Face Tracking — external blendshapes for posture practice.
- **Speech recognition:** WhisperKit + ensemble, tuned for children's voices.
- **Parent:** progress analytics (Swift Charts), encrypted speech diary (AES-GCM), chat
  with a specialist, family voice recordings.
- **Specialist:** screening, formal assessment (Levina/Arkhipova), reports.
- «Lyalya» mascot with professional voice-over (GCP Chirp3-HD); educational cartoon videos.

## Tech stack
SwiftUI 6 · Swift 6 (strict concurrency) · Clean Swift (VIP) · Realm · Firebase
(Auth/Firestore/Storage/App Check/Functions/Remote Config/FCM) · WhisperKit · Core ML ·
MLX (on-device Qwen2.5-1.5B) · ARKit · Accelerate/vDSP · Swift Charts · Pow.

## Architecture
`App` (DI container, coordinator) · `Core` · `DesignSystem` (tokens + components) ·
`Features` (Clean Swift VIP) · `Services` · `Data` (Realm) · `Content` (content engine) ·
`ML` · `Sync` · `Resources`. Features reach data/ML only through service protocols.

## Build & Run
```bash
brew install xcodegen swiftlint
xcodegen generate
open HappySpeech.xcodeproj
# or from the command line:
xcodebuild -project HappySpeech.xcodeproj -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Testing
```bash
xcodebuild test -project HappySpeech.xcodeproj -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```
Unit (XCTest/Swift Testing), snapshot (light+dark), and UI tests (XCUITest).

## Privacy & COPPA
Offline-first; no third-party trackers, ads, or analytics SDKs. A child's audio is
processed **on-device** and never uploaded to a server. External links sit behind a
parental gate. The app is pedagogical support, not medical diagnosis.
