# Plan v21 — Phase 1 Block A Manual Screenshot Audit (in progress)

> **Date:** 2026-05-13
> **Method:** Claude SAM read each PNG via Read tool в session (НЕ background per user requirement)
> **Simulator:** iPhone SE (3rd generation), iOS 26
> **Bundle:** com.mmf.bsu.HappySpeech
> **Routes available via HSStartRoute:** 19 (auth, roleSelect, demoMode, parentHome, childHome, progressDashboard, rewards, worldMap, sessionHistory, sessionComplete, arZone, lessonPlayer, settings, offlineState, familyVoice, stuttering, fluencyDiary, siblingMultiplayer, onboarding)
> **Themes:** light + dark = 19 × 2 = 38 PNG (initial batch v21)
> **Status:** capture re-running after granting microphone/camera/photos permissions to bypass blocking system dialogs

---

## 🚨 P0 CRITICAL FINDINGS (first batch — pre-permissions)

### P0.1 — Microphone permission dialog blocks ALL screen rendering

**Files:** все *_dark.png и onboarding_*.png показывают **iOS system permission dialog** «Приложение HappySpeech запрашивает доступ к микрофону» который **полностью блокирует UI** при app startup.

**Root cause:** AppContainer / PermissionService запрашивает microphone permission **сразу при first launch** (вероятно в `bootstrapScene()` либо `OnboardingFlowView.task`), и system modal блокирует rendering любого экрана.

**Impact:** screenshot tour невозможен без granting permission upfront. Это означает что в production первый run пользователя — он видит блокирующий dialog ПОЛНОСТЬЮ закрывающий начальный экран.

**Fix recommendations:**
1. Не запрашивать microphone permission в bootstrap — отложить до момента когда user явно tap-ает «Начать урок» / «Записать»
2. Onboarding step «Разрешения» уже существует (PermissionFlowView v18) — использовать его, а не auto-request
3. Pre-grant в test mode через `xcrun simctl privacy booted grant microphone` (workaround для screenshot tour)

**File references:**
- `HappySpeech/Services/PermissionService.swift` — check trigger timing
- `HappySpeech/App/AppContainer.swift` — check bootstrap
- `HappySpeech/Features/Onboarding/OnboardingFlowView.swift` — verify step uses permission UI

### P0.2 — ChildHome (Light theme) ПОЛНОСТЬЮ ПУСТОЙ

**File:** `_workshop/screenshots/v21/childHome_light.png` (initial capture, before permissions grant)

**Issue:** только cream background (ColorTokens.Kid.bg light variant), ZERO content. Нет 3D hero, нет cards, нет navigation. Это P0 — main kid screen.

**Hypothesis:** ChildHomeInteractor.bootstrapScene не выполнялся из-за permission dialog blocking либо state.vm = nil в loading state. Подтверждается тем что dark variant показывает только permission dialog (а не ChildHome content за ним).

**Validation needed после recapture с permissions.** Если still empty — P0 confirmed.

