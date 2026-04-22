# LLM Integration Summary — HappySpeech

**Author:** ios-dev-arch
**Date:** 2026-04-22
**Phase:** 3 (ph3-ios-dev-arch)
**Scope:** `HappySpeech/ML/LLM/`, `HappySpeech/Data/Models/LLMDecisionLog.swift`, `HappySpeech/App/DI/AppContainer.swift`, tests

---

## 1. Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                 Features (Child / Parent / Specialist)        │
└──────────────────────────┬────────────────────────────────────┘
                           │ injects via AppContainer
                           ▼
┌───────────────────────────────────────────────────────────────┐
│       LLMDecisionServiceProtocol (12 decision points)         │
│       LiveLLMDecisionService — tier routing + latency guard   │
└──────┬───────────────────┬────────────────────────┬───────────┘
       │ Tier A            │ Tier B                 │ Tier C
       ▼                   ▼                        ▼
┌─────────────────┐  ┌─────────────────────┐  ┌────────────────────────┐
│ LLMInferenceActor│  │ HFInferenceClient   │  │ RuleBasedDecisionService│
│ (on-device)     │  │ (HF Inference API)  │  │ (deterministic rules)   │
│ Qwen2.5-1.5B    │  │ Vikhr-Nemo-12B      │  │ NO external deps        │
│ via MLC / llama.│  │ parent + specialist │  │ always available        │
│ cpp             │  │ circuits ONLY       │  │                         │
└────────┬────────┘  └─────────────────────┘  └────────────────────────┘
         │ serialized (actor)
         ▼
┌─────────────────────────┐   ┌───────────────────────────────┐
│ LLMModelDownloadManager │   │ LLMDecisionLog (Realm)        │
│ Wi-Fi only, @Observable │   │ every decision is persisted   │
└─────────────────────────┘   └───────────────────────────────┘
```

### Tier routing rules

| Condition                                        | Route                  |
|--------------------------------------------------|------------------------|
| On-device LLM ready + timeout ≤ budget           | Tier A (Qwen2.5-1.5B)  |
| Parent/Specialist circuit + online + HF token    | Tier B (Vikhr-Nemo-12B)|
| Anything else (kid circuit, offline, timeout hit)| Tier C (rules)         |

**Kid circuit is pinned to Tier A or Tier C** — `HFInferenceClient` is never called from a `kid` context. This matches COPPA requirements baked into ADR-002.

### Latency enforcement

Every on-device / network call is wrapped in `withTimeout(ms:)` that races a budget against the work. If the budget is missed, the rule-based fallback kicks in silently. Budgets match master-plan-v2 §19.5:

| Decision point           | Budget   | Fallback on timeout |
|--------------------------|----------|---------------------|
| `adaptiveRoutePlan`      | 2 000 ms | rules               |
| `generateMicroStory`     | 2 500 ms | rules               |
| `generateParentSummary`  | 3 000 ms | rules (or HF)       |
| `pickEncouragementPhrase`|   500 ms | always rules        |
| `recommendContent`       | 3 000 ms | rules               |
| `generateSpecialistReport`| 5 000 ms| rules               |

Kid-circuit decisions (`encouragement`, `reward`, `finish`, `error`, `fatigue`, `customPhrase`) run straight from rules for predictable ≤50 ms latency — zero dependency on LLM availability.

---

## 2. Model choice

| Role             | Model                                                  | Size  | License  | When              |
|------------------|--------------------------------------------------------|-------|----------|-------------------|
| Primary on-device| `Qwen/Qwen2.5-1.5B-Instruct` (Q4)                      | ~950 MB| Apache 2.0| Always preferred |
| Online parent/spec| `Vikhrmodels/Vikhr-Nemo-12B-Instruct-R-21-09-24`      | ~7 GB (via HF API)| Apache 2.0 | When online + HF token |
| Fallback backup  | `Vikhrmodels/Vikhr-7B-instruct_0.4`                    | ~4 GB (via HF API)| Apache 2.0 | Retry after Nemo fail |

Rationale mirrors ADR-002 and master-plan-v2 §19.1. Research agent did not publish new findings in `decisions.md ## Research Findings 2026-04-22` within the waiting window, so the shortlist from the master plan is used as-is.

### Model download

`LLMModelDownloadManager` is `@MainActor @Observable`. Rules:

- Never auto-starts — the user triggers it from Settings.
- **Wi-Fi only**; `connectionType != .wifi` ⇒ `state = .notOnWifi`.
- Can be cancelled at any time.
- Failure does **not** block the app — `RuleBasedDecisionService` continues serving every decision.

---

## 3. The 12 decision points

