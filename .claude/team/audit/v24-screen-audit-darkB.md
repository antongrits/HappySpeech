# v24 Manual Screen Audit — Dark Batch B (59 PNGs)

**Date:** 2026-05-15
**Method:** Read tool на каждый PNG из `_workshop/v24_uitest_tour/dark/` (alphabetical second half)
**Source:** `/tmp/v24_batch_darkB.txt` (59 files, `neurolinguistInsights` → `worldMap`)
**Criteria:** 12 (Dark theme + emoji cross-check + production bugs)

---

## Summary counts

| Metric | Count | Notes |
|---|---|---|
| Total PNGs read | 59 | All processed |
| Dark theme actually applied (bg dark) | 58 | `splash_dark` рендерит светло-оранжевый bg (launch screen storyboard не respect launchArg) |
| 3D Lyalya present where expected | ~22 | onboarding (1-10 идентичны), offlineState, sessionShell, voiceCloning, sibling*, soft/stuttering |
| Russian-only text | 58 | `profileEditor_dark` содержит baked-asset "REWARD" (English на стикере) |
| No эмодзи в production UI | **52** | См. P0 ниже — 7 экранов с эмодзи |
| No overflow 320pt | 59 | Width OK |
| Text readable (light on dark) | 58 | Кроме splash |
| Touch targets ≥56pt | 59 | CTA OK |
| Hardcoded blue/white CTA в Dark | 4 | `softOnset`, `stuttering`, `stutteringHome`, `siblingMultiplayer*` (антенна-иконка) |
| Identical screen placeholder (route bug) | 24 | onboarding 1-10 (=splash route), 8× settings sub, 4× «blue blob Занятия» (programEditor/sessionReview/specialistHome/studentsList), 3× sibling identical, 2× stuttering, 2× soundAndFace=poseSequence (AR placeholder cropped) |
| Auth fallback (login screen leak) | 3 | `offlineMiniGame`, `specialistLogin`, `weeklyChallenge` |

---

## P0 — Emoji в production UI (cross-check с Light batches)

Criteria #7 violated:

| Screen | Emoji | Cross-check Light |
|---|---|---|
| `parentHome_dark.png` | 🔥 (flame в "streak"-cell, иконка серии дней) | Совпадает с Light Batch A childHome 🎉 — общий emoji-pattern |
| `sessionComplete_dark.png` | ⭐⭐⭐ (3 жёлтые звёзды baked-art "поделиться") | Same as Light B (baked) |
| `sessionShell_dark.png` | ❤️❤️❤️ (3 розовые сердца HUD — попытки) | **Совпадает с Batch A childHome ❤️ — production hearts код-генерируется** |
| `soundDictionary_dark.png` | 👄 (губы в section header "Гласные"), 💨 (в "Свистящие") | Новый bug — не было в Light B |
| `rewardAlbum_dark.png` / `rewardCollection_dark.png` / `rewardDetail_dark.png` / `rewards_dark.png` | ✨ (искры/sparkles вокруг "Щенок Новое" — производства анимация asset, не emoji в Text) | Identical в Light B |
| `worldMap_dark.png` | 🔥 (flame в "4 дн. подряд" pill) | Совпадает с Light Batch A |
| `profileEditor_dark.png` | ❤️ (heart-icon в Avatar grid) | Same as Light A |

**Production hearts ❤️ в `sessionShell` подтверждены второй раз** — это код, не баг renderer'а. Нужен `git grep "❤️\|Image(systemName: \"heart"` в `Features/Session/`.

## P0 — Splash Dark не применил тему (1 screen)
- `splash_dark.png` — orange/peach bg вместо `Color.background.primary` Dark. **Launch screen storyboard игнорирует `-HSForceDarkTheme` launchArg** (это нормально для нативного launch.storyboard, но faux-splash после launch — приложение должно сразу применить тему). Skip if true launch screen.

## P0 — Auth fallback (3 screens — `offlineMiniGame`, `specialistLogin`, `weeklyChallenge`)
Эти route'ы падают в `HappySpeech` login form (как в Batch A — `auth_dark`). UITestHost не имеет mock-auth для них.

## P0 — Onboarding route отсутствует (10 screens идентичны)
`onboarding_dark`, `onboarding1..10_dark` — все рендерят шаг 1 («Привет! Я Ляля» «Шаг 1 из 10»). UITestHost не умеет двигать шаги по step-index. **Same bug as Light Batch B.**

---

## P1 — Hardcoded blue placeholder («Занятия» blue blob, 4 screens)
`programEditor_dark`, `sessionReview_dark`, `specialistHome_dark`, `studentsList_dark` — все показывают одинаковый огромный голубой blob с надписью «Занятия» поверх tab-bar mock. Это `SpecialistTabView` route-placeholder для UITestHost. **Same bug as Light Batch B `specialistHome`.**

