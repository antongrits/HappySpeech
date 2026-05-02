# Visual Bug Report v14 — Block M Manual Screenshot Tour

**Date:** 2026-05-02
**Tested devices:** iPhone SE 3rd generation (375×667pt, @2x) + iPhone 17 Pro (402×874pt, @3x)
**Screenshots taken:** 60 iPhone SE 3 + 82 iPhone 17 Pro = 142 total
**Build:** Debug, -HSStartRoute bypass used for main screens, onboarding.completed=YES for auth bypass
**BUILD RESULT:** BUILD SUCCEEDED

---

## Critical Visual Bugs (Priority 1)

### BUG-001: Onboarding Step 4 — "Далее" button hidden below fold on SE3
- **Screen:** OnboardingFlowView → Age selection step (Шаг 4 из 10)
- **Device:** iPhone SE 3rd generation
- **Symptom:** "Далее" button rendered at y=704pt, screen ends at y=667pt → button unreachable
- **Impact:** BLOCKING — user cannot complete onboarding on SE3 without external bypass
- **File:** `HappySpeech/Features/Onboarding/` — age selection step view
- **Fix:** Wrap in ScrollView or use `.safeAreaInset(edge: .bottom)` for the button; use `ViewThatFits` or reduce vertical padding on SE3

### BUG-002: Auth Screen — Multiple buttons below fold on SE3
- **Screen:** AuthView / LoginView
- **Device:** iPhone SE 3rd generation
- **Symptom:** Buttons at y=671 (Восстановить пароль), y=700 (Создать аккаунт), y=733 (Демо-режим) all outside 667pt visible area
- **Impact:** BLOCKING — user cannot access demo mode, registration, or password recovery on SE3
- **File:** `HappySpeech/Features/Auth/AuthView.swift` (или аналог)
- **Fix:** Wrap auth content in ScrollView; compact spacing between buttons for SE3; или использовать `GeometryReader` для адаптивных отступов

### BUG-003: SessionCompleteView — Localization keys visible in UI
- **Screen:** SessionCompleteView
- **Device:** Both (SE3 + IP17)
- **Symptom:** Raw localization keys shown instead of translated text:
  - `sessionComplete.score.label`
  - `sessionComplete.breakdown.bonus`
- **Impact:** HIGH — debug artifacts visible to users; professional appearance ruined
- **File:** `HappySpeech/Features/SessionComplete/SessionCompleteView.swift`
- **Fix:** Add missing keys to `Localizable.xcstrings` or fix String(localized:) calls

### BUG-004: ParentHomeView — Localization key visible in greeting
- **Screen:** ParentHomeView (route: parentHome)
- **Device:** Both (SE3 + IP17)
- **Symptom:** `parent.home.greeting.night` shown as literal string instead of localized text
- **Impact:** HIGH — visible to all users in parent dashboard
- **File:** `HappySpeech/Features/ParentHome/ParentHomeView.swift`
- **Fix:** Add `parent.home.greeting.night` (and morning/day variants) to `Localizable.xcstrings`

### BUG-005: ParentHomeView — Session card shows raw localization key for date
- **Screen:** ParentHomeView (route: parentHome)
- **Device:** Both
- **Symptom:** `parent.home.date.today` shown literally in session card
- **Impact:** HIGH — visible in main dashboard
- **File:** Same as BUG-004
- **Fix:** Same — add missing localization keys

### BUG-006: SettingsView — Header shows raw keys
- **Screen:** SettingsView (route: settings)
- **Device:** Both
- **Symptom:** `settings.header.greeting` and `settings.header.subtitle` shown literally
- **Impact:** MEDIUM — settings screen looks unfinished
- **Fix:** Add to Localizable.xcstrings

### BUG-007: SettingsView — Customization shows raw keys
- **Screen:** SettingsView
- **Device:** Both
- **Symptom:** `customization.skin.classic` and `customization.color.warm` shown literally
- **Impact:** MEDIUM
- **Fix:** Add to Localizable.xcstrings

---

## Visual Issues (Priority 2)

### BUG-008: ChildHomeView — Lyalya mascot absent from hero area
- **Screen:** ChildHomeView (route: childHome)
- **Device:** Both
- **Symptom:** No Lyalya character visible in the main child home screen; only text greeting "Миша!" and chat bubble "Миша, готов тренировать «Р»?" — no 3D or illustration mascot
- **Expected:** Lyalya mascot prominent hero in child-facing screens
- **Impact:** MEDIUM — kids category app missing key mascot presence

### BUG-009: ChildHomeView — Mascot chat bubble uses plain text style
- **Screen:** ChildHomeView
- **Device:** Both
- **Symptom:** "Миша, готов тренировать «Р»?" shown as plain rounded rect; no Lyalya avatar attached
- **Expected:** Lyalya bubble with avatar + speech cloud decoration
- **Impact:** MEDIUM

### BUG-010: WorldMapView — Map has minimal content, no illustrated zones
- **Screen:** WorldMapView (route: worldMap)
- **Device:** SE3
- **Symptom:** World map shows basic circles/nodes without rich illustrated backgrounds; mostly grey locked zones
- **Expected:** Illustrated landscape/world with terrain, colors, illustrated sound zones
- **Impact:** MEDIUM — core navigation feature looks sparse

### BUG-011: StutteringHomeView — Large empty white space at top
- **Screen:** StutteringHomeView (route: stuttering)
- **Device:** SE3
- **Symptom:** Large empty white area at top of screen (~40% of viewport) before the Lottie/video preview
- **Impact:** MEDIUM — layout imbalance, unprofessional on small screens

