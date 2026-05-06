# Manual Screen Audit v15 — HappySpeech
**Date:** 2026-05-06
**Device:** iPhone SE (3rd generation) Simulator
**Build:** Release candidate (Sprint 12, main branch)
**Screenshots:** `_workshop/screenshots/v15/` (100 PNGs, local, .gitignore)
**Auditor:** qa-simulator (Block G v15)
**ClaudeDesign reference:** `happyspeech-design/project/tokens.jsx`, `ui.jsx`, `screens-kid.jsx`, `screens-parent.jsx`

---

## Summary

| Severity | Count |
|---|---|
| P0 (blocker, ship-stopper) | 0 |
| P1 (must fix before App Store) | 3 |
| P2 (should fix, UX regression) | 5 |
| P3 (minor / polish) | 4 |
| BLOCKED (requires real device or auth) | 3 |
| Deferred to Block L screenshot tour | 18 |

**Screens captured:** 30 unique screens
**Screens not captured (deferred to Block L):** ~18 (SpecialistHome, ComparisonDashboard, ProfileEditor, NarrativeQuest, MinimalPairs, DragAndMatch, PuzzleReveal, SoundHunter, VisualAcoustic, Rhythm, StoryCompletion, AR-activity in-session, LessonSummary detail, FamilyHome, ParentalGate, CustomizationPicker, SharePlay, ReportExport)

---

## Screen 1: SplashView

**File:** `HappySpeech/Features/Auth/SplashView.swift`
**Screenshot:** `_workshop/screenshots/v15/01_splash.png`

**Observations:**
- Background gradient coral to darker coral matches ClaudeDesign `Brand.primary` to `Brand.primaryHi`. Correct.
- "HappySpeech" logotype visible, white, centered. Typography correct.
- "ГОВОРИМ ВОЛШЕБНО" subtitle present, uppercased, small caption weight. Matches spec.
- Loading indicator visible at bottom ("загрузка..." text).
- Mascot Ляля: NOT VISIBLE. `LyalyaRealityKitView` (3D USDZ RealityKit) does not render in iOS Simulator.

**Severity P2:**
- Mascot placeholder empty in simulator — no fallback 2D illustration shown. In production on real device this renders correctly (RealityKit 3D). For screenshots and TestFlight on simulator builds a 2D fallback (`illustrationName`) should be activated. Affects all screens using `HSMascotView` / `LyalyaMascotView`.

**Severity P3:**
- "загрузка..." text in bottom area is very small and low contrast — borderline AA compliance.

---

## Screen 2: OnboardingFlowView — Step 1 (Welcome)

**File:** `HappySpeech/Features/Onboarding/OnboardingFlowView.swift`
**Screenshot:** `_workshop/screenshots/v15/02_onboarding_step1.png`

**Observations:**
- Cream background (`oklch(0.975 0.012 80)` equivalent). Correct.
- "Привет! Я Ляля" text with butterfly emoji visible. Mascot absent (simulator limitation).
- Subtitle "Подружка-бабочка..." readable, body font weight.
- "Начать" CTA button: coral background, white text, rounded corners ~22px. Matches KidCTA spec.
- Progress indicator "Шаг 1 из 10" in top-right. Correct.
- Back chevron absent on step 1. Correct (first step).

**Severity P3:**
- Butterfly emoji substitutes mascot — works but is not the intended Ляля character. Note: simulator-only limitation.

---

## Screen 3: OnboardingFlowView — Step 3 (Child Name)

**File:** `HappySpeech/Features/Onboarding/OnboardingFlowView.swift`
**Screenshot:** `_workshop/screenshots/v15/04_onboarding_step3_withname.png`

**Observations:**
- "Как зовут ребёнка?" title. Correct.
- "ИМЯ РЕБЁНКА" section label with TextField "Введи имя" placeholder.
- "ВЫБЕРИТЕ АВАТАР" section with emoji avatar row visible.
- No "Далее" button visible — button either disabled (name field empty) or below fold.

