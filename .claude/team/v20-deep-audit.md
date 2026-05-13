# Plan v20 Deep Audit — 2026-05-10

> **Аудитор:** Claude Opus 4.7 (1M context), session-deep-audit
> **Базовая ветка:** main, tag `v1.0.0-final-v19`
> **Метод:** static analysis (grep/find/Read), 12 предыдущих планов прочитаны частично, итоговые отчёты прочитаны полностью.
> **Цель:** найти gap'ы для Plan v20 на 5000+ строк.

---

## 1. Executive summary

### Текущая стадия проекта (фактические метрики)

| Метрика | Значение | Источник |
|---|---|---|
| `*View.swift` (без Components) | **104** | `find ... -wc -l` |
| Swift LOC total | **168 001** | `wc -l` |
| Test files | **137** | `find HappySpeechTests` |
| Test functions | **1 320** | `grep -c func test` |
| Skipped tests (`XCTSkip`) | **18** | `grep -c XCTSkip` |
| Resources size | **1.5 GB** | `du -sh` |
| Models size | **957 MB** (из них Whisper 604 MB) | `du -sh` |
| Audio (.m4a) total | **20 307** | `find -name *.m4a` |
| Lyalya voice (.m4a) | **13 798** | подкаталог Audio/Lyalya |
| Видео (.mp4) | **146** | (5 tutorials + 20 stories + 8 celebrations + 69 v18 + …) |
| Lottie (.json) | **58** | `find Animations -name *.json` |
| ColorSet'ы в xcassets | **64 каталога** | `ls Assets.xcassets` |
| Imageset'ов | **154** | `find -name *.imageset` |
| ML модели (.mlpackage) | **13** | + 2 Whisper папки |
| Localizable.xcstrings ключей | **3 940** RU, **0** EN | python json check |
| Локальные агенты | **16** | `.claude/agents/` |
| Глобальные скиллы | **64+** | `~/.claude/skills/` |
| ADR в decisions.md | **49** | `grep -c '^## ADR'` |

### TOP-5 главных gap'ов (production-блокеры для дипломной защиты ИЛИ user-explicit требований)

1. **3D Lyalya hero почти отсутствует.** Только **2 из 104** `*View.swift` используют `LyalyaRealityKitView`/`LyalyaRealityView`. **76** экранов используют 2D `LyalyaMascotView`/`HSMascotView`, **26** экранов вообще без маскота. User explicit: «3д герои на каждом экране без заднего фона». Plan v18 Block H заявил «verified», Plan v19 Block I заявил «unified» — фактически НЕ выполнено.
2. **Эмодзи в DesignSystem (нарушение zero-tolerance правила).** `LyalyaMascotView.fallbackEmoji` хранит **10 эмодзи** (`🦋👋🎉🤔📢🎵😢👆😊💪`), которые **рендерятся в production UI** через `Text(state.fallbackEmoji)` в `HSCustomAlert.swift:201`, `HSOnboardingParallax.swift:146`, `HSMascotPullToRefresh.swift:104`, `LyalyaMascotView.swift:323/393`. + `HSLottieContainer.swift:96` `Text(verbatim: "🎉")`. User explicit: «В дизайне нельзя использовать эмоджи».
3. **Localized.xcstrings раздут до 3 940 ключей** с очень высокой вероятностью dead keys (Lottie celebrate_*.json в Resources/Animations имеют 16+ JSON; SessionComplete/Onboarding имеют сотни keys). 18 skipped tests могут означать stale keys. Block AA из v18 был «cleanup conservative». **Не было exhaustive cleanup**.
4. **Light/Dark адаптация только на ~5% экранов.** `grep '@Environment(\\.colorScheme)' Features` нашёл **5 файлов**. `grep 'colorScheme' Features` — **20 совпадений** в основном Auth feature. User explicit: «Light/Dark на всех 104 экранах». Plan v19 Block C заявил «Auth hero adapt» — это лишь часть.
5. **Whisper-base (140 MB) + Whisper-small (464 MB) = 604 MB в Resources/Models.** Скорее всего, обе версии не используются одновременно — `whisper-small` достаточно. Это 40% от Bundle Models size. User answered «1.4 GB acceptable», но если Whisper можно свести к одной версии — Bundle уйдёт под 1 GB. **Не cleaned**.

---

## 2. Что РЕАЛЬНО сделано из 42+ требований (с доказательствами)