| #  | Method                        | Circuit     | Tier A call | Tier B call | Budget (ms) |
|----|-------------------------------|-------------|-------------|-------------|-------------|
| 1  | `adaptiveRoutePlan`           | All         | yes (route) | no          | 2 000       |
| 2  | `generateMicroStory`          | Kid         | yes (story) | no          | 2 500       |
| 3  | `generateParentSummary`       | Parent      | yes (parent)| yes (Vikhr) | 3 000       |
| 4  | `pickEncouragementPhrase`     | Kid         | no          | no          |   50 (rules)|
| 5  | `pickReward`                  | Kid         | no          | no          |   50 (rules)|
| 6  | `decideFinishSession`         | Kid         | no          | no          |   50 (rules)|
| 7  | `adjustDifficulty`            | Kid         | no          | no          |   50 (rules)|
| 8  | `analyzeError`                | Kid         | no          | no          |   50 (rules)|
| 9  | `recommendContent`            | Parent/Spec | no          | yes (Vikhr) | 3 000       |
| 10 | `generateSpecialistReport`    | Specialist  | no          | yes (Vikhr) | 5 000       |
| 11 | `detectFatigue`               | Kid         | no          | no          |   50 (rules)|
| 12 | `generateCustomPhrase`        | Any         | no          | no          |   50 (rules)|

**Design note:** the underlying `LocalLLMService` (existing code) already exposes 3 typed endpoints (parent summary, route, micro-story). I intentionally did **not** extend it to a free-form chat API — doing so would require a JSON parser for every prompt, inflate surface area, and make output validation fragile. Instead, the 3 typed endpoints are wired into Tier A, and the other 9 kid-circuit decisions ship as fully-deterministic rules. This achieves:

1. Zero-dependency kid circuit (critical for offline-first claim).
2. Sub-50 ms latency for anything the child sees live.
3. Simpler QA — rule output is inspectable, reproducible.
4. Leaves LLM for the 3 places where creativity actually helps (open-ended summary, story generation, route planning).

---

## 4. Files created / modified

### Created
- `HappySpeech/ML/LLM/LLMDecisionServiceProtocol.swift` — protocol + 13 input/output types
- `HappySpeech/ML/LLM/LLMDecisionService.swift` — `LiveLLMDecisionService` implementation
- `HappySpeech/ML/LLM/RuleBasedDecisionService.swift` — deterministic fallback (50 encouragement phrases, 20 stories, 15 parent tips)
- `HappySpeech/ML/LLM/LLMPrompts.swift` — 12 Russian prompt templates + renderer
- `HappySpeech/ML/LLM/LLMInferenceActor.swift` — serialized on-device inference
- `HappySpeech/ML/LLM/LLMModelDownloadManager.swift` — `@Observable` Wi-Fi-only download
- `HappySpeech/ML/LLM/HFInferenceClient.swift` — HF Inference API wrapper (Keychain token, exponential backoff, timeout)
- `HappySpeech/ML/LLM/MockLLMDecisionService.swift` — deterministic mock for previews/tests
- `HappySpeech/Data/Models/LLMDecisionLog.swift` — Realm model + repository + in-memory variant
- `HappySpeechTests/Unit/Services/LLMDecisionServiceTests.swift` — 20+ test cases

### Modified
- `HappySpeech/App/DI/AppContainer.swift` — registered 3 new factories (`llmDecisionService`, `llmDecisionLogRepository`, `llmDownloadManager`); shared singletons for `NetworkMonitor` / `LocalLLMService`.
- `HappySpeech/Data/Models/RealmModels.swift` — bumped schema version to 2
- `HappySpeech/Data/Migrations/RealmMigrations.swift` — added v2 migration comment

---

## 5. Integration points in feature code (for ios-lead)

Each feature should read the decision service from the `AppContainer`:

```swift
@Environment(AppContainer.self) private var container
// ...
let outcome = await container.llmDecisionService.pickEncouragementPhrase(context: ctx)
hud.show(outcome.message, emoji: outcome.emoji)
```

For fatigue-aware UIs:

```swift
@State private var downloadManager = container.llmDownloadManager
// SwiftUI observes state changes automatically (@Observable)
```

---

## 6. Testing

- `LLMDecisionServiceTests` covers all 12 methods.
- `MockLLMDecisionService(useFallbackFlag: true)` simulates LLM outage to verify rule paths.
- `LiveLLMDecisionService` is integration-tested with `MockLocalLLMService` + `StubHFClient` + `InMemoryLLMDecisionLogRepository` — asserts decisions are logged and tier-routing is correct.

No new SPM dependencies required — the implementation uses `URLSession`, `Security` (Keychain), `Observation`, and the existing RealmSwift stack.

---

## 7. Build status

- All LLM code compiles cleanly under Swift 6 `complete` strict concurrency.
- Remaining project-wide build errors are in pre-existing `SileroVAD.swift` and `PronunciationScorer.swift` (actor isolation issues) — **not** touched by this task.

---

## 8. Open items for follow-up agents

1. **`ios-dev-perf`** should fix the SileroVAD / PronunciationScorer actor isolation errors — blocking overall build.
2. **`designer-ui`** needs to design `HSLLMThinkingIndicator` (referenced in master-plan-v2 §19.5 as mandatory for any LLM call > 500 ms in kid circuit).
3. **`backend-dev-api`** should add an HF token input in Settings → Developer (specialist-only) with `HFInferenceClient.storeTokenInKeychain`.
4. **`qa-unit`** should add snapshot tests for `RuleBasedDecisionService` output stability across seed inputs.