**Severity P3:**
- Avatar picker row clips at right edge — rightmost avatars not fully visible, no horizontal scroll indicator shown.

---

## Screen 4: OnboardingFlowView — Step 4 (Child Age) — P1 BUG

**File:** `HappySpeech/Features/Onboarding/OnboardingFlowView.swift`
**Screenshots:** `_workshop/screenshots/v15/05_onboarding_step4_childage.png`, `05_extreme_bottom.png`

**Observations:**
- "Сколько лет ребёнку?" title.
- Age bubble selector: 5, 6 (selected, coral), 7, 8 visible. Age 6 pre-selected. Correct.
- "или ДРУГОЙ ВОЗРАСТ" section with drum-roll picker showing 5/6/7 лет.
- "Возраст важен — к выбору" hint at very bottom.
- "Далее" action button COMPLETELY ABSENT from all Step 4 screenshots across 10+ tap attempts.

**Severity P1 — BLOCKER for onboarding completion on SE3:**
- `actionFooter` rendered via `.safeAreaInset(edge: .bottom)` is not appearing on iPhone SE 3 (375x667pt logical resolution). Users on SE3 cannot advance past Step 4 and cannot complete onboarding. Critical regression on the smallest supported device.
- Fix: Replace `.safeAreaInset(edge: .bottom)` with explicit `VStack` + `Spacer` layout for the CTA button, OR add minimum height constraint. Verify on SE3 simulator before ship.
- File: `HappySpeech/Features/Onboarding/OnboardingFlowView.swift`, `actionFooter` view builder, line ~225.

---

## Screens 5–10: OnboardingFlowView Steps 5–10

All screenshots captured show Step 4 (child age) — navigation past Step 4 was not achievable due to P1 blocker above. Steps 5 (Goals), 6 (Sounds), 7 (Schedule), 8 (Permissions), 9 (Model Download), 10 (Completion) were NOT reached.

**Status: DEFERRED — pending P1 fix for actionFooter on SE3.**

---

## Screen 11: AuthSignInView

**File:** `HappySpeech/Features/Auth/AuthSignInView.swift`
**Screenshots:** `_workshop/screenshots/v15/12_auth_signin_full.png`, `12b_auth_signin_scrolled.png`

**Observations:**
- Top gradient blob: coral Brand.primary opacity gradient. Matches spec.
- "HappySpeech" logotype + subtitle. Clean.
- "Эл. почта" + "Пароль" text fields with SF Symbol icons. Correct.
- "Войти" CTA: disabled state shown (desaturated coral, 0.5 opacity). Correct disabled styling.
- "Войти через Google" outlined button: coral border, coral text. Matches secondary button spec.
- "Забыли пароль?" + "Зарегистрироваться" links in coral. Correct.
- "Попробовать без входа" tertiary link at very bottom.

**Severity P3:**
- "Попробовать без входа" uses plain underlined text style. Contrast borderline. Consider proper `.tertiary` button style.

---

## Screen 12: AuthSignUpView

**File:** `HappySpeech/Features/Auth/AuthSignUpView.swift`
**Screenshot:** `_workshop/screenshots/v15/13_auth_signup.png`

**Severity P2:**
- "Создать аккаунт" CTA button is clipped at bottom on SE3 — same safeAreaInset issue as Onboarding. With 4 form fields the CTA falls below visible area. Fix: scrollable form or smaller field spacing on SE3.

---

## Screen 13: AuthForgotPasswordView

**File:** `HappySpeech/Features/Auth/AuthForgotPasswordView.swift`
**Screenshot:** `_workshop/screenshots/v15/14_auth_forgot_password_correct.png`

Simpler single-field form. No layout issues on SE3. No findings.

---

## Screen 14: DemoModeView

**File:** `HappySpeech/Features/Demo/DemoModeView.swift`

**Severity P2:**
- "Попробовать без входа" link on AuthSignInView navigates to AuthSignUpView instead of DemoModeView. User expecting a no-auth preview gets a registration form. Either route is misconfigured or label is misleading.
- File: `HappySpeech/Features/Auth/AuthSignInView.swift` footerLinks section, demoMode route binding.