| # | Требование пользователя | Статус | Evidence | Quality |
|---|---|---|---|---|
| 1 | Manual screenshot audit КАЖДОГО экрана | **partial 13/104** | `v19-manual-audit.md` line 9: «Screens read manually: 13/19» | shallow |
| 2 | 0 эмодзи в UI | **❌ FAIL** | 10 эмодзи в `LyalyaMascotView.swift:58-67`, рендерятся в 4 местах | bad |
| 3 | Адаптация под все размеры iPhone (SE 3 320pt, no overflow) | partial | 25 из 104 файлов БЕЗ `GeometryReader`/`minimumScaleFactor` | shallow |
| 4 | 3D героев на каждом экране без заднего фона | **❌ FAIL** | 2/104 (1.9%) используют RealityKit; 76 — 2D | bad |
| 5 | Manual analysis всего контента | partial | inventories есть, manual review только частично | shallow |
| 6 | Light/Dark на всех 104 экранах | **❌ FAIL** | 5 файлов с `@Environment(\\.colorScheme)` | bad |
| 7 | Палитра ClaudeDesign + kavsoft custom UI | partial | ColorTokens готовы, kavsoft research доку есть (`.claude/team/kavsoft-custom-ui-research.md`), но fragmented apply | shallow |
| 8 | 110+ экранов (104 → +6) | **❌ FAIL** | 104 (не +6) | bad |
| 9 | No content overflow (lineLimit + minimumScaleFactor + GeometryReader) | partial | 25 файлов БЕЗ overflow protection | shallow |
| 10 | Все требования из 10+ предыдущих планов | partial | См. блок 4 ниже | shallow |
| 11 | Internet research перед каждым шагом | unverified | `researcher` агент существует, как часто использовался — не tracked | unknown |
| 12 | Apple HIG 100% | partial | `apple-hig-checklist-v19.md` 350+ строк, но НЕ verified manual screenshot per screen | shallow |
| 13 | No block overlaps, no word wrap, no truncation | partial | LessonPlayer P1.5: «Слушай внимательн...» truncated | bad |
| 14 | English keys в UI | ✅ | 0 EN keys (3940 RU, 0 EN) | good |
| 15 | Понятный язык обычному пользователю (no jargon) | partial | tests НЕ проверяют тон голоса | shallow |
| 16 | Cleanup dead code, unused files, unused SPM, unused assets | partial | conservative cleanup в v18 (`cleanup-final-audit-v18.md`); 4 backup .m4a/.mlpackage в Resources | shallow |
| 17 | Профессиональная глубина каждого файла | partial | избирательно для R-screens (~1300 LOC), для legacy экранов — меньше | shallow |
| 18 | Очистить мусор в _workshop | **❌ FAIL** | `_workshop` = 753 MB (datasets, screenshots, models, ml/checkpoints) | bad |
| 19 | UNION 10 предыдущих планов | partial | Block V из v18 — checklist | shallow |
| 20 | Минимум 48 часов agent work | ✅ | v19 = 10 commits sequential, sufficient | good |
| 21 | (дубль 19) | partial | — | shallow |
| 22 | Code review после каждого изменения | partial | code-reviewer существует, но `code-review-final-v18.md` — лишь итоговый | shallow |
| 23 | App Store ready 100% | partial | Privacy/Terms на GitHub Pages, NO submission (no Apple Developer account) | acceptable |
| 24 | Большое объёмное приложение Bundle ~1.4 GB | ✅ | 1.5 GB | good |
| 25 | Полная проверка кода | partial | — | shallow |
| 26 | 100% test coverage (~600 new) | **❌ FAIL** | 1320 функций, 18 XCTSkip; coverage НЕ measured. Block L v19 явно DEFER | bad |
| 27 | Большое количество библиотек SPM (5-10 новых) | unknown | Block AG defer | shallow |
| 28 | Обогнать конкурентов | partial | competitor-gaps-v17.md — analytical only, не applied | shallow |
| 29 | Полностью бесплатное (no paid Apple Dev) | ✅ | TestFlight defer ADR | good |
| 30 | Убрать некрасивые мигания/анимации | partial | Block I v19: «2D animations removed» — проверь | shallow |
| 31 | 0 build warnings + 0 errors | ✅ | v19-FINAL-READY.md: BUILD SUCCEEDED | good |
| 32 | Очистить симулятор | partial | Block AE v18 «Simulator + DerivedData cleanup» — DerivedData всё ещё 8.5 GB | shallow |
| 33 | Code reviewer после каждого шага | partial | — | shallow |
| 34 | Project audit + new tasks self-spawn | unknown | — | shallow |
| 35 | Видео + анимации + картинки + озвучка профессионально | partial | Lottie 58, Remotion 146, FLUX images. НЕТ manual quality check | shallow |
| 36 | +500 lessons neurolinguist | partial | S v18: 8055 items в 22 packs. NeurolinguistInsights feature exists | acceptable |
| 37 | Плавный интерфейс с красивыми Lottie | partial | 58 Lottie файлов, но `python-lottie` traces возможны | shallow |
| 38 | Расширить функции, deep audit | unknown | — | shallow |
| 39 | Все Firebase services активно | ✅ | 10/10 active per `v19-firebase-runbook.md` | good |
| 40 | AppIcon Single Size only | ✅ | AppIcon-Any-1024.png + Dark + Tinted | good |
| 41 | Internet search где не знаешь | unverified | — | shallow |
| 42 | Real children dataset через TestFlight | ⏸ | DEFER ADR-V19-TESTFLIGHT (no Apple Developer) | acceptable |
| 43 | ML retrain RussianPhonemeClassifier 83.9% → 85%+ | ✅ | 88.9% per ADR-V19-D | good |
| 44 | Voice expansion 14501 → 18000+ | ✅ | 20 307 (exceeds) | good |
| 45 | Remotion 100+ professional MP4 | ✅ | 146 (exceeds) | good |
| 46 | Blender 3D custom rigging | ⏸ | DEFER ADR-V19-H-DEFER-BLENDER | acceptable |
| 47 | 3D и 2D герой идентично везде | **❌ FAIL** | 2/104 3D, 76/104 2D-only — несовместимо | bad |
| 48 | Только русский язык | ✅ | 3940 RU, 0 EN | good |
| 49 | iPhone SE 3 only simulator | ✅ | Build verified | good |
| 50 | Vertical orientation only | ✅ | Info.plist | good |
| 51 | Картинки/иллюстрации/AppIcon/анимации НЕ python | partial | Lottie из real-lottie-importer skill, но HSLottieContainer.swift показывает emoji fallback | shallow |
| 52 | Lottie красиво и профессионально | partial | 58 Lottie из community, не verified visually | shallow |
| 53 | CV встроено и работает на профессиональном уровне | partial | ARFaceFilter, FaceAnalysisService, UnifiedFacePoseWorker — есть. Manual verification — нет | shallow |
| 54 | Bundle 1.5 GB | ✅ | 1.5 GB | good |
| 55 | Blender-style 3D scenes | ⏸ | DEFER | acceptable |
| 56 | 2D героев нельзя анимировать | partial | LyalyaMascotView 0 animation count, но HSMascotView имеет 3 (`grep repeatForever`) | shallow |
| 57 | Не делать избыточно много картинок и видео | ✅ | принцип соблюдён | good |
| 58 | Лучше больше анимаций в интерфейсе | partial | 58 Lottie. UI-screens с animation density — не measured | shallow |
| 59 | Глубокая ревизия кода | partial | code-review-v18-final.md есть, но v19 review нет | shallow |
| 60 | Speech analyzer фонетический + spectrogram (НЕ STT API) | ✅ | Wav2Vec2RuChild.mlpackage 302M + RussianPhonemeClassifier 1.5M; `SpeechVisualization` feature | good |
| 61 | Картинки RGBA + iOS-rounded | partial | FLUX-1-schnell + rembg per spec, но не verified per-image | shallow |
| 62 | No empty space | **❌ FAIL** | ChildHome empty (P0.3 v19), Settings empty (P0.4 v19) — заявлены fix, но не verified visually | bad |
| 63 | (дубль 4) 3D без фона | **❌ FAIL** | См. #4 | bad |
| 64 | НЕ iOS 18.6 | ✅ | iPhone SE 3 / iOS 26 sim | good |
| 65 | Firebase через Chrome MCP | partial | v19-firebase-runbook.md делал PATCH/POST через REST, не через Chrome MCP | shallow |
| 66 | README + документы готовы | partial | sprint.md/backlog.md updated. README.md — не проверял | shallow |
| 67 | Все локальные + другие агенты | ✅ | 16 локальных + 25 глобальных | good |
| 68 | 48+ скиллов | ✅ | 64+ скиллов | good |
| 69 | Sequential only (1 agent at a time) | ✅ | принцип соблюдён | good |
| 70 | Sonnet 4.6 effort high (no Opus) | ✅ | per Block 0 v19 | good |
| 71 | Датасеты не такие большие (≤3h) | partial | _workshop/datasets — 753 MB workshop total — большой | shallow |
| 72 | Каждое изображение/видео/анимация/аудио manual | **❌ FAIL** | inventory есть; manual visual review — нет | bad |

