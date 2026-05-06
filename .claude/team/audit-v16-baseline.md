# HappySpeech — Audit v16 Baseline (May 7, 2026)

> Этот файл — **полный read-only deep-audit** проекта HappySpeech перед написанием Plan v16.
> Аудит выполнен Opus 4.7 1M (sequential, ~20 минут tool calls), 9 планов прочитаны.
> Записан в plan-файл (Plan Mode), пользователь может скопировать в `.claude/team/audit-v16-baseline.md`.

---

## Executive Summary

**Что критично (P0):** ВСЕ 464 illustrations RGB без alpha (0% RGBA — план v15 требовал 100% RGBA), все 9 главных Core ML моделей по-прежнему stubs (≤330 KB при ожидаемых 2–370 MB), 46 файлов в Features/ содержат эмодзи в production UI (явно запрещено), 13 крупных USDZ остались логопедически нерелевантными (animal_hummingbird 20 MB и т.д. не заменены), HealthKit refs остались в 3 файлах в виде комментариев (надо удалить полностью), GuidedTour без VIP, only 6 экранов из 488 используют ParentalGate, only 16 из 488 экранов содержат Lyalya/3D-героя — большинство экранов БЕЗ героя, only 1 файл из 488 использует `@Environment(\.colorScheme)` — Light/Dark адаптация поверхностна.

**Что приемлемо (соответствует v15):** 0 EN-keys (только русский, sourceLanguage=ru), 0 print() statements, 0 TODO/FIXME, ≈1 force unwrap, 12 189 audio .m4a (превышает target 12 000), 58 Lottie real (no python-lottie), 3 Speech Service wrappers созданы (Ensemble/Speaker/Emotion ~830 LOC total), heuristic fallback убран из PronunciationScorerLive, 9 hex-color literals только в DesignSystem (Features почти чисты, кроме CustomizationViewCards и LyalyaSceneView), 123/488 файлов используют ColorTokens, 102/488 файлов используют SF Symbols, Bundle ID + Firebase verified.

**Общая оценка готовности к Plan v16:** проект на **65–70%** от заявленной production-quality крупной компании. v15 закрыл inventory-задачи (services, files, sizes), но **визуальная глубина и intentional UI design — поверхностные**. Требуется v16: regen всех illustrations, real ML training (single biggest gap), full asset replacement non-relevant USDZ, mascot-on-every-screen, Light/Dark systematic audit, parental-gate full coverage, GuidedTour VIP, удаление 46 эмодзи-файлов, modern iOS-26 affordances (Live Activities/Dynamic Island/Siri Intents) verified end-to-end.

---

## Section 1 — Все требования пользователя из 9 планов (UNION)

### Базовые правила (из всех планов)
- Только русский язык (sourceLanguage=ru, 0 en keys, CFBundleDevelopmentRegion=ru, CFBundleLocalizations=[ru])
- App display name = `HappySpeech`, Bundle ID = `com.mmf.bsu.HappySpeech` (НЕ менять)
- App Store category = `public.app-category.education`
- iOS 17.0 minimum, iOS 26 features, версия 1.0.0 (НЕ повышать)
- Только iPhone (TARGETED_DEVICE_FAMILY=1), Mac Designed for iPhone разрешён ТОЛЬКО для self-test
- Portrait primary, landscape ТОЛЬКО для AR-игр
- Симулятор iPhone SE (3rd gen) primary, НЕ скачивать iOS 18.6
- Adaptive под iPhone SE (320pt width) во всех экранах
- Light + Dark обе темы everywhere
- RealmSwift = `Embed & Sign`

### Запрещено (no paid Apple Developer)
- HealthKit, TestFlight upload, App Store submission, APNs Push, Apple Sign-in, Crashlytics, Analytics, AdMob, 3rd-party trackers
- Live Activities/Widget Extension distribute (локально OK)

### Firebase (`antongric132@gmail.com` → `happyspeech-dfd95`)
- Auth (Email + Google + Anonymous), Firestore + Cloud Functions, Storage, App Check (DeviceCheck enforce), Remote Config, FCM (parent-only opt-in COPPA), Performance Monitoring (parent-only)
- Использовать ВСЕ Firebase сервисы по максимуму
- Если что-то нужно настроить в Firebase Console — делать самому через MCP/Chrome MCP без вопросов

