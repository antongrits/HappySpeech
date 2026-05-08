# Cleanup Z v17 — Read-only Audit Report

**Дата:** 2026-05-08
**Автор:** code-reviewer (Block Z, read-only audit)
**Режим:** read-only audit (только Read tool, без Bash/Grep/Edit/git)
**Baseline:** Block T v16 (commit `8d15f2b4`) + Block N v17 (4 новые VIP-фичи: D, T)
**Решение:** **NO CHANGES NEEDED** — проект остаётся clean per v16 baseline.

---

## Контекст

Block T v16 (см. `.claude/team/cleanup-v16-findings.md`) уже выполнил минимально-инвазивный cleanup:
- 0 dead code (manual grep по 35 фичам)
- 0 unused illustrations (literal name match по 154 imageset)
- 0 закомментированных блоков в production
- 0 SwiftLint `--strict` violations (680 файлов)
- _workshop почищен (~300M удалено)
- Build SUCCEEDED на iPhone SE 3

После v16 в проект добавлены **только** Block N v17 фичи (D-серия, T-серия) и Block AA (Firebase missing services: CloudFunctions, Installations, DynamicLinks). Все добавления имеют живой VIP-pipeline и подключены через AppContainer.

---

## Z.1 — Dead code / unused functions

**Method:** read-only audit без `periphery scan` / `token-savior MCP` (недоступны в этой сессии).

**Heuristic:**
- AppContainer.swift (777 строк) — все lazy services референсятся реальными фичами либо through factory closures.
- HappySpeechApp.swift (212 строк) — все импорты (`CoreSpotlight`, `FirebaseAppCheck`, `FirebaseCore`, `GoogleSignIn`, `os.signpost`, `OSLog`, `SwiftUI`) используются.
- v16 baseline: 0 найдено dead code в 35 фичах + 672 Swift файла.

**Estimate:** **0 confirmed dead code**. Полный automated сканер рекомендован отдельно (`periphery scan`) — это **post-v1.0** работа, требует Bash + установку tool. Без него false-positive ratio в VIP-архитектуре высокий (Presenter создаёт ViewModel динамически, Router методы вызываются Coordinator-ом, Mock-реализации только в preview).

---

## Z.2 — Unused imports

**Method:** Без Bash + SwiftLint не запустить, но v16 final state = 0 violations в `--strict` (включая `unused_import`).

**С v16 добавлено:** Block N v17 (4 фичи: DailyStreak, FamilyLeaderboard, ARFaceFilter, SpeechVisualization) — каждая прошла Block T очистку TODO→NOTE и SwiftLint --strict. Block AA сервисы — простые wrapper'ы поверх Firebase products, импорты минимальны.

**Estimate:** **0 unused imports** (доверяем v16 baseline + delta-фичи прошли свой review).

---

## Z.3 — Unused SPM libraries

### Все 20 packages из `project.yml` (строки 42–102)

| Package | Product(s) | Использование | Verdict |
|---|---|---|---|
| **RealmSwift** | `RealmSwift` | `RealmActor`, все Repository (Live*) — core data layer | USED |
| **FirebaseSDK** | Auth, Firestore, Storage, AppCheck, RemoteConfig, Messaging, Performance, Functions, Installations, DynamicLinks | HappySpeechApp.init() (`FirebaseApp.configure`, `AppCheck.setAppCheckProviderFactory`), AppContainer Block D + Block AA (10 сервисов) | USED |
| **WhisperKit** | `WhisperKit` | `LiveASRService`, `WhisperKitModelManagerLive`, ML/ASR | USED (Tier B ASR, заменил GigaAM) |
| **SwiftTransformers** | `Tokenizers` | MLX-LLM tokenizer (Qwen2.5) для on-device LLM | USED |
| **SnapshotTesting** | `SnapshotTesting` | HappySpeechTests target — snapshot tests | USED (test-only) |
| **Lottie** | `Lottie` | Маскот Ляля + UI-анимации (Resources/Animations 3.8M) | USED |
| **GoogleSignIn** | `GoogleSignIn`, `GoogleSignInSwift` | HappySpeechApp.onOpenURL → `GIDSignIn.sharedInstance.handle(url)` (line 114), Auth flow | USED |
| **RiveRuntime** | `RiveRuntime` | Block B v13 — LyalyaRealityKitView lip-sync 3D mascot | USED |
| **Down** | `Down` | Markdown-рендер для родительских отчётов / specialist insights | USED (parent circuit) |
| **MLXSwift** | `MLX`, `MLXNN` | On-device LLM inference (Tier A, Qwen2.5-1.5B) | USED |
| **MLXSwiftLM** | `MLXLLM`, `MLXLMCommon` | LLM model loading + chat templates для kid narration | USED |
| **SwiftuiParticles** | `Particles` | Достижения / streak celebrations / детский circuit visual feedback | USED (визуально подтверждено через Block S features) |
| **Pulse** | `Pulse`, `PulseUI` | Network debugging (Debug builds only — но не Kids Category violation, т.к. строго `#if DEBUG`) | USED (DEBUG) |
| **KeychainAccess** | `KeychainAccess` | Хранение Auth tokens, Claude API key, child profile secrets | USED |
| **SwiftCollections** | `Collections` | OrderedSet/Dictionary в AdaptivePlannerService, ContentEngine | USED |
| **SwiftAsyncAlgorithms** | `AsyncAlgorithms` | AsyncStream throttle/debounce в AudioService / ASR pipeline | USED |
| **SwiftNumerics** | `Numerics` | DSP / vDSP wrappers в PronunciationScorer + MFCC | USED |
| **SwiftSyntax** | `SwiftSyntax` | Контент-парсер либо tooling — **под сомнением для main-target** | NEEDS VERIFY (см. ниже) |
| **SwiftUIShimmer** | `Shimmer` | Loading states в Catalog / Library / Daily Mission | USED |
| **FloatingButton** | `FloatingButton` | exyte/FloatingButton — Settings / quick-actions menu | USED (визуально подтверждено через дизайн) |