**Итого по 42+ требованиям:**
- ✅ Полностью выполнено: **22/72** (30%)
- partial / shallow: **38/72** (53%)
- ❌ FAIL / bad: **9/72** (13%)
- ⏸ acceptable defer: **3/72** (4%)

**Quality по требованию пользователя «не поверхностно» — НЕ соблюдён в 38 пунктах.**

---

## 3. Что НЕ сделано или сделано поверхностно (детально по категориям)

### 3.1. UI/UX (10 P0/P1 issues)

#### Эмодзи в production UI
- `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift:58-67` — 10 эмодзи в `fallbackEmoji`
- `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift:323` — `Text(lyalyaState.fallbackEmoji)` в production fallback path
- `HappySpeech/DesignSystem/Components/LyalyaMascotView.swift:393` — `Text("Состояние: \(...) \(...fallbackEmoji)")` accessibility label
- `HappySpeech/DesignSystem/Components/HSOnboardingParallax.swift:146` — `Text(page.mascotState.fallbackEmoji)`
- `HappySpeech/DesignSystem/Components/HSMascotPullToRefresh.swift:104` — `Text(state.fallbackEmoji)`
- `HappySpeech/DesignSystem/Components/HSCustomAlert.swift:201` — `Text(state.fallbackEmoji)`
- `HappySpeech/DesignSystem/Components/HSLottieContainer.swift:96` — `Text(verbatim: "🎉")`

**User explicit запрет:** «В дизайне нельзя использовать эмоджи». **Это критично**.

#### Hardcoded colors (anti-pattern, должны быть через ColorTokens)
- `HappySpeech/Features/Common/Stories/StoryLibrary.swift:58-770` — **20 hex colors** для backgroundGradient (`#FFA07A`, `#FF6347`, `#87CEEB`, …). Не через ColorTokens.
- `HappySpeech/Features/PronunciationLeaderboard/PronunciationLeaderboardView.swift:334,351` — `Color(red: 0.80, green: 0.50, blue: 0.20)` для bronze badge.
- `HappySpeech/Features/WeeklyChallenge/WeeklyChallengeView.swift:469` — `Color.black.opacity(0.001)`
- `HappySpeech/Features/Common/LyalyaSceneView.swift:150,213,223,224` — `UIColor.white` для SceneKit (acceptable если SceneKit, но всё же)

#### DispatchQueue.main.async (anti-pattern, modern Swift use Task)
- `HappySpeech/Features/Common/CelebrationOverlayView.swift:169,187`
- `HappySpeech/Features/Common/StoryPlayerView.swift:198`
- `HappySpeech/Features/Common/Stories/AnimatedStoryPlayerView.swift:407`

#### Force-unwrap (3 места — acceptable contextual для vDSP)
- `HappySpeech/Features/Common/Spectrogram/SpectrogramAudioRecorder.swift:212,214,226` — `realPtr.baseAddress!` для DSPSplitComplex. **Acceptable** в Accelerate context, но можно через guard.

#### print statements
- `HappySpeech/ProductSpecs/master-plan-v2.md:974-1107` — Python код в Markdown spec. **Acceptable** (не в Swift).
- В Swift коде `print()` НЕ найден. ✅

#### TODO/FIXME/HACK/XXX
- В `HappySpeech/` коде НЕ найдено. ✅ (Plan v18 Block Y v18 «11 warnings clean»)

### 3.2. 3D vs 2D Lyalya — DRAMATIC GAP

Из 104 `*View.swift` (без Components):
- **2** используют 3D `RealityView`/`LyalyaRealityKitView`/`LyalyaRealityView` (1.9%)
  - `Features/AR/Mascot3D/LyalyaRealityView.swift` (сама обёртка)
  - `Features/OfflineState/OfflineMiniGameView.swift`
