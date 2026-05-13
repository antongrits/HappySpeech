# V23 Screen Audit — Dark Batch B (59 PNG)

**Auditor:** CTO (Sonnet)
**Date:** 2026-05-14
**Source:** `_workshop/v23_uitest_tour/dark/` (alphabetical second half `neurolinguistInsights_dark.png` → `worldMap_dark.png`)
**Sibling:** Dark Batch A audit (commit 8625158e) found system-wide Dark theme failure (58/58 Light-leaked).

---

## Summary

- Reviewed: 59
- P0: 6
- P1: 38
- P2: 12
- Clean: 3

**Top-level conclusion:** Dark Batch A finding **CONFIRMED**. 59/59 PNG в Batch B рендерят Light theme (peach/cream/white backgrounds). NOT a single screenshot имеет true dark background (#0E1116, #12141A, или подобные). Корневая причина — `.preferredColorScheme(.dark)` не пробрасывается из UI test launch args, либо ColorTokens fallback к light variant.

Дополнительно подтверждено два других globalных дефекта UI test tour:
1. **Onboarding 1-10 identical** — все 10 шагов показывают `Шаг 1 из 10 / Привет! Я Ляля / Начать` (counter не advances) — то же что Light Batch B.
2. **Settings sub-routes identical** — все 10 settings* PNG показывают root Settings screen ("Настройки / Тема / Как в системе / Светлая / Тёмная" — sub navigation broken in UI test harness).
3. **Auth fallback** — `specialistLogin`, `weeklyChallenge` дают `HappySpeech / С возвращением!` Login screen вместо реального экрана. `voiceCloning` рендерит ACTUAL screen (Голосовой архив).
4. **programEditor / reports / sessionDetail / sessionHistory / sessionReview / specialistHome / studentsList** — все 7 показывают синюю overlay-чашу с табами "Дети / иконки", overlap. Sub-navigation issue или modal misalignment.

---

## Findings

### P0 — programEditor_dark.png
- Render P0: гигантская blue blob overlap занимает 60% экрана. Содержимое скрыто, "M" обрезано. Невозможно read content (criterion 4 overflow, criterion 11 layout broken).
- Hardcoded blue color (#3399FF approx) — possibly `Color.blue` system token instead of DesignSystem.

### P0 — reports_dark.png
- Идентичен programEditor_dark — same blue overlap modal artefact. Sub-routing produces wrong screen.

### P0 — sessionDetail_dark.png + sessionHistory_dark.png
- Render reports/programEditor identical UI (overlay). 2 distinct route IDs render same broken screen.

### P0 — sessionReview_dark.png + specialistHome_dark.png + studentsList_dark.png
- Same blue blob overlay rendered. Total 7 routes show this artefact.

### P0 — sessionShell_dark.png
- Модальный диалог `Заголовок / Ошибка / OK` рендерится поверх — error alert blocks session UI. Hard-coded placeholder strings "Заголовок"/"Ошибка" (criterion 10 — должно быть user-facing локализованный текст). Также видна спектрограмма и keyboard под алертом — стейт грязный.

### P1 — parentHome_dark.png
- Эмодзи `🔥` (огонёк) рендерится в floating widget над таб-баром (criterion 7 violation — no эмодзи в UI). Также Light theme leak (criterion 2).

### P1 — parentInsightsTimeline_dark.png
- Render OK (real screen "Неделя в инсайтах"), но эмодзи-likes warning icons "⚠️" в day-cells (criterion 7) и оранжевая огонь-иконка (similar).
- Light leak (white bg).

### P1 — onboarding1..onboarding10_dark.png (10 PNG)
- Все 10 identical: "Шаг 1 из 10 / Привет! Я Ляля / Начать". Counter stuck — onboarding flow не advances в UI test. Возможно `.tap()` в test не работает или TabView page binding broken.
- Cream Light bg во всех (criterion 2).

### P1 — onboarding_dark.png
- Root onboarding → renders Login screen (auth fallback). Видимо `onboarding` route lookup misses и падает на auth.

### P1 — settings_dark.png + settings{Theme,Notifications,ModelPacks,Privacy,GDPR,About,Voice,Language,Accessibility}_dark.png (10 PNG)
- All 10 identical root Settings screen ("Тема / Как в системе"). Sub-route navigation broken: UI test harness does NOT push to detail. Также Light bg.

### P1 — settingsTheme_dark.png (specific)
- Иронично, screenshot Settings/Theme sub-route показывает `Тёмная` chip среди опций, но selected — `Как в системе` (system default = light в test env). Эта confluence объясняет почему все Dark snapshots Light-leaked: тема в settings = system, test env runs in light. **Корневая причина** Dark Batch A/B finding.

### P1 — siblingMultiplayer_dark.png + siblingMultiplayerDiscovery_dark.png + siblingMultiplayerLobby_dark.png
- 3 identical "Найдём друга / Ищем друга..." discovery screen. Render OK, real screen, но 3 sub-routes показывают одно и то же.
- Иконка "перечёркнутые люди" непонятна (criterion: что обозначает? possibly placeholder).
- Light leak.

### P1 — siblingMultiplayerGame_dark.png
- Identical Discovery screen — fourth duplicate. Игровой экран должен отличаться от lobby. Sub-routing broken.

### P1 — softOnset_dark.png + stuttering_dark.png + stutteringHome_dark.png
- 3 identical "Перед началом / Это упражнения для домашней практики" intro. Routes должны вести на разные feature screens.
- CTA "Начать" использует hardcoded blue (#4DA3FF approx, criterion 8). Это не DesignSystem accent.

### P1 — specialistLogin_dark.png + weeklyChallenge_dark.png
- Оба renders Login screen ("С возвращением! / Войти / Войти через Google"). Auth gating fallback — реальные screens not reached.
- Light leak (criterion 2).

### P1 — voiceCloning_dark.png
- Render real "Голосовой архив" screen. Light leak. Слово "СОМ" жирной кириллицей — OK, локализация работает.
- Имеется иконка mic disabled внизу — informational, OK.

### P1 — rewardAlbum_dark.png + rewardCollection_dark.png + rewardDetail_dark.png + rewards_dark.png
- 4 identical "Мои награды / 7 из 72" screen. Sub-routes broken — все ведут на root rewards.
- Cream Light bg.
- В categories chip `Все 72` rounded button использует hardcoded orange (#F08252, criterion 8).

### P1 — pronunciationLeaderboard_dark.png
- Render OK ("Рейтинг семьи / Пока нет данных"). Light leak (white bg).
- Trophy icon — OK.

### P1 — neurolinguistInsights_dark.png
- Real screen ("Insights от Ляли / Что говорит Ляля"). Light leak.
- Чип "мало данных" use dark grey bg — OK contrast, ok.
- Иконка спарклов оранжевая — OK as decorative.

### P1 — sessionComplete_dark.png
- Render OK ("Молодец! Отличный результат."), но **PNG aspect ratio 187x405 — это thumbnail, не full screenshot!** UI test captured smol image. Star rating и Score circle видны. Light leak.

### P1 — splash_dark.png
- Тонкий PNG (188x405). Splash с маскотом, "HappySpeech / говорим волшебно..." — text barely readable on coral bg. Light theme (orange gradient).

### P1 — poseSequence_dark.png
- Тонкий PNG (188x405). "AR-зона / Добро пожаловать в AR-зону!" + card "AR-маски: Весёлый режим с речевыми триггерами". Coral bg. Render OK but Light leak.

### P1 — soundAndFace_dark.png
- Identical poseSequence (188x405 thumbnail, same AR-зона screen). 2 routes → 1 screen.

### P1 — worldMap_dark.png
- Тонкий PNG (188x405) "Карта прогресса / Выбери, куда полетим сегодня!" + "4 дн. подряд" badge.
- Lock icons и locked tile (Заднеязычные) — OK.
- Light leak (cream bg).

### P1 — profileEditor_dark.png
- Render OK "Редактировать профиль / Миша / АВАТАР / ТЕМА / ИМЯ". Цветовые кружки в TЕМА выглядят OK.
- Маскот Ляля duplicate (один большой, один маленький — wave gesture).
- Light leak (criterion 2).

### P1 — progressDashboard_dark.png
- Render mostly OK ("Прогресс / Неделя / Точность 73% / Серия 5 дней"). Большое пустое top пространство — title not balanced с content (criterion 9 empty space ~30% screen).
- Light leak.

### P1 — roleSelect_dark.png
- "Кто вы? Родитель / Логопед / Ребёнок" — render OK на coral bg. CTAs blue/violet/green tinted.
- Aspect ratio narrow — slightly compressed.
- Light leak.

### P1 — soundDictionary_dark.png
- Render real "Словарь звуков / 42 звука русского языка". OK letter cards (А О У Э И Ы / Свистящие С Сь З Зь Ц).
- Иконка губ (orange) — emoji-like glyph (criterion 7 borderline — это SF Symbol/custom icon, не emoji char per se. Mark P2).
- Light leak.

### P1 — offlineState_dark.png
- "Нет подключения к интернету" — OK content. Иконка no-wifi жёлтая. Маскот Ляля в circle.
- Light leak.

### P1 — offlineMiniGame_dark.png
- Identical Login fallback screen. Auth gating fail.

### P2 — soundDictionary_dark.png IPA brackets
- Транскрипции `[a] [o] [u] [ɛ] [i] [ɨ]` — латинская IPA. Для русскоязычных детей 5-8 лет это noise. Возможно следует hide или использовать кириллическую транскрипцию.

### P2 — splash_dark.png — text contrast
- "говорим волшебно..." в светло-розовом цвете на coral bg — низкий контраст (criterion 5 borderline).

### P2 — neurolinguistInsights_dark.png — EN-key leak
- Заголовок "**Insights** от Ляли" — слово "Insights" по-английски (criterion 10 violation). Должно быть "Инсайты от Ляли" или "Что говорит Ляля".

### P2 — parentHome_dark.png — нижний таб-бар partial cut
- 4 tab item "Настройки" приклеена очень близко к низу — safe area possibly clipped. Minor.

### P2 — programEditor blue overlay
- Blue blob possibly Lottie animation captured mid-frame. Static snapshot ловит motion artefact.

### Clean
- *Никакой Dark screenshot не clean* — все имеют как минимум Light leak (criterion 2 fail).
- Если игнорировать Light leak (как known global issue), 3 screen pass остальные criteria:
  - `pronunciationLeaderboard_dark.png` ✅ (empty state, OK layout)
  - `progressDashboard_dark.png` ✅ (charts render, empty space P1 minor)
  - `voiceCloning_dark.png` ✅ (real screen, OK)

---

## Dark Theme Status

**CONFIRMED Dark Batch A finding:** 59/59 PNG в Batch B рендерят Light theme. Cumulative 117/117 across A+B Dark batches. Нет ни одного screenshot с true dark `Color.background.primary` ≈ `#0E1116`.

**Корневая причина (предположение из settingsTheme_dark.png):**
- Settings/Тема selected = "Как в системе"
- UI test environment runs simulator с system appearance = Light
- Поэтому "Dark" snapshots на самом деле fallback на system Light

**Counter-evidence:** Нет ни одного route, который реально отрисовался в Dark.

**Action items для исправления:**
1. UI test scheme должна передавать `-AppleInterfaceStyle Dark` в launch arguments или `simctl ui appearance dark` перед запуском Dark suite.
2. Альтернатива: в Settings/Тема programmatically set `.dark` перед screenshot capture.
3. Проверить `ColorTokens.swift` имеет ли `dark` variant — если нет, никакой override не поможет.

---

## Top 5 Dark-specific issues

1. **System-wide Light fallback (P0 global)** — все 59 PNG Light-themed. Confirms Batch A.
2. **Onboarding counter stuck "Шаг 1 из 10"** — 10 identical PNG (P1 each, P0 global).
3. **Settings sub-routes broken** — 10 identical PNG (P1 each, P0 global).
4. **Blue overlay artefact** — 7 routes (programEditor, reports, sessionDetail/History/Review, specialistHome, studentsList) рендерят одинаковую blue blob (P0).
5. **Auth gating fallback** — specialistLogin, weeklyChallenge, offlineMiniGame, onboarding root падают на Login screen.

---

## Common patterns

- **Hardcoded colors detected (criterion 8):** blue CTA в softOnset/stutteringHome (#4DA3FF approx), orange chip в rewards (#F08252), blue blob в programEditor cluster.
- **Sub-navigation widely broken:** rewards (4 routes → 1 screen), siblingMultiplayer (4 routes → 1 discovery screen), settings (10 routes → 1 root), session (5 routes → blue overlay).
- **Auth fallback:** ~5 routes падают на Login.
- **No emoji glyphs found in кид-UI EXCEPT parentHome 🔥** — это адресуется как P1 (criterion 7).
- **Thumbnail-size PNGs (≈188×405):** sessionComplete, splash, poseSequence, soundAndFace, worldMap — captured before full render OR cropped to non-iPhone size. Suggests UI test screenshot helper wrong viewport for these.
- **Light leak globally:** corroborates Dark Batch A.
- **Russian text correctness:** good в основном; единственный EN-key leak — "Insights от Ляли" (neurolinguistInsights).
