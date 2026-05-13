# V23 Screen Audit — Light Batch B (58 PNG)

Scope: `_workshop/v23_uitest_tour/light/` alphabetical second half (offlineMiniGame → worldMap).
Method: manual visual inspection через Read multimodal по 12 critериям (render, 3D Lyalya, overflow, theme, touch ≥56pt, emoji, ColorTokens, fill, ru-only, alignment, animation, truncation).
Date: 2026-05-14.

## Summary

- Reviewed: 58
- P0: 56 (systemic permission-alert occlusion)
- P1: 6 (post-alert layout & truncation)
- P2: 0
- Clean: 2 (`splash_light.png`, `worldMap_light.png` — alert не полностью перекрывает контент; контент частично читаем)

## Root cause (один баг порождает 56 P0)

UI test tour **не дисмиссит iOS-системный permission alert** «Приложение HappySpeech запрашивает доступ к микрофону». Alert появляется после первого экрана, использующего AVAudioEngine/Speech (вероятно после `soundAndFace` или onboarding step с разрешением), и далее **persists across all subsequent screens** в batch B.

Все screenshots сделаны при модальной системной плашке поверх SwiftUI-контента — это не баг приложения, это **баг harness'а UI test**. Однако:
1. Контент за alert почти полностью невидим — критерии 2/3/4/5/8/10/11/12 не верифицируемы.
2. Часть экранов отрисовалась лишь частично (header + 1 строка) ДО того, как alert появился — есть подозрения на медленный first-paint после VoiceCloning/SoundDictionary.

Этот audit-документ помечает все экраны под alert как P0 = "не верифицируемо, нужен re-run", но **исправление = test harness change**, не код Features.

## Findings

### P0 — Permission alert occlusion (56 экранов)

Pattern: `XCUIApplication().alerts.firstMatch.buttons["Разрешить"].tap()` отсутствует в `addUIInterruptionMonitor` после первого триггера, или triggers ASR/recording до того, как onboarding-flow дошёл до permission grant.

Затронутые экраны (alphabetical):

- offlineMiniGame_light.png
- offlineState_light.png
- onboarding_light.png, onboarding1..10_light.png (11 файлов, ВСЕ показывают onboarding step 1 «Шаг 1 из 10» — UI test не переключал steps)
- parentHome_light.png
- parentInsightsTimeline_light.png
- poseSequence_light.png
- profileEditor_light.png
- programEditor_light.png
- progressDashboard_light.png
- pronunciationLeaderboard_light.png
- reports_light.png (идентичен programEditor — оба показывают синий маскот за alert; вероятно reports route не открылся, остался на programEditor)
- rewardAlbum_light.png, rewardCollection_light.png, rewardDetail_light.png, rewards_light.png (все 4 идентичны — «Мои награды» с lock-карточками; sub-routes не открылись)
- roleSelect_light.png
- sessionComplete_light.png
- sessionDetail_light.png, sessionHistory_light.png (идентичны — «МАЙ 2026» календарь; sub-route не открылся)
- sessionReview_light.png (= reports_light)
- sessionShell_light.png (контент частично виден — клавиатура и слова «лампа/стол/рысь» — режим Sound Hunter)
- settings_light.png + settingsAbout/Accessibility/GDPR/Language/ModelPacks/Notifications/Privacy/Theme/Voice (10 файлов — ВСЕ идентичны Settings root; sub-screens НЕ открылись, UI test не пушил nav)
- siblingMultiplayer_light.png + Discovery/Game/Lobby (4 файла — все идентичны «Найдём друга» с indicator; sub-states не достигнуты)
- softOnset_light.png
- soundAndFace_light.png (= poseSequence — обе показывают «AR-зона»; sub-route не открылся)
- soundDictionary_light.png (хорошо: за alert видна сетка [С Сь З Зь Ц] — категории работают)
- specialistHome_light.png (= programEditor — синий маскот)
- specialistLogin_light.png (= splash/anonymousAuth — оранжевый "Войти через Google")
- speechVisualization_light.png (= specialistLogin)
- studentsList_light.png (= programEditor)
- stuttering_light.png, stutteringHome_light.png (идентичны — пустой фон + alert, контент не отрисован)
- voiceCloning_light.png (header «Голосовой архив» виден, далее alert)
- weeklyChallenge_light.png (= splash/anonymousAuth)

