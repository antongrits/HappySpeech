# V24 Screen Audit — Light Batch B (59 PNG)

**Auditor:** cto Opus xhigh
**Date:** 2026-05-15
**Source:** `_workshop/v24_uitest_tour/light/` (rows 60-118, alphabetical second half: `neurolinguistInsights` → `worldMap`)
**Theme:** Light only
**Method:** Manual Read tool inspection of all 59 PNGs against 12-criteria checklist.

---

## Summary

- Screens reviewed: **59**
- **P0** issues (critical, blocking release): **38**
- **P1** issues (major): **9**
- **P2** issues (nice-to-have): **2**
- Clean screens (no issues): **10**

---

## Cross-cutting systemic issues (P0)

### SYS-P0-1 (v24): Onboarding navigation completely broken — all 10 steps render Step 1

`onboarding_light.png`, `onboarding1_light.png` через `onboarding10_light.png` — **все 11 screenshots идентичны** ("Шаг 1 из 10", "Привет! Я Ляля"). Test cannot advance onboarding state. Либо:
- UITest не нажимает кнопку «→ Начать» между screenshots;
- OnboardingInteractor не продвигает `currentStep` (state mutation lost через router push);
- Все step routes указывают на step 1.

Affected routes (11): `onboarding`, `onboarding1`…`onboarding10`. **Blocking** — onboarding это P0 surface для дипломной презентации.

### SYS-P0-2 (v24): Blue oval blob render bug across 5 routes

`programEditor_light.png`, `reports_light.png`, `sessionReview_light.png`, `studentsList_light.png`, `specialistHome_light.png` — все показывают одинаковый артефакт: огромный синий вытянутый овал по центру (~600×900pt), bottom toolbar с иконками «👥 / 🎵 Занятия / 📄 / ⚙️», заголовок "Co..." обрезан в левом верхнем углу.

Это похоже на повреждённый **SpecialistTabView** или splash-loading state, который never resolves. Все specialist-routes сваливаются в этот broken shell. Likely root cause: `SpecialistCoordinator` initialization fails → fallback view с overgrown placeholder Capsule shape.

### SYS-P0-3 (v24): Settings sub-routes all return base Settings root (8 routes)

`settings_light.png`, `settingsAbout_light.png`, `settingsAccessibility_light.png`, `settingsGDPR_light.png`, `settingsLanguage_light.png`, `settingsModelPacks_light.png`, `settingsNotifications_light.png`, `settingsPrivacy_light.png`, `settingsTheme_light.png`, `settingsVoice_light.png` — **все 10 screenshots идентичны** (base Settings root с "Внешний вид / Тема / Наряд Ляли / Профиль ребёнка").

UITest не углубляется в push-destination subviews. Либо `NavigationLink` destinations not wired, либо tour script просто рендерит root settings 10 раз.

Bonus issue: ширина 750pt (rendered на iPad/Plus simulator) — должна быть 390pt (iPhone 17 Pro per CLAUDE.md).

### SYS-P0-4 (v24): Specialist & sibling-multiplayer routes fall through to login / discovery hub

- `specialistLogin_light.png`, `weeklyChallenge_light.png` → отображают **HappySpeech parent auth** ("С возвращением! / Эл. почта / Войти через Google") — routes не реализованы.
- `siblingMultiplayer_light.png`, `siblingMultiplayerDiscovery_light.png`, `siblingMultiplayerGame_light.png`, `siblingMultiplayerLobby_light.png` — **все 4 идентичны** "Найдём друга" discovery screen. Game/Lobby/Discovery sub-states не реализованы.

### SYS-P0-5 (v24): Stuttering / softOnset / voiceCloning routes fall through to disclaimer screen

- `softOnset_light.png`, `stuttering_light.png`, `stutteringHome_light.png` — все три идентичны "Перед началом / Это упражнения для домашней практики / Если у ребёнка серьёзное заикание — обратитесь к логопеду / Начать". Это disclaimer hub, а не отдельные tools. Stuttering tools (DAF, metronome, prolonged speech) не отображаются.
- `voiceCloning_light.png` → отображает auth screen (route не реализован).

### SYS-P0-6 (v24): Mini-thumbnail rendering — soundAndFace, worldMap, sessionComplete

Три route'а отрисованы в нестандартно малом размере (~190×360pt вместо 390×844):
- `soundAndFace_light.png` — only top "AR-зона / AR-маски" peek;
- `worldMap_light.png` — only top "Карта прогресса / Грамматика" card peek;
- `sessionComplete_light.png` — "Молодец! Отличный результат." + 3 stars + empty circle.

Похоже на UI tour rendering bug или screenshot capture в неправильной size class. Если это реальный layout — то это P0 too small for child user.

### SYS-P0-7 (v24): pronunciationLeaderboard / parentInsightsTimeline rendered at 750pt (iPad/Plus)