- **76** используют 2D `LyalyaMascotView`/`HSMascotView` only (73%)
- **26** не используют ни 2D, ни 3D маскота (25%)

Plus 4 features имеют `LyalyaRealityKitView`/`RealityView` в **Components/Workers** (ARZone, ARMirror), но это не root View экранов.

**User requirement:** 3D на КАЖДОМ экране (104). **Реальное покрытие: 2 (1.9%).**

Plan v19 Block I заявил «unified Lyalya» — это иллюзия consistency 2D states, **НЕ конверсия 2D→3D**.

### 3.3. Light/Dark systematic adaptation

- 104 *View.swift, всего **5 файлов** используют `@Environment(\\.colorScheme)`:
  - `Features/ARZone/ARZoneViewComponents.swift:203`
  - `Features/Auth/AuthForgotPasswordView.swift:16`
  - `Features/Auth/AuthSignInView.swift:9`
  - `Features/Auth/AuthVerifyEmailView.swift:15`
  - `Features/Auth/AuthSignUpView.swift:21`

Все 4 Auth — добавлены в Plan v19 Block C. **Остальные 99 экранов** полагаются на Asset Catalog colorset Any/Dark variants. Это **частичная** адаптация:
- ColorTokens auto-adapt через xcassets (Light/Dark variants есть для всех Brand* и Kid* colorset).
- Но manual visual differentiation (например, opacity adjustment, gradient direction change, illustration variant) есть **только на 5 экранах**.

**v19-manual-audit.md явно нашёл:** StutteringHome dark = белый фон, FluencyDiary dark = светлый, ProgressDashboard low contrast — Block AA v18 fix только 4. **Не verified в v19** ни на одном Dark screenshot.

### 3.4. Localization volume / dead keys

- 3 940 RU keys, 0 EN — formal compliance ✅
- Файл `Localizable.xcstrings` = 43 289 строк JSON
- 18 `XCTSkip` в тестах могут указывать на stale keys
- **Не было exhaustive `grep "String(localized:" → match against keys` audit** в v19. Plan v18 Block L заявил «coverage 100%» — но это keys → translations, не translations → usage.

### 3.5. Tests gap

- 1320 test functions, 137 файлов
- Coverage НЕ measured (нужно `xcodebuild test -enableCodeCoverage YES`)
- 18 XCTSkip — что они skip?
- Plan v19 Block L явно DEFER per ADR-V19-L-DEFER-TESTS-FULL: «100% coverage отложено на v20 (>40h scope)»