### Оркестрация и агенты
- 16 локальных субагентов в `.claude/agents/` — обязательные исполнители (никогда не писать код вручную, исключение — config files)
- 48+ скиллов + создавать новые через `skill-creator` где требуется
- MCPs: Firebase, Xcode, Simulator, Apple Docs, Context7, GitHub, HuggingFace, Lottiefiles, Token Savior, Figma, Computer Use, Chrome
- ТОЛЬКО ПОСЛЕДОВАТЕЛЬНЫЕ АГЕНТЫ — никаких параллельных
- `run_in_background: true` — ОДИН фоновый агент одновременно
- Default model: Sonnet @ high (claude-sonnet-4-6 effort high)
- Сложные задачи (deep audit, code review, архитектура) — Opus 4.7 1M Extra high
- Никогда не писать код вручную (исключение: project.yml, .firebaserc, file ops, .claude/team/*.md)
- Rate limit → ждать reset

### Датасеты для ML
- Компактные ≤3ч на группу
- Валидация: 16 kHz mono, SNR ≥15 dB, silence ratio <20%, 0 clipping
- Синтетика только augmentation (pitch + formant), НЕ TTS как ML вход
- Validation accuracy ≥85%
- Real-trained Core ML — ВСЕ модели РЕАЛЬНО обучены, не stubs

### UI требования (из всех планов)
- Красивый и современный UI на профессиональном уровне (как в крупной компании, Apple Design Award level)
- Liquid Glass `.glassEffect()` iOS 26+, `.ultraThinMaterial` fallback iOS 17
- Real Lottie (НЕ procedural python-lottie) — кастомные Lottie запрещены
- HD Illustrations через FLUX-1-schnell (НЕ python PIL procedural)
- Никакой генерации картинок/иллюстраций/AppIcon/анимаций питоновским скриптом
- Профессиональная Lyalya voice (edge-tts SvetlanaNeural -16 LUFS), не Siri TTS
- Remotion videos professional motion-designer level (не procedural shapes)
- AppIcon по Apple HIG: full bleed, НЕТ внутренних закругленных рамок (iOS делает закругления)
- Картинки/illustrations НЕ должны иметь форму квадратов/прямоугольников — закруглять под iOS, прозрачный фон
- Ни одного экрана без анимации/иллюстрации/voice
- ClaudeDesign reference: `happyspeech-design/project/` — единая UI тема
- Modern stylistics: SF Symbols 6, MeshGradient, matchedGeometryEffect, hero transitions, AnimationPhase
- Не должно быть много пустого места на экранах
- Изучать best iOS design practices в интернете (researcher агент)

### Герои (3D / 2D)
- 3D героев — primary через USDZ + RealityKit blendshapes
- 3D героев БЕЗ заднего фона (прозрачный, не розовый прямоугольник)
- 2D героев убрать совсем (просто картинки не очень красиво)
- Если 2D — никаких bounce/scale/rotation, только entrance fade
- Анимации только для 3D на профессиональном уровне через RealityKit blendshapes
- Custom Lyalya.riv defer post-v1.0 — заменён на Custom 3D USDZ + RealityKit blendshapes
- Если есть библиотека для professional 3D героев (Blender bpy, Reality Composer Pro CLI) — создать skill
- Должно быть видно что работала целая команда разработчиков

### Анимации
- Удалить procedural particles/анимации в SwiftUI коде
- Real Lottie только LottieFiles community CC0/MIT, hand-crafted Bodymovin export
- Кастомные Lottie запрещены
- SwiftUI tools (matchedGeometryEffect, MeshGradient, hero transitions, AnimationPhase) предпочитаются над избыточными видео
- Reduce Motion compliance везде

### Видео
- Real Remotion (TypeScript/React) либо CC0 от Pexels.com / Mixkit / Coverr
- Не procedural shapes
- НЕ избыточно много видео — только там где нужно и уместно
- Лучше больше анимаций в интерфейсе чем bulk-видео
- Если возможно создать в Blender (через skill) — делать профессионально

### Speech Analyzer (приложение должно понимать любого ребёнка)
- НЕ использовать обычную Speech-to-Text API
- Фонетический анализ (CMU Pronouncing Dictionary, IPA, Phonemizer, Kaldi, DeepSpeech)
- Анализ спектрограммы через ML (TensorFlow Audio Recognition, Wav2Vec2, DeepSpeech)
- Спектрограммы — нейросеть для сравнения с эталонными
- G2P dictionary русские фонемы (russian_phonemes.json 7712 entries)
- Real-trained Core ML модели:
  - Real Wav2Vec2 Russian (jonatasgrosman/wav2vec2-large-xlsr-53-russian → coremltools int8 ~370 MB)
  - Real SileroVAD CNN (snakers4/silero-vad → ~2 MB)
  - Real RussianPhonemeClassifier Conv1d-BiLSTM (≥85% acc)
  - Real SpeakerVerification ECAPA-TDNN (~30 MB)
  - Real EmotionDetection Conv1d-LSTM (≥75% acc)
  - Real TonguePostureClassifier (real children data)
  - Real PronunciationScorers × 4 групп (MFCC + Conv1D, ≥88% acc each)
- Spectrogram visualizer real-time во всех games произношения
- Ensemble ASR: Whisper + Wav2Vec2 + RussianPhonemeClassifier weighted voting
- Tier A (kid on-device, lightweight) и Tier B (parent/specialist, full accuracy)

### Computer Vision
- Real-time CV встроено профессионально
- ARKit Face Tracking (ARFaceAnchor blendshapes 76 landmarks)
- Apple Vision (VNDetectFaceLandmarksRequest 76 точек)
- MediaPipe Face Mesh attempt (если coremltools конвертируется — иначе ADR defer)
- TonguePostureClassifier CNN, Lip Symmetry Analyzer, Air Stream Detector через vDSP
- Real-time lip-sync mascot в ARMirror (ARFaceAnchor.jawOpen → LyalyaRealityKitView.mouthOpen)
- ARKit Body Tracking (ARBodyTrackingConfiguration TrueDepth iPhone X+) в PoseSequence

### Bundle size
- Target = РОВНО ~1.5 GB через ГЛУБИНУ (не bulk-видео и не bulk-картинки)
- ГЛУБИНА = real ML модели + USDZ logopedic-relevant + voice phrases + SPM libraries + DocC catalog
- "Ты не должен останавливаться пока не приблизишься к 1.5 ГБ"

### Manual audit (100% покрытие)
- Полный аудит всех 60+ экранов (фактически 91+ *View.swift)
- Каждую кнопку/слово/видео/картинку/функцию/аудиозапись проверять
- Каждый 3D hero через RealityKit Preview render → Read
- Все скриншоты screenshot tour — Read tool каждый
- Не выборочно — полный аудит каждого second-tier экрана
- Покрытие 100%, ничего не пропускать
- После аудита — приложение полностью готово на 100%

### SPM libraries (расширение)
- Использовать максимум полезных и крупных библиотек через SPM
- Pulse (kean/Pulse), KeychainAccess, swift-collections, swift-async-algorithms, Down (уже есть)
- Lottie iOS, Rive, WhisperKit, Realm, GoogleSignIn, Firebase, MLX Swift (уже есть)
- Создать `spm-library-discovery-skill`

### Cleanup
- Удалить временные файлы из /Users/antongric/Downloads/
- Больше ничего в Downloads не писать
- Временные скрипты внутри проекта (`_workshop/`) — после использования удалять
- HealthKit полностью удалить из кода (не оставлять comments)
- Удалить ненужные ассеты/dead code
- Анализ через `mcp__token-savior__find_dead_code`

### Git
- Author = antongrits только
- `Co-Authored-By: Claude` убрать только из новых v15+ коммитов
- Старая история (228 commits) НЕ rewrite (destructive)
- Каждый коммит → push в main сразу обязательно
- BUILD SUCCEEDED перед каждым commit
- Russian-only страж перед каждым commit
- Conventional commits (feat/fix/chore/docs/refactor)

### Конкуренты + новые функции
- Обогнать всех русских конкурентов (Логопотам, Буковки, Логомаг)
- Иметь все функции конкурентов + кастомные оригинальные
- Дальше анализировать в интернете чего не хватает в подобных приложениях
- Чего хотят пользователи — внедрять самому
- Расширять функции и количество экранов

### "Как будто разрабатывала команда крупной компании"
- Production-quality на уровне Apple Design Award
- Объёмное приложение (≥1.4 GB через depth)
- Богатый функционал, все best practices
- Должно быть видно что работала целая команда разработчиков

### Apple HIG compliance
- Полное соответствие гайдлайнам Apple
- Touch targets ≥56pt kids, ≥44pt adults
- VoiceOver labels на 100% interactive
- Dynamic Type Small → AccessibilityLarge
- Reduced Motion compliance
- WCAG AA contrast ≥4.5:1
- Parental Gate для external links (Privacy/Terms/GitHub)
- Kids Category requirements (COPPA strict)

### Internet research
- Если что-то не знаю — искать в интернете перед действием
- researcher агент для web-поиска
- mcp__Control_Chrome__* для browser-based settings
- Изучать Apple docs (mcp__apple-docs__*)
- HuggingFace, GitHub community

### Самостоятельность
- "Ты должен сделать всё сейчас сам"
- Не спрашивать "Sample image generation OK?" — делать самому
- Сделать так, чтобы пользователю ничего не оставалось проверять/доделывать
- Если что-то нужно делать в браузере — делать самому без вопросов

### Pre-existing issues (явный список, must fix)
- AppIcon переgenerate (если не доволен)
- 3D героев на онбординге — розовый прямоугольник убрать (transparent bg)
- Картинки квадраты/прямоугольники — закруглять под iOS-style
- Много пустого места — заполнить meaningful content
- Кастомные Lottie некрасивые — удалить (только real)
- ClaudeDesign не везде — единая тема
- UI несовременный, видео некрасивые, анимации некрасивые, картинки некрасивые
- Сейчас очень много моментов не закрыто и сделано поверхностно

### Запрещено для эмодзи в UI
- Эмодзи в UI явно запрещены ("удешевляет интерфейс")
- Использовать SF Symbols или иллюстрации

### Запрещено для тестов
- НЕ запускать xcodebuild слишком тяжело без необходимости
- Снапшоты должны иметь стабильные thresholds (0.05–0.10)

---

## Section 2 — Текущее состояние проекта (метрики)

| Metric | Current (v15 ship) | Target v16 | Status | Notes |
|---|---|---|---|---|
| Bundle Resources | **1.1 GB** | ≥1.4 GB через depth | ⚠️ | Audio 195 MB + Models 654 MB + ARAssets 163 MB + Videos 47 MB + Animations 3.8 MB |
| Models real-trained size | **1.0 MB** sum (mlmodel) | ~415 MB (depth) | ❌ | ALL stubs, weights bin missing or empty |
| Wav2Vec2RuChild.mlpackage | **328 KB** mlmodel | ~370 MB INT8 | ❌ STUB | планировалось B.1 v15, не выполнено |
| Wav2Vec2RuChildLogopedic | 16 KB mlmodel | ~370 MB INT8 | ❌ STUB |  |
| SileroVAD.mlpackage | 12 KB mlmodel | ~2 MB CNN | ❌ STUB | "energy stub" comment |
| RussianPhonemeClassifier | 16 KB mlmodel | ~10 MB Conv1d-BiLSTM | ❌ STUB |  |
| TonguePostureClassifier | 4 KB mlmodel | ~3 MB | ❌ STUB |  |
| PronunciationScorer × 4 | 12 KB mlmodel each | ~3 MB each | ❌ STUB |  |
| SpeakerVerification | 12 KB mlmodel | ~30 MB d-vector | ❌ STUB |  |
| EmotionDetection | 16 KB mlmodel | ~5 MB Conv1d-LSTM | ❌ STUB |  |
| SoundClassifier | 12 KB mlmodel | ~5 MB | ❌ STUB |  |
| Whisper bundled | base+small | tiny only (move base/small remote) | ⚠️ | 604 MB bulk |
| Total Swift LOC | **145 174** LOC | ≥150 000 | ⚠️ | 623 swift files |
| Feature *View.swift | **118** files | ≥120 | ✅ | |
| Feature *Interactor.swift | **63** files | 70+ | ⚠️ | 8 stubs <200 LOC |
| Largest View | **ChildHomeViewComponents** 1142 LOC | ≤700 LOC | ⚠️ | 13 views >600 LOC |
| Stub Interactors <200 LOC | **8** files | 0 | ⚠️ | ButterflyCatch 69 / BreathingAR 74 / SoundAndFace 75 / HoldThePose 84 / MimicLyalya 115 / OfflineMiniGame 121 / ARMirror 129 / PoseSequence 188 |
| Stub Interactors <250 LOC | **9** files | 0 | ⚠️ | + ARZone 233 |
| EN-keys в Localizable.xcstrings | **0** | 0 | ✅ | source=ru, 2239 ru keys |
| Files using String(localized:) | 258/488 (53%) | 100% | ⚠️ | 230 files без localized |
| print() statements | **0** | 0 | ✅ |  |
| TODO/FIXME/HACK | **0** | 0 | ✅ |  |
| Force unwraps in production | **≈1** | 0 | ✅ | acceptable |
| Files with emojis (Features/) | **46** files | 0 | ❌ | пользователь явно запретил |
| Files with hex colors literals | 4 (Features/) + 9 (DesignSystem) | 0 in Features | ⚠️ | CustomizationViewCards = 30+ Color(red:..) |
| Files using ColorTokens | **123/488** (25%) | ≥90% | ❌ | 75% Features НЕ используют DesignSystem |
| Files using SF Symbols | 102/488 (21%) | ≥80% | ❌ | большинство экранов без icons или эмодзи |
| Files using GeometryReader/minScaleFactor | **94/488** (19%) | ≥80% | ❌ | iPhone SE adaptation поверхностна |
| Files using @Environment(.colorScheme) | **1/488** (!) | ≥40% | ❌ | Light/Dark адаптация поверхностна |
| Files using Lyalya/3D mascot | 16/488 (3%) | ≥50 экранов | ❌ | большинство БЕЗ героя |
| Files using ParentalGate | **6** | ≥10 (все external links) | ⚠️ |  |
| illustrations (PNG total) | **464** | ≥464 RGBA | ❌ | |
| illustrations RGB (no alpha) | **464/464** (100%) | 0 | ❌ КРИТИЧНО | план v15 требовал 100% RGBA, НЕ ВЫПОЛНЕНО |
| Lottie animations | 58 (real) | ≥60 real | ✅ | no python-lottie |
| Audio .m4a files | **12 189** | ≥12 000 | ✅ | exceeded target |
| Audio total size | 195 MB | ≥150 MB | ✅ |  |
| Videos .mp4 | **77** files, 47 MB | ≤80 (curated) | ⚠️ | многие procedural Remotion |
| USDZ ARAssets total | 27, 163 MB | ≥30 logopedic-relevant | ⚠️ | 13 нерелевантных нужно заменить |
| USDZ нерелевантных (animal_*, sport_*, kitchen_*) | **13** | 0 | ❌ | план v15 F.4 не выполнен |
| USDZ logopedic relevant | 14 (apple/bell/snake/cup/truck/whale/rocket/mouse/fox/drum) | ≥20 | ⚠️ | 10 из них 8 KB stubs (placeholder) |
| Test files | 119 (HappySpeechTests) + 8 UI | ≥130 | ⚠️ | snapshot tests embedded в Tests/Snapshot |
| Snapshot reference PNGs | 403 | ≥500 | ⚠️ | |
| Coverage | unknown (need rerun) | ≥90% Services+VM | ⚠️ |  |
| HealthKit refs in code | **3** files (comments only) | 0 (полная деаннотация) | ⚠️ | хоть и закомментированы — `grep HealthKit` всё ещё non-zero |
| GuidedTour VIP | Coordinator-only (0 Interactor/Presenter/Router/DisplayLogic) | VIP или documented as Coordinator-flow | ❌ | план v15 D.3 не выполнен |
| Speech Service wrappers | 3 created (Ensemble 267 / Speaker 289 / Emotion 275 = 831 LOC) | ✅ | ✅ |  |
| /Users/antongric/Downloads/HappySpeech | удалён (не нашёл duplicate) | удалён | ✅ |  |
| _workshop/ | удалён локально (нет в проекте) | удалён | ✅ |  |
| /Users/antongric/Downloads/ остаточный мусор | 14 неотносящихся проектов + Гайд по Review .docx | ничего | ⚠️ | пользователь сказал НЕ писать в Downloads, но dir содержит другие проекты — оставить |
| AppIcon | iOS 17+ format, 3 appearance | full bleed Apple HIG | ⚠️ | требует визуальной inspection |
| Spotlight indexing | реализован (App + AppContainer) | ✅ | ✅ |  |
| Siri App Intents | unknown (требует поиска) | ≥5 intents | ? |  |
| Live Activities | unknown | реализованы | ? |  |
| AR features | 23 files используют AR | ≥25 | ✅ |  |
| Default model в коде | claude-sonnet-4-6 (cto, code-reviewer на opus) | sonnet @ high default, opus для сложных | ✅ |  |

---

## Section 3 — КРИТИЧЕСКИЕ проблемы (P0)

### P0.1 — 464 illustrations RGB (no alpha) — 100% failure of v15 plan E
**v15 план E** требовал regen всех 254 RGB illustrations через FLUX-1-schnell + rembg для guaranteed alpha. **Текущее состояние: 464/464 PNG в `Assets.xcassets/Illustrations/` имеют pixelDepth=24 (RGB)**, что значит ВСЕ illustrations имеют непрозрачный фон / rectangle border. Это нарушает прямое explicit user requirement: "3d и 2d герои должны быть без заднего фона". Регресс относительно v15 (который сообщал 192 RGBA + 254 RGB).

**Action v16:** новый Block — regen ВСЕХ 464 illustrations через `professional-illustration-generator` skill с явным "transparent background, isolated subject, no rectangle frame, alpha channel" prompt, post-process через `rembg`, verify `sips -g pixelDepth` returns 32 (RGBA). Batch 50 per commit.

### P0.2 — 9 главных Core ML моделей stubs (≤330 KB)
**v15 Block B** требовал real-trained модели (Wav2Vec2 ~370 MB INT8, SileroVAD ~2 MB CNN, RussianPhonemeClassifier ≥85% acc, SpeakerVerification ~30 MB, EmotionDetection ~5 MB, PronunciationScorer × 4 ~3 MB each). **Текущее состояние: ВСЕ mlmodel файлы ≤330 KB** (`Wav2Vec2RuChild` 328 KB при ожидаемых 370 000 KB). Сам `_workshop/` отсутствует — обучение не было запущено. Это ключевой провал v15: пользователь явно сказал "приложение должно понимать любого ребёнка даже плохо произносящего" → требует РЕАЛЬНЫХ моделей.

**Action v16:** новый Block с приоритетом — `ml-engineer` через `wav2vec2-coreml-russian` / `russian-asr-pipeline` / `speaker-verification-coreml` / `emotion-detection-coreml` / `gigaam-coreml-russian` skills делает РЕАЛЬНОЕ обучение. Это самая большая P0 задача. На каждую модель — ≤3ч tier dataset + augmentation + train на MPS + coremltools INT8 conversion. Validation accuracy в `.claude/team/ml-models.md` per model.

### P0.3 — 46 файлов в Features/ содержат эмодзи
**Пользователь явно запретил эмодзи в UI** ("удешевляет интерфейс"). Найдено 46 файлов в Features/ с эмодзи (диапазон 😀-🛿, 🌀-🗿, 🚀-🛸). Список:
- `Demo/DemoView.swift`, `Demo/DemoPresenter.swift`, `Demo/DemoInteractor.swift`, `Demo/DemoDisplayLogic.swift`
- `Settings/SettingsPresenter.swift`
- `SharePlay/SharePlaySessionView.swift`
- `Rewards/RewardsView.swift` (через Models), `Rewards/RewardsPresenter.swift`, `Rewards/RewardsInteractor.swift`, `Rewards/RewardsModels.swift`
- `Family/FamilyHomeModels.swift`, `Family/ProfileEditorModels.swift`
- `SessionComplete/SessionCompleteInteractor.swift`
- `OfflineState/OfflineMiniGameView.swift`
- `Permissions/PermissionFlowView.swift`
- `Common/Stories/StoryLibrary.swift`
- `SessionShell/SessionShellPresenter.swift`
- `LessonPlayer/PuzzleReveal/{View,Interactor}.swift`
- `LessonPlayer/Memory/MemoryModels.swift`
- `LessonPlayer/VisualAcoustic/{View,Interactor,Models}.swift`
- `LessonPlayer/ArticulationImitation/Models.swift`
- `LessonPlayer/StoryCompletion/StoryCompletionInteractor.swift`
- `LessonPlayer/Sorting/SortingModels.swift`
- `LessonPlayer/DragAndMatch/DragAndMatchModels.swift`
- `LessonPlayer/Rhythm/{View,Interactor}.swift`
- `LessonPlayer/MinimalPairs/MinimalPairsModels.swift`
- `LessonPlayer/RepeatAfterModel/RepeatAfterModelModels.swift`
- `LessonPlayer/NarrativeQuest/NarrativeQuestInteractor.swift`
- `LessonPlayer/Bingo/BingoView.swift`
- `SessionHistory/SessionHistoryView.swift`
- `ProgressDashboard/ProgressDashboardView.swift`
- `ChildHome/{View,Interactor,Models}.swift`
- `AR/HoldThePose/HoldThePoseView.swift`
- `AR/SoundAndFace/SoundAndFaceView.swift`
- `AR/ARMirror/ARMirrorView.swift`
- `AR/ARStoryQuest/{View,Models}.swift`
- `AR/Mascot3D/LyalyaRealityView.swift`
- `AR/MimicLyalya/{View,Presenter}.swift`
- `WorldMap/{View,Interactor,Presenter,IslandsCanvas}.swift`
- `Onboarding/{Models,FlowViewComponents2}.swift`

**Action v16:** новый Block — `code-reviewer` Opus per-file scan → emoji → SF Symbol mapping (`mcp__apple-docs__*` для SF Symbol catalog) → `ios-developer` replace. Каждый emoji char → semantic SF Symbol (например 🔥 → "flame.fill", ✅ → "checkmark.circle.fill", 🎯 → "target"). Verify через `grep -rln '[😀-🛿]' HappySpeech/Features` returns 0.

### P0.4 — HealthKit refs остались (план v13/v15 explicit)
**Пользователь явно сказал "HealthKit нельзя использовать".** v15 план A.1 требовал полное удаление + verify `grep -c HealthKit` = 0. **Текущее состояние:** `grep -rln HealthKit HappySpeech/` возвращает 3 файла:
- `HappySpeech/Features/Settings/SettingsView.swift:29` — comment "HealthKit удалён (ADR-V13-HEALTHKIT-REMOVED)"
- `HappySpeech/Features/LessonPlayer/Breathing/Workers/BreathingMetricsWorker.swift:7` — doc comment
- `HappySpeech/Features/LessonPlayer/Breathing/BreathingInteractor.swift:253` — comment

Файл уже переименован, но **trace мысли остался в коде**. Это НЕ функциональный bug, но `grep HealthKit` ≠ 0 → план v15 DoD не достигнут.

**Action v16:** убрать ВСЕ упоминания HealthKit (включая comments), оставить только `.claude/team/decisions.md` ADR-V13-HEALTHKIT-REMOVED как историю. Single sed-replace acceptable (3 файла).

### P0.5 — 13 нерелевантных USDZ остались, 10 logopedic — stubs (8 KB)
**v15 план F.4** требовал заменить kitchen_pancakes.usdz / animal_hummingbird.usdz / sport_glove_boxing.usdz / toy_drummer.usdz на 10 logopedic-relevant USDZ (apple_red, mouse_grey, fox_orange, snake_green, cup_steaming, bell_brass, truck_red, whale_blue, rocket_silver, drum_wooden) каждый ~10-15 MB через `realitykit-blendshapes-character` skill.

**Текущее состояние:**
- Нерелевантные USDZ остались: `animal_hummingbird.usdz` (20 MB), `animal_seahorse.usdz` (19 MB), `animal_chameleon.usdz` (15 MB), `sport_ball_football/basketball/baseball/soccer.usdz` (10-14 MB each), `toy_car/biplane.usdz` (11-12 MB each), `kitchen_teapot.usdz` (8.6 MB), `scene_robot.usdz` (12 MB), `scene_playground_slide.usdz` (6.2 MB), `scene_solar_panels.usdz` (4.5 MB), `sport_glove_baseball.usdz` (11 MB) — total ~150 MB нерелевантного контента
- 10 logopedic-named USDZ есть, но `apple_red/mouse_grey/fox_orange/snake_green/cup_steaming/bell_brass/truck_red/whale_blue/rocket_silver/drum_wooden` все **8 KB = stubs** (не реальные 3D-модели)

**Action v16:** новый Block — `animator` через `realitykit-blendshapes-character` или Reality Composer Pro CLI делает 10 РЕАЛЬНЫХ logopedic USDZ (10-15 MB каждый, geometry + PBR materials). Удалить animal_hummingbird/seahorse/chameleon, sport_*, kitchen_teapot, scene_robot, etc.

### P0.6 — Lyalya/3D-герой только в 16 экранах из 488 файлов (3%)
**Пользователь явно сказал "ни одного экрана без анимации/иллюстрации/voice"** и "должно быть видно что работала команда крупной компании". **Текущее состояние:** `grep HSMascotView|LyalyaRealityKitView|LyalyaHeroView|LyalyaMascotView` возвращает только 16 файлов. Большинство из 118 *View.swift БЕЗ героя/animation/voice anchor.

Critical экраны без героя (нужен mascot/illustration):
- ChildHomeView (есть) ✅
- Auth/Sign* (есть SplashView + AuthSign* etc.) ✅
- Lesson games (некоторые есть, не все)
- Settings, ProgressDashboard, SessionHistory, FamilyCalendar, Specialist, Stuttering — нужна проверка

**Action v16:** новый Block "Mascot-Everywhere" — для каждого *View добавить либо `HSMascotView` (для 2D entrance fade) или `LyalyaRealityKitView` (для 3D с blendshape) или real Lottie или illustration RGBA с прозрачным фоном.

### P0.7 — Light/Dark адаптация поверхностна (1 file uses @Environment(.colorScheme))
Только **1 файл из 488** использует `@Environment(\.colorScheme)`. Это означает: либо все экраны полагаются исключительно на `ColorTokens` (что приемлемо если ColorTokens корректно различают), либо Dark mode полу-сломан. **План v15 требовал** "Каждый экран тестируется в light и dark", но 0 systematic dark-mode tests кроме snapshot 403.

**Action v16:** systematic Light/Dark audit:
1. Запустить snapshot tests с обеими темами для каждого экрана (target ≥800 snapshot reference PNG, currently 403 = 50%).
2. Для каждого View — verify ColorTokens use OR explicit `@Environment(\.colorScheme)` adaptation.
3. Manual visual check на иллюстрациях с прозрачным фоном — они смотрятся ОК на dark BG?

### P0.8 — GuidedTour без VIP (план v15 D.3 не выполнен)
GuidedTour содержит только Coordinator + Container + TipView + Models (нет Interactor/Presenter/Router/DisplayLogic). Нарушает Clean Swift VIP convention. План v15 требовал: либо добавить VIP, либо документировать как `// Coordinator-based flow, no VIP needed`.

**Action v16:** `ios-developer` либо реализовать VIP (Interactor + Presenter + Router + DisplayLogic + Models = 5 файлов), либо добавить doc comment + `decisions.md` ADR-V16-GUIDEDTOUR-COORDINATOR-ONLY с обоснованием.

---

## Section 4 — Поверхностные моменты (P1)

### P1.1 — 102/488 файлов используют SF Symbols (21%)
Многие экраны вообще без иконок (или используют эмодзи как иконки). **Пользователь требует** "Modern stylistics: SF Symbols 6". Каждый *View.swift должен иметь хотя бы 3-5 SF Symbols.

### P1.2 — 123/488 файлов используют ColorTokens (25%)
75% Features НЕ используют DesignSystem ColorTokens, могут полагаться на system colors типа `.primary` / `.secondary`. Это OK если consistent, но риск design system fragmentation.

### P1.3 — `CustomizationViewCards.swift` 30+ Color(red:..) literals
Все scenes/themes/avatar themes используют hex-колоры через `Color(red: 0.72, green: 0.87, blue: 0.98)` etc. Должны быть в `ColorTokens` (например `ColorTokens.themeEveryday`, `ColorTokens.themeBeach`).

**Action:** `designer` extract palette → ColorTokens, `ios-developer` replace.

### P1.4 — 13 View files >600 LOC (план v15 H требовал ≤700)
Самые большие:
- ChildHomeViewComponents 1142 LOC
- RepeatAfterModelView 1004 LOC
- SessionCompleteView 908 LOC
- WorldMapView 847 LOC
- SessionShellView 837 LOC
- ChildHomeView 789 LOC
- NarrativeQuestView 690 LOC
- SortingView 688 LOC
- RewardsView 687 LOC
- SettingsViewSections 671 LOC
- MinimalPairsView 664 LOC
- SpecialistReportsView 658 LOC
- DragAndMatchView 652 LOC

**Action:** extract `*ViewComponents.swift` для каждого.

### P1.5 — 8 Stub Interactors <200 LOC, 9 <250 LOC
План v15 D.1 требовал 350+ LOC. **Действительно legitimate orchestration-only** для AR Interactors (ARSession delegate). **Action:** documented как `// VIP-thin orchestration only` или углубить с error handling, retry, biometric, deep state machine. Список:
- ButterflyCatchInteractor 69 LOC
- BreathingARInteractor 74 LOC
- SoundAndFaceInteractor 75 LOC
- HoldThePoseInteractor 84 LOC
- MimicLyalyaInteractor 115 LOC
- OfflineMiniGameInteractor 121 LOC
- ARMirrorInteractor 129 LOC
- PoseSequenceInteractor 188 LOC
- ARZoneInteractor 233 LOC

### P1.6 — Audio Lyalya 93 MB но scattered (12k+ файлов)
12 189 .m4a — превышает план v15 target 12 000 ✅, но distribution across 4 dirs (Ambient/Content/Lyalya/UI). Требует verification: каждый файл -16 LUFS, 16 kHz mono, ≤50 KB? Sample audit.

### P1.7 — 77 MP4 videos, многие procedural Remotion
План v15 ADR-V15-VIDEOS-CLEANUP-AND-DEFER задокументировал defer post-v1.0. **v16 решение:** оставить current 77 OR заменить на real CC0 (Pexels/Mixkit) для 10-15 hero videos, defer rest.

### P1.8 — ParentalGate в 6 файлах, нужно ≥10
External links (Privacy/Terms/GitHub Pages/About/etc.) должны иметь ParentalGate. Проверка какие — manual.

### P1.9 — 230 файлов БЕЗ String(localized:) (47%)
258/488 используют String(localized:). 230 могут содержать hardcoded русский (что OK для русского-only app), но риск fragmentation. Verify each.

---

## Section 5 — Категории A-I детально

### Категория A — Критические UI проблемы

**A.1 — Эмодзи в Features/ (46 файлов):** см. P0.3 выше. Полный список 46 файлов. Регэксп `[😀-🛿]\|[🌀-🗿]\|[🚀-🛸]\|[✅❌⭐🎉🎯🎁🎮🎨🎵🎬🎭🎪]`.

**A.2 — Hex literals в Features/:** 4 файла:
- `Customization/CustomizationModels.swift` — colors enum
- `Customization/CustomizationViewCards.swift` — 30+ Color(red:..) для themes/avatars
- `Common/ConfettiEmitterView.swift` — confetti palette
- `Common/CelebrationOverlayView.swift` — celebration palette
- `Common/LyalyaSceneView.swift` — UIColor(red:..) for ambient/material

**A.3 — Hardcoded строки:** 230/488 без String(localized:). Risk medium для русского-only.

**A.4 — Image(systemName:) usage:** 102/488. Хорошо в DesignSystem (HSButton/HSCard используют), плохо в Features.

**A.5 — Адаптация iPhone SE 3 (320pt):** 94/488 файлов используют GeometryReader/minimumScaleFactor. **v16 нужно:** systematic check — каждый View должен иметь либо GeometryReader, либо ScrollView, либо minimumScaleFactor ≥0.85. Проверить через snapshot tests с iPhone SE simulator.

**A.6 — Light/Dark:** см. P0.7 выше. 1/488 — критично.

**A.7 — LocalizationKey ключи vs текст в UI:** требует runtime check. Snapshot tests могут показать "key.name" вместо текста.

### Категория B — 3D героев / иллюстрации

**B.1 — HSMascotView.swift, LyalyaRealityKitView.swift:** существуют, используются в 16/488 файлов (3%).

**B.2 — 3D rendering с прозрачным фоном:** код LyalyaRealityKitView должен иметь `arView.environment.background = .color(.clear)` + `arView.cameraMode = .nonAR` + `arView.backgroundColor = .clear`. Не проверено runtime.

**B.3 — Иллюстрации transparent bg:** 0/464 имеют alpha (см. P0.1). КРИТИЧНО.

**B.4 — Rectangle borders:** все illustrations rectangular RGB → имеют borders/backgrounds.

### Категория C — Аудит ассетов

**C.1 — USDZ:** 27 files в ARAssets, 163 MB total. 13 нерелевантных (~150 MB), 10 logopedic stubs (8 KB), 4 actual (lyalya3d 744 KB, lyalya3d_v2 104 KB, scene_solar 4.5 MB, scene_playground 6.2 MB). См. P0.5.

**C.2 — Lottie:** 58 JSON files, 3.8 MB total. План v15 confirmed all real (no python-lottie). ✅

**C.3 — MP4 Videos:** 77 files, 47 MB. Включая `intro.mp4`, `trailer.mp4`, `onboarding_hero.mp4`, achievements/, celebrations/, lessons/, onboarding/, seasonal/, stories/, transitions/, tutorials/. План v15 ADR defer review post-v1.0.

**C.4 — Иллюстрации:** 464 PNG, ВСЕ RGB. Папки: phoneme_*, seasonal_*, reward_*, scene_*, и др. P0.1 critical.

**C.5 — AppIcon:** `Assets.xcassets/AppIcon.appiconset/` существует. iOS 17+ format (3 appearance) confirmed by план v15. **v16 нужно** — visual inspection (Read tool) на full bleed compliance, no inner rounded frames.

### Категория D — Code health

- **31+ файл с эмодзи:** 46 в Features/, 53 total в HappySpeech/ (см. полный список в P0.3)
- **Stub Interactors <250 LOC:** 9 файлов (см. P1.5)
- **View files >1000 LOC (план v15 H список):** 1142 LOC — фактически 13 файлов >600 LOC, 1 >1000 (ChildHomeViewComponents). Раньше было 9 >1000, теперь только ChildHomeViewComponents — план v15 H частично выполнен но не полностью.
- **Force unwraps:** ≈1 в production. ✅
- **TODO/FIXME/HACK/XXX:** 0. ✅
- **print() statements:** 0 (только Logger). ✅
- **Debug strings в UI:** требует manual check.

### Категория E — ML и speech

- **mlpackage sizes:** ВСЕ stubs (≤330 KB). См. P0.2. План v15 B1-B7 НЕ выполнен.
- **Wav2Vec2:** 328 KB / 16 KB stubs vs 370 MB target.
- **PronunciationScorerLive heuristic fallback:** УБРАН в v15 ✅ (verified comment "Block B.8 v15: удалён heuristic RMS fallback").
- **EnsembleASRService.swift:** 267 LOC, создан в v15 ✅
- **SpeakerVerificationServiceLive.swift:** 289 LOC, создан в v15 ✅
- **EmotionDetectionServiceLive.swift:** 275 LOC, создан в v15 ✅
- **Whisper bundled:** base + small (604 MB). План v15 B.9 предлагал tiny only — НЕ выполнено.

### Категория F — Bundle и cleanup

- **HappySpeech/Resources:** 1.1 GB total (target 1.5 GB через depth = 400 MB gap, должны заполнить real ML моделями ~415 MB)
- **_workshop/:** удалён (нет в проекте) ✅
- **/Users/antongric/Downloads/HappySpeech:** удалён (не нашёл duplicate) ✅
- **/Users/antongric/Downloads/:** содержит другие проекты (ChoiceForge, CoinLoom, etc.) — оставить как есть, это не HappySpeech
- **Unused assets:** требует анализа через `mcp__token-savior__find_dead_code` + асset references scan
- **Dead code:** требует scan

### Категория G — Test coverage

- **HappySpeechTests:** 119 .swift files
- **HappySpeechSnapshotTests:** 0 (snapshot tests embedded in Tests/Snapshot dir)
- **HappySpeechUITests:** 8 .swift files
- **Snapshot reference PNGs:** 403 в `__Snapshots__/`
- **Real coverage:** unknown — требует rerun `xcodebuild test -enableCodeCoverage YES`

### Категория H — Firebase сервисы

Проверка через grep в Services/:
- AuthService.swift, LiveAuthService.swift ✅ (Email + Google + Anonymous)
- FCMService.swift ✅ (план v15 — parent-only opt-in)
- PerformanceMonitorService.swift ✅ (parent-only)
- RemoteConfigService.swift ✅
- ContentPackDownloadService.swift ✅
- SyncService — есть в Sync/ dir
- App Check — нужен grep `AppCheck`
- 10 Cloud Functions — на стороне Firebase, не в iOS code

### Категория I — Экраны и фичи

**Total *View.swift:** 118 files (план v15 заявлял 91+, фактически 118 = exceeded)

**31 Feature dirs (top-level):** AR, ARZone, Auth, ChildHome, Common, Customization, Demo, Extensions, Family, FamilyCalendar, GrammarGame, GuidedTour, HomeTasks, LessonPlayer, OfflineState, Onboarding, ParentChild, ParentHome, Permissions, ProgressDashboard, Rewards, Screening, SessionComplete, SessionHistory, SessionShell, Settings, SharePlay, SiblingMultiplayer, Specialist, StutteringModule, WorldMap.

**13 AR sub-features:** HoldThePose, BreathingAR, SoundAndFace, PoseSequence, ARMirror, EyeFocus, Mascot3D, ARStoryQuest, Shared, ObjectDetection, HandPose, ButterflyCatch, MimicLyalya.

**LessonPlayer games (≥18):** Bingo, Breathing, ArticulationImitation, DragAndMatch, ListenAndChoose, MinimalPairs, Memory, NarrativeQuest, ObjectHunt, PuzzleReveal, RepeatAfterModel, Rhythm, Sorting, SoundHunter, StoryCompletion, VisualAcoustic, LetterTracing, GrammarGame.

**Запланированные но требуют verify:**
- Live Activities (план v11 #13, v15 J.6) — нужен grep ActivityKit
- Dynamic Island — grep Activity*
- Siri App Intents 5-7 (план v15 J.5) — grep AppIntent
- Widget Extensions (план v11 #14) — нужен Widget Extension target
- CoreSpotlight (план v11 #11, v15 J.4) — ✅ realized in App/HappySpeechApp.swift

**Конкуренты + новые функции:** competitor-analysis.md в `.claude/team/` — нужно прочитать в Plan v16.

---

## Section 6 — Что нужно сделать в Plan v16 (распределение по агентам)

### Block 1 — `cto` (Opus 4.7 1M) — Audit baseline + ordering
- Прочитать этот аудит
- Verify metrics с runtime build
- Создать Plan v16 с 18-20 блоков, sequential
- Output: `.claude/team/audit-v16-baseline.md` (этот файл copy)

### Block 2 — `ml-engineer` (Sonnet @ high, RUN_IN_BACKGROUND) — REAL ML training (P0.2 — самая большая задача)
**Skills:** `wav2vec2-coreml-russian`, `russian-asr-pipeline`, `speaker-verification-coreml`, `emotion-detection-coreml`, `gigaam-coreml-russian`, `russian-phoneme-analyzer`
**Tasks (sequential per model):**
1. Wav2Vec2 Russian (jonatasgrosman/wav2vec2-large-xlsr-53-russian → coremltools int8 ~370 MB)
2. SileroVAD CNN (snakers4/silero-vad → ~2 MB)
3. RussianPhonemeClassifier retrain (Conv1d-BiLSTM, ≤3ч golos+LJ child Russian, ≥85% acc)
4. SpeakerVerification ECAPA-TDNN (Conv1d + Bi-LSTM + 64-dim, ≤3ч Lyalya phrases + augmented)
5. EmotionDetection Conv1d-LSTM (40 MFCC, 4 эмоции, ≥75% acc на REDB subset)
6. PronunciationScorer × 4 групп (whistling/hissing/sonants/velar, MFCC+Conv1D, ≥88% acc each)
7. TonguePostureClassifier (real children data ≤3ч augmented OR ADR defer)
8. Whisper-base/small → remote download (keep tiny bundled)

### Block 3 — `icon-generator` (Sonnet @ high, RUN_IN_BACKGROUND) — 464 illustrations RGBA regen (P0.1)
**Skills:** `professional-illustration-generator`, новый `rgb-to-rgba-illustration-skill`
**Tasks:**
- For each 464 PNG → try `rembg i input.png output.png` first (cheap)
- If quality OK → save → verify `sips -g pixelDepth = 32`
- If quality bad → regenerate via FLUX-1-schnell с prompt "transparent background, isolated character/object, no rectangle frame, alpha channel"
- Batch 50 per commit, resumable

### Block 4 — `ios-developer` (Sonnet) — Эмодзи → SF Symbol replacement (P0.3)
**Skills:** `engineering:code-review`
**MCPs:** `mcp__apple-docs__*` (SF Symbol catalog)
**Tasks:**
- Per file (46 in batch of 5):
  - Identify each emoji char + context
  - Map to semantic SF Symbol (🔥 → "flame.fill", ✅ → "checkmark.circle.fill", 🎯 → "target", 🎉 → "party.popper.fill", etc.)
  - Replace `Text("Привет 🎯")` → `HStack { Image(systemName: "target"); Text("Привет") }`
  - Verify build + screenshot

### Block 5 — `ios-developer` — HealthKit refs full removal (P0.4, easy)
- 3 files: SettingsView line 29, BreathingMetricsWorker line 7, BreathingInteractor line 253
- Remove comments, leave only `decisions.md` ADR-V13

### Block 6 — `animator` (Sonnet) — 10 logopedic USDZ real (P0.5)
**Skills:** `realitykit-blendshapes-character`, Reality Composer Pro CLI
**Tasks:**
- Replace stub apple_red.usdz / mouse_grey / fox_orange / snake_green / cup_steaming / bell_brass / truck_red / whale_blue / rocket_silver / drum_wooden (8 KB → 10-15 MB each)
- Delete нерелевантные: animal_hummingbird (20 MB), animal_seahorse (19 MB), animal_chameleon (15 MB), sport_ball_*4 (40 MB), kitchen_teapot (8.6 MB), scene_robot (12 MB), toy_car/biplane (11-12 MB each), scene_playground_slide (6.2 MB), scene_solar_panels (4.5 MB), sport_glove_baseball (11 MB)

### Block 7 — `ios-developer` + `designer` — Mascot-Everywhere (P0.6)
**Skills:** `realitykit-blendshapes-character`, `design:design-system`
**Tasks:**
- Sprint per Feature dir (31 dirs):
  - For each *View.swift без Lyalya/HSMascotView/Image — add appropriate hero
  - Use HSMascotView для 2D entrance fade или LyalyaRealityKitView для 3D или Lottie animation или illustration RGBA
  - Avoid duplicate mascot везде — choose ONE per screen

### Block 8 — `qa-engineer` + `designer` — Light/Dark systematic audit (P0.7)
**Skills:** `apple-hig-audit-skill`, `design:accessibility-review`
**Tasks:**
- Snapshot tests с обеими темами для каждого *View (target ≥800 reference PNG)
- Per View: verify ColorTokens use OR explicit @Environment(.colorScheme)
- Findings → `.claude/team/dark-mode-audit-v16.md`

### Block 9 — `ios-developer` — GuidedTour VIP (P0.8)
- Add GuidedTourInteractor + Presenter + Router + DisplayLogic + Models
- OR documented + `decisions.md` ADR-V16-GUIDEDTOUR

### Block 10 — `ios-developer` — Stub Interactors deepening (P1.5, продолжение v15 D)
- 9 Interactors <250 LOC
- Document как `// VIP-thin orchestration only` ИЛИ deepen с error handling

### Block 11 — `ios-developer` — View files >600 LOC split (P1.4)
- Extract `*ViewComponents.swift` для top-13 (target ≤700 main, ≤500 components)

### Block 12 — `ios-developer` — Hardcoded colors → ColorTokens (P1.3)
- Customization themes/avatars → ColorTokens.themeBeach/Winter/etc.
- ConfettiEmitter / CelebrationOverlay palette → ColorTokens
- LyalyaSceneView UIColor → UIColor(named:)

### Block 13 — `qa-engineer` — Manual screen audit 118 *View (план v15 G)
**Skill:** `manual-screen-audit-skill`
**Tasks:**
- Build app на iPhone SE 3 simulator
- Open each screen → save screenshot
- Read each PNG → analyze → write findings в `.claude/team/manual-audit-v16.md`
- Per screen checklist: hero present / GeometryReader / minimumScaleFactor / ColorTokens / SF Symbols / VoiceOver labels / Dynamic Type / no emojis

### Block 14 — `ios-developer` — Modern iOS 26 features verification + completion
- ARKit Body Tracking PoseSequence (план v15 J.2)
- Real-time lip-sync mascot ARMirror (план v15 J.1) — confirm ARFaceAnchor.jawOpen → mouthOpen
- On-device Qwen2.5-1.5B kid circuit playful narrations (план v15 J.3, MLX-Swift)
- Siri App Intents 5-7 (план v15 J.5)
- Live Activities + Dynamic Island (план v15 J.6) — verify ActivityKit imported

### Block 15 — `qa-engineer` + `ios-debugger` — Performance + screenshot tour (план v15 L)
- Coverage ≥90% Services + ViewModels
- Snapshot threshold 0.05-0.10 stabilize
- Performance audit: startup <2s SE3, AR fps ≥30
- Screenshot tour 118 экранов × 2 темы = 236 → fix loop пока 0 visual bugs

### Block 16 — `code-reviewer` (Opus) — Final dead code + cleanup
**MCPs:** `mcp__token-savior__find_dead_code`, `find_unused_imports`, `find_hotspots`
- Dead code → удалить
- Unused assets → удалить
- xcodegen regenerate
- SwiftLint strict — 0 errors

### Block 17 — `pm` + `cto` — Final docs + tag
- README v16 update
- sprint.md close v16
- decisions.md ADR-V16-FINAL
- ml-models.md (с validation accuracy всех моделей)
- apple-hig-checklist-v16.md
- Tag `v1.0.0-final-v16`

### Block 18 — `qa-engineer` — Audio sample audit
- 10% sample 12 189 .m4a через `afinfo` + LUFS check
- Verify -16 LUFS, 16 kHz mono, ≤50 KB

### Block 19 — `researcher` — Конкурентный анализ + новые фичи
- Прочитать existing `.claude/team/competitor-analysis.md`
- Web research чего нет у Логопотам/Буковки/Логомаг
- Recommendations для +3-5 новых фич в v16

### Block 20 — `cto` (Opus) — Final independent QA + git push
- BUILD SUCCEEDED iPhone SE 3
- Russian-only страж: 0 en
- Bundle size ≥1.4 GB
- Git tag pushed

---

## Section 7 — Cross-cutting concerns

### 7.1 — Эмодзи (cross 46 файлов)
Каждый emoji → SF Symbol mapping table в `.claude/team/emoji-to-sfsymbol-mapping.md`. Common mappings:
- 🎯 → target, 🔥 → flame.fill, 🎉 → party.popper.fill, ✅ → checkmark.circle.fill, ❌ → xmark.circle.fill
- ⭐ → star.fill, 🌟 → sparkles, 💡 → lightbulb.fill, 🎁 → gift.fill, 🏆 → trophy.fill
- 🎨 → paintbrush.fill, 🎵 → music.note, 🎮 → gamecontroller.fill, 📱 → iphone, 📷 → camera.fill
- 🎭 → theatermasks.fill, 🎪 → tent.fill, ❤️ → heart.fill, 👶 → figure.child, 📚 → books.vertical.fill

### 7.2 — Темы (Light/Dark)
1 файл из 488 проверяет colorScheme. Это либо OK (если ColorTokens корректные), либо плохо. **v16 решение:** systematic snapshot tests в обеих темах + per-screen visual review.

### 7.3 — Размер (1.1 GB → 1.4-1.5 GB через depth)
Gap 300-400 MB. Заполнить через:
- Real ML модели ~415 MB (Wav2Vec2 370 + остальные 45)
- Real USDZ logopedic ~100 MB (10 × 10-15 MB)
- HD illustrations 464 × 100 KB (RGBA 512×512) = +50 MB
- Voice expansion +50 MB
- DocC catalog +20 MB
- SPM libs binary +10 MB

### 7.4 — Конкуренты (Логопотам / Буковки / Логомаг)
Прочитать `.claude/team/competitor-analysis.md` в v16. Определить gap-analysis. Реализовать missing features.

### 7.5 — Новые функции пользователи хотят
Web research + recommendations. Кандидаты:
- Voice cloning ребёнка (для self-comparison)
- AR face filter mode (карнавальные маски с речевыми триггерами)
- Group multiplayer (SharePlay уже есть, но без real-time game co-op)
- Apple Pencil drawing exercises (LetterTracing уже есть)
- Speech диктовка → визуализация в виде анимированного текста
- Daily streak rewards (ежедневный логин)
- Семейный leaderboard (среди семьи)

### 7.6 — Cosmetic vs structural
**Cosmetic (Block 3, 7, 11, 12, 13):** illustrations, mascot, hero, colors, Light/Dark, screen audit.
**Structural (Block 2, 6, 9, 10, 14):** ML training, USDZ real, GuidedTour VIP, Interactors deepening, modern iOS features.
**Both required для production-quality.**

### 7.7 — План v16 estimated duration
- Block 2 (ML training) — 8-12 часов background (самый тяжёлый)
- Block 3 (illustrations regen) — 6-8 часов background
- Block 4 (emoji removal) — 4-6 часов
- Block 5 (HealthKit cleanup) — 30 минут
- Block 6 (USDZ real) — 4-6 часов
- Block 7 (Mascot-Everywhere) — 8-10 часов (118 screens)
- Block 8-12 (UI quality) — 12-16 часов
- Block 13 (manual audit) — 8 часов background
- Block 14 (modern iOS) — 6-8 часов
- Block 15 (perf+screenshots) — 6-8 часов
- Block 16-20 (cleanup+docs+QA) — 4-6 часов

**Total estimate:** 70-100 часов agent work, sequential. С background tasks (ML/illustrations) параллельно — 50-70 часов wall-clock.

---

## Конец Audit v16 Baseline

**Дата создания:** 2026-05-07 (deep audit Opus 4.7 1M, 9 планов прочитаны).

**Базируется на анализе:**
- 9 планов (v0/initial → v15)
- Текущее состояние: 623 .swift files (145k LOC), 118 *View.swift, 488 Feature swift files
- Critical findings: 100% RGB illustrations, 100% stub ML моделей, 46 файлов с эмодзи, 13 нерелевантных USDZ, 16/488 экранов с героем
- Plan v15 partial completion: A (cleanup) ✅, B (ML real-train) ❌ NOT EXECUTED, C (Speech wrappers) ✅, D (Interactors) частично, E (illustrations RGBA) ❌ REGRESSED, F (USDZ) ❌, G (manual audit) частично, H (View split) частично

**Сохранено по пути:** `/Users/antongric/.claude/plans/indexed-prancing-tide-agent-af24f588c9ad6e7b9.md`
**(Plan Mode requires write to plan-file. Пользователь может скопировать в `.claude/team/audit-v16-baseline.md` после exit Plan Mode.)**