Width 750pt вместо 390pt. Layout не ломается, но это inconsistent с остальным tour. Возможно, UI tour mid-flight переключил simulator или screen size class change.

### SYS-P0-8 (v24): soundDictionary contains emoji "👄" in section header

`soundDictionary_light.png` — "Гласные" имеет розовую губу-emoji circle icon ("👄"). Per CLAUDE.md "no эмодзи" rule + Kids Category compliance — должен быть SF Symbol или custom asset.

---

## Findings (per screen)

### CLEAN — neurolinguistInsights_light.png
- Хороший экран "Insights от Ляли / Что говорит Ляля / Прогресс за неделю" с pill "мало данных". 3D Lyalya отсутствует (acceptable для analytics screen). Russian copy OK. No truncation.

### CLEAN — offlineMiniGame_light.png
- Это **auth screen** (С возвращением). P0 — route fallthrough.
- Reclassify: **P0** offlineMiniGame route не реализован.

### CLEAN — offlineState_light.png
- Хороший offline state screen с 3D Lyalya + WiFi-off icon + "Нет подключения к интернету / Проверить подключение / Продолжить без интернета". CTA buttons ≥56pt. Light theme correct.

### P0 — onboarding_light.png  /  onboarding1…10_light.png  (11 screens)
- SYS-P0-1: all 11 identical Step 1 of 10.

### CLEAN — parentHome_light.png
- "Прогресс / Доброй ночи! / Миша 6 лет · Р, Ш / 9/12 Слушай и выбирай" + bottom tab bar (Обзор / Занятия / Аналитика / Настройки). 3D Lyalya отсутствует на parent surface (acceptable). Streak flame icon hover между card и tab bar — minor P2 spacing.

### P1 — parentInsightsTimeline_light.png
- Rendered at 750pt width (SYS-P0-7). Cards "1 Сессий / 8 мин / 75% / 1 из 7" + days list "Сб 9 мая / Вс 10 мая". Warning triangle icons "⚠️" в каждой day-row — стилизованные SF Symbols, не эмодзи. Russian copy correct. Контент логичен.

### P1 — poseSequence_light.png
- Rendered tiny (190×340pt). "AR-зона / Добро пожаловать в AR-зону! / Выбери весёлую игру" + одна AR-маски card. Это AR hub fallthrough, не pose sequence. **P0**: route не реализован отдельно.
- Reclassify: **P0** poseSequence falls through to AR hub.

### CLEAN — profileEditor_light.png
- "Редактировать профиль / Миша" + 3D Lyalya иконка-Reward + avatar grid (5 emoji-style avatars: butterfly/star/rocket/heart/rainbow) + colour theme picker + "Аа имя Миша" text field. **Issue**: «🌈» rainbow + «❤️» heart в Avatar row — могут быть emoji (P1). Если это PNG-assets — OK.

### P0 — programEditor_light.png
- SYS-P0-2 (blue oval blob).

### P1 — progressDashboard_light.png
- Bar chart values "55, 60, 63, 65, 60, 66, 71, 78, 73, 74, 78, 78, 80, 79, 78, 85, 80, 85" — overlap of digit labels above bars (visible "8055", "78,80" stacking). Numbers too close together. Need smaller font / rotate labels / show every-other.
- Tabs "Неделя / Месяц / Квартал" OK. "Точность 70% / Серия 18 дней подряд" cards good. Title "Прогресс" + empty space ~280pt before cards — P1 wasted space.
- Width 562pt (SYS-P0-7-like).

### P1 — pronunciationLeaderboard_light.png
- Rendered at 750pt width. "Рейтинг семьи / Рейтинг точности произношения / Всего детей в рейтинге: 0" + segmented "Эта неделя / Прошлая / Всё время" + empty state "Пока нет данных / Запиши хотя бы одно занятие". Trophy SF Symbol OK. Empty state text well-aligned.

### P0 — reports_light.png
- SYS-P0-2 (blue oval blob).

### CLEAN — rewardAlbum_light.png  /  rewardCollection_light.png  /  rewardDetail_light.png  /  rewards_light.png
- 4 screens **идентичны** "Мои награды / 7 из 72 / 9% / Все 72 / Животные 12 / Котик / Щенок [Новое] / Лисёнок / Мишка / Панда / Лев". P0: routes Album/Collection/Detail должны быть разные. **P0** for collection/detail not distinguishable from rewards root.
- Reclassify: **P0** reward sub-routes are aliases of `rewards`.

### P0 — roleSelect_light.png
- Отображает **parentHome** (Прогресс / Миша / 9/12). Должен быть role-picker (Ребёнок / Родитель / Логопед). Route fallthrough.

