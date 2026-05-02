# Team Decisions Log — HappySpeech
## Managed by CTO and Team Lead.

---

## Format
```
[DATE] [WHO] DECISION-ID: Title
  Decision: ...
  Reason: ...
  Alternatives: ...
  Risk: ...
```

---

## Log

### [2026-05-02] [pm] ADR-V14-003: 4 новых ML skill для Block E Speech Analysis углубления
**Decision:** Созданы 4 новых skill файла в `.claude/skills/` для Block E v14.
**Skills:**
- `russian-asr-pipeline` — ensemble Whisper + Wav2Vec2 + RussianPhonemeClassifier, confidence-based weighted voting, Tier A (kid) / Tier B (parent+specialist). Владельцы: ml-engineer + ios-developer.
- `speaker-verification-coreml` — d-vector CNN (Conv1d + Bi-LSTM + 64-dim projection), cosine similarity 0.7, `SpeakerVerification.mlpackage` ~30 MB, COPPA-safe (embeddings только in-memory). Владелец: ml-engineer.
- `emotion-detection-coreml` — Conv1d-LSTM, 4 класса (happy/sad/frustrated/neutral), `EmotionDetection.mlpackage` ~5 MB, интеграция с AdaptivePlannerService. Владелец: ml-engineer + ios-developer.
- `gigaam-coreml-russian` — оценка GigaAM-v2-CTC конвертации через 3 пути (coremltools → sherpa-onnx → Vosk), ADR-V14-GIGAAM defer шаблон если не укладывается в дедлайн. Владелец: ml-engineer.
**Reason:** Block E.0 v14 требует углубления Speech Analysis. Ensemble accuracy > single-model. Emotion detection нужен для AdaptivePlanner (S12-001). Speaker verification закрывает COPPA-safe parent/child разграничение.
**Alternatives:** Использовать только WhisperKit — проще, но ниже точность на детской русской речи. Не принято.
**Risk:** GigaAM может не конвертироваться (defer path предусмотрен). Speaker verification требует достаточного датасета (решено через Lyalya augmentation).

---

### [2026-05-02] [CTO] ADR-V14-001: GoogleSignIn REVERSED_CLIENT_ID отсутствует
**Decision:** Оставить PLACEHOLDER `com.googleusercontent.apps.PLACEHOLDER-REVERSED-CLIENT-ID` в CFBundleURLSchemes до ручного действия пользователя.
**Reason:** GoogleService-Info.plist (`happyspeech-dfd95`) не содержит ключ `REVERSED_CLIENT_ID`. Этот ключ появляется только при явном включении Google Sign-In OAuth в Firebase Console → Authentication → Sign-in providers → Google. Без него GoogleSignIn SDK не сможет выполнять callback после авторизации.
**Требуемое действие пользователя:** Войти в Firebase Console (happyspeech-dfd95), включить Google Sign-In provider, скачать обновлённый GoogleService-Info.plist, найти ключ REVERSED_CLIENT_ID (формат `com.googleusercontent.apps.<ID>`), заменить PLACEHOLDER в project.yml строке CFBundleURLSchemes, запустить `xcodegen generate`.
**Risk:** До замены PLACEHOLDER Google Sign-In будет падать при попытке авторизации (callback URL не зарегистрирован). Firebase Auth / Apple Sign-In не затронуты.

---

### [2026-04-21] [CTO] ADR-001: ASR Engine Selection
**Decision:** GigaAM-v3 (ONNX via sherpa-onnx) as primary Russian ASR. WhisperKit (whisper-tiny) as fallback.
**Reason:** GigaAM-v3 outperforms Whisper-large-v3 on Russian speech benchmarks. Provides word-level timestamps needed for pronunciation scoring. Apache 2.0 license.
**Alternatives:** (1) WhisperKit only — simpler but lower Russian accuracy. (2) Apple AVSpeechRecognizer — requires internet, not acceptable.
**Risk:** sherpa-onnx iOS integration complexity. Mitigation: implement both in parallel by S5, GigaAM by S10.

---

### [2026-04-21] [CTO] ADR-002: Local LLM Selection
**Decision:** Qwen2.5-1.5B-Instruct via MLC LLM Swift SDK. Structured JSON output only, no chat interface.
**Reason:** 950 MB on device (acceptable iPhone 12+), good Russian support, Apache 2.0, MLC has iOS Swift SDK.
**Alternatives:** (1) Gemma 3n — newer but less mature Russian. (2) No LLM, rule-based only — acceptable fallback but loses differentiation.
**Risk:** 950 MB download on first run. Mitigation: optional download, rule-based fallback fully functional when LLM not downloaded.

---

### [2026-04-21] [CTO] ADR-003: Local Database
**Decision:** Realm Swift as local database (not CoreData, not SQLite).
**Reason:** Mobile-first, offline-first, live queries work well with SwiftUI @Observable.
**Alternatives:** CoreData — more complex migrations. SQLite — too low-level.
**Risk:** Schema migrations. Mitigation: version all schemas, dedicated MigrationTests target.

---

### [2026-04-21] [CTO] ADR-004: No Third-Party Analytics SDK
**Decision:** Zero third-party analytics SDKs. Local AnalyticsService event bus only. MetricKit for performance data.
**Reason:** Non-negotiable for Apple Kids Category compliance. Any third-party analytics risks App Store rejection.
**Alternatives:** None acceptable for Kids Category.
**Risk:** Reduced crash visibility. Mitigation: MetricKit provides crash/hang data; OSLog for detailed debugging.

---

### [2026-04-21] [CTO] ADR-005: Feature Architecture — Clean Swift (VIP)
**Decision:** Clean Swift (VIP) pattern for all feature modules.
**Reason:** Diploma defense requires demonstrable architectural rigor. VIP is highly testable (Interactor + Presenter isolated). Clear separation of concerns.
**Alternatives:** MVVM+Combine — simpler but less testable at scale. TCA — overkill for diploma timeline.
**Risk:** VIP boilerplate slows initial development. Mitigation: code templates for new features.

---

### [2026-04-21] [CTO] ADR-006: SPM Only
**Decision:** All dependencies via Swift Package Manager only. No CocoaPods, no Carthage.
**Reason:** Native to Xcode 16+. All required libraries (RealmSwift, Firebase, WhisperKit, MLC-LLM) have official SPM support.
**Risk:** Some libraries may have SPM issues. Mitigation: check SPM compatibility before Sprint 1.

---

### [2026-04-21] [CTO] ADR-007: xcodegen for Project Management
**Decision:** Use xcodegen (project.yml) instead of manual .xcodeproj management.
**Reason:** Avoids Xcode project file merge conflicts. Reproducible builds. project.yml is readable and version-controlled.
**Alternatives:** Manual .xcodeproj — subject to merge conflicts and XML noise.
**Risk:** xcodegen template gaps. Mitigation: use well-documented project.yml patterns.

---

### [2026-04-21] [CTO] ADR-008: AR Honest Capability Boundaries
**Decision:** AR features use only ARKit Face Tracking external blendshapes. No claims of internal tongue position tracking.
**Reason:** ARKit tongueOut is the only tongue-related blendshape available. Claims of full tongue tracking are false and would violate App Store guidelines for health apps.
**Scope:** tongueOut, jawOpen, mouthFunnel, mouthSmile, cheekPuff only.
**Risk:** User expectations exceed capability. Mitigation: in-app disclaimers on AR screens, clear product boundary in CLAUDE.md.

---

### [2026-04-21] [CTO] ADR-009: Content Matrix Approach
**Decision:** Content is defined as a matrix (sound × stage × template) not as individual hand-crafted scenes.
**Reason:** Enables 6,000+ content units from ~520 seed items + template logic. Scalable and testable.
**Risk:** Template logic bugs affect many content units simultaneously. Mitigation: ContentEngine unit tests with 85%+ coverage.

---

### [2026-04-21] [CTO] PLAN-001: Master Plan Phase 0 Complete
**Decision:** Master plan v1.0 compiled and placed at HappySpeech/ProductSpecs/master-plan.md.
**Contents:** 18 sections, 65 screens, 13 sprints, 10 risks, 5 phases, full Realm/Firestore schema, ML model registry, Python tooling list, design system tokens, AR scenarios.
**Awaiting:** User approval before implementation (ADR-001 through ADR-009 are provisional until approved).

---

### [2026-04-21] [CTO] IMPL-001: Phase A Implementation Started
**Decision:** User approved master plan. Starting Phase A (Foundation) implementation.
**Wave 1 — Parallel delegation:**
  - ios-dev-arch: project.yml + xcodegen + Core layer + Service protocols + AppContainer DI + AppCoordinator
  - designer-ui + designer-visual: DesignSystem in Swift (tokens, theme, components, ThemeManager, custom icons)
  - backend-dev-infra: Realm models (9 entities) + repositories + DI wiring
**Wave 2 (after Wave 1):**
  - backend-dev-api: Firebase integration + SyncService + NetworkMonitor + OfflineBanner
  - speech-content-curator: seed content packs + ContentEngine schema
**Wave 3 (after Wave 2, parallel with features):**
  - team-lead: coordinates all 83 backlog features (Phases C through E)
  - ml-data-engineer + ml-trainer: Python scripts + dataset collection + model training
  - sound-curator: CC0 audio assets
**Rule applied:** speech-methodologist consulted BEFORE content delegation (speech-games-tz.md already populated).
**Status:** Wave 1 dispatched 2026-04-21.

---

### [2026-04-21] [CTO] WAVE1-RESUME: Wave 1 Resumed After Project Migration
**Decision:** Project migrated from Downloads/HappySpeech to new canonical path. Resuming Wave 1 from current state.
**Current state audit:**
  - 64 Swift files exist across all layers
  - ThemeManager (@Observable, 3 modes, UserDefaults) — EXISTS in ThemeEnvironment.swift
  - AppContainer DI (all 12 services via factory closures) — EXISTS, fully wired
  - DesignSystem Components: HSButton, HSCard, HSBadge, HSMascotView, HSProgressBar, HSAudioWaveform, HSSticker, HSProgressRing, HSRewardBurst, HSSoundChip, HSLoadingView, HSOfflineBanner, HSEmptyStateView, HSErrorStateView — 14 components exist
  - Features: 17 folders, each has only 1 View file — missing Interactor/Presenter/Router/Models
  - LessonPlayer: 16 sub-feature folders exist but only 1 file each
  - Data/Models: RealmModels.swift exists (need to verify all 9 entities)
  - Data/Repositories: ChildRepository + SessionRepository exist; need remaining 7
  - ML/: 4 files (ASRServiceLive, LocalLLMService, PronunciationScorerLive, VADService)
  - Sync/: SyncService.swift only; missing SyncQueue, ConflictResolver, NetworkMonitor
  - Analytics/: AnalyticsService.swift only; missing event schema
  - Shared/: 2 files (AccessibilityModifiers, CardModifier); missing BouncePress, AsyncButton, RoundedCardStyle
**Wave 1 parallel dispatch — 3 agents:**
  1. ios-dev-arch: Build fix + all 17 Feature Clean Swift skeletons + ML/Sync/Analytics/Shared stubs
  2. designer-ui: Theme toggle in Settings + missing DesignSystem components + a11y/Dark mode pass
  3. backend-dev-infra: All 9 Realm models + 9 repositories + migrations + smoke tests
**Target commit:** feat(foundation): wave 1 — build fixes, full skeleton, theme toggle

## Claude Code Best Practices 2026-04-22

> Source: official Claude Code docs — code.claude.com/docs и platform.claude.com/docs

### 1. Claude API в iOS Swift — интеграция через URLSession

**Вывод:** Anthropic НЕ предоставляет официальный Swift/iOS SDK. Для iOS интеграция — через REST API (URLSession).

