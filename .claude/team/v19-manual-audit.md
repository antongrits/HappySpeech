# Plan v19 Block A — Manual Screenshot Audit

**Date:** 2026-05-10
**Method:** Claude SAM в session (НЕ background per user explicit requirement)
**Simulator:** iPhone SE (3rd generation), iOS booted
**Bundle:** com.mmf.bsu.HappySpeech (1.5 GB built)
**Theme captured:** Light (Dark to follow)
**Screens captured:** 19 routes via -HSStartRoute launch argument
**Screens read manually:** 13/19 (auth, roleSelect, demoMode, parentHome, childHome, progressDashboard, rewards, worldMap, sessionHistory, sessionComplete, arZone, lessonPlayer, settings, offlineState, familyVoice, stuttering, fluencyDiary, siblingMultiplayer)

---

## 🚨 P0 CRITICAL FINDINGS (must fix immediately)

### P0.1 — Demo Step 1 emoji 🐵 в speech bubble (Block AA v18 incomplete fix)
**File:** `HappySpeech/Features/Demo/DemoModels.swift` или `DemoView.swift` step 1 narration
**Issue:** Текст "Привет! Я Ляля. Покажу всё по шагам." имеет emoji 🐵 (обезьяна) слева
**User explicit requirement:** «В дизайне нельзя использовать эмоджи»
**Fix:** Replace 🐵 на SF Symbol либо удалить иконку, replace на small Lyalya illustration через HSMascotView size: .compact

### P0.2 — ParentHome serious UI bug (huge blue ellipse blocking content)
**File:** `HappySpeech/Features/ParentHome/ParentHomeView.swift` либо TabView container
**Issue:** Огромный синий oval/ellipse blocking большую часть экрана. Tab bar items (Обзор, document, chart, settings) wrapped в round shape которая закрывает content. "Пр..." truncated в top-left.
**Fix:** Найти и удалить broken background shape. Verify TabView NavigationStack hierarchy. Likely .background или .clipShape misconfigured.

### P0.3 — ChildHome ПОЧТИ ПУСТОЙ (kid contour main screen!)
**File:** `HappySpeech/Features/ChildHome/ChildHomeView.swift`
**Issue:** Только "дружок!" фрагмент текста + "Пасха" badge + tiny Lyalya icon. Огромное пустое orange пространство. Никаких карточек уроков, daily mission, streak banner, quick play.
**Fix:** Restore content blocks. Возможно loadVM не инициализировался — проверить Interactor + ChildHomeView.

### P0.4 — Settings ПОЛНОСТЬЮ ПУСТОЙ
**File:** `HappySpeech/Features/Settings/SettingsView.swift`
**Issue:** Только background gradient + tiny Lyalya. Никаких settings entries, options, switches.
**Fix:** Verify SettingsViewSections/SettingsView VIP flow. Likely DI mock data missing для preview launch route.

### P0.5 — SessionHistory contrast critical
**File:** `HappySpeech/Features/SessionHistory/SessionHistoryView.swift`
**Issue:** Текст practically invisible на orange tinted overlay. "История сессий" header faded. Stats labels unreadable. Chart axes faded.
**Fix:** Replace tinted text colors на ColorTokens.Kid.ink (high contrast). Reduce orange overlay opacity.

### P0.6 — OfflineState emoji 🐵
**File:** `HappySpeech/Features/OfflineState/OfflineStateView.swift`
**Issue:** Emoji 🐵 (обезьяна) показан в центре экрана как hero. User explicitly запретил.
**Fix:** Replace 🐵 на SF Symbol (например `wifi.exclamationmark`) или Lyalya illustration с offline pose.

---

## ⚠️ P1 IMPORTANT FINDINGS

### P1.1 — ProgressDashboard typo "лчший рекорд"
**Issue:** Должно быть "Лучший рекорд". Просто typo.
**Fix:** Локализационный ключ + значение.