### BUG-012: FluencyDiaryView — Empty state without Lyalya illustration
- **Screen:** FluencyDiaryView (route: fluencyDiary)
- **Device:** SE3
- **Symptom:** "Записей ещё нет" empty state uses system book icon (grey SF Symbol) without Lyalya character or custom illustration
- **Expected:** Custom empty state with Lyalya and encouraging message
- **Impact:** LOW-MEDIUM — generic iOS empty state in kids app

### BUG-013: LessonPlayerView — No answer image illustrations
- **Screen:** LessonPlayerView (route: lessonPlayer, template: bingo/listen-and-choose)
- **Device:** SE3
- **Symptom:** Answer cards show SF Symbol placeholder (leaf/bird-like icons) instead of actual illustrations; cards have no rounded corner polish
- **Expected:** Colorful rounded illustrations for each answer option
- **Impact:** HIGH — gameplay cards are the core visual of the app

### BUG-014: ARZoneView — Butterfly illustration with rectangular crop
- **Screen:** ARZoneView (route: arZone)
- **Device:** SE3
- **Symptom:** Butterfly illustration appears to have a visible rectangular container boundary; not naturally clipped
- **Impact:** LOW

### BUG-015: SessionCompleteView — Score circle empty, no animation
- **Screen:** SessionCompleteView
- **Device:** Both
- **Symptom:** Large empty circle in center of screen; no score number, no Lottie animation, no confetti
- **Expected:** Score display with celebration animation
- **Impact:** HIGH — completion screen is key emotional moment in UX

### BUG-016: ChildHomeView SE3 — "Быстрая игра" game cards truncated
- **Screen:** ChildHomeView scrolled (route: childHome)
- **Device:** SE3
- **Symptom:** Horizontal scroll of game cards partially clips; "Запомни" card text truncated to "Запомни"
- **Impact:** LOW

### BUG-017: ParentHome SE3 — tab bar partial overlap
- **Screen:** ParentHomeView
- **Device:** SE3
- **Symptom:** Tab bar icon labels partially overlap bottom safe area on SE3 (home indicator area)
- **Impact:** LOW

### BUG-018: OnboardingView — Lyalya illustration appears as rectangular video thumbnail
- **Screen:** OnboardingView step 1 (route: onboarding)
- **Device:** Both
- **Symptom:** Lyalya is displayed as a small rectangular thumbnail image (Remotion video frame?) rather than a full-bleed animated mascot
- **Expected:** Full-screen or large hero Lyalya with animation
- **Impact:** HIGH — first impression of the app

### BUG-019: SiblingMultiplayerView — Shows iPhone 17 Pro as peer device
- **Screen:** SiblingMultiplayer (route: siblingMultiplayer)
- **Device:** SE3
- **Symptom:** Correctly discovers iPhone 17 Pro simulator as available peer — functional but shows simulator name in production UI. Minor.
- **Impact:** LOW (works correctly, cosmetic)

---

## SE3-Specific Layout Issues (Priority 3 — All Same Root Cause)

### BUG-020: SE3 Layout Root Cause Analysis
All SE3-specific layout bugs share one root cause: **fixed-height layouts not using `.safeAreaInset`, `ScrollView`, or `GeometryReader` for adaptive sizing**.

Affected screens confirmed:
- OnboardingFlowView steps 3-10 (name input, age selection, etc.)
- AuthView (login + register)

**Recommended fix pattern:**
```swift
// Instead of:
VStack {
    content
    Spacer()
    Button("Далее") { ... }
        .padding(.bottom, 24)
}

// Use:
ScrollView {
    content
}
.safeAreaInset(edge: .bottom) {
    Button("Далее") { ... }
        .padding()
        .background(.background)
}
```

---

## Audit Statistics

| Metric | Value |
|---|---|
| Total screenshots taken (iPhone SE 3) | 60 |
| Total screenshots taken (iPhone 17 Pro) | 82 |
| Total screenshots | 142 |
| Routes tested | 18 unique routes |
| Critical bugs (Priority 1) | 7 |
| Visual issues (Priority 2) | 12 |
| SE3-specific layout bugs | 2 blocking (BUG-001, BUG-002) |
| Localization bugs | 5 (BUG-003–007) |
| Missing illustrations/animations | 4 (BUG-008, 013, 015, 018) |
| Overall visual quality score | 5/10 (blocked by loca bugs + missing art) |

---

## Top-3 Critical Bugs Summary

1. **BUG-001** — OnboardingFlowView age step: "Далее" button at y=704pt on 667pt SE3 screen → BLOCKING, user cannot complete onboarding
2. **BUG-003 + BUG-004 + BUG-005 + BUG-006** — SessionComplete, ParentHome, Settings screens show raw localization keys instead of translated text → ALL SCREENS LOOK BROKEN
3. **BUG-015** — SessionCompleteView celebration circle empty + no animation → key emotional moment of the app is broken

---

## Notes for Next Developer Iteration

1. Use `-HSStartRoute <route>` launch argument to bypass auth for all screenshot tours (already in AppCoordinator)
2. SE3 screen = 375×667pt; all CTAs must be reachable without scroll or use `safeAreaInset`
3. All localization keys must be in `Localizable.xcstrings` before any screen is considered "done"
4. Lyalya mascot should be visible on ChildHome hero, SessionComplete, and Onboarding as hero element
5. LessonPlayer answer cards need actual artwork — SF Symbol placeholders are visible in demo/preview data