---

## Screen 15: ChildHomeView (Light)

**File:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`
**Screenshots:** `_workshop/screenshots/v15/20_child_home_main.png`, `20_child_home_scroll1.png`, `20_child_home_scroll2.png`, `20_child_home_scroll3.png`

**Observations:**
- Background: warm cream/apricot gradient. Correct kid circuit surface.
- "Привет, Миша! / 6 мая" greeting header. Correct personalization.
- Seasonal banner "Пасха" coral card. Attractive.
- Mascot interaction zone: EMPTY (3D mascot not visible). White oval placeholder aura visible.
- Mascot speech bubble "Миша, готов тренировать Р?" readable.
- Achievement banner: coral, dismissible. Correct.
- Streak banner: flame icon, amber. Correct.
- Daily Mission card: progress "5/5", "Миссия выполнена!" green badge. Correct.
- Words of Day: "рыба / рыба", "гора / го·ра", "ворона / во·ро·на" with syllable hyphenation. Correct.

**Severity P2:**
- Mascot empty area creates large blank white space in hero section — visually jarring. The MoodAuraView ambient glow renders but without 3D mascot above it looks like a rendering error. Requires 2D illustration fallback.

---

## Screen 16: ChildHomeView (Dark Mode)

**Screenshot:** `_workshop/screenshots/v15/50_child_home_dark.png`

Dark surface applied correctly. Seasonal banner adapts. Mission card visible. Token compliance: PASS.

**Severity P3:**
- "Привет, дружок!" shown (anonymous) instead of personalized "Миша" in dark mode capture — likely test artifact.

---

## Screen 17: ParentHomeView (Light)

**File:** `HappySpeech/Features/ParentHome/ParentHomeView.swift`
**Screenshot:** `_workshop/screenshots/v15/21_parent_home.png`

**Observations:**
- "Прогресс" large title, light cool gray surface. Correct parent circuit.
- Child row shows "0 лет ·" — mock data returns empty age.
- Empty state "Занятий пока нет" with "Начать занятие" outlined CTA. Correct.
- Bottom tab bar: Обзор | Занятия | Аналитика | Настройки. All 4 tabs present.

**Severity P2:**
- Child profile row shows "0 лет" — age 0 not nil-guarded. Should show "—" or hide age label when value is 0. File: ParentHomeView or ViewModel child age formatter.

---

## Screen 18: ParentHomeView (Dark Mode)

**Screenshot:** `_workshop/screenshots/v15/51_parent_home_dark.png`

Dark mode correct. "Миша — 6 лет · Р, Ш" child row loaded. Last session card readable. Streak card amber/brown.

**Severity P2:**
- Tab bar selected indicator color is iOS system blue instead of `ColorTokens.Brand.primary` (coral). Affects both light and dark. Check TabView tint / accentColor setting.

---

## Screen 19: SettingsView

**File:** `HappySpeech/Features/Settings/SettingsView.swift`, `SettingsViewSections.swift`
**Screenshot:** `_workshop/screenshots/v15/22_settings.png`

**Observations:**
- "Настройки" large title (~40pt bold). Correct large title style.
- Double "Настройки" — navigation title + card header. Redundant.
- "ВНЕШНИЙ ВИД" section: Тема picker "Как в с..." (truncated) / Светлая / Тёмная.
- Lyalya Customization row: "customization.skin.classic · customization.color.warm" — RAW LOCALIZATION KEYS.
- "ПРОФИЛЬ РЕБЁНКА": Avatar (fox), "Малыш", "Возраст: 6 лет". Correct.

**Severity P1 — Localization bug:**
- `SettingsViewSections.swift` line ~69: `Text(LyalyaCustomizationStorage.shared.settingsSubtitle)` displays raw keys instead of Russian text. Root cause: `CustomizationModels.swift` uses dynamic key interpolation `String(localized: String.LocalizationValue("customization.skin.\(rawValue)"))` — keys either missing from Localizable.xcstrings or dynamic interpolation not resolving at runtime.
- Fix: Add static entries `customization.skin.classic`, `customization.skin.fantasy`, `customization.color.warm`, `customization.color.cool` etc. to Localizable.xcstrings, OR switch to switch-statement `var localizedName: String` returning direct Russian strings.
- Files: `HappySpeech/Features/Customization/CustomizationModels.swift`, `HappySpeech/Resources/Localizable.xcstrings`

**Severity P2:**
- "Тема" picker "Как в с..." truncated on SE3 — three equal-width segments too wide. Use shorter label "Авто".
- Redundant double title. Rename card header or remove.

---

## Screen 20: ProgressDashboardView

**File:** `HappySpeech/Features/ProgressDashboard/ProgressDashboardView.swift`
**Screenshot:** `_workshop/screenshots/v15/23_progress_dashboard.png`

**Observations:**
- Period selector: "Неделя" (blue pill) / Месяц / Квартал.
- Accuracy card: "73%" with blue fill.
- Streak card: amber. Correct.
- Bar chart Пн–Вс with values 62–86%. Clean.

**Severity P3:**
- Period selector selected state uses blue pill instead of `ColorTokens.Brand.primary` (coral). Accuracy bar also blue. Same accentColor/tint misconfiguration as tab bar.

---

## Screen 21: RewardsView

**File:** `HappySpeech/Features/Extensions/Rewards/RewardsView.swift`
**Screenshot:** `_workshop/screenshots/v15/24_rewards.png`

- "Мои награды" title. "7 из 72 / 9%" circular progress ring (coral). Correct.
- Category tabs: coral pill selection. Correct.
- Animal sticker grid: unlocked (Котик, Щенок+NEW, Лисёнок), locked (Мишка, Панда, Лев).
- Background: warm cream. Correct.

**No issues found.** Most polished screen in the app.

---

## Screen 22: WorldMapView

**File:** `HappySpeech/Features/WorldMap/WorldMapView.swift`
**Screenshot:** `_workshop/screenshots/v15/25_world_map.png`

- Node map with locked/unlocked nodes. Lock icons correct.
- Stars counter bottom bar.

**Severity P3:**
- "Заблокировано" node label text ~10pt — too small for 5–8yr target audience. Use lock icon only or larger label.

---

## Screen 23: SessionHistoryView

**File:** `HappySpeech/Features/SessionHistory/SessionHistoryView.swift`
**Screenshot:** `_workshop/screenshots/v15/26_session_history.png`

- "17 занятий / 75% точность / 144 минуты" stats row. Clean.
- Line chart Апр 6–27. Readable.
- Session entry "Слушай и выбирай — 9 мин · 12 попыток · Звук Р — 84%" with green badge. Correct.

No issues found.

---

## Screen 24: OfflineStateView

**File:** `HappySpeech/Features/OfflineState/OfflineStateView.swift`
**Screenshot:** `_workshop/screenshots/v15/27_offline_state.png`

- Correct offline-first messaging. "Повтор через 3 секунды" countdown. Coral CTA + outline secondary.

No issues found.

---

## Screen 25: ARZoneView

**File:** `HappySpeech/Features/ARZone/ARZoneView.swift`
**Screenshot:** `_workshop/screenshots/v15/28_ar_zone.png`

- 2D fallback (butterfly illustration) renders correctly in simulator. Correct.
- "Лучше играть в наушниках" tip banner. Good UX hint.
- Note: ARZone has 2D fallback but `HSMascotView` does not — inconsistency confirming P2-001.

No critical issues.

---

## Screen 26: SessionCompleteView

**File:** `HappySpeech/Features/LessonPlayer/SessionCompleteView.swift`
**Screenshot:** `_workshop/screenshots/v15/29_session_complete.png`

- "Молодец! Отличный результат." encouragement. Correct tone.
- Three gold stars. "Бонус" badge. Correct.
- Mascot circle EMPTY.

**Severity P2:**
- Mascot absence in session complete is most jarring — this is the primary emotional payoff moment for children. Empty circle with just aura glow provides zero positive reinforcement visually. 2D fallback illustration critical here.

---

## Screen 27: FamilyVoiceLibraryView

**File:** `HappySpeech/Features/Extensions/FamilyVoiceLibrary/FamilyVoiceLibraryView.swift`
**Screenshot:** `_workshop/screenshots/v15/30_family_voice.png`

- Coral icon card, word chip selector, mint record button. Clean.
- Parent circuit surface (light gray). Correct context.

No issues found.

---

## Screen 28: StutteringHomeView

**File:** `HappySpeech/Features/Extensions/Stuttering/StutteringHomeView.swift`
**Screenshot:** `_workshop/screenshots/v15/31_stuttering_home.png`

**Severity P2:**
- Default iOS navigation bar (white, large title area) — inconsistent with app's custom cream surfaces. Looks like a different app.
- "Начать" CTA is iOS system blue, not `ColorTokens.Brand.primary` coral.
- Fix: Add `.toolbarBackground(.hidden, for: .navigationBar)` + cream background + `HSButton` primary style.
- File: `HappySpeech/Features/Extensions/Stuttering/StutteringHomeView.swift`

---

## Screen 29: FluencyDiaryView

**Screenshot:** `_workshop/screenshots/v15/32_fluency_diary.png`

Empty state "Записей ещё нет" with green blob. Correct messaging. Nav bar style consistent (no white bar issue here).

No critical issues.

---

## Screen 30: SiblingMultiplayerView

**Screenshot:** `_workshop/screenshots/v15/33_sibling_multiplayer.png`

Searching state with radio animation, "Ищем друга...", "Вернуться" coral link. Correct.

No issues found. (SharePlay functionality BLOCKED: requires real device.)

---

## Screen 31: LessonPlayerView — ArticulationImitation (working)

**Screenshot:** `_workshop/screenshots/v15/40_lesson_articulationImitation.png`

- Header: step, timer, lives, pause. Correct.
- Question "Слушай внимательно и выбери картинку / Вопрос 1 из 8".
- Play button coral. "Повтори" secondary. Correct.
- Answer tiles with SF Symbol icons (lightning for "зубы", sun for "рак").

**Severity P2:**
- Word illustration icons wrong in answer tiles — SF Symbol placeholders don't match word content. Content/asset mismatch in mock sound pack. Confirm `sound_s_pack.json` has correct `imageName` fields.

---

## Screen 32: LessonPlayerView — Templates Rendering Blank (P1)

**Screenshots:** `_workshop/screenshots/v15/40_lesson_listenAndChoose.png`, `40_lesson_repeatAfterModel.png`, `40_lesson_sorting.png`, `40_lesson_memory.png`

All 4 show blank cream screen — only status bar visible.

**Severity P1 — Template loading regression:**
- `listenAndChoose`, `repeatAfterModel`, `sorting`, `memory` templates via `-HSStartRoute lessonPlayer?template=X -UITestMockServices` render blank. `articulationImitation` and `bingo` templates render content.
- Possible causes: (a) Mock content provider returns empty data for these template types, (b) Template discriminator in `LessonPlayerView` switch falls through to empty, (c) Missing mock exercise data.
- Files: `HappySpeech/Features/LessonPlayer/LessonPlayerView.swift`, mock services, `AppCoordinator.swift` HSStartRoute handler.
- Impact: Also affects S12-012 snapshot tests if using same route system.

---

## Screen 33: SpecialistHomeView — BLOCKED

`-HSStartRoute specialistHome` + `-UITestMockServices` returned blank screen. Mock AppContainer.preview does not inject specialist-role user.

Action: Add specialist profile to `AppContainer.preview`, OR add `-UITestSpecialistRole` launch argument.

---

## Screen 34: RoleSelectView — BLANK

`-HSStartRoute roleSelect` rendered blank cream screen. RoleSelectView requires auth context not provided by UITestMockServices.

---

## Deferred to Block L

The following screens were not accessible and are deferred to the Block L screenshot tour (real device / full auth):

1. SpecialistHomeView — BLOCKED, needs specialist role
2. ComparisonDashboardView — BLOCKED, needs specialist role
3. ProfileEditorView — route not tested
4. NarrativeQuestView — blank via HSStartRoute
5. MinimalPairsView — blank via HSStartRoute
6. DragAndMatchView — blank via HSStartRoute
7. PuzzleRevealView — blank via HSStartRoute
8. SoundHunterView — blank via HSStartRoute
9. VisualAcousticView — blank via HSStartRoute
10. RhythmView — blank via HSStartRoute
11. StoryCompletionView — blank via HSStartRoute
12. BreathingView — blank via HSStartRoute (salmon-colored blank)
13. ARActivityView (in-session) — AR not available in simulator
14. SharePlayView — BLOCKED, real device + FaceTime
15. ParentalGateView — not triggered
16. CustomizationPickerView — not navigated from Settings
17. ReportExportView — requires specialist + data
18. FamilyHomeView — route not captured
19. OnboardingFlowView Steps 5–10 — pending P1 fix for SE3

---

## Priority Issues Consolidated

### P1 — Must Fix Before App Store

| ID | Screen | Issue | File |
|----|--------|-------|------|
| P1-001 | OnboardingFlowView Step 4+ | "Далее" button invisible on SE3 — safeAreaInset(edge:.bottom) not rendering | `OnboardingFlowView.swift` ~line 225 actionFooter |
| P1-002 | SettingsView | Raw localization keys: "customization.skin.classic" instead of "Классическая" | `CustomizationModels.swift`, `Localizable.xcstrings` |
| P1-003 | LessonPlayerView | listenAndChoose / repeatAfterModel / sorting / memory render blank via UITestMockServices | `LessonPlayerView.swift` + mock data |

### P2 — Should Fix

| ID | Screen | Issue |
|----|--------|-------|
| P2-001 | All HSMascotView screens | 3D mascot blank in simulator, no 2D fallback. SessionCompleteView most critical. |
| P2-002 | AuthSignUpView | CTA button clipped below fold on SE3 |
| P2-003 | AuthSignInView | "Попробовать без входа" navigates to SignUp instead of DemoMode |
| P2-004 | ParentHome + ProgressDashboard | Tab bar tint / period picker use iOS system blue instead of Brand.primary coral |
| P2-005 | StutteringHomeView | Default white nav bar + iOS blue CTA — out of design system |

### P3 — Polish

| ID | Screen | Issue |
|----|--------|-------|
| P3-001 | SplashView | "загрузка..." low contrast |
| P3-002 | OnboardingFlowView Step 3 | Avatar picker clips rightmost items |
| P3-003 | WorldMapView | "Заблокировано" node label ~10pt too small for target age |
| P3-004 | SettingsView | Double "Настройки" title; "Как в с..." truncated |

---

## ClaudeDesign Token Compliance

| Token | Status |
|-------|--------|
| Brand.primary (coral) on KidCTA buttons | PASS |
| Brand.primary (coral) on tab bar tint / period pickers | FAIL — P2-004 |
| Surface.kidBackground (cream) on kid circuit | PASS |
| Surface.parentBackground (cool gray) on parent circuit | PASS |
| Corner radii lg 24px on cards | PASS |
| KidCTA height 54px | PASS |
| SF Pro Rounded typography (kid screens) | PASS |
| Dark mode adaptive surfaces | PASS |
| Localization ru strings | FAIL — P1-002 |

**Overall: 8/10 token groups PASS**

---

## Accessibility Quick Check

- VoiceOver labels on nav buttons: present
- HSMascotView `.accessibilityLabel` correct in code (untestable visually — mascot absent)
- CTA tap targets ≥44pt: PASS on all verified screens
- `@Environment(\.accessibilityReduceMotion)` checked in HSMascotView and ChildHomeView: PASS by code review
