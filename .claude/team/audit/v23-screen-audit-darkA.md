# V23 Screen Audit — Dark Batch A (58 PNG)

**Дата:** 2026-05-14
**Reviewer:** CTO (Claude Opus 4.7 1M)
**Source:** `_workshop/v23_uitest_tour/dark/` (alphabetical first half: anonymousAuth → mimicLyalya)
**Device:** iPhone SE 3rd gen iOS 26.5

## Summary

- Reviewed: 58
- P0: 14
- P1: 35
- P2: 4
- Clean: 5

## Top-level finding (SYSTEM-WIDE P0)

**ВСЕ 58 Dark screenshots отображают Light theme background.**
ColorTokens.swift не реагирует на `colorScheme == .dark`, либо `.preferredColorScheme(.dark)` не пробрасывается из UI test launch args. Это блокирующий баг для Dark theme support — Plan v23 Block 1.3 цель «manual visual review Dark» сейчас по сути ревью Light theme.

После фикса bg-токенов нужен **полный rerun** Dark tour. Финдинги ниже — это вторичные дефекты, ОБНАРУЖЕННЫЕ ПОПУТНО (debug placeholders, эмодзи в UI, alert «Заголовок/Ошибка», routing fallbacks).

---

## Findings — P0 (блокирующие)

### P0-DARK-001 — System-wide Dark theme not applied (58/58)
- **Files:** все 58 PNG batch A
- **Issue:** background = peach/cream (Light), text = dark-on-light. Никакой Dark variant ColorTokens не активируется.
- **Action:** проверить `ColorTokens.background` адаптивный init `Color(light:dark:)`, наличие `.preferredColorScheme(.dark)` в HappySpeechUITestsLaunchArguments, или хардкод `Color.white` в Background компонентах.

### P0 — authForgotPassword_dark.png
- Заголовок «Забыли пароль?» — light gray on cream, contrast ~2:1, ниже WCAG AA 4.5:1.
- Кнопка submit полностью invisible (cream-on-cream). Touch target есть, но пользователь не видит CTA.

### P0 — homeTasks_dark.png
- Resolution artifact: видно сильно уменьшенный экран (~50% scale). Возможно UI test snapshot не дождался layout. Подозрение на race.
- В badge «Просрочено ❗» — эмодзи в UI (violation rule «No эмодзи в UI»).

### P0 — lessonArticulationImitation_dark.png
- Debug placeholder: «По умолчанию» / «Формат» / «Заголовок» / «Кнопка». Это default SwiftUI Preview-style debug строки. Локализация отсутствует — String Catalog пустой для этого экрана.

### P0 — lessonBingo_dark.png
- Modal alert «Заголовок / Ошибка / OK» — debug LocalizedError без RU сообщения. Альерт показан **поверх** main lesson view → блокирует interaction.

### P0 — lessonDragAndMatch_dark.png
- Overlap: «Раунд 1 из 3» накладывается на «учаем звук 0 / 6» (текст «изучаем звук»). Layered Z-order broken.

### P0 — lessonMinimalPairs_dark.png
- Same «Заголовок / Ошибка / OK» alert P0.

### P0 — lessonNarrativeQuest_dark.png
- В заголовке rendered «**troph…**» (truncated EN key). Это `String(localized: "trophy_quest_title")` без RU перевода → ключ напечатан. Грубейший localization leak.

### P0 — lessonPlayer_dark.png
- Same «Заголовок / Ошибка / OK» alert P0.

### P0 — lessonSoundHunter_dark.png
- Same «Заголовок / Ошибка / OK» alert P0.

### P0 — logopedistChat_dark.png
- Routing fallback → screen рендерит auth_dark вместо логопеда. Feature не реализована / роутер падает на default auth.

### P0 — mascot3D_dark.png
- Routing fallback → AR-zone welcome вместо 3D mascot demo. RealityKit/USDZ загрузка не вызвана.

### P0 — dialectAdaptation_dark.png
- Routing fallback → auth_dark. Diallect adaptation feature не реализована.

### P0 — celebrationOverlay_dark.png
- «Очки» текст gray-on-cream, contrast ниже AA. Number («0» вероятно) и shareable counter — invisible. CTA «Поделиться» с эмодзи 🎉 в логотипе достижения.

---

## Findings — P1

### P1 — anonymousAuth_dark.png
- Light theme leak (P0-DARK-001 root cause). Кнопка «Войти» disabled / низкого contrast (cream).

