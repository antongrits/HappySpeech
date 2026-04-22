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