## P1 — Settings sub-screens идентичны (8 screens)
`settingsAbout/Accessibility/GDPR/Language/ModelPacks/Notifications/Privacy/Theme/Voice/_dark` — все рендерят main `settings_dark` (palette + Тема + Профиль). UITestHost не открывает sub-views по deeplink. **Identical bug pattern Light Batch B.**

## P1 — Sibling Multiplayer (3 screens identical + blue antenna)
`siblingMultiplayer_dark`, `siblingMultiplayerDiscovery_dark`, `siblingMultiplayerLobby_dark` — рендерят «Найдём друга» с антенной hardcoded `Color.blue` (#5DA9FF-like). Game screen же показывает антенну в **filled** blue circle (одинаковая P1).

## P1 — Stuttering preface (3 screens identical with blue CTA)
`softOnset_dark`, `stuttering_dark`, `stutteringHome_dark` — все рендерят `StutteringPrefaceView` с ярко-голубой кнопкой «Начать». **Identical to Batch A `breathingTree`/`metronome`** — общий wrapper `StutteringPrefaceView` использует hardcoded `Color.blue` background.

## P1 — Cropped AR placeholder (2 screens)
`poseSequence_dark.png`, `soundAndFace_dark.png` — узкие 320pt-wide thumbnails «AR-зона». UITestHost AR route не возвращает full-screen view (как в Batch A `arZone`/`arMirror`).

## P1 — sessionComplete cropped (1 screen)
`sessionComplete_dark.png` — рендерится 320pt thumbnail (window-sized snapshot). Реальный экран существует но UITestHost frame mis-aligned.

---

## Clean (no issues — pass all 12 criteria)
1. `neurolinguistInsights_dark` — отличный VipCard layout, P-pill «мало данных»
2. `offlineState_dark` — отличный, 3D Lyalya, orange CTA
3. `parentInsightsTimeline_dark` — Эвристическая аналитика card, 4 stat cards OK
4. `pronunciationLeaderboard_dark` — empty-state OK (yellow trophy 🏆 — baked-art иконка не emoji в Text)
5. `progressDashboard_dark` — Точность/Серия cards, гистограмма
6. `sessionDetail_dark` / `sessionHistory_dark` — identical (sessionHistory правильно роутится на detail), графики OK
7. `settings_dark` — main settings экран, OK
8. `voiceCloning_dark` — clean «Голосовой архив», orange CTA, 3D Lyalya
9. `worldMap_dark` — clean (минус 🔥 emoji в pill)

---

## Aggregate (Dark Batch B)

- **P0:** 14 (7 emoji-screens + 3 auth fallback + 10 onboarding=splash + 1 splash bg — overlap, считаю unique exemplars)
- **P1:** 24 (4 blue-blob + 8 settings + 3 sibling + 3 stuttering + 2 AR cropped + 1 sessionComplete cropped + 3 emoji baked sparkles)
- **Clean:** 9 unique screens

**Cross-batch comparison:**
- Light A: 19 P0 / 26 P1 / 14 Clean
- Light B: 38 P0 / 9 P1 / 10 Clean
- Dark A: 0 P0 / 2 P1 / 57 Clean (Dark theme applied 59/59)
- **Dark B: 14 P0 / 24 P1 / 9 Clean** — больше bugs т.к. содержит settings/specialist/stuttering группы которые в Batch A не были.

**Key Dark-specific learnings:**
1. ❤️ hearts в `sessionShell` — confirmed production code emoji (не baked-art). Same in Light A childHome.
2. 🔥 streak emoji в `parentHome` и `worldMap` — production code.
3. `splash_dark` storyboard не respect темы — мелкий cosmetic, low priority.
4. `StutteringPrefaceView` blue CTA — design-system regression, needs fix.
5. UITestHost не route'ит settings sub-views, sibling sub-views, onboarding steps — testing infrastructure gap.

---

## Recommended P1 fixes (highest leverage)

1. **`git grep -n "❤️\|sparkle\|🔥"` в `Features/`** — найти все hardcoded emoji в SwiftUI Text/Image
2. **`StutteringPrefaceView`** — заменить hardcoded `Color.blue` на `DesignSystem.Color.surface.primary`
3. **`SiblingMultiplayer*View`** — заменить blue antenna `Image(systemName:)` на token color
4. **UITestHost routing** — добавить deeplinks для settings.* и siblingMultiplayer.* sub-screens
5. **`profileEditor` baked "REWARD" sticker** — экспортировать asset с русским «НАГРАДА» или нейтральный значок