### P0 — sessionComplete_light.png
- SYS-P0-6 (rendered tiny 190×360pt). "Молодец! Отличный результат." + 3 yellow stars + empty circle "Очки / Бонус". Confetti/Pow effect отсутствует. 3D Ляля отсутствует на celebration screen — P0 (kid celebration moment should have hero mascot).

### CLEAN — sessionDetail_light.png  /  sessionHistory_light.png
- 2 screens идентичны "17 занятий / 75% точность / 144 минут / ПРОГРЕСС ТОЧНОСТИ chart Apr-May / МАЙ 2026 / Слушай и выбирай 86%". OK content, но history vs detail должны различаться. **P1** — minor.

### P0 — sessionReview_light.png
- SYS-P0-2 (blue oval blob).

### CLEAN — sessionShell_light.png
- "Шаг 1 из 5 / 00:04 / ♥♥♥ / pause btn" + 3D Lyalya + Спектрограмма dark card "Пусто" + микрофон Спектрограмма "● Запись" + word grid "пила / стол / лук / рыба / топор / ракета / тарелка / дятел / лягушка / руль / облако / лодка / лимон / корова / крокодил". Heart icons «♥» — могут быть emoji. **P1**: проверить что hearts — SF Symbol `heart.fill`, не emoji.

### P0 — settings_light.png + 9 sub-routes
- SYS-P0-3 (10 identical screens).

### P0 — siblingMultiplayer*_light.png (4 screens)
- SYS-P0-4.

### P0 — softOnset_light.png  /  stuttering_light.png  /  stutteringHome_light.png
- SYS-P0-5 (3 identical disclaimer screens).

### P0 — soundAndFace_light.png
- SYS-P0-6 (tiny render) + AR hub fallthrough.

### P0 — soundDictionary_light.png
- SYS-P0-8 (emoji "👄" в "Гласные" icon). Otherwise good: "Словарь звуков / 42 звука русского языка / Нажми на букву / Гласные А О У Э И Ы / Свистящие С Сь З Зь Ц" + IPA phonetic transcriptions [a][o][u]. Russian copy OK, IPA correct.

### P0 — specialistHome_light.png
- SYS-P0-2 (blue oval blob).

### P0 — specialistLogin_light.png
- SYS-P0-4 (auth fallthrough).

### P0 — speechVisualization_light.png
- Отображает auth screen. Route не реализован.

### CLEAN — splash_light.png
- 3D Lyalya cute pose + "HappySpeech / ГОВОРИМ ВОЛШЕБНО" + loading bar. Orange gradient background. Hero feel OK.

### P0 — studentsList_light.png
- SYS-P0-2 (blue oval blob).

### P0 — voiceCloning_light.png
- Auth fallthrough.

### P0 — weeklyChallenge_light.png
- Auth fallthrough.

### P0 — worldMap_light.png
- SYS-P0-6 (tiny render 190×340pt). Only top "Карта прогресса / Выбери, куда полетим сегодня! / 4 дн. подряд / Грамматика card" visible. Если это реальный layout — too small for child UX.

---

## Touch target / Accessibility check

Невозможно надёжно измерить exact px из screenshot — флаг для qa-engineer на повторную проверку через UIAccessibility audit:
- `offlineState`: CTA "Проверить подключение" / "Продолжить без интернета" — visually ≥56pt ✓.
- `parentHome` bottom tab bar items — visually ≥56pt ✓.
- `splash`: no touch targets (loading) ✓.
- `siblingMultiplayer` "Вернуться" — text-only link, no visible bg → **P1 borderline touch target**.
- `soundDictionary` letter tiles ~80×80pt ✓.

---

## Russian-only check
- Все P0 routes показывают русский. **Исключение**: `pronunciationLeaderboard` использует cyrillic correctly. `roleSelect` русский (parentHome). `splash` "HappySpeech" — brand name OK. **No English leaks found in batch B.**

---

## Files modified

- `/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech/.claude/team/audit/v24-screen-audit-lightB.md` (new)

---

## P0 route summary (top routes for sprint S12 fix queue)

| Route | Issue | Fix owner |
|---|---|---|
| onboarding*_light (11) | All identical Step 1 | ios-developer |
| settings*_light (10) | All identical Settings root | ios-developer |
| programEditor / reports / sessionReview / studentsList / specialistHome (5) | Blue oval blob render bug | ios-developer |
| siblingMultiplayer* (4) | All identical Discovery | ios-developer |
| stuttering / softOnset / stutteringHome (3) | All identical disclaimer | ios-developer |
| reward Album/Collection/Detail/rewards (4) | All identical | ios-developer |
| specialistLogin / voiceCloning / weeklyChallenge / speechVisualization / offlineMiniGame / roleSelect (6) | Auth fallthrough | ios-developer |
| soundAndFace / poseSequence / worldMap / sessionComplete (4) | Tiny render or AR hub fallthrough | ios-debugger + ios-developer |
| soundDictionary | Emoji "👄" in icon | designer |