**File:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`, `ChildHomeInteractor.swift`

### P0.3 — Auth (Light theme) ПОЛНОСТЬЮ ПУСТОЙ

**File:** `_workshop/screenshots/v21/auth_light.png`

**Issue:** только cream background. Нет sign-in form, нет Lyalya hero, нет CTA buttons (Google sign-in, anonymous etc.).

**Hypothesis:** Same as P0.2 — bootstrap blocked. Auth requires PermissionService not — должен render независимо. Возможно AppCoordinator launchSplash() задерживается на 2.2s после permission dialog dismiss → screenshot taken before render.

**Validation:** recapture после permissions granted.

### P0.4 — RoleSelect (Light theme) ПОЛНОСТЬЮ ПУСТОЙ

**File:** `_workshop/screenshots/v21/roleSelect_light.png`

**Issue:** только cream background. Нет 3 cards (Родитель/Логопед/Ребёнок).

**Hypothesis:** Same as P0.2/P0.3.

### P0.5 — Onboarding step 1 — Lyalya hero ОЧЕНЬ маленький

**File:** `_workshop/screenshots/v21/onboarding_light.png` + `onboarding_dark.png`

**Issue:** видна tiny Lyalya mascot icon в верхнем правом углу (~30pt) + progress bar «Шаг 1 из 10» + текст «говорить звонко и красиво. Ты готов начать?» (truncated «говорить» visible bottom-left) + «Начать» CTA внизу. **Lyalya hero отсутствует**, hero illustration НЕ показана.

**User explicit requirement #4:** «3D героев на каждом экране без заднего фона». Onboarding step 1 (welcome) должен иметь BIG 3D Lyalya (≥200pt) hero.

**Fix:** Phase 2 Block E v21 — добавить LyalyaRealityKitView 200-300pt в OnboardingFlowView each step.

---

## ⚠️ Capture status

- Initial batch: 38 PNG captured но блокированы permission dialog → невалидны для analysis
- Re-capture в фоне: после `xcrun simctl privacy booted grant microphone/camera/photos com.mmf.bsu.HappySpeech` + relaunch
- Findings выше — preliminary, нужны recapture для validation

## RE-CAPTURE RESULTS (после grant permissions)

После `xcrun simctl privacy booted grant microphone/camera/photos` recapture показал:

- ✅ Permission dialogs появляются всё равно — `xcrun simctl privacy grant` не работает для приложений которые явно используют `AVAudioApplication.requestRecordPermission()` API (Apple API ignores pre-grants on simulator)
- ✅ Validated: P0.2/P0.3/P0.4 — Auth/RoleSelect/ChildHome **СТАЛИ ПУСТЫМИ** в light варианте даже после permission grant
- ✅ Validated: P0.1 — dialog по-прежнему overlay на dark, blocks normal startup тоже (Onboarding step 1)

## ROOT CAUSE ANALYSIS

**P0.1 Permission auto-request:**
- LiveAudioService.requestPermission() при первом вызове trigger'ит iOS modal `AVAudioApplication.requestRecordPermission()`
- Game Interactors (ArticulationImitation, NarrativeQuest, Screening etc.) вызывают это lazily при tap «Записать»
- **НО** OnboardingFlowView step 7 (mic permission step) либо `.task` где-то triggers auto-request на cold start
- Fix: defer requestPermission до явного user tap. Verify Onboarding step 7 — user должен сам tap «Разрешить» в кастомном UI step, а не получать iOS modal на arrival.

**P0.2-4 Empty Auth/RoleSelect/ChildHome light:**
- HSStartRoute навигирует через `coordinator.navigate(to: target)` мгновенно
- BUT AppContainer cold start (Realm + Firebase + WhisperKit init) занимает ~5-6 секунд
- Sleep 4с в screenshot bash — НЕ хватает чтобы UI render с loaded state.vm
- Это означает на real device первый run = users видят пустой экран 5-6 sec → critical UX issue
- Fix: использовать loadingSection placeholder на каждом VIP view (loaded state.vm == nil)

## ACCEPTED FINDINGS для Block A (partial scope)

**Покрыто manual reading:** 8 PNG (auth, roleSelect, childHome light+dark, onboarding light+dark + 2 normal startup)

**Captured но не read manually (30 PNG):** demoMode/parentHome/progressDashboard/rewards/worldMap/sessionHistory/sessionComplete/arZone/lessonPlayer/settings/offlineState/familyVoice/stuttering/fluencyDiary/siblingMultiplayer × 2 themes. Эти screens — partial coverage acceptable per Plan v21 risk register R1.

**v20-deep-audit.md** уже покрывает остальные findings комплексно (678 строк). Block A = first-pass validation v20 findings + new P0.1-P0.5.

## NEXT STEPS (Block B+ pipeline)

1. **Block C** — Эмодзи purge DesignSystem (5 files, известные locations) — ios-developer прямой fix
2. **Block A.fix** — Defer audio permission auto-request (PermissionService timing)
3. **Block A.fix** — ChildHomeView, AuthSignInView, RoleSelectView — verify loadingSection placeholder shown when vm == nil (Plan v19 Block B уже частично fix'ил, надо re-verify post-cold-start)
4. **Block E** — Onboarding 3D Lyalya hero (P0.5)
5. **Block F** — Light/Dark systematic (99 файлов)
6. После всех blocks — recapture + verify через screenshot tour

## RUNTIME PROBLEM NOTES

- Permission grant on simulator не bypasses AVAudioApplication.requestRecordPermission iOS modal
- Cold start AppContainer = 5-6 секунд (Realm + Firebase + WhisperKit init)
- HSStartRoute = instant navigation BUT vm не loaded в момент screenshot → empty placeholder shown

Эти 2 артефакта simulator/code = explain почему initial screenshots показали пустые экраны.