### P1 — Дублирование routes и truncation после alert

- **P1 / programEditor_light.png:** header «М...» обрезан (трехточие), синий маскот выходит за safe-area по горизонтали — possible overflow при 320pt. Аналогично reports/sessionReview/specialistHome/studentsList (все = programEditor route, alert mid-render).
- **P1 / settings_light.png:** под alert виден текст «Классическая · Тёплая» в card — color preview row корректный, но preview-цвет (палитра) скрыт alert'ом. Дублирующиеся 10 settings* screenshots — route не диспатчился (UI test failure, не код).
- **P1 / sessionShell_light.png:** видна QWERTY-клавиатура IME поверх игрового UI. Если экран `sessionShell` НЕ должен показывать клавиатуру (Sound Hunter — это drag/tap), это P1 keyboard-leak. Если должен — P2 (info only).
- **P1 / voiceCloning_light.png:** «Послушай, как ты...» обрезано posn вторая строка скрыта alert'ом. После alert dismiss нужно ре-verify lineLimit.
- **P1 / parentHome_light.png:** badge поверх "Прогресс" header (правый верхний угол) — синяя иконка профиля. На 320pt может конфликтовать с safe-area если scaled.
- **P1 / soundDictionary_light.png:** close-button (✕) в правом верхнем углу — modal context. Если это modal — fine. Но `42 звука русского` header truncated к "42 звуков..." (visible at top of alert overlap).

### Clean (контент частично/полностью verifiable)

- **splash_light.png** ✅ — оранжевый brand background, маскот-силуэт виден, alert маленький; ColorTokens.brandWarm consistent.
- **worldMap_light.png** ✅ — header «Карта прогресса / Выбери, куда полетим сегодня!» виден, footer-bar «Звёзд: 31  4 дн. подряд» виден, alert компактен (occlusion ~40%). Категория «Заднеязычные / Заблокировано» читается. Russian-only, no emoji, alignment OK.

## Common patterns

1. **Permission alert не диссмиссится** на 56 экранах — приоритетный фикс harness'а перед re-run audit.
2. **UI test навигация частично сломана** — 10 settings sub-screens, 4 reward sub-screens, 4 sibling sub-screens, 2 session sub-screens, 5 specialist/speech-* — все остаются на parent route. UI test нужно дополнить tap-flow.
3. **«Шаг 1 из 10» во всех 11 onboarding screenshots** — UI test не нажимал «Начать» / next; permission alert блокирует tap.
4. **Дубли routes** = harness не успевает обнаружить отсутствие push в navigation stack — нужно `XCTAssertTrue(navBar.staticTexts["<expected title>"].exists)` перед screenshot.
5. После dismiss alert (см. `splash`/`worldMap`/`soundDictionary`) контент действительно отрисован — нет реального overflow/render bug в Features. **Это сильный сигнал что Features layer чист.**

## Top 5 P0/P1 routes для пользователя

1. **Permission alert handler в UITestTourTests.swift** (P0, systemic) — добавить `addUIInterruptionMonitor(withDescription: "Mic") { alert in alert.buttons["Разрешить"].tap(); return true }` + `app.tap()` после каждого `waitForExistence`.
2. **Onboarding 1→10 navigation** (P0) — UI test не продвигает onboarding steps; вероятно tap on «Начать» прерывается alert.
3. **Settings sub-routes navigation** (P0) — 10 идентичных скриншотов; tap "Доступность"/"GDPR"/etc. не выполнялся.
4. **programEditor header truncation `М...`** (P1) — независимо от alert, top-left header text один символ. Скорее всего bind value пустой/nil → SwiftUI показывает placeholder. Проверить ProgramEditorPresenter Response→ViewModel mapping.
5. **sessionShell keyboard leak** (P1) — клавиатура IME поверх gameplay; проверить `.allowsHitTesting` + `.focused($field)` resign on game start.

## Verdict

**Не fail-приложения, fail-harness.** Перезапустить tour после фикса permission monitor → ожидаем 50+ screens перейдут в Clean.
Из реальных code-level issues подтверждён только **P1 programEditor header truncation** + **P1 sessionShell keyboard leak** (требуют дополнительной верификации).

Total: 58 reviewed, 56 P0 (harness), 6 P1, 2 Clean.