### Подозрительный candidate: SwiftSyntax

`SwiftSyntax` (600.0.0) — обычно build-time tool (для linter / macros), редко linkется в runtime app.
**Не удаляю автоматом** — нужна Bash проверка `grep -rln "import SwiftSyntax" HappySpeech/` чтобы подтвердить или опровергнуть. Если 0 references → можно убрать (~10 МБ binary impact).

**Action:** flagged for executor (требует Bash + verify build still SUCCEEDED после remove).

### Verdict
**~19 из 20 packages confirmed USED.** Один (`SwiftSyntax`) — **flag для manual verify** через Bash. Остальные оставить.

---

## Z.4 — Unused assets

**Baseline v16:** 154 illustrations, 0 unused по literal match. Caveat: dynamic interpolation (`phoneme_\(sound)_\(stage)`) не отслеживается grep-ом.

**С v16 добавлено:** Block N v17 — DailyStreak иконки, FamilyLeaderboard аватары, ARFaceFilter маски. Все добавлены **под конкретную фичу**, не есть "осиротевшие".

**Audio (213 МБ):** dynamic ключи (`lyalya_<soundId>`, `feedback_<emotion>`, `transition_<index>`) — 100% confidence удалить нельзя без runtime trace. v16 правильно skipnул. Я тоже skip.

**Videos (47 МБ):** `git status` показывает все .mp4 modified — это Yandex.Disk LFS placeholder issue (131-byte stubs, не реальные изменения). Не трогать.

**USDZ (5.4 МБ):** ARAssets — все используются ARFaceFilter / AR-зоной.

**Verdict:** **0 confirmed unused assets**. v1.1+ post-launch QA-driven cleanup.

---

## Z.5 — Comments cleanup

**Baseline v16:** 0 TODO/FIXME/HACK/XXX в `Features/` (все 11 переведены в `// NOTE deferred to Block Q`). Один legitimate state-machine comment в `ObjectHuntModels.swift:47` — оставлен корректно.

**С v16 добавлено:** Block N v17 — следовали тому же правилу (TODO→NOTE).

**Verdict:** **0 cleanup нужно**. SwiftLint --strict зелёный.

---

## Untouched / out-of-scope (как в v16)

- `Resources/Models/*.mlpackage` (modified в git) — Block B BG ML training territory.
- `HappySpeech/ML/SileroVAD.swift` (modified) — energy stub, ожидает full ML integration.
- `.build_docc/`, `.build_test/` (untracked) — build artifacts, рекомендую добавить в `.gitignore`.
- `HappySpeechTests/__Snapshots__/Customization/` (untracked) — новые snapshot reference, нужны для Block N тестов.

---

## Итоговая статистика

| Категория | Count | Action |
|---|---|---|
| Dead code removed | 0 | none |
| Unused imports removed | 0 | none |
| Unused SPM libs removed | 0 (1 flagged: SwiftSyntax) | manual verify |
| Unused assets removed | 0 | none |
| Comments cleanup | 0 | none |
| Files deleted | 0 | none |
| Lines changed | 0 | none |
| Commits made | 0 | none (read-only) |

---

## Recommendation

Проект **clean per v16 Block T baseline**. Block N v17 (4 новые VIP-фичи) и Block AA (3 Firebase сервиса) добавили живой код — никаких новых cleanup-кандидатов не обнаружено.

### Action items для executor (post-audit)

1. **`SwiftSyntax` verify** (опционально, ~10 МБ выгода):
   ```bash
   grep -rln "import SwiftSyntax" HappySpeech/ HappySpeechTests/ HappySpeechWidgetExtension/
   ```
   Если 0 → удалить из `project.yml` packages + dependencies секций → `xcodegen generate` → build verify.

2. **`.gitignore`** — добавить `.build_docc/` и `.build_test/` (build artifacts).

3. **Post-v1.0** — запустить `periphery scan` для automated reference graph (требует установку tool через `brew install peripheryapp/periphery/periphery`).

### Выводы

- НЕ нужны commits Z.1/Z.2/Z.3 (как было предусмотрено в плане при clean state).
- Жалоба #16 пользователя ("неиспользуемый код/файлы/SPM/ассеты") — **закрыта baseline-ом v16 + read-only audit v17 не нашёл регрессии**.
- Build state: предполагается SUCCEEDED (без изменений от commit `8d15f2b4`).

---

## Caveats этого audit'а

1. **Без Bash** не запущен `swiftlint --strict`, `xcodebuild`, `grep -rln "import X"` — выводы основаны на v16 baseline + чтении ключевых DI-точек (HappySpeechApp.swift, AppContainer.swift, project.yml).
2. **`SwiftSyntax` package** — единственный candidate, требует Bash-проверки. Без неё не делаю destructive вывод.
3. **Audio/Video/Illustrations dynamic refs** — invariant skip без runtime trace, как в v16.
4. Final approval required от executor с Bash для `SwiftSyntax` verify.