### P1 — arFaceFilter_dark.png
- Идентично anonymousAuth — routing/fallback на auth, не AR face filter feature.

### P1 — arMirror_dark.png, arZone_dark.png, breathingAR_dark.png, butterflyCatch_dark.png, mimicLyalya_dark.png
- Все рендерят **один и тот же** AR-zone welcome (фиолетовая иллюстрация, «AR-маски» card). UI tests дёргают разные роуты, но все падают на AR-zone home. Это duplicate content — нужно либо реализовать саб-фичи, либо помечать в plan «AR_feature_not_implemented».

### P1 — arStoryQuest_dark.png
- AR-zone welcome повторно (см. выше).

### P1 — authSignUp_dark.png
- Light theme. «Создать аккаунт» CTA invisible (cream-on-cream).

### P1 — authVerifyEmail_dark.png
- Light theme. «Мы отправили письмо на» — конец строки пуст, email-адрес не подставлен (`%@` placeholder lost).

### P1 — auth_dark.png
- Light theme.

### P1 — breathingTree_dark.png
- Pure white bg (Light forced). Иллюстрация «Перед началом — упражнения для домашней практики». Header text good, но CTA «Начать» — bright blue button (`SystemBlue`?) — нарушает DesignSystem Coral primary токен.

### P1 — childHome_dark.png, childHome2_dark.png
- Эмодзи 🥳 («новое достижение») и 🔥 («5 дней подряд») в карточках. Violation rule «No эмодзи в UI».
- Light theme.

### P1 — culturalContent_dark.png
- Routing → auth fallback. Feature не реализована.

### P1 — dailyChallenge_dark.png
- Light theme. Иначе ОК — лента «Цель дня» отрисована корректно. Кнопка «Поделиться» CTA Coral.

### P1 — dailyStreak_dark.png
- Light theme. «Мои награды» tabs OK.

### P1 — demoMode_dark.png, demoStep1_dark.png, demoStep5_dark.png, demoStep10_dark.png, demoStep15_dark.png
- **Все 5 идентичны** — «Шаг 1 из 15» во всех (counter не двигается между snapshot). UI test не нажимает «Далее». Также Light theme.

### P1 — familyAchievements_dark.png
- Loader spinner, пустой контент после загрузки. Tab «Достижения» selected, body empty. Empty state без иллюстрации/CTA.

### P1 — familyAwardsCabinet_dark.png
- Empty showcase. Иллюстрации трофея = серый icon (Light theme). «Пока без наград» empty state OK.

### P1 — familyCalendar_dark.png
- Эмодзи 🔥 в card «Миша 1д». Также «Заголовок» (debug placeholder) ниже календаря — text не локализован.

### P1 — familyHome_dark.png
- Эмодзи 🔥 («5 дн.»).
- Дублирующиеся CTA: «Играть вдвоём» × 2 (game controller + person.2). Нужны разные labels («Локально» vs «FaceTime»).

### P1 — familyLeaderboard_dark.png
- Light theme. Tabs «Эта неделя / Прошлая / Всё время» OK.
- Empty state с иконкой персон — OK.

### P1 — familyVoice_dark.png
- Light theme. Микрофон CTA = bright green (SystemGreen) — нарушает DesignSystem coral/teal.

### P1 — fluencyDiaryHome_dark.png, fluencyDiary_dark.png
- Идентичны. Empty state «Записей ещё нет», иллюстрация-Ляля. Light theme.

### P1 — grammarGame_dark.png, guidedTour_dark.png
- Routing → auth_dark fallback.

### P1 — helpCenter_dark.png
- Light theme. Контент OK. Эмодзи нет.

### P1 — holdThePose_dark.png
- Routing → AR-zone fallback (см. P1 кластер AR).

### P1 — lessonARActivity_dark.png
- AR-zone fallback внутри урока. Header «AR-зона / Целевой звук: Р / Готово» — функционально ОК, но без AR rendering.

### P1 — lessonBreathingExercise_dark.png
- Dimmed bg overlay (modal «Пора отдохнуть»). Text contrast ОК. Light theme P1.

### P1 — lessonListenAndChoose_dark.png
- Resolution downscale (как homeTasks). UI test snapshot слишком ранний.

### P1 — lessonMemory_dark.png
- Карточки-cover с «?» — приемлемо как placeholder pattern. Light theme.

### P1 — lessonPuzzleReveal_dark.png
- Light theme. Контент OK. «ракета» tile + 9 ячеек coral. CTA «Произнеси слово с буквой Р» — text contrast OK.