User explicit (требование #26): «100% test coverage ~600 new». **Defer'нуто на v20**. Это критично.

### 3.6. _workshop (753 MB) и backup files

- `_workshop/` = 753 MB (datasets, ml/checkpoints, screenshots, models/converted, …)
- В `HappySpeech/Resources/Models/` есть **backup файл** `RussianPhonemeClassifier_v18_backup.mlpackage` 736 KB — должен быть удалён (current v19 = 1.5 MB, не нужен).
- 3 backup .m4a в `Resources/Audio/Lyalya/settings/` (`lyalya_backup_b/c.m4a`, `lyalya_setting_backup.m4a`).
- DerivedData = 8.5 GB (Plan v18 Block AE «cleanup» не sustained).

User explicit: «Очистить мусор в папке проекта». **Не done в v19**.

### 3.7. Whisper duplication

- `Resources/Models/Whisper/whisper-base/` = **140 MB**
- `Resources/Models/Whisper/whisper-small/` = **464 MB**

Если оба загружаются в Bundle — это 604 MB Whisper, что = 40% всех Models. Скорее всего, runtime использует только один (whisper-small для качества OR whisper-base для скорости). **Не cleaned, не documented в ADR**.

### 3.8. Empty / broken VIPs (заявлены fixed в v19, но не verified)

Plan v19 Block B заявил fix for:
- P0.1 Demo emoji 🐵 → SF Symbol — **ПРОВЕРИТЬ** (DemoModels.swift screenSymbol поля сейчас `waveform.badge.microphone`, `house.fill` — SF Symbol. ✅ возможно fixed)
- P0.2 ParentHome blue ellipse → unfixed возможно (не verified screenshot после fix)
- P0.3 ChildHome empty → unfixed возможно
- P0.4 Settings empty → unfixed возможно
- P0.5 SessionHistory contrast → unfixed возможно
- P0.6 OfflineState emoji 🐵 → проверить (HSMascotView использует fallbackEmoji = 🦋 для idle, потенциально)

**Из v19 commit `0fbbe971`:** «B v19 P0 fixes (TabView, ChildHome bootstrap, Settings sync, SessionHistory contrast)». Но **screenshot после fix не сделан** в v19. Проблема: тот же баг может persist.

### 3.9. Apple HIG нарушения (потенциальные)

- iPhone SE 3 (320pt width × 568pt height) — **25 файлов БЕЗ `GeometryReader` или `minimumScaleFactor`**.
- Touch targets ≥56pt kids — `apple-hig-checklist-v19.md` заявлено, но не verified per-screen.
- Dynamic Type Small → AccessibilityLarge — не tested.
- VoiceOver labels — `accessibility-audit-final.md` дата 2026-04-27 (старый).
- Reduce Motion — частично соблюдается.

### 3.10. Animations on 2D Lyalya

- `LyalyaMascotView.swift` — 0 `repeatForever`/`withAnimation`/`TimelineView`. ✅
- `HSMascotView.swift` — **3** matches. Может быть animation на 2D Lyalya. **User explicit:** «2D героев нельзя анимировать».
- `LyalyaHeroView.swift` — 0. ✅

**Не fully verified.** Block I v19 заявил «removed», но HSMascotView имеет 3 animation hooks.

---

## 4. Gap-анализ предыдущих 12 планов

### Plan v3 (zesty-gliding-tiger, 72 KB, 2026-04-23)
- Initial scaffolding plan
- **Открытые gap'ы:** ML pipeline (Wav2Vec2/GigaAM defer), Real children dataset (TestFlight defer), Blender 3D (defer)

### Plan v4.1 (expressive-hoare, 37 KB, 2026-04-24)
- Design specs initial
- **Открытые:** kavsoft custom UI (только research, не applied), Liquid Glass effects partial

### Plan v5 (vivid-cat, 28 KB, 2026-04-25)
- 5 contours plan
- **Открытые:** Specialist contour shallow (есть feature, но не depth)

### Plan v8 (sunny-scone, 80 KB, 2026-04-27)
- 50+ блоков
- **Открытые:** Full localization audit, тесты coverage (defer уже здесь)

### Plan v11 (precious-dragonfly, 57 KB, 2026-04-29)
- Cleanup focus
- **Открытые:** _workshop cleanup (continues to v20), DerivedData (continues)

### Plan v13 (stateless-whale, 99 KB, 2026-05-01)
- Big plan, 60+ блоков
- **Открытые:** Manual screenshot tour (defer to v18/v19 each time)

### Plan v14 (memoized-cat, 97 KB, 2026-05-02)
- Apple HIG focus
- **Открытые:** HIG verify per screen (только checklist, не verified)

### Plan v15/v16 (indexed-prancing-tide, 60 KB, 2026-05-07)
- Lyalya 3D push
- **Открытые:** 3D coverage остался 2/104 (заявил «verified» — false positive)

### Plan v17 (valiant-wondering-sonnet, 56 KB, 2026-05-08)
- 5 R-screens implementation
- **Закрыто:** R.1-R.5 успешно (~6000 LOC)
- **Открытые:** T (6+ new screens) defer

### Plan v18 (calm-fountain, 295 KB, 2026-05-09) — самый большой
- 105 commits, 50+ блоков
- **Закрыто:** R-screens, 18 Cloud Functions, illustrations regen, Remotion 69 MP4, design system 4 components
- **Открытые** (defer ADR'ы):
  - AG: Blender 3D defer
  - E: ML retrain partial defer (исправлено в v19)
  - Z: 74 PNG manual screenshot (P0=3, P1=5, P2=6 — partial fix in AA)
  - L: 100% test coverage defer (передаётся в v19)
  - U: Dynamic Links replace ✅
  - I: Onboarding 3D + 2D anims (заявлено verified, оспаривается)

### Plan v19 (humming-sprouting-sun, 60 KB, 2026-05-10) — finished today
- 35 блоков, 10 commits
- **Закрыто:** ML 88.9%, Voice 20307, RTDB, 4 P0 UI fixes, ADR-V19-G/H/L
- **Открытые** (defer'ы оставшиеся для v20):
  - **L** Tests 100% coverage (ADR-V19-L-DEFER-TESTS-FULL)
  - **H** Blender 3D (ADR-V19-H-DEFER-BLENDER)
  - **AC** App Store submission (no Apple Dev account)
  - **AG** Big libs SPM expansion
  - **AH** Competitor gap (continues to v20)
  - **AN** +500 lessons neurolinguist (8055 items current)
  - **T** 6+ new VIP screens (104 уже sufficient claim)

### Plan v20 — должен закрыть ВСЕ defer + 9 P0 FAIL'ов выше

---

## 5. Anti-patterns в коде (конкретные строки)

### Force unwrap
- **3 места** в `SpectrogramAudioRecorder.swift:212/214/226` — vDSP context, acceptable
- **0** в Features (исключая выше)
- **Verdict:** ✅ acceptable

### print
- **0** в Swift коде (только в .md spec files)
- **Verdict:** ✅

### Hardcoded colors
- **20 hex** в `StoryLibrary.swift:58-770` (gradient backgrounds для stories)
- **2 RGB** в `PronunciationLeaderboardView.swift:334/351` (bronze)
- **1 black opacity 0.001** в `WeeklyChallengeView.swift:469` (invisible tap area pattern)
- **4 UIColor.white** в `LyalyaSceneView.swift` (SceneKit context)
- **Verdict:** ⚠ shallow — нужен ColorToken для bronze badge, gradients in StoryLibrary

### TODO/FIXME/HACK
- **0**
- **Verdict:** ✅

### DispatchQueue.main.async (anti-pattern modern Swift)
- **4 места** (CelebrationOverlayView 2, StoryPlayerView 1, AnimatedStoryPlayerView 1)
- **Verdict:** ⚠ — заменить на `Task { try? await Task.sleep(...); ... }`

### 2D Lyalya animations
- `HSMascotView.swift` — **3 animation hooks** (repeatForever/withAnimation/TimelineView)
- **Verdict:** ⚠ — User запретил 2D animations, нужен audit per usage

### Emoji в production UI (ZERO TOLERANCE)
- **5 файлов в DesignSystem** (LyalyaMascotView, HSOnboardingParallax, HSMascotPullToRefresh, HSCustomAlert, HSLottieContainer)
- **Verdict:** ❌ FAIL — нужно убрать **немедленно**

---

## 6. Технический долг

### Tests gap (priority P0 для v20)
- 1320 functions, **0% coverage measurement**
- 18 XCTSkip — **не documented**
- User requested 100% — gap может быть >50%
- Effort estimate: 40-80h

### 2D mascots вместо 3D (priority P0)
- 76/104 экранов используют 2D
- Effort: миграция 76 экранов на `LyalyaRealityKitView`
- Requires: GPU performance test on iPhone SE 3 (multiple LyalyaRealityKitView в одной view может быть expensive)

### Lottie procedural traces
- 58 Lottie файлов в Resources/Animations
- Не verified что все из real-lottie-importer (CC0/MIT)
- HSLottieContainer fallback на `Text("🎉")` указывает что fallback emoji живёт в production

### _workshop bloat (priority P1)
- 753 MB в `_workshop/` (datasets, models, screenshots)
- gitignored, но физически на диске
- DerivedData 8.5 GB

### Whisper duplication (priority P1)
- 604 MB обе версии — runtime usage не ясен
- Decide: small only (464 MB) или base only (140 MB) → освободит 140-464 MB

### Hardcoded gradients in StoryLibrary
- 20 stories × 2 hex colors = 40 magic strings
- Должны быть через ColorTokens или per-story content pack JSON

### GeometryReader / minimumScaleFactor отсутствуют в 25 файлах
- iPhone SE 3 (320pt) — overflow risk
- Effort: per-file audit

### DispatchQueue → Task migration (4 места)
- Modern Swift Concurrency

### Fallback emoji в DesignSystem (priority P0)
- Заменить на SF Symbol или Lyalya 3D rendering

---

## 7. Top-30 пунктов для Plan v20 (ranked)

> Каждый пункт указывает агента и P0/P1/P2 приоритет.

### P0 (must close для дипломной защиты, blocking)

1. **Удалить все эмодзи из DesignSystem fallbacks** (5 файлов) → `designer` + `ios-developer`. Заменить fallbackEmoji на SF Symbol map либо tiny static Lyalya illustration.
2. **3D Lyalya migration на 76 экранах** (или хотя бы top-30 high-traffic) → `ios-developer` + `animator`. Заменить `LyalyaMascotView` на `LyalyaRealityKitView` с `cameraMode: .nonAR` + transparent bg verified.
3. **Light/Dark adaptation на 99 экранах** → `designer` + `ios-developer`. Add `@Environment(\\.colorScheme)` где нужна manual differentiation, сделать manual screenshot 99 × 2 themes.
4. **Manual screenshot tour на 104 × 2 = 208 PNG** → Claude SAM (НЕ background). Каждый PNG read через Read tool.
5. **Tests 100% coverage** → `qa-engineer`. Realistic target: 90%+. Effort 40-80h. Закрыть все 18 XCTSkip.
6. **Verify P0 fixes из v19 Block B (4 баги: TabView, ChildHome, Settings, SessionHistory)** → manual screenshot после fix.

### P0 (high-value cleanup)

7. **Fix DemoStep emoji 🐵** (если ещё в content) → `pm` + `designer` (verify after Plan v19 Block B fix).
8. **HSLottieContainer.swift `Text(verbatim: "🎉")` → SF Symbol или Lottie fallback** → `ios-developer`.
9. **HSMascotView animation hooks audit** — User запретил 2D animation. → `ios-developer`. Удалить или conditionally за `@Environment(\\.accessibilityReduceMotion)` flag.
10. **Whisper consolidation** — оставить одну версию (small). Освободит 140 MB. → `ml-engineer` + ADR.

### P1 (quality + completeness)

11. **iPhone SE 3 overflow audit** на 25 файлах БЕЗ GeometryReader/minimumScaleFactor → `qa-engineer` + `ios-developer`.
12. **Localization dead keys cleanup** (xcstrings 3940 → возможно ~3000-3200 после cleanup) → `ios-developer` + `pm`.
13. **DispatchQueue → Task migration** (4 места) → `ios-developer`.
14. **StoryLibrary gradients → ColorTokens** (20 hex) → `designer` + `ios-developer`.
15. **PronunciationLeaderboard bronze color → ColorTokens** → `designer`.
16. **VoiceOver labels audit** на всех 104 экранах (расширить `accessibility-audit-final.md`) → `qa-engineer`.
17. **Dynamic Type test** Small → AccessibilityLarge per screen → `qa-engineer`.
18. **HIG checklist verify per screen** (350+ строк checklist apply to 104 screens) → `qa-engineer` + `designer`.
19. **kavsoft custom UI elements** apply (research доку есть, но fragmented apply) → `designer` + `ios-developer`. **Animated tab bar custom**, **liquid card morphing**, **breathing button**.
20. **Tutorial videos audit** (5 tutorial MP4) → `animator`. Manual visual review.

### P1 (cleanup и feature additions)

21. **Удалить backup файлы**: `RussianPhonemeClassifier_v18_backup.mlpackage`, `lyalya_backup_b/c.m4a`, `lyalya_setting_backup.m4a` → `pm`.
22. **_workshop cleanup** to ≤200 MB → `pm`. Datasets уже trained — exported в Models, чекпоинты можно удалить.
23. **DerivedData regular cleanup hook** → `pm`. settings.json `Stop` hook чтобы автоматически удалять `~/Library/Developer/Xcode/DerivedData/HappySpeech-*` после 7 дней.
24. **+6 новых VIP screens** (Block T defer'd) → `ios-developer`. Спецификации:
    - HelpCenterView (FAQ + видео гиды)
    - ParentInsightsTimeline (timeline view of weekly insights)
    - FamilyAwardsCabinetView (trophy cabinet 3D)
    - SpecialistMaterialsLibrary (logopedist resources)
    - VoiceJournalView (recordings child made)
    - CommunityEventsView (sezonal events)
25. **Apple HIG ≥56pt touch targets verify** на всех interactive elements → `qa-engineer` runtime test.
26. **Reduce Motion full compliance audit** на 58 Lottie + 4 DispatchQueue places → `qa-engineer`.

### P2 (nice-to-have, продвинутые)

27. **GigaAM-v2 Core ML conversion** retry per `gigaam-coreml-russian` skill (могло быть невозможно ранее) → `ml-engineer`.
28. **DocC documentation catalog** generation per `docc-documentation-skill` → `ios-developer`.
29. **CHHapticEngine custom AHAP patterns** apply (15 patterns per haptic-design-skill) → `designer` + `ios-developer`.
30. **SharePlay group lesson** проверка работоспособности на iPhone SE 3 sim → `qa-engineer` + `ios-developer`.

---

## 8. Метрики baseline vs target

| Метрика | Baseline (v19, 2026-05-10) | Target v20 |
|---|---|---|
| `*View.swift` | 104 | **110+** (Block T defer'd) |
| Swift LOC | 168 001 | 175 000+ |
| Test files | 137 | 160+ |
| Test functions | 1 320 | 1 800+ (+30%) |
| Test coverage | unknown (likely ~40-50%) | **90%+** |
| XCTSkip | 18 | **0** (close all) |
| Audio (.m4a) | 20 307 | 20 307 (sufficient) |
| Lyalya voice | 13 798 | 13 798 (sufficient) |
| Видео (.mp4) | 146 | 146 (sufficient) |
| Lottie (.json) | 58 | 70+ (real CC0) |
| Resources size | 1.5 GB | **1.0-1.2 GB** (after Whisper consolidation) |
| Models size | 957 MB | **500-600 MB** (-Whisper-base, -backup) |
| ML accuracy (RussianPhoneme) | 88.9% | 92%+ |
| Эмодзи в UI | **11 places** | **0** |
| 3D Lyalya screens | 2 | **30+** (high-traffic) |
| 2D-only Lyalya screens | 76 | ≤30 |
| Light/Dark @Environment screens | 5 | **104** |
| Manual screenshot tour | 13/19 partial | **208/208** (104 × 2 themes) |
| Hex colors hardcoded | 27 places | 0 (all → ColorTokens) |
| DispatchQueue.main.async | 4 places | 0 (Task migration) |
| backup files | 4 | 0 |
| _workshop size | 753 MB | ≤200 MB |
| DerivedData size | 8.5 GB | ≤2 GB после cleanup |
| Firebase services | 10/10 | 10/10 (verify все enforcement modes) |
| Localization keys | 3 940 | ~3 000-3 200 (после dead key cleanup) |
| ADR в decisions.md | 49 | 60+ (новые v20 ADR) |
| Apple HIG verified per screen | 0/104 manual | 104/104 |
| VoiceOver verified per screen | 0/104 manual | 104/104 |
| Dynamic Type tested | 0/104 | 104/104 |

---

## 9. Дополнительные findings

### 9.1. Storage / hardcoded gradients dump

`HappySpeech/Features/Common/Stories/StoryLibrary.swift` — 20 stories, каждая с `backgroundGradient: ["#XXXXXX", "#YYYYYY"]`. **20 × 2 = 40 hex colors**. Это user-facing visual content per story, но они должны быть либо:
- (а) в Content Pack JSON (если контент выгружается),
- (б) в ColorTokens.Story.<storyName> для consistency,
- (в) generated on-the-fly из dominant color of story illustration.

**Currently:** hardcoded в Swift code → менять цвет = recompile.

### 9.2. SceneKit для Lyalya вместо RealityKit

`HappySpeech/Features/Common/LyalyaSceneView.swift` — **SceneKit** (не RealityKit). Использует `UIColor.white` для lighting. SceneKit и RealityKit — разные стэки. Если у нас есть и `LyalyaRealityKitView` (RealityKit) и `LyalyaSceneView` (SceneKit) — это **дублирование** и потенциальный визуальный inconsistency.

**Decision:** consolidate на ONE engine (RealityKit recommended per user req «3D без заднего фона + transparent»).

### 9.3. ML модели — несбалансированный inventory

| Модель | Размер | Назначение | Status |
|---|---|---|---|
| Wav2Vec2RuChild.mlpackage | **302 MB** | Child Russian ASR | active |
| Whisper-small (papka) | 464 MB | Adult Russian ASR | active? |
| Whisper-base (papka) | 140 MB | Adult Russian ASR fallback | redundant? |
| RussianPhonemeClassifier.mlpackage | 1.5 MB | Phoneme detection | active |
| RussianPhonemeClassifier_v18_backup.mlpackage | 736 KB | **DELETE** (старая версия) | **trash** |
| Wav2Vec2RuChildLogopedic.mlpackage | 804 KB | Logopedic specific | active? |
| EmotionDetection.mlpackage | 272 KB | Emotion detection | active |
| PronunciationScorer_*.mlpackage (4) | 4 × 108 KB | Pronunciation scoring | active |
| SpeakerVerification.mlpackage | 164 KB | Parent vs child voice | active |
| SileroVAD.mlpackage | 52 KB | Voice activity detection | active |
| SoundClassifier.mlpackage | 20 KB | Sound classification | active |
| TonguePostureClassifier.mlpackage | 12 KB | Tongue posture | active |

**Total:** ~907 MB — но 3 candidates на удаление: backup (-736 KB), Whisper-base (-140 MB) → потенциал **141 MB** освобождения.

### 9.4. Test gaps по features

| Feature | Test directory exists? | Файлов |
|---|---|---|
| StutteringModule | ✅ | (ls confirmed) |
| SiblingMultiplayer | ✅ | |
| ParentChild | ✅ | |
| Customization | ✅ | |
| GrammarGame | ✅ | |
| FamilyCalendar | ✅ | |
| Stories | ✅ | |
| Games | ✅ | |
| Mocks | ✅ | |
| Snapshot | ✅ | |
| DesignSystem | ✅ | |
| Unit | ✅ | |
| ML | ✅ | |
| Performance | ✅ | |
| Accessibility | ✅ | |

Но **отсутствуют папки тестов для:**
- ARFaceFilter
- ARZone
- AR/Mascot3D
- ARMirror
- CulturalContent
- DialectAdaptation
- LogopedistChat
- WeeklyChallenge
- FamilyAchievements
- DemoMode (есть в Unit?)
- VoiceCloning
- PronunciationLeaderboard
- WorldMap (если только в Unit/Interactors)

**Эстимейт coverage gap:** 13+ features без dedicated test directory. Нужно ~13 × 5 ≈ **65 новых test files**, ~500 функций.

### 9.5. Скиллы — дополнительные неиспользованные

В `~/.claude/skills/` есть 64+ скиллов. Plan v19 использовал ~20-25 (из ML, design, voice, illustration). **Unused skills которые могли бы помочь v20:**
- `apple-pencil-drawing-skill` — для iPad letter tracing (defer ADR из v18 — но iPhone SE 3 only target → defer ok)
- `shareplay-multiplayer-skill` — feature exists, но manual test не done
- `docc-documentation-skill` — 0 DocC catalog в проекте сейчас
- `core-data-avdlee` — Core Data не используется (Realm), defer
- `pow-swiftui-effects` — Liquid Glass partial implementation
- `hero-transitions` — `HSHeroCardTransition.swift` есть, но widely used?
- `lottie-animator` — для verify 58 Lottie quality
- `omnilottie-ai` — generation new Lottie

---

## 10. Блокирующие риски для дипломной защиты

### High risk (могут быть замечены экзаменатором)

1. **Эмодзи в UI** — User explicit не разрешает. Если экзаменатор тапнет на pull-to-refresh / alert → увидит 🦋/👋/etc. **Critical to fix**.
2. **3D vs 2D mismatch** — User просил 3D, факт 2D. Если экзаменатор просмотрит 5 random экранов — все будут 2D.
3. **Empty Settings / ChildHome** (если v19 fix не работает) — обнаруживается на первом запуске.
4. **iPhone SE 3 overflow** — экзаменатор может тапнуть на длинную label, увидеть truncation.

### Medium risk

5. Whisper duplication — может вызвать «зачем 600 MB Whisper в kid app?»
6. _workshop в проекте — physically на диске, gitignored, но если делать `ls` экзаменатор спросит.
7. Test coverage не measured — formal claim «1320 tests» легко проверяется, но coverage % не известен.

### Low risk

8. ADR documentation gap — v18 имел 30+ ADR, v19 добавил 4. Нужно поддерживать.
9. Localization dead keys — невидимо для пользователя.
10. SceneKit vs RealityKit dup — не visible если LyalyaSceneView не используется на видимых экранах.

---

## 11. Recommended Plan v20 structure (мета-предложение)

Plan v20 должен иметь **~50 блоков** (между v18 50+ и v19 35+), организованных так:

### Phase 1 — Cleanup & Anti-pattern Removal (Block A-G)
- A: Manual screenshot tour 104 × 2 (208 PNG, 100% manual via Claude)
- B: Эмодзи purge (5 DesignSystem files + verify production)
- C: 3D Lyalya migration to top-30 high-traffic screens
- D: Light/Dark systematic adaptation (99 screens)
- E: iPhone SE 3 overflow audit + fix (25 files)
- F: DispatchQueue → Task migration (4 places)
- G: Hex colors → ColorTokens (27 places)

### Phase 2 — Tests & Coverage (Block H-K)
- H: Coverage measurement baseline (`xcodebuild test -enableCodeCoverage YES`)
- I: Close 18 XCTSkip
- J: New test files for 13 missing features (~500 new tests)
- K: Snapshot tests for 104 × 2 (Light/Dark)

### Phase 3 — Asset & Code Cleanup (Block L-P)
- L: Whisper consolidation (-140 MB)
- M: Backup files removal (-2 MB)
- N: _workshop pruning (-550 MB)
- O: DerivedData hook (auto-cleanup)
- P: Localization dead keys (-700 keys)

### Phase 4 — Quality & Polish (Block Q-V)
- Q: Apple HIG verify per screen (104)
- R: VoiceOver verify per screen (104)
- S: Dynamic Type test per screen (104)
- T: kavsoft custom UI apply (animated tabs, breathing buttons, liquid cards)
- U: 6+ new VIP screens (Block T defer'd from v17/v18/v19)
- V: HSMascotView animation removal/conditional за reduce motion

### Phase 5 — Advanced (Block W-AC)
- W: ML retrain RussianPhonemeClassifier 88.9% → 92%+
- X: GigaAM-v2 Core ML retry
- Y: DocC documentation catalog
- Z: Custom AHAP haptic patterns (15 per skill)
- AA: Spectrogram visualizer enhancement
- AB: SharePlay manual test
- AC: Final tag `v1.1.0-final-v20`

---

## 12. Closing notes

**Реальность:** Plan v19 закрыл **критические ML и audio targets** (88.9% accuracy, 20307 voice files). Но **визуальное / UX качество** на дипломной защите будет недостаточным:
- 76/104 экранов = 2D Lyalya (User просил 3D)
- 11 эмодзи в production UI (User запретил)
- Light/Dark только на 5 экранах
- Tests 100% defer'd
- Manual screenshot tour 13/19 (12.5%)

**v20 должен быть UI/UX heavy plan**, противоположность v19 (ML-heavy). Effort estimate **80-120 hours agent work** sequential для full closure.

**Принцип v20:** «Не оставить ни одного screen без verified Light/Dark + 3D Lyalya + iPhone SE 3 overflow check + VoiceOver label». Это значит **104 × 4 = 416 проверок minimum** в screenshot tour phase.

**Критичные defer'ы которые НЕ нужно закрывать в v20** (acceptable per ранее user answers):
- Blender 3D custom rigging (no Blender installed)
- App Store submission (no Apple Developer account)
- TestFlight real children dataset (no Apple Developer)
- Apple Pencil iPad feature (target = iPhone only)

---

**End of Plan v20 Deep Audit.**

Файл сохранён: `/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech/.claude/team/v20-deep-audit.md`
Размер: ~1100 строк markdown.
Подготовил: Claude Opus 4.7 (1M context).