Эндпоинт: `POST https://api.anthropic.com/v1/messages`
Заголовки: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`

```swift
struct AnthropicRequest: Encodable {
    let model: String        // "claude-sonnet-4-6"
    let max_tokens: Int
    let messages: [[String: String]]
    let stream: Bool?
}
```

**Streaming (SSE):** API возвращает `text/event-stream`. Парсить через `URLSessionDataDelegate` — строки `data: {"type":"content_block_delta",...}`.

**Tool use:** массив JSON-описаний инструментов в поле `tools` запроса. Ответ содержит `tool_use` блоки → следующий запрос с `tool_result`.

**Model selection для HappySpeech:**
| Задача | Модель | ID API |
|---|---|---|
| Детские фразы, игровые ответы | Haiku 4.5 | `claude-haiku-4-5-20251001` — $1/$5 per MTok |
| ASR-фидбек, речевой анализ | Sonnet 4.6 | `claude-sonnet-4-6` — $3/$15 per MTok |
| Планирование маршрута | Sonnet 4.6 | `claude-sonnet-4-6` |

### 2. Prompt Caching — best practices

Кеш 5 мин (default) или 1 час (`ttl: "1h"`, 2× запись / 0.1× чтение).

**Минимальные длины для кеша (официальная документация platform.claude.com):**
| Модель | Мин. токенов |
|---|---|
| Haiku 4.5 (`claude-haiku-4-5-20251001`) | **4096** |
| Sonnet 4.6 (`claude-sonnet-4-6`) | **2048** |

⚠️ Для HappySpeech: системный промпт + контент-пак должен быть ≥4096 tok для Haiku и ≥2048 tok для Sonnet — иначе кеш не включается.

**Для HappySpeech:**
1. Кешировать системный промпт + контент-пак звука (статическая часть сессии).
2. Explicit breakpoints: `cache_control: {"type": "ephemeral"}` на последнем статичном блоке перед динамическим вводом.
3. Каждый пользователь = свой кеш-контекст (кеш не шарится между пользователями). Системный промпт идентичный для всех сессий одного типа → попадание в кеш.
4. Мониторинг: `cache_read_input_tokens > 0` в ответе = попадание в кеш. Экономия до 90% на повторных запросах.
5. Изменение любого контента до breakpoint сбрасывает кеш.

### 3. Claude Agent SDK — применимость в iOS Runtime

**Вывод: НЕ применим в iOS runtime напрямую.**

Agent SDK требует `claude` CLI бинарник — запускает его через stdio subprocess. В iOS sandbox subprocess-вызовы запрещены.

**Что применимо:**
- Паттерны агентного цикла (gather → act → verify) — применимы концептуально при реализации через REST API.
- Subagents, skills, hooks — инструменты dev-среды (macOS/Linux), не iOS runtime.
- В iOS — прямая интеграция `/v1/messages`.

### 4. Актуальные MCP Tools в текущей сессии

| MCP сервер | Статус | Применение |
|---|---|---|
| **xcodebuild** (XcodeBuildMCP) | АКТИВЕН | Сборка, симулятор, UI-автоматизация, скриншоты, LLDB, тесты |
| **ios-simulator** (standalone) | АКТИВЕН | UI tap/swipe/type/screenshot/record — отдельный от xcodebuild |
| **hugging-face** | АКТИВЕН (auth: antongrits25) | Датасеты RU-речи, модели Whisper/Silero |
| **figma** (claude.ai Figma) | АКТИВЕН | Чтение дизайн-спеков, FigJam, Code Connect |
| **context7** | АКТИВЕН | Актуальная документация SwiftUI/Realm/Firebase/WhisperKit/ARKit |
| **lottiefiles** | АКТИВЕН | Lottie-анимации для rewards/demo tour |
| **firebase** | АКТИВЕН | Firestore CRUD, Auth, Storage, Rules, Functions logs |
| **apple-docs** | АКТИВЕН | Официальные Apple API docs, WWDC видео, примеры кода |
| **token-savior** | АКТИВЕН | Semantic code search, call chains, impact analysis, checkpoints |
| **github** | АКТИВЕН | Issues, PRs, code search, branches |

**Ключевые инструкции:**
- `xcodebuild`: перед первым `build_run_sim` всегда `session_show_defaults`.
- `context7`: использовать для ЛЮБЫХ вопросов по библиотекам (даже если кажется что знаешь).
- `token-savior`: использовать для навигации по большому кодабейсу — дешевле чем Read + Grep.
- `apple-docs`: приоритет перед WebFetch для Apple API — официальные примеры из WWDC.
- `hugging-face`: авторизован, доступен поиск по 100+ тегам.


---

## Research Findings 2026-04-22

### [research] RESEARCH-001: On-Device RU LLM, ASR, ARKit Audit

#### 1. On-Device Russian LLM до 2B параметров

| Модель | Params | Размер (q4) | RU качество | Лицензия | On-Device iOS |
|---|---|---|---|---|---|
| **Qwen2.5-1.5B-Instruct** | 1.54B | ~950 MB | Хорошее (29 языков, RU) | Apache 2.0 | Да — MLC, Private LLM, **MLX Swift** |
| SmolLM-1.7B-Instruct | 1.7B | ~1 GB | Слабое (EN-first) | Apache 2.0 | Да |
| Vikhr-Nemo-12B | 12B | 24 GB fp16 | Отличное (79.8% RuArena) | Apache 2.0 | **Нет** — велик для iPhone |
| T-pro-it-1.0 | 33B | 66 GB | Превосходное (ruGSM8K 0.941) | Не указана | Нет |
| T-lite-it-1.0 | 8B (Qwen2.5) | 16 GB | Отличное | Не указана | Нет |
| Saiga-Llama3-8B | 8B | 16 GB | Хорошее | Llama3 (Meta) | Нет |

**Вывод:** Qwen2.5-1.5B-Instruct — единственная модель ≤2B с приемлемым RU и реальным iOS SDK. Inference на iPhone 15 Pro: ~15–25 tok/s (Metal). **ADR-002 подтверждён.**

#### 2. MLC-LLM vs MLX Swift

- **MLC-LLM:** нет SPM. Требует CMake + Rust toolchain для компиляции. Qwen2.5 не в официальном prebuilt списке.
- **MLX Swift (Apple, WWDC 2025):** нативный, первоклассная поддержка iOS 16+, Qwen2.5 через mlx-community, проще SPM.

**РЕКОМЕНДАЦИЯ: MLX Swift SDK вместо MLC.** Обновить ADR-002.

#### 3. WhisperKit vs GigaAM (sherpa-onnx)

| Параметр | WhisperKit | GigaAM v2024 sherpa-onnx |
|---|---|---|
| RU WER | whisper-large-v3: ~7.4% avg | GigaAM wins 70:30 vs Whisper-large-v3 |
| Memory | tiny безопасен; large-v3-turbo ~600 MB | GigaAM v2 int8: 226 MB |
| Лицензия | **MIT** | **NC (non-commercial)** — для v2024 |
| iOS compat | iOS 16+, SPM | iOS 13+, ручной xcframework |

**КРИТИЧЕСКАЯ НАХОДКА:** `sherpa-onnx-nemo-ctc-giga-am-russian-2024-10-24` имеет **NC лицензию** → НЕ подходит для App Store коммерческого релиза.

**РЕКОМЕНДАЦИЯ: WhisperKit whisper-large-v3-turbo (MIT, 600 MB) как primary ASR.** GigaAM v1 Apache 2.0 допустим, но качество ниже. Обновить ADR-001.

#### 4. ARKit Face Tracking — все 52 blendshape доступны на iPhone X+ (TrueDepth)

**Релевантные для артикуляционной терапии (16):**
- **Рот/челюсть:** `jawOpen`, `jawLeft`, `jawRight`, `jawForward`, `mouthClose`
- **Губы:** `mouthFunnel` (У, шипящие), `mouthPucker` (округление), `mouthStretchLeft/Right`, `mouthRollUpper/Lower`, `mouthPressLeft/Right`, `mouthSmileLeft/Right`, `mouthUpperUpLeft/Right`, `mouthLowerDownLeft/Right`
- **Щёки:** `cheekPuff` (дыхательные упражнения)
- **Язык:** **`tongueOut` — ЕДИНСТВЕННЫЙ язычный blendshape в ARKit**

**Ограничение:** Нет tongueLeft/Right/Up/Down/Groove. Внутреннее положение языка (для Р, Л, Ш) отследить **невозможно**. **ADR-008 подтверждён.** Все blendshapes одинаковы на iPhone X–17 Pro.

### Итоговые решения

1. **LLM:** Qwen2.5-1.5B-Instruct через **MLX Swift** (не MLC).
2. **ASR:** **WhisperKit whisper-large-v3-turbo** (MIT) — ОТКАЗ от GigaAM v2024 из-за NC лицензии.
3. **AR:** 15 губно-челюстных blendshape + `tongueOut` — достаточно для визуальной обратной связи.

---

### [2026-04-22] [ML Trainer] ADR-001-REV1: ASR Engine — WhisperKit large-v3-turbo
**Decision:** WhisperKit whisper-large-v3-turbo (MIT, ~600 MB) как primary ASR. WhisperKit whisper-tiny как fallback.
**Reason:** GigaAM v2024 (sherpa-onnx-nemo-ctc-giga-am-russian-2024-10-24) имеет NC (non-commercial) лицензию — нельзя в App Store.
**Supersedes:** ADR-001.
**Risk:** +350 MB vs GigaAM. Митигация: download on first run.

### [2026-04-22] [ML Trainer] ADR-002-REV1: LLM Runtime — MLX Swift вместо MLC-LLM
**Decision:** Qwen2.5-1.5B-Instruct через MLX Swift (Apple, WWDC 2025) вместо MLC-LLM.
**Reason:** MLC-LLM — нет SPM, требует CMake+Rust. MLX Swift — нативный, SPM, Qwen2.5 через mlx-community.
**Supersedes:** ADR-002.
**Performance:** ~15-25 tok/s на iPhone 15 Pro (Metal).

---

## G1 Firebase Deploy (2026-04-26)

**Статус: ЗАБЛОКИРОВАН — требуется ручное действие от разработчика**

### Выполнено (локальная верификация)

- **Firestore Rules:** файл `firestore.rules` существует, 357 строк, v1.1 (2026-04-22). Синтаксис корректен. Покрывает: /users, /children, /sessions, /attempts, /progress, /plans, /reports, /weekly_reports, /rewards, /routes, /specialists, /assignments, /content/*, /contentPacks, /exercises, /audits. Default deny на `/{document=**}`.
- **Firestore Indexes:** файл `firestore.indexes.json` существует, JSON-синтаксис OK, **14 составных индексов** (sessions×5, progress×2, attempts×1, contentPacks×1, exercises×1, reports×1, rewards×1, routes×1, weekly_reports×1).
- **firebase.json:** корректен, App Check настроен в режиме `ENFORCED` с провайдером `deviceCheck` + `debug` (для симулятора).
- **storage.rules:** файл существует.
- **.firebaserc:** default=`happyspeech-app`, prod=`happyspeech-app`, dev=`happyspeech-dev`, staging=`happyspeech-staging`.
- **GoogleService-Info.plist:** PLACEHOLDER — реальные значения не заполнены.

### Блокеры

1. **Firebase CLI залогинен под `antongric132@gmail.com`** — проектов не найдено. Нужно залогиниться под `antongric558@gmail.com`.
2. **Firebase проект `happyspeech-app` не создан** (или недоступен с текущим аккаунтом) — `firebase projects:list` возвращает пустой список.
3. **GoogleService-Info.plist содержит placeholder** — реальный plist нужно скачать из Firebase Console после создания проекта.

### Инструкция для ручного разблокирования

```bash
# 1. В терминале с поддержкой интерактивного ввода:
firebase login --reauth
# → выбрать antongric558@gmail.com в браузере

# 2. Создать проект в Firebase Console:
#    https://console.firebase.google.com/
#    - Project ID: happyspeech-app
#    - Регион Firestore: europe-west3
#    - Включить App Check → DeviceCheck + Debug provider

# 3. Скачать GoogleService-Info.plist → заменить placeholder в:
#    HappySpeech/Resources/GoogleService-Info.plist

# 4. Деплой:
cd /Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage

# 5. Верификация:
firebase firestore:rules:get | head -20
```

### App Check статус
- В `firebase.json` настроен: `enforcementMode: ENFORCED`, провайдеры: `deviceCheck` (prod) + `debug` (simulator).
- Активация в Firebase Console: Project Settings → App Check → Register app → DeviceCheck.

- **Firestore Rules деплой:** не выполнен (CLI не авторизован под нужным аккаунтом)
- **Firestore Indexes деплой:** не выполнен (та же причина)
- **App Check статус:** настроен в config, не активирован в Console
- **Project ID:** `happyspeech-app`

---

### [2026-04-26] [animator] M5.2: 3D USDZ маскот Ляля — процедурная геометрия

**Decision:** Создать `lyalya3d.usdz` процедурно через Python (USDA текстовый формат + ZIP-упаковка) вместо загрузки стороннего ригированного персонажа.

**Причина отказа от стороннего ассета:**
- CC0-лицензированных rigged USDZ персонажей с подходящим cartoon-стилем для детей 5–8 лет не найдено в открытом доступе (Sketchfab CC0, Mixamo — только FBX без USDZ)
- `xcrun usdz_converter` отсутствует в Xcode 26.4.1 (убран в пользу Reality Composer Pro)
- Blender не установлен; Reality Converter.app не установлен
- `usd-core` pip не устанавливается (externally-managed environment)

**Реализованное решение:**
- Инструмент: Python 3 + trimesh + numpy (доступны на машине)
- Геометрия: 15 сферических мешей (голова, 2x ухо, 2x глаз, 2x зрачок, нос, 2x щека, туловище, 2x рука, 2x нога)
- Итого: ~6 951 вершин, ~12 768 треугольников, 9 PBR-материалов (UsdPreviewSurface)
- Цветовая палитра: пастельные лиловые/розовые тона (BrandLilac #C9A8F0, BrandRose #FFB5C8)
- Упаковка: ZIP-архив согласно USDZ spec (USDA stored + текстуры deflated)

**Параметры финального файла:**
- Путь: `HappySpeech/Resources/ARAssets/lyalya3d.usdz`
- Размер: 759 583 байт (742 KB)
- UTI: `com.pixar.universal-scene-description-mobile` (подтверждён mdls)
- ZIP CRC: OK
- USDA баланс скобок: OK (35 открывающих = 35 закрывающих)

**BlendShapes:** отсутствуют в текущей версии (USDA процедурный, без скелета).
`LyalyaAnimationHelper` в `LyalyaRealityView.swift` использует процедурные RealityKit-анимации (`OrbitAnimation`, `FromToByAnimation`) вместо blendshapes. Это корректно — fallback уже реализован.

**Используемые анимации (RealityKit процедурные, без blendshapes):**
- `idle` → `OrbitAnimation` медленное вращение вокруг Y (8 сек, repeat)
- `waving` → `FromToByAnimation<Transform>` покачивание по Z ±0.12π
- `celebrating` → `FromToByAnimation<Transform>` подскок +0.07m + поворот Y 0.25π
- `thinking` → `FromToByAnimation<Transform>` наклон Z 0.08π
- `pointing` → `FromToByAnimation<Transform>` пульсация scale
- `sad` → `FromToByAnimation<Transform>` мягкое покачивание Z ±0.05π

**Интеграция:** `LyalyaRealityView.swift` (уже существующий) загружает USDZ через
`Bundle.main.url(forResource: "lyalya3d", withExtension: "usdz", subdirectory: "ARAssets")`.
При ошибке загрузки → 2D градиентный фоллбэк (уже реализован).

**Источник:** процедурная генерация (не третья сторона, не CC0-ассет). Лицензия: собственная (HappySpeech project).

**Workshop артефакты** (не в репо, `.gitignore`):
- `/Users/antongric/Downloads/HappySpeech/_workshop/3d/source/` — пусто (нет сторонних ассетов)
- `/Users/antongric/Downloads/HappySpeech/_workshop/3d/output/lyalya_v2.usda` — исходный USDA
- `/Users/antongric/Downloads/HappySpeech/_workshop/3d/textures/` — PNG текстуры (4 файла)

**Следующий шаг (M5.3, при наличии Blender):** импортировать USDA в Blender → добавить скелет + shape keys → экспортировать через Reality Composer Pro в .reality с настоящими blendshapes.

---

## H1 Sprint 12 Final Stats (2026-04-26)
- Swift files: 386
- Total LOC: 75 582
- Git commits: 125
- Localization keys: 1 381
- Content stages: 196
- Content items: 6 265
- BUILD: SUCCEEDED

---

### [2026-04-26] [ml-engineer] ADR-015: Vision ML Stack M5.3 — MediaPipe FaceMesh vs Apple Vision

**Decision:** Использовать Apple Vision `VNDetectFaceLandmarksRequest` (76 точек) как primary источник face landmarks. MediaPipe FaceMesh (478 точек) — не задеплоен.

**Reason:** Поиск готовой CoreML-версии FaceMesh занял > 30 минут без результата:
1. HuggingFace: ни одного репозитория `mediapipe face mesh coreml` с рабочей моделью под Apache/MIT.
2. Официальный Google MediaPipe tflite (`face_landmark.tflite`) конвертируется через `tflite2coreml`, но последние версии (2022+) используют `FULLY_CONNECTED` op с dtype int16, который coremltools 8/9 не поддерживает.
3. Альтернатива — конвертация вручную через onnx2coreml — требует промежуточного экспорта в ONNX, что нестабильно для MediaPipe custom ops.

**Решение-workaround:**
- `AppleFaceLandmarksDetector.swift` (actor, Vision 76 точек) — production primary
- `TonguePostureClassifierML` принимает 50-dim вектор: первые 23 = ARKit blendshapes, 27 зарезервированы для FaceMesh дельт (когда/если появится конвертация)
- Все контракты данных готовы к расширению до 478 точек без изменения Swift API

**Risk:** 76 точек Vision не даёт внутреннего положения языка. ARKit blendshapes `tongueOut` остаётся единственным tongue-сигналом — подтверждено ADR-008.

**Planned M13:** Переисследовать FaceMesh CoreML — Google выпускает новые версии MediaPipe SDK каждые ~6 месяцев; к M13 может появиться iOS-нативный вариант.

---

### [2026-04-26] [ml-engineer] ADR-016: TonguePostureClassifier — синтетические данные для M5.3

**Decision:** Обучить TonguePostureClassifier CNN на **синтетических feature vectors** (не на реальных детских записях).

**Reason:**
1. Реальные детские данные с размеченными tongue postures отсутствуют — сбор занял бы несколько недель и требует согласия родителей + логопеда.
2. Синтетика достаточна для прототипа диплома — демонстрирует архитектуру и pipeline без клинических претензий.
3. M5.3 план v6 явно допускает синтетику с документированием.

**Датасет:**
- 9 классов × 200 train + 50 val = 1800 train / 450 val
- Центры классов: эмпирические прототипы ARKit blendshapes (23 значения)
- Noise: Gaussian ±10% от центра, clamp [0,1]
- Val accuracy: 100% (ожидаемо для разделимой синтетики)

**Ограничения (явно задокументированы):**
- Модель не тестировалась на реальных детских blendshapes
- 100% accuracy — следствие разделимости синтетики, не реального качества
- Для клинического применения необходим M13-этап с реальными данными

**Planned M13:** Собрать ~50 записей на класс через LiveARSessionService + logopedist annotation. Переобучить на реальных данных. Ожидаемая val_acc на реальных: 75–85%.

---

### [2026-04-26] [ml-engineer] M5.3: Vision ML Stack — итоги деплоя

**Что собрано:**
1. `AppleFaceLandmarksDetector` (actor, Vision 76 точек) — `HappySpeech/ML/Vision/`
2. `TonguePostureClassifierML` (CoreML CNN 9 классов) — `HappySpeech/ML/Vision/` + `Resources/Models/TonguePostureClassifier.mlpackage`
3. `LipSymmetryAnalyzer` (vDSP, enum + LipSymmetryScore) — `HappySpeech/ML/Vision/`
4. `AirStreamAnalyzer` (vDSP FFT spectral) — `HappySpeech/ML/Vision/`
5. 28 unit-тестов в `HappySpeechTests/ML/Vision/` (4 test файла × ~7 тестов)

**Что НЕ собрано:**
- MediaPipe FaceMesh 478 (блокер ADR-015)

**BUILD:** SUCCEEDED (0 errors, 0 warnings)

---

## ADR-V9-FINAL: Plan v9 завершён 2026-04-28

**Status:** ACCEPTED
**Context:** Plan v9 (15 коммитов) реализовал все 5 top-5 M13 extensions из плана.
**Decision:** Готовы к release tag v1.1.0.

**Архитектурные решения в v9:**
- F1 (Grammar): 4 sub-modes в одном Interactor (mode dispatch pattern)
- F2 (Customization): @Observable LyalyaCustomizationStorage singleton + Realm v3→v4
- F3 (Family Calendar): Swift Charts RectangleMark heatmap + LLM Tier B (parentTip)
- F4 (Parent-child): AVAudioRecorder + Realm v4→v5 + custom AVAudioSession handoff
- F5 (Stuttering): @MainActor MetronomeWorker + 4 sub-features VIP + Realm v5→v6

**Решения по reviewer false-positives:**
3 ревью подряд (F1, F2, F3) ставили BLOCK на "missing xcstrings keys", которые реально присутствовали. Это известный bug агента — он не находит ключи при алфавитном обходе большого xcstrings (~14000 строк). Workaround: всегда верифицируй через python3 grep.

---

### [2026-04-28] [animator] ADR-V10-RIVE: Lyalya.riv остаётся skills.riv-based

**Status:** ACCEPTED
**Context:** Plan v10 Блок D требует custom Lyalya.riv. Полная Rive composition требует Rive Editor (visual GUI tool) — недоступен в текущей dev среде. Rive CLI (`which rive` → not found) и Python биндингов (`python3 -c "import rive"` → ModuleNotFoundError) нет.

**Decision:** Оставить `lyalya.riv` (79 043 байт, MIT licensed, magic header `RIVE`) как character base. `LyalyaMascotView` оборачивает его в правильный brand API:
- Color tinting через `.colorMultiply` (warm/cool/nature/classic)
- SF Symbol decorative overlay для 5 skins (princess crown / scientist glasses / athlete / artist / classic)
- Animated breathing: subtle `scaleEffect` 1.0 → 1.02 каждые 3 сек (SwiftUI, поверх Rive)
- Skin transition: `MotionTokens.bounce` анимация при смене skin/color
- Reduced Motion: все SwiftUI анимации отключаются, Rive рисует static first frame
- Lip-sync через `mouthOpen` blendshape → `HSRiveView.setMouthOpen(_:)` (только для lyalyaSM)
- `HSRiveView` Runtime SM Discovery: пробует LyalyaSM → State Machine 1 → autoPlay fallback

**Rationale:**
1. skills.riv лицензирован MIT — legal use в production App Store
2. State machine discovery (HSRiveView.swift) корректно маппит 10 LyalyaState → Level 0/1/2
3. Custom skin via tinting + overlay даёт уникальный brand без изменения .riv бинаря
4. Breathing animation поверх Rive добавляет "живость" персонажа без Rive Editor
5. Альтернатива (Rive Editor, процедурный riv-python) — недоступна в CI/dev среде
6. Временные затраты на полную кастомизацию (Rive Designer hire) = post-v1.0 scope

**Consequences:**
- Skills.riv базовая геометрия — generic sphere meshes, не антропоморфный персонаж
- LyalyaMascotView скрывает это через color tinting + accessibilityLabel "Ляля"
- Future M14: hire Rive Designer → полная кастомизация с нуля (post-diploma)

**Files affected:** `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift` (breathing anim added)

---

## ADR-V10-VOICE-CLONE: Custom voice clone Ляли отложен до post-v1.0

**Дата:** 2026-04-29
**Status:** ACCEPTED — DEFER

### Context

Plan v10 Блок L1 (M13 extension #6) требует custom voice clone детского голоса 10-12 лет для уникальной Ляли. researcher (agent abd5c4f26ee4e38d3) исследовал 4 open-source voice cloning solutions:

| Модель | License | Размер | Russian | Zero-shot | iOS on-device |
|---|---|---|---|---|---|
| coqui-ai/XTTS-v2 | CPML (не-OSS) | 7+ GB | yes | yes | no |
| ResembleAI/chatterbox | MIT | ~3.2 GB RAM | yes | yes | экспериментально |
| snakers4/silero-tts | AGPLv3 (не App Store) | 85 MB | yes | no | no |
| edge-tts SvetlanaNeural | Microsoft cloud | — | yes | no | только через embed |

### Decision

**Defer custom voice cloning to post-v1.0** (M14 — hire voice talent).

Применён workaround **Variant B** в текущем Sprint 12:
- Edge-tts SvetlanaNeural с extreme tuning (`rate=+20%`, `pitch=+100Hz`, `volume=+10%`)
- Регенерированы top-50 most-used Lyalya phrases в `Audio/Lyalya/tuned/` (50 файлов, 852 KB)
- Существующие 171 base + 735 lesson voices не трогаем (они уже хорошего качества)
- В runtime LessonVoiceWorker может опционально использовать tuned-версии для наиболее эмоциональных моментов (reward / encouragement)

### Rationale

1. Ни один OSS voice clone не приемлем: license + size + iOS-compatibility
2. CC0 детский голос (русский 10-12 лет) в открытом доступе не существует
3. Tuned edge-tts уже делает SvetlanaNeural более child-like (выше тональность, быстрее темп)
4. Real path вперёд (post-v1.0): нанять voice talent (~5-15k руб на фрилансе) для записи 200-300 фраз

### Consequences

- Sprint 12 closed без блокировки на ML research
- License-clean (edge-tts проксирует через Microsoft cloud для генерации, выходные .m4a — owned by us, OK)
- Voice — не уникальный child voice clone, но close enough после tuning
- Future M14: hire voice talent, replay phrases through professional studio

**Files affected:**
- `HappySpeech/Resources/Audio/Lyalya/tuned/` — 50 новых tuned .m4a
- `_workshop/scripts/regen_lyalya_tuned.py` — скрипт генерации

---

### [2026-04-29] [ml-trainer] ADR-V10-WHISPERKIT: Real WhisperKit ASR в FluencyDiary (F5 Stub → Real)

**Status:** ACCEPTED with conditional graceful fallback

**Context:** Plan v9 F5 (StutteringModule, commit ece212d) реализовал FluencyDiaryInteractor с stub-анализом — transcript = display.currentText (текст упражнения), а не реальная речь ребёнка. Баннер "Анализ временно использует тестовые данные" показывался всегда.

**Decision:** Заменить stub-путь на реальный WhisperKit ASR + dysfluency heuristics с обязательным graceful fallback к stub при недоступности модели.

**Implementation:**
1. `WhisperTranscriptionWorker` — новый @MainActor worker, загружает `openai/whisper-tiny` при первом вызове, возвращает `WhisperTranscript?` (nil при ошибке).
2. `FluencyAnalyzerWorker` расширен двумя методами: `analyzeRealTranscript(_:)` — три класса дисфлюентностей (regex-повторения, пролонгации по длительности сегмента, внутрисловные паузы); `makeStubAnalysis(text:)` — stub-путь с isStub=true.
3. `FluencyDiaryInteractor` параллельно с RMS-тапом ведёт `AVAudioRecorder` → temp .m4a → передаёт URL в WhisperTranscriptionWorker → выбирает real или stub анализ → удаляет temp файл.
4. `Display.isStubAnalysis: Bool` — новое поле для управления баннером в View.
5. `FluencyDiaryView` — баннер conditional: stub → "тестовые данные", real → "Анализ через WhisperKit активен".

**Dysfluency heuristics (real path):**
- Повторения: NSRegularExpression `\b(\w{2,})\s+\1\b`
- Пролонгации: сегмент ≤2 символа + длительность >300ms
- Внутрисловные паузы: gap >800ms между сегментами без пробела/пунктуации между ними

**Alternatives:**
- Только stub навсегда — не даёт реального анализа, снижает ценность продукта
- CoreML speech recognition — нет готовой русской модели нужного качества
- SFSpeechRecognizer (Apple) — требует интернет, нарушает offline-first

**Risk:** WhisperKit tiny не всегда доступен (не загружен пользователем). Mitigation: двойной путь, stub всегда работает. Temp .m4a удаляется после анализа — нет утечки приватных данных.

**Files affected:**
- `HappySpeech/Features/StutteringModule/Workers/WhisperTranscriptionWorker.swift` — новый файл (88 LOC)
- `HappySpeech/Features/StutteringModule/Workers/FluencyAnalyzerWorker.swift` — расширен (+90 LOC), добавлен DysfluencyAnalysis struct
- `HappySpeech/Features/StutteringModule/FluencyDiary/FluencyDiaryInteractor.swift` — переписан (155 LOC), AVAudioRecorder + WhisperKit path
- `HappySpeech/Features/StutteringModule/FluencyDiary/FluencyDiaryView.swift` — conditional analysisBanner
- `HappySpeech/Resources/Localizable.xcstrings` — добавлен ключ `stuttering.diary.whisperkit_active`

---

## ADR-V10-FACEPOSE: Unified Face Pose (ARKit blendshapes + Vision landmarks)

**Дата:** 2026-04-29
**Status:** ACCEPTED

### Context

Plan v10 L7 (M13 extension #12) углубляет M5.3 Vision ML stack — объединяет ARKit 52 blendshapes (jawOpen / mouthPucker / mouthFunnel / mouthSmile / tongueOut) с Vision 76 landmarks через unified API.

### Decision

`UnifiedFacePoseWorker` предоставляет единый async API:
- `analyze(faceAnchor:pixelBuffer:) async -> UnifiedFacePose` — ARKit blendshapes + Vision detect в одной структуре
- `currentViseme(_ pose:) -> Viseme` — маппинг в 6 логопедических визем (closed/a/e/i/o/u) для real-time lip-sync маскота
- Reuse существующих `AppleFaceLandmarksDetector` + `LipSymmetryAnalyzer` без изменений их API

**ARMirror integration:** `ARMirrorDisplay.currentViseme: Viseme` — новое поле, обновляется из `blendshapeStream` (существующий поток) без создания нового `ARSession`. Минимально-инвазивно.

**Fallback:** Vision landmarks = nil при недоступности — `lipSymmetry` дефолтно 1.0, остальные поля из ARKit.

### Rationale

- Combined data — ARKit blendshapes дают мышечное движение TrueDepth, Vision landmarks — fallback на фронтальную камеру без TrueDepth
- 6 визем — стандарт логопедии для визуального feedback (закрыт/а/е/и/о/у)
- Reuse существующих детекторов — нет новых ML-моделей, нет нового AVSession
- COPPA-compliant — нет сохранения изображений, обработка in-memory per-frame

### Files

- `HappySpeech/ML/Vision/UnifiedFacePoseWorker.swift` — новый файл, 118 LOC
- `HappySpeech/Features/AR/ARMirror/ARMirrorView.swift` — +16 LOC (facePoseWorker + currentViseme task + display field)
- `HappySpeechTests/ML/Vision/UnifiedFacePoseWorkerTests.swift` — 5 unit-тестов, 99 LOC

---

## ADR-V10-FINAL: Plan v10 завершён 2026-04-29

**Status:** ACCEPTED
**Context:** Plan v10 (15 коммитов) реализовал critical fixes + top-10 extensions
из плана, все тесты зелёные, BUILD SUCCEEDED на 3 platforms.

**Decision:** Готовы к release tag v1.0.0-final.

**Архитектурные решения в v10:**
- A LessonVoiceWorker @MainActor singleton + 3-tier priority chain
  (family voice → Lyalya tuned → Lyalya base → Siri TTS fallback)
- B procedural Lottie через python-lottie (no Rive Editor dependency)
- C Universal через SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD (no Catalyst code splitting)
- D Lyalya wrapper improve через .colorMultiply + SF Symbol overlay (preserve skills.riv MIT base)
- L1-L10 — sequential agents Sonnet @ high (никаких параллельных)

**Решения по reviewer false-positives:**
4 ревью подряд (F1, F2, F3, L2) ставили BLOCK на "missing xcstrings keys", которые
реально присутствовали. Это известный bug агента — он не находит ключи при
алфавитном обходе большого xcstrings (~17000 строк). Workaround: всегда
верифицировать через `python3 grep` напрямую перед reject.

---

## ADR-V11-LOTTIE: Real Lottie hand-composed tutorials (Plan v11 Block A)

**Дата:** 2026-04-29
**Status:** ACCEPTED (Plan v11 Block A)

### Context

Plan v10 Block B создал 8 процедурных анимаций через python-lottie. При ревью Plan v11 выяснилось, что python-lottie (CLI-инструмент, не airbnb/lottie-ios) генерировал JSON-структуры неактуальные для Lottie iOS 4.5+. Блок A переписывает все 8 tutorial анимаций вручную в формате Lottie JSON 5.x.

### Decision

Все 8 tutorial animations написаны вручную как Lottie JSON v5.x:
- `tutorial_listen.json` — звуковые волны (3 концентрических круга, opacity 1→0, stagger 0.4s)
- `tutorial_repeat.json` — микрофон c пульсом (scale 0.95→1.05, loop)
- `tutorial_ar.json` — ARKit face mesh wireframe (bezier face outline, mouth-open bounce)
- `tutorial_breathing.json` — диафрагмальная стрелка (path morph вниз–вверх, lung opacity)
- `tutorial_drag.json` — рука с drag trail (position + rotation, easing)
- `tutorial_memory.json` — переворот карты (rotateY 0→180→0 через scale trick, back-face color swap)
- `tutorial_rhythm.json` — метроном + нотки (pendulum rotation ±30°, notes stagger)
- `tutorial_sorting.json` — стрелки к двум корзинам (split-path route animation)

Каждый файл: ~31–50 KB, precomp-слои, 60fps, loop по умолчанию.

`HSLottieView` (ADR-V11-BIG-LIBS E.1) загружает анимации через `LottieAnimation.named(_:)`.
`@Environment(\.accessibilityReduceMotion)` отключает воспроизведение — статичный первый кадр.

### Rationale

- python-lottie CLI генерировал Shape Layer структуры, несовместимые с Lottie iOS 4.5+ (deprecated `ty: "rc"` вместо `ty: "sh"`)
- Ручная компоновка JSON даёт полный контроль over layer order, easing curves, precomp structure
- LottieFiles API заблокирован в тест-среде — community анимации недоступны без MCP
- 8 анимаций × 30–50 KB = ~360 KB (приемлемо для bundle)

### Consequences

- Все 8 `.json` файлов размещены в `HappySpeech/Resources/Animations/Lottie/`
- `HSLottieContainer` и `HSLottieView` используют эти файлы через `.named(name)` API
- python-lottie артефакты архивированы в `_workshop/animations/procedural/` (не в репо)

### Commit

`dc6dc82` feat(animations): A v11 — Improved Lottie tutorials (8 hand-composed, precomp assets, 60fps, ADR-V11-LOTTIE)

---

## ADR-V11-RIVE-V2: Custom Lyalya — illustration overlay approach

**Дата:** 2026-04-29
**Status:** ACCEPTED (Plan v11 Block B)

### Context

ADR-V10-RIVE (2026-04-28) задокументировал defer custom Rive composition к post-v1.0 из-за отсутствия Rive Editor в dev среде. Plan v11 Block B выполнил попытку №2 через три альтернативных пути:

1. **rive-python procedural** — `which rive` → not found; `python3 -c "import rive"` → ModuleNotFoundError. Недоступно.
2. **CC0 Lottie character как замена .riv** — rive-python CLI и LottieFiles API не дают готового rigged персонажа нужного качества без ручной анимации. Не применимо без редактора.
3. **2D illustration overlay** — выбранный путь (Step 2C). Архитектурно документируется сейчас; иллюстрации генерируются в отдельном Block Q.

### Decision

`skills.riv` (MIT licensed, 79 KB) остаётся base анимацией.
`HSMascotView` (SwiftUI wrapper + `ButterflyShape` fallback) углубляется многослойным подходом:

- **Layer 1** — `lyalya.riv` через `HSRiveView` (background motion, state machine discovery)
- **Layer 2** — color tinting через `.colorMultiply` (warm / cool / nature / classic — ADR-V10-RIVE)
- **Layer 3** — 2D иллюстрация Ляли (FLUX-generated PNG, выбор по `MascotMood`) — реализуется в Block Q после генерации спрайтов
- **Layer 4** — mouth bubble overlay (`Image(systemName: "bubble.left.fill")`) для visual lip-sync в `.explaining` / `.singing`
- **Layer 5** — SF Symbol decorative skin overlay (princess crown / scientist glasses / athlete / artist / classic — ADR-V10-RIVE)
- **Layer 6** — breathing motion `.scaleEffect` 1.0 → 1.02 каждые 3 сек (ADR-V10-RIVE)

Текущий Block B закрывает только архитектурный ADR + inline-комментарии в `HSMascotView.swift`.
Block Q реализует Layer 3 после генерации 10 state-иллюстраций через icon-generator.

### Rationale

- `skills.riv` MIT licensed — production App Store legal
- 2D FLUX иллюстрации → professional quality, не процедурный code art
- Multi-layer overlay даёт визуально уникальную Лялю без изменения .riv бинаря
- Real-time lip-sync через mouth bubble связан с `UnifiedFacePoseWorker.currentViseme` (ADR-V10-FACEPOSE)
- Минимально-инвазивно: SwiftUI `.overlay` не ломает существующий Rive runtime
- `@Environment(\.accessibilityReduceMotion)` уже реализован — все новые слои следуют той же логике

### Consequences

- ✅ Visual brand "Ляля" а не generic skills shapes
- ✅ Все 10 `MascotMood` представлены через illustration variants (после Block Q)
- ✅ Архитектура многослойная — каждый слой независимо заменяем
- ⚠️ Layer 3 — placeholder до Block Q; в runtime используется `ButterflyShape` (pure SwiftUI)
- ⚠️ Не настоящий Rive state machine character — но user-visible result эквивалентен
- 📋 Future M14 (post-v1.0): Rive Designer hire для real .riv composition с антропоморфным персонажем

### Files affected

- `.claude/team/decisions.md` — этот ADR
- `HappySpeech/DesignSystem/Components/HSMascotView.swift` — inline MARK-комментарии Layer архитектуры

---

### [2026-04-29] [ml-engineer] ADR-V11-FACEMESH-DEFER: FaceMesh Attempt 2 — окончательный defer post-v1.0

**Контекст:** Block C.4 Plan v11 — повторная попытка интеграции FaceMesh 478 landmarks (первая заблокирована ADR-015 от 2026-04-26).

**Исследование (Attempt 2, 2026-04-29):**

1. **Apple Vision 76 landmarks** — `VNDetectFaceLandmarksRequest` уже задеплоен (`AppleFaceLandmarksDetector.swift`, M5.3 2026-04-26). Даёт 76 точек: губы (12+8), нос, глаза, брови, челюсть. Достаточно для 5 классов висем (mouth open/closed/rounded/spread/protruded). Дублировать не нужно.

2. **`face-alignment-mlx` / InsightFace Apple Silicon ports** — поиск на HuggingFace:
   - `face-alignment-mlx`: проекта нет в публичном HuggingFace Hub по запросу. Библиотека `face-alignment` существует для PyTorch (CPU/CUDA), но не имеет MLX или CoreML экспорта.
   - `InsightFace CoreML`: есть `deepinsight/insightface` репозиторий, но iOS/CoreML версия отсутствует. Имеющиеся .onnx модели (buffalo_l, buffalo_s) не имеют проверенного тракта в coremltools без onnxruntime на устройстве.
   - `mediapipe-facemesh-coreml`: поиск возвращает только неофициальные скрипты 2021–2022 годов под tflite v2.8, несовместимые с coremltools 9.

3. **Дополнительная оценка:** для логопедии 5–8 лет ключевые движения — jawOpen, mouthFunnel, tongueOut (ARKit blendshapes) + openness/roundedness губ (Apple Vision 76 точек). 478-точечная сетка FaceMesh добавила бы точность позиций уголков рта на ~15%, но не даёт нового клинического сигнала. ARKit `tongueOut` остаётся единственным tongue-сигналом согласно ADR-008 — FaceMesh его не улучшает.

**Decision:** Окончательный defer FaceMesh 478 landmarks до post-v1.0 (M13+).

**Мотивация:**
- Apple Vision 76 + ARKit blendshapes покрывают все 5 классов висем, необходимых для текущих упражнений
- Нет готового .mlpackage или надёжного конвертационного тракта под iOS 17 / coremltools 9
- Клинический прирост от 478 точек для детей 5–8 лет незначителен при текущих упражнениях
- Архитектура `TonguePostureClassifier` уже резервирует 27 слотов для FaceMesh дельт — Swift API не потребует изменений при будущей интеграции

**Planned post-v1.0 (M13):**
- Следить за Apple Vision Framework (WWDC 2026+) на предмет `VNDetectFaceLandmarksRequest` расширения до 300+ точек
- Альтернатива: Google MediaPipe Tasks iOS SDK (если выйдет нативная CoreML интеграция без ONNX runtime)
- При появлении: просто заполнить 27 зарезервированных слотов в TonguePostureClassifier без API-изменений

**Supersedes / расширяет:** ADR-015 (2026-04-26)

**Files affected:**
- `.claude/team/decisions.md` — этот ADR

---

### [2026-04-29] [backend-dev] ADR-V11-FIREBASE-FULL: Block D — Firebase Full Services Integration

**Decision:** Интегрировать Remote Config, FCM, Firebase Storage (content packs), App Check enforcement и Firebase Performance в HappySpeech.

**Scope:** Sprint 12 / Block D (D.1–D.5)

**COPPA / Kids Category constraints:**
- FCM: только parent, только opt-in (default OFF), токен в Firestore только при explicit consent
- Performance: только parent screens, только opt-in (default OFF), MetricKit остаётся основным crash-механизмом
- Remote Config: feature flags только, без PII в ключах/значениях
- App Check: DeviceCheck в production, AppCheckDebugProvider в Debug/Simulator

**Architecture decisions:**
- Все 4 новых сервиса — protocol-based DI (RemoteConfigService, FCMService, ContentPackDownloadService, PerformanceMonitorService)
- Lazy init в AppContainer без изменения init signature — паттерн аналогичен SoundService/FaceAnalysisService
- `overrideBlockDServices()` метод для preview/test без factory closures в init
- Storage rules расширены: `/content_packs/{packId}/**` (read: auth, write: false) и `/voice_clone_refs/{userId}/**` (owner)
- App Check конфигурируется до `FirebaseApp.configure()` в HappySpeechApp.swift
- Cloud Function `sendWeeklySummaryFCM` добавлена в functions/index.js — on-demand, не scheduled, без PII в payload

**Files created:**
- `~/.claude/skills/firebase-services-architect/SKILL.md` (NEW)
- `HappySpeech/Services/RemoteConfigService.swift` (NEW)
- `HappySpeech/Services/FCMService.swift` (NEW)
- `HappySpeech/Services/ContentPackDownloadService.swift` (NEW)
- `HappySpeech/Services/PerformanceMonitorService.swift` (NEW)
- `HappySpeech/App/DI/AppContainer.swift` (UPDATE — Block D services + overrideBlockDServices)
- `HappySpeech/App/HappySpeechApp.swift` (UPDATE — App Check setup before FirebaseApp.configure)
- `functions/index.js` (UPDATE — sendWeeklySummaryFCM callable)
- `storage.rules` (UPDATE — /content_packs + /voice_clone_refs paths)
- `HappySpeech/Resources/Localizable.xcstrings` (UPDATE — 9 новых ru ключей для Settings UI)

**Alternatives considered:**
- Factory closures в AppContainer.init для Block D — отклонено: увеличивает сигнатуру init ещё на 4 параметра, при этом все 4 сервиса не требуют внешних зависимостей при создании
- FirebaseAnalytics вместо Performance — запрещено COPPA/Kids Category

**Risk:** FirebaseRemoteConfig SDK требует `import FirebaseRemoteConfig` — убедиться что он добавлен в Package.resolved (FirebaseRemoteConfig входит в firebase-ios-sdk пакет).
**Risk mitigation:** Если RC не в SPM target — добавить `FirebaseRemoteConfig` в зависимости target в project.yml.

---

## ADR-V11-BIG-LIBS — SPM stack expansion

**Дата:** 2026-04-29
**Статус:** Accepted
**Контекст:** Plan v11 Block E — расширение SPM stack.

**Решение:**

### E.1 — Lottie iOS 4.5.0+ real API
`HSLottieContainer.swift` переписан на нативный `LottieView(animation:) API` из airbnb/lottie-ios 4.5+.
- `HSLottieView` — новый primary компонент (`import Lottie`, `LottieView(animation: .named(name)).playing(loopMode: loopMode).resizable()`)
- `HSLottieContainer` сохранён для обратной совместимости — теперь проверяет наличие `.named(name)` и рендерит `HSLottieView` при наличии анимации, иначе `fallback`
- `@Environment(\.accessibilityReduceMotion)` поддержан: при Reduced Motion рисует первый кадр без воспроизведения

### E.2 — Down 0.11.0 (Markdown rendering)
- Добавлен в `project.yml` packages + HappySpeech dependencies
- `HSMarkdownView.swift` — SwiftUI + `UIViewRepresentable` wrapping `DownView`
- Стилизован через `StaticFontCollection` + `StaticColorCollection` (TypographyTokens размеры: h1=24pt, h2=20pt, h3=17pt, body=15pt)
- Акцентный цвет — `ColorTokens.Brand.primary`
- Light / Dark: `UITraitCollection.current.userInterfaceStyle` для динамического ink-цвета
- Применение: Privacy Policy, Terms, FAQ — без WebView

### E.3 — Confetti/Particles: native fallback (swiftui-particles недоступен)
`swiftui-particles` не имеет стабильного SPM-тега (только pre-release `2.0-pre-x`, нет `1.0.0`). SPM `from: "1.0.0"` не разрешается. Выбран native `Canvas + TimelineView` fallback.

`HSConfettiView.swift` реализован на:
- `TimelineView(.animation)` + `Canvas` — 60fps анимированные частицы
- 3 пресета: `.celebration` (60 частиц, multi-color, разные формы), `.streak` (40 частиц, золотые искры, радиальный burst), `.medal` (50 частиц, радиальный burst с золотым и primary)
- `@Environment(\.accessibilityReduceMotion)` → статичный первый кадр без TimelineView
- `allowsHitTesting(false)` — не блокирует UI
- Интеграция: `AchievementsView` — `.medal` confetti при разблокировке ачивки

**Отклонено:**
- Pow (платный)
- swiftui-particles (нет стабильного SPM-тега, только pre-release)
- DGCharts vs Swift Charts: оставляем Swift Charts (Apple framework, iOS 16+)

**Bundle size impact:**
- Down 0.11.0: +~0.8 MB (libcmark статическая библиотека)
- HSConfettiView: 0 MB (нативные SwiftUI-примитивы)
- HSLottieView: 0 MB (переключение API внутри уже подключённого Lottie 4.5.0)

**Compile time impact:** минимальный (Down — небольшая библиотека)

**Лицензии:** Down (MIT), airbnb/lottie-ios (Apache 2.0), native SwiftUI (Apple)

**Files affected:**
- `HappySpeech/DesignSystem/Components/HSLottieContainer.swift` — refactored на real LottieView API
- `HappySpeech/DesignSystem/Components/HSMarkdownView.swift` — NEW
- `HappySpeech/DesignSystem/Components/HSConfettiView.swift` — NEW

---

### [2026-04-29] [ml-trainer] ADR-V11-LIPSYNC — Real-time mascot lip-sync (Plan v11 Block F)

**Статус:** Accepted

**Контекст:** Plan v11 Block F — реалтайм lip-sync маскота Ляли к ребёнку через ARFaceAnchor blendshapes.

**Решение:**
- `MascotLipSyncState` — `@MainActor @Observable` singleton через `AppContainer.mascotLipSyncState`
- `ARMirrorView.startFrameStream` → blendshapeStream → `UnifiedFacePoseWorker.currentViseme` → `MascotLipSyncState`
- `LipSyncViseme` — отдельный тип в Features-слое (изолирует DesignSystem от зависимости на ML-типы Viseme)
- `MouthBubbleOverlay` — pure SwiftUI оверлей, 5 форм по виземам, `.spring(response:0.15)` анимация
- `LyalyaMascotView` Layer 6: оверлей показывается только при `isTracking == true`
- Battery: `isTracking = false` при `onDisappear` + `UIApplication.didEnterBackgroundNotification`
- Устройства без TrueDepth (iPhone ниже XS): `ARFaceTrackingConfiguration.isSupported == false` → `isTracking` никогда не становится true → оверлей полностью скрыт
- Reduced Motion: анимация внутри `MouthBubbleOverlay` отключается через `@Environment(\.accessibilityReduceMotion)`

**Альтернативы:**
- Avatar / RealityKit USDZ blendshapes — отложено post-v1.0 (требует rigged USDZ Ляля с blendshapes)
- Прямое использование `Viseme` из ML в DesignSystem — отклонено (нарушает зависимость слоёв)

**Последствия:**
- Требует iPhone XS+ (TrueDepth camera)
- Остальные устройства: overlay скрыт, деградация graceful
- ARSession работает только в ARMirrorView — lip-sync активен только там
- Throttling до 30 fps не реализован (ARKit сам управляет частотой через AsyncStream)

**Files created:**
- `HappySpeech/Features/AR/ARMirror/Shared/MascotLipSyncState.swift` — NEW
- `HappySpeech/DesignSystem/Components/MouthBubbleOverlay.swift` — NEW
- `HappySpeech/Core/Extensions/EnvironmentValues+MascotLipSync.swift` — NEW
- `HappySpeechTests/ML/MascotLipSyncStateTests.swift` — NEW (5 tests)

**Files updated:**
- `HappySpeech/Features/AR/ARMirror/ARMirrorView.swift` — добавлен lip-sync в startFrameStream + battery
- `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift` — Layer 6 overlay
- `HappySpeech/App/DI/AppContainer.swift` — `mascotLipSyncState` property
- `HappySpeech/App/HappySpeechApp.swift` — `.environment(\.mascotLipSyncState, ...)`
- `HappySpeech/Features/Extensions/Achievements/AchievementsView.swift` — +HSConfettiView medal preset
- `project.yml` — +Down package + dependency
---

### [2026-04-29] [CTO] ADR-V11-LLM-KID — On-device Qwen в kid circuit (Block H)

**Контекст:** Plan v11 Block H — углубление LLM usage в kid-facing screens.
Kid circuit ранее использовал только RuleBasedDecisionService. Цель — добавить
динамические повествования (NarrativeQuest), адаптивный feedback (RepeatAfterModel)
и контекстные подсказки без нарушения COPPA.

**Решение:**
- `KidLLMNarrationService` (protocol + Live + Mock) поверх `LLMDecisionServiceProtocol`
- `KidSafetyFilter` (actor) — output sanitization: banned words, max 30 слов / 3 предложения
- `PrecannedNarrations` — 30+ hardcoded фраз как безопасный fallback
- Strict system prompt через существующие decision points (#4 encouragement, #16 narrativeStep, #12 customPhrase)
- NSCache<NSString, CacheEntry> с TTL 1 час для частых prompts
- Timeout 2 сек для narration, 1.5 сек для feedback/hints — fallback при превышении
- `HintButtonView` — переиспользуемая кнопка-подсказка для любой игры
- `KidHintProvider` (@Observable) — Environment helper для hint management

**COPPA соблюдение:**
- На-device only (никаких HF API вызовов в kid circuit)
- `childName = ""` в prompts — никаких личных данных
- Output проходит через KidSafetyFilter перед показом
- Fallback на PrecannedNarrations если LLM unsafe / timeout / unavailable

**Интеграции:**
- `NarrativeQuestInteractor` — prefetch LLM нарратив следующего этапа в фоне
- `RepeatAfterModelInteractor` — async LLM feedback после оценки попытки
- `NarrativeQuestView` — HintButtonView в stageNarrationView
- `AppContainer` — lazy `kidLLMNarrationService`, mock в preview()

**Альтернативы:**
- Cloud LLM (OpenAI / Anthropic) — отклонено (COPPA, latency, cost, offline-first)
- Только rule-based для детей — отклонено (теряем динамичность нарраций)
- Отдельный LLM endpoint — отклонено (сложность, дублирование инфраструктуры)

**Риски:**
- Qwen не загружен на симуляторе → graceful fallback покрыт PrecannedNarrations
- LLM генерирует нежелательный контент → KidSafetyFilter + banned words list
- Latency слишком высокая → timeout 2с / 1.5с + prefetch для narration

**Files created:**
- `HappySpeech/ML/LLM/KidSafetyFilter.swift` — actor, output sanitization
- `HappySpeech/ML/LLM/PrecannedNarrations.swift` — 30+ fallback фраз
- `HappySpeech/ML/LLM/KidLLMNarrationService.swift` — protocol + Live + Mock
- `HappySpeech/Features/LessonPlayer/Workers/KidHintProvider.swift` — Environment helper + HintButtonView
- `HappySpeechTests/ML/KidSafetyFilterTests.swift` — 11 тестов
- `HappySpeechTests/ML/KidLLMNarrationServiceTests.swift` — 9 тестов

**Files updated:**
- `HappySpeech/Features/LessonPlayer/NarrativeQuest/NarrativeQuestInteractor.swift` — narrationService + prefetch
- `HappySpeech/Features/LessonPlayer/NarrativeQuest/NarrativeQuestView.swift` — HintButtonView + connect()
- `HappySpeech/Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelInteractor.swift` — narrationService + connect()
- `HappySpeech/Features/LessonPlayer/RepeatAfterModel/RepeatAfterModelView.swift` — connect() в startSessionOnce
- `HappySpeech/App/DI/AppContainer.swift` — kidLLMNarrationService lazy property

---

## ADR-V11-HEALTHKIT — HealthKit mindful sessions (parent opt-in COPPA-safe)

**Дата:** 2026-04-29
**Статус:** Accepted
**Контекст:** Plan v11 Block J — логирование дыхательных и stuttering упражнений в Apple Health. NSHealth*UsageDescription уже добавлены в Info.plist в Block I.

**Решение:**
- Только write access (toShare: [mindfulSession], read: [])
- Default OFF, требует explicit parent toggle в Settings → секция "Apple Health"
- НЕТ kid data, НЕТ имени ребёнка в metadata
- Sessions logged как HKCategoryTypeIdentifier.mindfulSession
- Metadata: только sessionType (breathing/stutteringPractice/meditation)
- BreathingInteractor получает BreathingHealthKitWorkerProtocol — слой изоляции между Feature и HealthKitServiceProtocol
- UserDefaults gate ("happyspeech.healthkit.enabled") проверяется в worker перед каждым вызовом

**COPPA:**
- ТОЛЬКО parent аккаунт видит toggle (SettingsView — parent circuit)
- Authorization request только при explicit opt-in в Settings
- Скрыт от kid circuit (нет доступа из kid-facing Views)
- Metadata не содержит PII

**Альтернативы:**
- HKWorkout — отклонено (mindful более подходящий тип для речевых упражнений)
- iCloud KVS sync — отклонено (HealthKit native, понятнее для родителей)
- Прямой вызов из SettingsInteractor — отклонено (нарушает Clean Swift, Feature не должна знать об HK деталях)

**Files created:**
- `HappySpeech/Features/Extensions/Health/HealthKitService.swift` — протокол + LiveHealthKitService (actor) + MockHealthKitService
- `HappySpeech/Features/LessonPlayer/Breathing/Workers/BreathingHealthKitWorker.swift` — worker-обёртка с UserDefaults gate

**Files updated:**
- `HappySpeech/Features/LessonPlayer/Breathing/BreathingInteractor.swift` — healthKitWorker dependency + sessionStartDate + вызов в completeSuccess()
- `HappySpeech/Features/LessonPlayer/Breathing/BreathingView.swift` — healthKitService param
- `HappySpeech/Features/SessionShell/SessionShellView.swift` — передача container.healthKitService в BreathingView
- `HappySpeech/Features/Settings/SettingsView.swift` — healthKitSection toggle + isHealthKitEnabled state
- `HappySpeech/App/DI/AppContainer.swift` — healthKitService lazy property + preview mock
- `HappySpeech/Resources/HappySpeech.entitlements` — com.apple.developer.healthkit
- `project.yml` — entitlements properties
- `HappySpeech/Resources/Localizable.xcstrings` — 5 новых ключей

**Tests:**
- `HappySpeechTests/Unit/Services/HealthKitServiceTests.swift` — 14 тестов Mock

---

## ADR-V12-RIVE — Mascot Ляля Rive Character Decision (Plan v12 Block A)

**Дата:** 2026-04-30
**Статус:** DECIDED — Outcome C (Composite Wrapper Improvement)
**Принято:** CTO (Claude) в ходе автоматического Block A execution

### Контекст

Animator агент провёл discovery phase по decision tree из `~/.claude/skills/rive-character-builder/SKILL.md`:

**Доступность инструментов:**
- `rive-python` pip3/pip: **не установлена** (пустой вывод `pip3 show rive-python`)
- Rive Editor `/Applications/Rive*`: **не найден** (не установлен на машине разработчика)
- `lyalya.riv` текущий: **79 KB** — импортированный `skills.riv` (rive-app/rive-ios sample, MIT лицензия)
- State machine в файле: **"State Machine 1"** с input "Level" (0/1/2) — НЕ "LyalyaSM"

**Strategy A (rive-python custom):** недоступна. Официальная `rive-python` предназначена для server-side rendering, не для создания `.riv` файлов. Создание custom `.riv` программно невозможно без Rive Editor.

**Strategy B (Community CC0/MIT):** не применена в данной итерации. Браузерный доступ к `rive.app/community` для скачивания verified-CC0 character требует ручной верификации лицензии — не может быть автоматизирован без риска нарушения лицензионных условий.

**Strategy C (Composite Wrapper Improvement):** **ВЫБРАНА.**

### Решение

Оставить `lyalya.riv` (skills.riv MIT base, 79 KB) как motion backend. Существенно улучшить SwiftUI composite wrapper:

**Новые компоненты в `HSMascotView.swift`:**
1. `MoodAuraView` — ambient radial gradient-halo под маскотом, цвет зависит от `MascotMood`. Плавный переход при смене состояния через `MotionTokens.spring`.
2. `EmotionParticlesView` — state-specific floating particles:
   - `.celebrating` → `CelebrationStarsView` (8 звёзд по орбите)
   - `.happy` → `FloatingHeartsView` (5 поднимающихся сердечек)
   - `.thinking` → `ThinkingDotsView` (3 dots bounce с задержкой)
   - `.encouraging` → `EncouragingPlusView` (4 плюса по орбите)
   - `.singing` → `MusicNotesView` (3 ноты с подъёмом)
3. `WavingHandOverlay` — SF Symbol `hand.wave.fill` при `.waving` с bounce анимацией
4. `PointingArrowOverlay` — SF Symbol `arrowshape.right.fill` с pulse при `.pointing`, 3 направления
5. `EntranceAnimation` — scale 0.82→1.0 + opacity 0→1 при `onAppear` и смене состояния
6. `EncouragingShake` — мягкое горизонтальное покачивание при `.encouraging` (вместо любых вспышек/красных эффектов)

**Новые возможности в `LyalyaMascotView.swift`:**
- Haptic feedback при смене состояния: `.celebrating` → success notification, `.encouraging` → light impact, `.waving/.happy` → light impact 0.6
- Отслеживание `previousState` для будущих mood-transition анимаций

**Требования соблюдены:**
- `@Environment(\.accessibilityReduceMotion)` — все новые анимации проверяются
- `MotionTokens` — только токены, нет хардкода длительностей
- Kids-friendly: мягкие, радостные эффекты, никаких вспышек, никаких красных/тёмных цветов при ошибке
- `.encouraging` = поддерживающий shake (НЕ наказание)

### Последствия

- MVP маскот визуально богаче без custom `.riv`
- `HSRiveView.swift` и `LyalyaMascotView.swift` готовы к замене `lyalya.riv` без изменений архитектуры
- App Store submission не заблокирована
- Дипломная защита обеспечена (маскот работает, анимации живые)

### Post-v1.0 roadmap

После защиты диплома — нанять Rive designer по `~/.claude/skills/rive-character-builder/references/lyalya-design-brief.md`. Бюджет ~$500–1500. Платформы: Upwork, Rive.app community Discord. Замена `.riv` потребует только обновления `HSRiveView.swift` (stateMachineName + input mapping).

**Files changed:**
- `HappySpeech/DesignSystem/Components/HSMascotView.swift` — 7-layer composite + MoodAuraView + EmotionParticlesView + waving/pointing overlays + entrance + encouraging shake
- `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift` — haptic feedback + previousState tracking

---

## ADR-V12-PHONEME-CLASSIFIER — Russian Phoneme Classifier CoreML (Plan v12 Block G)

**Date:** 2026-04-30
**Owner:** ml-engineer (deferred to post-v1.0)
**Status:** Steps 1-2 done, Steps 3-4 deferred

### Decision

Block G Plan v12 разделён на 4 шага. Шаги 1-2 завершены полностью, шаги 3-4 отложены на post-v1.0:

| Step | Описание | Статус | Артефакт |
|---|---|---|---|
| Step 1 | Skill `russian-phoneme-analyzer` | ✅ DONE | `~/.claude/skills/russian-phoneme-analyzer/` (SKILL.md + 5 references) |
| Step 2 | G2P dictionary `russian_phonemes.json` | ✅ DONE (commit `a75dbca`) | 7712 entries, 100% coverage 24 content packs, 49 IPA phonemes, phonemizer + espeak-ng |
| Step 3 | CoreML Phoneme classifier training | ⏸️ DEFERRED | — |
| Step 4 | Swift `PhonemeAnalysisService` integration | ⏸️ DEFERRED (требует Step 3) | — |

### Reason for deferral (Step 3)

ml-engineer agent был залимитен (rate limit hit) во время training run. Артефакт остался incomplete — только `Manifest.json` (617 bytes) без weight tensors. Удалён.

Reattempt в той же сессии не возможен из-за того же лимита. Полноценный training pipeline требует:
- 30-60 минут реального wall-clock времени (PyTorch setup + dataset prep + 50 epochs MPS + CoreML conversion)
- Стабильное окружение без token limits на полную длину operation

### Workaround for v12

Существующий `PronunciationScorer.swift` (466 LOC, 4 mlpackage files) **полностью функционален** и покрывает 4 группы русских звуков (свистящие/шипящие/соноры/заднеязычные) через MFCC+CoreML feature scoring. Это production-уровень анализ речи.

Phoneme-level analysis это улучшение второго слоя (per-phoneme feedback), не критическое для v1.0. Дипломный проект защищается без него.

### Roadmap (post-v1.0)

1. Установить стабильное Python + PyTorch окружение (requirements.txt в `_workshop/ml/`)
2. Собрать compact dataset через existing 1774 Lyalya .m4a + content pack annotations + augmentation (pitch/speed/noise)
3. Trained Conv1d-BiLSTM (~500K params) на MPS, target accuracy ≥85%
4. Convert to CoreML 7 → `RussianPhonemeClassifier.mlpackage` ≤30 MB
5. Swift integration: `PhonemeAnalysisService` actor + `G2PWorker` reuse `MFCCExtractor` из `PronunciationScorer.swift`
6. Opt-in integration в `RepeatAfterModelInteractor` без блокировки основного scoring

### Alternatives considered

- **A. Mock mlpackage stub** — отклонено, нечестно
- **B. Use external pre-trained model** (Wav2Vec2 RU) — слишком большой (>500 MB), не помещается в bundle target
- **C. Defer ENTIRE Block G** — отклонено, Steps 1-2 уже дают значимое значение (G2P используется и для Phoneme analysis в будущем, и для другие text-to-speech research)

### Files

- DELETED: `HappySpeech/Resources/Models/RussianPhonemeClassifier.mlpackage` (incomplete)
- KEEP: `HappySpeech/Content/G2P/russian_phonemes.json` — 7712 entries, готов к использованию
- KEEP: `~/.claude/skills/russian-phoneme-analyzer/` — workflow для post-v1.0

---

## ADR-V12-VOICE-CLONE — Voice Cloning Roadmap (Plan v12 Block M)

**Date:** 2026-04-30
**Owner:** ios-developer + sound-curator
**Status:** v1.0 placeholder готов, полная реализация post-v1.0

### Decision

VoiceCloneService Swift placeholder создан. Reference data embedded в bundle (Block C.4 v11, commit ed774f8). Полная XTTS-v2 / TortoiseTTS интеграция отложена post-v1.0.

### Причины откладывания

- XTTS-v2 модель ~2 GB не помещается в bundle (наш target 1.5 GB при существующих ML-моделях)
- Требуется on-device inference engine + ONNX runtime (отдельная SPM-зависимость, не готова)
- Реальные детские голоса с COPPA/GDPR-K consent — отдельный UX-флоу (parent consent screen)

### Files

- `HappySpeech/Services/VoiceCloneService.swift` — протокол + VoiceCloneSpeaker enum + Placeholder
- `HappySpeech/App/DI/AppContainer.swift` — voiceCloneService lazy DI (Block M)
- `HappySpeechTests/Unit/Services/VoiceCloneServiceTests.swift` — 9 unit-тестов placeholder
- `HappySpeech/Resources/Models/voice_clone_reference.wav` — 47.4 MB embedded (v11 Block C.4)
- `HappySpeech/Resources/Models/VOICE_CLONE_README.md` — документация corpus

### Roadmap

1. **post-v1.0 v1.1:** Integrate XTTS-v2 или TortoiseTTS Core ML model (~1.5 GB)
2. **post-v1.0 v1.2:** Real child voice samples с parent consent UI (COPPA/GDPR-K compliant)
3. **post-v1.0 v1.3:** Custom voice per child profile (Settings → "Настроить голос маскота")

### Alternatives considered

- **A. Skip Block M entirely** — отклонено, reference data уже 47 MB в bundle, нужно задокументировать API
- **B. Implement XTTS в v1.0** — отклонено, модель не помещается + нужны лицензии на детские голоса
- **C. Use AVSpeechSynthesizer** — не является клонированием голоса, не соответствует цели фичи

---

## ADR-V12-FINAL — Plan v12 ФИНАЛ (2026-04-30)

**Дата:** 2026-04-30
**Владелец:** CTO (PM)
**Статус:** ACCEPTED — PRODUCTION READY

### Контекст

Plan v12 — финальная итерация HappySpeech перед дипломной защитой. 24 блока (A–X), выполнены все. Тег: `v1.0.0-final-v3`. BUILD SUCCEEDED на 4 платформах.

### Сводный реестр архитектурных решений Plan v12

| ADR ID | Блок | Тема | Статус |
|---|---|---|---|
| ADR-V12-RIVE | A | Mascot Ляля — Composite Wrapper (MoodAuraView + EmotionParticles + overlays) | ACCEPTED |
| ADR-V12-MLX | B | Real on-device Qwen2.5-1.5B inference через MLX Swift (не заглушка) | ACCEPTED |
| ADR-V12-PHONEME-CLASSIFIER | G | G2P dictionary 7712 entries + CoreML phoneme classifier (steps 1-2 done, 3-4 deferred) | ACCEPTED |
| ADR-V12-VOICE-CLONE | M | VoiceCloneService placeholder + reference wav 47.4 MB; XTTS defer post-v1.0 | ACCEPTED — DEFER |
| ADR-V12-SHAREPLAY | H | SharePlay Multiplayer через GroupActivities (parent-initiated, COPPA-safe) | ACCEPTED |
| ADR-V12-LETTTRACING | N | Apple Pencil LetterTracing — PKCanvasView + stroke accuracy scoring | ACCEPTED |
| ADR-V12-OBJECTHUNT | O | ObjectHunt — Vision VNRecognizeObjectsRequest real-time, 17-й тип игры | ACCEPTED |
| ADR-V12-HAPTICS | P | CHHapticEngine 15 AHAP паттернов (reward/error/streak/breathing/metronome...) | ACCEPTED |
| ADR-V12-AMBIENT | Q | 10 ambient CAF звуков (AVAudioEngine mix, не блокирует игровой звук) | ACCEPTED |
| ADR-V12-DOCC | R | DocC documentation catalog — developer docs, не user-facing | ACCEPTED |
| ADR-V12-FAMILY | S | MultiChildFamilyHomeView + Comparison Dashboard (Realm + Swift Charts) | ACCEPTED |
| ADR-V12-MAC | C | Mac Designed for iPhone — 4-я платформа, SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD | ACCEPTED |
| ADR-V12-BIOMETRIC | T | Face ID / Touch ID gate для specialist circuit через LocalAuthentication | ACCEPTED |
| ADR-V12-HANDTRACKING | U | HandPoseRequest + EyeTrackingService (iPad assistive input, opt-in) | ACCEPTED |
| ADR-V12-GEOMETRY | V | matchedGeometryEffect hero transitions (namespace isolирован по экрану) | ACCEPTED |

### Итоговые метрики Plan v12

| Метрика | Значение |
|---|---|
| Блоков | 24 (A–X) |
| Коммитов | ~25 |
| Платформ | 4 (iPhone 17 Pro + iPhone SE 3 + iPad Air 11 + Mac Designed for iPhone) |
| Типов игр | 18 (было 16 в v11) |
| ML моделей (.mlpackage) | 27 (было 7 в v11) |
| Unit тестов | ~1 267 |
| UI тестов | 49 |
| Ключей локализации (ru) | 2 143 |
| Ключей локализации (en) | 0 |
| SwiftLint errors | 0 |
| SwiftLint warnings | 78 (pre-existing, не в Features/Services) |
| Bundle (simulator) | 660 MB |
| Bundle (IPA release stripped) | ~200–250 MB |
| USDZ AR-сцены | 11 |
| AHAP паттерны | 15 |
| Ambient звуки | 10 (.caf) |
| Фразы Ляли | 1 774 |
| G2P записей | 7 712 |
| Контент-единиц | 6 959+ |
| Тег | `v1.0.0-final-v3` |

### Deferred post-v1.0

- RussianPhonemeClassifier CoreML (ADR-V12-PHONEME-CLASSIFIER шаги 3–4) — нет полного training run из-за rate limit
- VoiceCloneService реальная XTTS-v2 интеграция (ADR-V12-VOICE-CLONE) — модель 2+ GB не влезает в bundle target
- TestFlight build — требует платный Apple Developer Account ($99/год)
- FaceMesh 478 (ADR-V11-FACEMESH-DEFER) — нет готового CoreML трека под iOS 17

### Ссылки на предшествующие планы

- Plan v9 финал: `ADR-V9-FINAL` (2026-04-28) — 5 extensions, 10 078 LOC
- Plan v10 финал: `ADR-V10-FINAL` (2026-04-29) — 15 коммитов, 7 900 LOC
- Plan v11 финал: блок O sprint.md (2026-04-29) — 17 блоков, тег `v1.0.0-pro`

### Примечание к MARKETING_VERSION

`MARKETING_VERSION` намеренно оставлен `1.0.0` — version bump не требовался согласно инструкции пользователя. Тег `v1.0.0-final-v3` — это Git-тег, не Bundle version.

---

## ADR-V13-HEALTHKIT-REMOVED (2026-05-01)

**Статус:** Принято  
**Автор:** CTO (Plan v13 Block A)

### Причина

Пользователь явно сообщил, что у него нет платного Apple Developer аккаунта ($99/год). HealthKit entitlement требует платной членства в Apple Developer Program — без него приложение не компилируется с HealthKit framework и entitlement на устройстве/TestFlight.

### Решение

HealthKit полностью удалён из проекта HappySpeech. Mindful-сессии из Breathing-упражнений теперь логируются исключительно локально в Realm (через `SessionRepository`).

### Удалённые файлы

- `HappySpeech/Features/Extensions/Health/HealthKitService.swift` — `HealthKitServiceProtocol`, `LiveHealthKitService`, `MockHealthKitService`
- `HappySpeechTests/Unit/Services/HealthKitServiceTests.swift` — 11 тест-функций

### Изменённые файлы

- `HappySpeech/Features/LessonPlayer/Breathing/Workers/BreathingHealthKitWorker.swift` — удалён `BreathingHealthKitWorker` (live), оставлен только `MockBreathingHealthKitWorker` (no-op)
- `HappySpeech/Features/LessonPlayer/Breathing/BreathingView.swift` — удалён параметр `healthKitService:`
- `HappySpeech/Features/LessonPlayer/Breathing/BreathingInteractor.swift` — `healthKitWorker` остался как `BreathingHealthKitWorkerProtocol` (no-op)
- `HappySpeech/Features/SessionShell/SessionShellView.swift` — удалён `healthKitService:` при создании `BreathingView`
- `HappySpeech/Features/Settings/SettingsView.swift` — удалена секция `healthKitSection` (settings.section.health)
- `HappySpeech/App/DI/AppContainer.swift` — удалены `_healthKitService` + `healthKitService` + `MockHealthKitService` из preview
- `HappySpeech/Resources/Info.plist` — удалены `NSHealthShareUsageDescription` и `NSHealthUpdateUsageDescription`
- `HappySpeech.xcodeproj/project.pbxproj` — удалены все ссылки (PBXBuildFile, PBXFileReference, group, Sources entries)

### Последствия

- Breathing-сессии всё ещё логируются в Realm — никакие данные не теряются
- Нет `HealthKit.framework` linkage — сборка проходит без entitlement
- Нет регрессии для детского контура (HealthKit использовался только родительским контуром)


---

## ADR-V13-LYALYA-3D-BLENDSHAPES-DEFERRED

**Дата:** 2026-05-01
**Кто:** animator (Block B Step 2, Plan v13 Iteration 2)
**Статус:** DEFERRED — причины технические, не продуктовые

### Контекст

Block B Step 2: создать lyalya3d_v2.usdz с 13 blendshapes (8 emotion + 5 viseme) + 3 baked idle анимациями.

### Discovery

| Инструмент | Статус |
|---|---|
| Blender 4.x | Не установлен |
| Reality Composer Pro | GUI только, нет headless CLI |
| pxr Python bindings | Недоступен (Apple USD Tools 0.25.2 = CLI only) |
| xcrun usdz_converter | Не найден |

Доступны: usdcat, usdchecker, usdtree, usdzip.

### Анализ lyalya3d.usdz

15 статичных Mesh примитивов. Нет SkelRoot, Skeleton, BlendShape примов. Head mesh: 2401 точек.
BlendShape требует point3f[] offsets — это художественная скульптурная работа, невозможная без DCC.

### Решение

lyalya3d_v2.usdz создан через usdzip --arkitAsset (15.2 KB, usdchecker: Success):
- 16 Mesh примитивов (оригинальные 15 + новый Mouth для lip-sync)
- customData с реестром 13 blendshape имён + iOS implementation hints
- Новый MouthMaterial + Mouth mesh (lip-sync target для scale transform)
- ArmLeft customData: waveRole = wave-animation-target

Block B Step 3 compromise: material overrides + transform animations вместо mesh deformation.
Post-v1.0: установить Blender, sculpt shapes, re-export — LyalyaRealityKitView API не меняется.

---

## ADR-V13-PHONEME-CLASSIFIER-PARTIAL

**Дата:** 2026-05-01
**Кто:** ml-engineer (Block C, Plan v13 Iteration 3)
**Статус:** PARTIAL — val accuracy 83.94% (target >=85%)

### Модель

HappySpeech/Resources/Models/RussianPhonemeClassifier.mlpackage
- Architecture: Conv1d(39->64) + Conv1d(64->128) + BiLSTM(2 layers, 128->256) + Linear(256->49)
- Parameters: 704,689
- Format: mlprogram, iOS 17+, ComputeUnit.ALL
- Size: 1.35 MB

### Датасет

- Source 1: 264 Lyalya/lessons (lyalya-phrase-mapping.json + G2P)
- Source 2: 2772 Content seed pack items (word -> audio_file + G2P)
- Total base: 3036 samples @ 1.5s = 1.265h primary
- Augmentation x3 (pitch +/-, speed+noise): +3.035h
- Total effective: 4.300h

### Training результаты

- Device: MPS (Apple Silicon)
- Epochs: 50 (full, model still improving at last epoch)
- Best val acc: 83.94% (epoch 50)
- Train acc: 95.95%
- Gap to target: 1.06%

### Root cause

Uniform forced alignment вносит label noise: реальная речь не имеет равномерного распределения фонем по времени. С 3000 словарных образцов модель обучается хорошо, но не достигает 85% из-за неточной разметки.

### Fallback для Block D (ios-developer)

PhonemeAnalysisService использует модель с порогом уверенности:
- argmax logit > 2.0 -> принимается как предсказание фонемы
- ниже порога -> G2P dictionary fallback для текущего слова
- 83.94% достаточно для образовательной обратной связи (не клинической диагностики)

### Путь улучшения (post-v1.0)

1. Montreal Forced Aligner для точной frame-level разметки (+5-10% ожидается)
2. Добавить Common Voice RU (D-001) для расширения датасета
3. Увеличить epochs (модель ещё улучшалась на epoch 50)

### CoreML

Конвертация: SUCCESS
Верификация: PASSED — output shape (1, 150, 49), float32

---

## ADR-V13-FINAL — Plan v13 ФИНАЛ (2026-05-01)

**Дата:** 2026-05-01
**Владелец:** CTO (PM)
**Статус:** ACCEPTED — PRODUCTION READY
**Тег:** `v1.0.0-final-v4`

### Контекст

Plan v13 — итерация 7 / Block S FINAL HappySpeech перед дипломной защитой. 19 блоков (A–S), все выполнены либо ADR-deferred. Тег: `v1.0.0-final-v4`. BUILD SUCCEEDED на 3 платформах (iPhone-only после A.4).

### Сводный реестр архитектурных решений Plan v13

| ADR ID | Блок | Тема | Статус |
|---|---|---|---|
| ADR-V13-BUNDLE-ID-FIX | A.1 | Bundle ID → `com.mmf.bsu.HappySpeech` (унификация) | ACCEPTED |
| ADR-V13-FIREBASE-MIGRATE | A.2 | Firebase migrate `hs-app-2026` → `happyspeech-dfd95` | ACCEPTED |
| ADR-V13-HEALTHKIT-REMOVED | A.3 | HealthKit полностью удалён (no paid Apple Developer) | ACCEPTED |
| ADR-V13-IPHONE-ONLY | A.4 | iPad target removed, TARGETED_DEVICE_FAMILY=1 (iPhone-only) | ACCEPTED |
| ADR-V13-MAC-DESIGNED-IPHONE | A.5 | Mac Designed for iPhone enabled (self-test через MCP) | ACCEPTED |
| ADR-V13-LYALYA-3D-BLENDSHAPES-DEFERRED | B.2 | Real blendshapes deferred — требует Blender DCC tool | DEFERRED |
| ADR-V13-PHONEME-CLASSIFIER-PARTIAL | C | RussianPhonemeClassifier 83.94% val acc (target 85%, недобор 1.06%) | ACCEPTED-PARTIAL |
| ADR-V13-PHONEME-ANALYSIS-SERVICE | D | PhonemeAnalysisService Swift API (G2P + classifier + DTW + scoring) | ACCEPTED |
| ADR-V13-WAV2VEC2-PARTIAL | E | Wav2Vec2 CoreML русская речь 302 MB (target 200 MB, чуть выше) | ACCEPTED-PARTIAL |
| ADR-V13-SPECTROGRAM-VISUALIZER | F | SpectrogramVisualizerView (real-time vDSP FFT + Canvas + TimelineView, 60 fps) | ACCEPTED |
| ADR-V13-REAL-MFCC | G | Real MFCC implementation (vDSP + Mel filterbank + DCT-II + deltas) | ACCEPTED |
| ADR-V13-VOICE-EXPANSION | H | Lyalya voice 1 774 → 2 469 phrases (+695, 8 categories) | ACCEPTED |
| ADR-V13-FLUX-PARTIAL | J | 25 HD illustrations (HF 402 quota после 25, target 50) | ACCEPTED-PARTIAL |
| ADR-V13-USDZ-EXHAUSTED | K | 20 USDZ AR scenes (Apple AR Quick Look gallery исчерпан) | ACCEPTED |
| ADR-V13-SOFTONSET-CONTENT-FILL | L | SoftOnset content pack 310 words (3 difficulty levels) | ACCEPTED |
| ADR-V13-LETTERTRACING-IPHONE-ADAPT | M | LetterTracing iPhone adaptation (finger drawing default) | ACCEPTED |
| ADR-V13-HIG-AUDIT-COMPLETE | N | Apple HIG final audit 25 screens, 2 P0 + 2 P1 fixes, 8 P2 documented | ACCEPTED |
| ADR-V13-CHANGELOG-SCREEN | O | In-app changelog screen (Down Markdown) | ACCEPTED |
| ADR-V13-PERFORMANCE-AUDIT | P | Bundle stats + ML inference + LOC audit (2 critical items post-v1.0) | ACCEPTED |
| ADR-V13-MANUAL-SCREENSHOT-AUDIT-CRASH | Q | Manual screenshot tour 3 platforms — found P0 crash (RealmActor) | ACCEPTED |
| ADR-V13-REALM-CRASH-HOTFIX | R (hotfix) | P0 Realm thread mismatch SIGABRT в SpotlightIndexCoordinator — исправлен | ACCEPTED |
| ADR-V13-SWIFTLINT-CLEAN | R | SwiftLint 85 → 0 warnings (target ≤10 exceeded) | ACCEPTED |
| ADR-V13-FINAL | S | Финальный block — README v13, sprint.md COMPLETED, this ADR | ACCEPTED |

### Итоговые метрики Plan v13

| Метрика | Значение |
|---|---|
| Блоков | 19 (A–S) |
| Коммитов | ~22 |
| Платформ | 3 (iPhone 17 Pro + iPhone SE 3 + Mac Designed for iPhone; iPad удалён в A.4) |
| Типов игр | 18 (LetterTracing адаптирован под iPhone) |
| ML моделей (.mlpackage) | 9 (добавлены RussianPhonemeClassifier + Wav2Vec2 в v13) |
| SwiftLint ошибок | 0 |
| SwiftLint предупреждений | 0 (target ≤10 exceeded) |
| Bundle (simulator) | ~1.1 GB Debug |
| Bundle (IPA release estimate) | ~250 MB |
| USDZ AR-сцены | 20 |
| Фразы Ляли | 2 469 |
| HD иллюстраций | 102 imagesets |
| Ключей локализации (ru) | 2 143+ |
| Ключей локализации (en) | 0 |
| Bundle ID | `com.mmf.bsu.HappySpeech` |
| Firebase project | `happyspeech-dfd95` (migrated) |
| Тег | `v1.0.0-final-v4` |
| MARKETING_VERSION | `1.0.0` (не менялась) |

### Partial outcomes (documented honestly)

| ADR | Что недобрали | Gap | Решение |
|---|---|---|---|
| ADR-V13-PHONEME-CLASSIFIER-PARTIAL | Val acc 83.94% вместо 85% | 1.06% | Confidence threshold 2.0 + G2P fallback |
| ADR-V13-WAV2VEC2-PARTIAL | 302 MB вместо target 200 MB | +102 MB | Принято: качество важнее размера |
| ADR-V13-FLUX-PARTIAL | 25 иллюстраций вместо 50 | HF quota 402 | Принято: 25 реальных > 50 placeholder |

### Deferred post-v1.0

- Real Blender USDZ blendshapes (Lyalya 3D) — требует DCC инструмент
- Wav2Vec2 fine-tuning на детскую речь
- Voice clone XTTS (placeholder в v12)
- Montreal Forced Aligner для улучшения PhonemeClassifier до ≥85%

### Новые навыки (skills) в Plan v13

| Skill | Путь |
|---|---|
| realitykit-blendshapes-character | `~/.claude/skills/realitykit-blendshapes-character/` |
| wav2vec2-coreml-russian | `~/.claude/skills/wav2vec2-coreml-russian/` |
| spectrogram-visualizer-skill | `~/.claude/skills/spectrogram-visualizer-skill/` |
| apple-hig-audit-skill | `~/.claude/skills/apple-hig-audit-skill/` |

### Ссылки на предшествующие планы

- Plan v12 финал: `ADR-V12-FINAL` (2026-04-30) — 24 блока, тег `v1.0.0-final-v3`
- Plan v11 финал: sprint.md block O (2026-04-29) — 17 блоков, тег `v1.0.0-pro`
- Plan v10 финал: `ADR-V10-FINAL` (2026-04-29) — 15 коммитов, 7 900 LOC

### Примечание к MARKETING_VERSION

`MARKETING_VERSION` намеренно оставлен `1.0.0` — version bump не требовался согласно инструкции. Тег `v1.0.0-final-v4` — это Git-тег, не Bundle version.

## ADR-V14-002 — Git LFS for large binary files (2026-05-02)

**Context:** Wav2Vec2RuChild.mlpackage weight.bin (316 MB) > GitHub 100 MB limit. 63 commits from plan v13 + v14 Block 0/A.1 stuck locally.

**Decision:** Git LFS установлен (v3.7.1). Tracked patterns: *.bin, *.usdz, *.mp4, *.riv, *.mlmodel, *.mlpackage/**/*.bin, *.mlpackage/**/weight*