### P1 — lessonRepeatAfterModel_dark.png
- В badge «REWARD» — EN-key leak внутри иконки-награды. Должно быть «НАГРАДА» или вообще без подписи.

### P1 — lessonRhythm_dark.png
- Светло-зелёный header bg вместо peach. Inconsistent с другими уроками — урок «Повтори ритм» имеет свой gradient. Light theme P1.

### P1 — lessonSorting_dark.png
- Truncation: «Разложи слова по количеству сло…» — нужно `lineLimit(nil)` + `.minimumScaleFactor(0.85)`.

### P1 — lessonStoryCompletion_dark.png
- Light theme. Иначе ОК.

### P1 — lessonVisualAcoustic_dark.png
- Content mismatch: «Как звучит тигр?» / «Найди слово со звуком Р» → но картинка = красное **сердце** 💖. Lottie/Rive asset перепутан. P1.

### P1 — metronome_dark.png
- Routing fallback на breathingTree «Перед началом». Metronome feature не реализован.

---

## Findings — P2

### P2 — celebrationOverlay_dark.png — confetti emoji «🎉» в text «новое достижение» (если это card label).
### P2 — childHome_dark.png — 14 мая дата ОК, но 14 мая = текущая дата теста → корректно.
### P2 — familyHome_dark.png — gear icon в SF Symbol blue = OK, но синий не из DesignSystem coral palette.
### P2 — lessonNarrativeQuest_dark.png — Ляля avatar в чат-bubble крупная (40pt) — может быть adjusted.

---

## Clean (Light theme reservation: исключая системный P0-DARK-001)

Эти скрины **функционально работают**, hardcoded debug-текстов нет, нет эмодзи в основном UI, нет critical alerts/overlaps:

- dailyChallenge_dark.png ✅
- dailyStreak_dark.png ✅
- familyLeaderboard_dark.png ✅
- helpCenter_dark.png ✅
- lessonStoryCompletion_dark.png ✅

(Все 5 всё равно с light bg — будут revalidated после фикса P0-DARK-001.)

---

## Top 5 Dark-specific issues

1. **58/58 screens рендерят Light theme** — system-wide ColorTokens.dark не применяется или `.preferredColorScheme(.dark)` отсутствует в UI test launch args. Это **P0 root cause**, после фикса ВЕСЬ Dark batch требует rerun + повторного аудита.
2. **«Заголовок / Ошибка / OK» modal alert** в 4-5 lesson screens (Bingo, MinimalPairs, Player, SoundHunter) — debug `LocalizedError` без RU описания, blocking interaction.
3. **Debug placeholders в lessonArticulationImitation** («По умолчанию», «Кнопка», «Формат», «Заголовок») — String Catalog отсутствует для этого экрана.
4. **EN-key localization leaks**: «troph…» (lessonNarrativeQuest), «REWARD» badge (lessonRepeatAfterModel).
5. **Routing fallbacks → auth_dark или AR-zone** для 10+ скринов (logopedistChat, dialectAdaptation, mascot3D, culturalContent, grammarGame, guidedTour, holdThePose, metronome, arMirror, arStoryQuest, breathingAR, butterflyCatch, mimicLyalya). Эти фичи либо не реализованы, либо роутер пробивается на default. Plan v23 должен честно пометить их «not implemented» или реализовать.

## Common patterns

- **AR-zone welcome** — единственный AR экран, все AR-роуты падают на него (5 скринов идентичны).
- **Auth fallback** — все не-реализованные «авторизованные» фичи фоллбэчат на auth (~6 скринов).
- **«Заголовок/Ошибка/OK» modal** — типовой `Alert(title: String(localized: "...title"), ...)` без локализации (4 экрана).
- **Эмодзи в UI**: 🥳 🔥 ❗ 🎉 встречаются в childHome, family*, celebrationOverlay, homeTasks. Должно быть SF Symbols + DesignSystem coral.
- **Hardcoded blue/green CTA** (breathingTree «Начать», familyVoice mic) — игнорируют DesignSystem coral.

## Recommendations (для CTO следующих спринтов)

- **Block 1.3 v23 итог:** аудит проведён, но dark theme невозможно ревьюить пока root cause P0-DARK-001 не исправлен. Передать `ios-developer` на P0 fix DesignSystem ColorTokens + UI tests launch args.
- После фикса — повторный screenshot tour + второй прогон этого аудита.
- Plan v23 Block 1.4 (если есть) должен подхватить найденные P0 фиксы (alerts, placeholders, EN-key leaks).
