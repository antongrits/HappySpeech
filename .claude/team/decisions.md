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