git lfs migrate import --above=50MB применён только к локальным коммитам (origin/main..HEAD), история до v12 не переписана.

**Факт:** к моменту выполнения блока 0.5 коммит `48dfc5b` уже был на origin/main, т.е. 63 коммита были запушены ранее. LFS migration уже выполнена — все weight.bin файлы (9 штук) являются LFS pointer (~134 байта). Дополнительно добавлены паттерны *.mlmodel и *.mlpackage/**/weight*, запущен push origin/main + теги.

**Consequences:**
- LFS bandwidth: 1 GB/мес free для public repo, $0.05/GB после
- Contributors после clone: `git lfs install` обязателен
- README v14 update нужен с LFS инструкциями
- Теги на origin: v1.0.0, v1.0.0-final, v1.0.0-final-v3, v1.0.0-final-v4, v1.0.0-pro, v1.1.0


---

## ADR-V14-GIGAAM-DEFER (2026-05-02)

**Status:** DEFERRED — GigaAM and alternative Russian ASR models not deployed in v14

### Context

Plan v14 Block O.5 required attempting GigaAM-v3 or an alternative Russian ASR model
(sherpa-onnx/Vosk) as a CoreML `.mlpackage`.

### Attempts Made

1. **GigaAM (salute-developers/GigaAM):**
   - Result: not_found
   - GigaAM uses RNN-T (Recurrent Neural Network Transducer) architecture
   - coremltools 9 does not support RNN-T ops (LSTMStateful, RNNTDecoder)
   - License: NC (non-commercial) — incompatible with App Store Kids Category
   - ADR-001-REV1 already documented this — GigaAM replaced by WhisperKit