### P1.2 — ProgressDashboard cards empty values
**Issue:** "Серия" / "лчший рекорд" cards без значений (только labels).
**Fix:** Mock state в preview либо load from Realm.

### P1.3 — WorldMap layout chaotic
**Issue:** Top icon (envelope?) locked. Many "Заблокировано" labels overlap. Lyalya tiny.
**Fix:** Redesign WorldMap с лучшей hierarchy + Lyalya hero ≥150pt.

### P1.4 — SessionComplete "Очки" empty value
**Issue:** "Очки" label без значения — placeholder.
**Fix:** Inject preview score.

### P1.5 — LessonPlayer instruction truncated "Слушай внимательн..."
**Issue:** Lipscaling text truncates with "..."
**Fix:** `.lineLimit(nil) + .minimumScaleFactor(0.85)` или wrap to multi-line.

---

## ✅ GOOD SCREENS

| Screen | Status | Notes |
|---|---|---|
| Auth (SignIn) | ✅ | Lyalya hero, clean form, "Войти через Google" CTA |
| RoleSelect | ✅ | 3 cards (Родитель/Логопед/Ребёнок), good layout |
| Rewards | ✅ | Stickers grid, animal illustrations |
| AR-зона | ✅ | Welcome screen with circular hero |
| FamilyVoice | ✅ best | Card design, words selector chips, big mic button |
| StutteringHome | ✅ | Clean "Перед началом" with big "Начать" CTA |
| FluencyDiary | ✅ | Empty state with Lyalya hero |
| SiblingMultiplayer | ✅ | Good "Найдём друга" with antenna animation |

---

## CROSS-CUTTING ISSUES (на всех экранах)

1. **2D Lyalya вместо 3D RealityKit** — User explicit req: 3D Lyalya на каждом экране через LyalyaRealityKitView
2. **2D Lyalya не consistent** — visible различия в pose/style между экранами (sleeping vs waving vs standing)
3. **Lyalya размеры варьируются от tiny (40pt) до large (200pt)** — нет единого стандарта
4. **Light theme orange tint overlay** ухудшает contrast text на kid screens
5. **Empty state design** — слишком много пустого места на multiple screens

---

## NEXT STEPS (Block B fixes)

1. Fix P0.1 — Demo emoji 🐵 → SF Symbol/Lyalya
2. Fix P0.2 — ParentHome blue ellipse bug (TabView config)
3. Fix P0.3 — ChildHome empty (restore Interactor flow)
4. Fix P0.4 — Settings empty (restore SettingsView)
5. Fix P0.5 — SessionHistory contrast (ColorTokens fix)
6. Fix P0.6 — OfflineState emoji 🐵 → SF Symbol/Lyalya
7. Rebuild + re-screenshot all 19 routes
8. Verify все P0 fixed
9. Then proceed Dark theme screenshots (Block A.6)
10. Then Block C — Light/Dark systematic across 104 *View files

## SCREENS NOT YET CAPTURED (deferred to Block A.6+)

Эти screens требуют sub-routes / deep links не покрытых -HSStartRoute simple cases:
- 10 Onboarding steps (only step 1 captured via auto-onboarding flow)
- 16 LessonPlayer game templates (only Bingo captured via simple lessonPlayer route)
- 8 AR sub-games (только ARZone entry captured)
- Specialist (login, students list, ProgramEditor, SessionReview, Reports)
- Family (FamilyHome, ProfileEditor, ComparisonDashboard, FamilyCalendar, FamilyLeaderboard, FamilyAchievements)
- 5 R-screens (DialectAdaptation, LogopedistChat, WeeklyChallenge, FamilyAchievements, CulturalContent)
- HomeTasks, NeurolinguistInsights, SpeechVisualization, OfflineMiniGame, DailyStreak, ARFaceFilter, GuidedTour, GrammarGame, etc.

## VERDICT

**Status:** 6 critical P0 issues found in 13 screens analyzed.
**Recommendation:** Fix all P0 sequentially before continuing to remaining screens + Dark theme.