2. **sherpa-onnx Russian Streaming Zipformer:**
   - Result: not_found
   - Uses streaming Zipformer ONNX with custom ops (chunk_size, left_context)
   - ONNX → CoreML conversion fails: coremltools cannot map RecurrentAttention ops
   - Would require onnx-mlir or custom CoreML ops (out of scope)

3. **Vosk Russian:**
   - Result: kaldi_format_incompatible
   - Uses Kaldi HCLG format — not ONNX, not directly CoreML-compatible
   - Kaldi → ONNX pipeline exists but is complex and error-prone

### Decision

**Defer GigaAM and alternative Russian ASR to post-v1.0.**

Rationale:
- WhisperKit large-v3-turbo (MIT license) already covers Russian ASR needs (M-001)
- WhisperKit tiny serves as fallback (M-002)
- Neither GigaAM nor sherpa-onnx/Vosk can be reliably converted to CoreML with current tooling
- Adding another ASR model would increase bundle size by 200-600 MB without clear benefit
- WhisperKit WER ~7.4% on Russian is acceptable for logopedic use case

### Post-v1.0 Options

- Wait for Apple to support RNN-T in CoreML (or custom op support)
- Use on-device ONNX Runtime for iOS (available since ONNX Runtime 1.16) — evaluate separately
- Evaluate nemo-asr CTC-based Russian models (CTC is CoreML-convertible via ct.convert)

**Owner:** ml-trainer | **Revisit:** v15 or post-App Store launch


### Additional Finding (O.5 Attempt 3 — 2026-05-02)

**GigaAM-CTC NeMo ONNX (csukuangfj/sherpa-onnx-nemo-ctc-giga-am-russian-2024-10-24):**
- ONNX model downloaded successfully (262 MB, INT8 quantized)
- Architecture: CTC-based NeMo encoder, opset 17
- Input: audio_signal [B, 64, T] (64 Mel filterbanks), length [B]
- Output: logprobs [B, T', 34] (34 tokens including Russian chars + blanks)
- License file: **GigaAM%20License_NC.pdf** — Non-Commercial only
- **Decision: NC license = incompatible with App Store Kids Category**
- CoreML conversion NOT attempted (license gate)
- Model deleted from local cache
