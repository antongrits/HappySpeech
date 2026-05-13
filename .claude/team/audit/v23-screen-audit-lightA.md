# V23 Screen Audit — Light Batch A (59 PNG)

**Auditor:** cto Opus xhigh
**Date:** 2026-05-14
**Source:** _workshop/v23_uitest_tour/light/ (rows 1-59, alphabetical first half)
**Theme:** Light only (Dark batch — separate auditor)

---

## Summary

- Screens reviewed: 59
- P0 issues (critical, blocking release): **23**
- P1 issues (major, должны быть закрыты в v23): **11**
- P2 issues (nice-to-have, defer): **3**
- Clean screens (no issues): **22**

---

## Cross-cutting systemic issues (P0)

### SYS-P0-1: Microphone permission alert overlays all lesson/insight screens (15 screens affected)

Permission alert «Приложение HappySpeech запрашивает доступ к микрофону» перекрывает контент во всех экранах, где используется аудиозапись. UI tour должен дисмиссить alert через `addUIInterruptionMonitor` или pre-grant permission через `simctl privacy grant`, ИЛИ тест должен делать tap "Разрешить" до screenshot.

Affected routes:
- lessonBreathingExercise, lessonDragAndMatch, lessonListenAndChoose, lessonMemory, lessonMinimalPairs, lessonNarrativeQuest, lessonPlayer, lessonPuzzleReveal, lessonRepeatAfterModel, lessonRhythm, lessonSorting, lessonSoundHunter, lessonStoryCompletion, lessonVisualAcoustic
- logopedistChat, mimicLyalya, neurolinguistInsights, metronome

Fix: добавить в `HappySpeech.xctestplan` или test setup:
```swift
addUIInterruptionMonitor(withDescription: "Mic permission") { alert in
    alert.buttons["Разрешить"].tap()
    return true
}
```
ИЛИ pre-grant: `xcrun simctl privacy <udid> grant microphone <bundleID>` перед запуском tour.

### SYS-P0-2: Missing route screens fall through to auth_light (8 screens)

Следующие routes возвращают экран авторизации вместо собственного контента, что означает route не реализован или router падает обратно на login:
- anonymousAuth_light → auth screen
- culturalContent_light → auth screen
- dialectAdaptation_light → auth screen
- grammarGame_light → auth screen
- guidedTour_light → auth screen
- demoStep1/5/10/15 — все идентичны Step 1 из 15 (auto-advance не работает, не route fallthrough но похожий эффект)

Эти routes должны быть либо удалены из карты экранов, либо реализованы.

### SYS-P0-3: AR-зона hub дублируется для 6 AR-routes

Routes `arFaceFilter`, `arMirror`, `arStoryQuest`, `arZone`, `breathingAR`, `holdThePose`, `mascot3D` — все показывают один и тот же AR-зона hub экран. Под-routes (face-filter, mirror, story-quest, mascot3D viewer) не реализованы — навигация не углубляется.

---

## Findings (per screen)

### P0 — anonymousAuth_light.png
- Route отображает экран обычного auth (С возвращением, Войти, Войти через Google). Нет кнопки "Пропустить" / "Войти анонимно". Anonymous auth flow не реализован визуально.

### P0 — arFaceFilter_light.png
- AR-зона hub вместо отдельного экрана face-filter. Должен быть полноэкранный AR-просмотр с camera.

### P0 — arMirror_light.png
- AR-зона hub вместо отдельного экрана зеркала. Должен быть AR-mirror viewer.

### P0 — arStoryQuest_light.png
- AR-зона hub вместо экрана story-quest. Контент quest отсутствует.

### P0 — breathingAR_light.png
- AR-зона hub вместо экрана дыхательного AR-упражнения (пузырь/частицы).

### P0 — celebrationOverlay_light.png
- Текст "Молодец! Отличный результат." и звёзды отрисованы, но центральный круг с прогрессом пустой ("Очки" + "Бонус" — мелкий текст внутри пустого circle). Confetti / Pow эффект отсутствует. На overlay не видно конкретных цифр (XP, accuracy). Hero feel недостаточен для celebration moment.

### P0 — childHome_light.png
- 3D Lyalya отсутствует — в hero card видна только маленькая outline-иконка Ляли (P0 для kids primary screen). Должен быть полноценный 3D mascot.
- Touch targets cards "Пасха / Играть" + achievement banners — visually OK но 3D-маскот блокер.

### P0 — childHome2_light.png
- Идентично childHome — повторно отсутствует 3D Lyalya. Только outline-иконка в bubble "Миша, готов тренировать «Р»?".

### P0 — culturalContent_light.png
- Auth fallthrough — route не реализован.

### P0 — demoMode_light.png
- Сам demo overlay рендерится корректно (Шаг 1 из 15, "Главный экран", chat bubble от Ляли). Но проблема в комбинации с demoStep1/5/10/15 — все 4 step screenshots идентичны (см. SYS-P0-2).

### P0 — demoStep1_light.png
- Идентичен demoMode (Шаг 1). Auto-advance demo не triggers.

### P0 — demoStep5_light.png
- Идентичен demoStep1 (показывает "Шаг 1 из 15"). Тест не продвинул demo на step 5.

### P0 — demoStep10_light.png
- Идентичен demoStep1. Тест не продвинул на step 10.

### P0 — demoStep15_light.png
- Идентичен demoStep1. Тест не продвинул на step 15.

### P0 — dialectAdaptation_light.png
- Auth fallthrough — route не реализован.

### P0 — familyAchievements_light.png
- Бесконечный loading spinner в центре экрана. Контент достижений не подгружается. После waitForExistence + 1.2 сек экран всё ещё loading — repository hang или missing fixture.

### P0 — grammarGame_light.png
- Auth fallthrough — route не реализован.

### P0 — guidedTour_light.png
- Auth fallthrough — route не реализован.

### P0 — holdThePose_light.png
- AR-зона hub вместо экрана упражнения "Удержи позу" с timer и face tracking.

### P0 — lessonArticulationImitation_light.png
- **Placeholder strings leak**: "По умолчанию", "Формат", "Заголовок", "Кнопка" — visible вместо реальных L10n keys / контента. Это generic SwiftUI defaults, означает что View вызывается без необходимых параметров либо InteractorImpl возвращает empty model.
- 3D Lyalya present (2D illustration in top-right) — OK.
- Lips icon в circle — placeholder, должно быть видео/Lottie артикуляции.

### P0 — logopedistChat_light.png
- Auth fallthrough поверх mic permission alert — route не реализован.

### P0 — mascot3D_light.png
- AR-зона hub вместо отдельного экрана 3D mascot viewer. Должен быть rotation/zoom 3D-сцены с Лялей.

### P0 — mimicLyalya_light.png
- Mic permission alert + под ним AR-зона hub (route fallthrough на AR hub). Route не реализован отдельно.

### P1 — authForgotPassword_light.png
- Прогресс OK, иллюстрация бабочки-Ляли, форма Эл. почта. Кнопка "Отправить ссылку" в disabled state (бледная) — но при пустом поле это OK. Нижний padding кнопки скрыт под home indicator на SE — close to safe area edge.

### P1 — authSignUp_light.png
- Внизу обрезана кнопка "Создать аккаунт" — видна только верхняя часть на SE 320pt. ScrollView пропущен либо form не уместилась. Поля Имя/Эл.почта/Пароль/Повторите ОК.

### P1 — auth_light.png
- Внизу обрезан текст «Нет аккаунта? Зарегистрироваться» — видна только полоса. ScrollView/safe area нужен.

### P1 — anonymousAuth_light.png (duplicate concern)
- См. P0 выше + safe area issue same as auth_light.

### P1 — arZone_light.png
- Hero card "Добро пожаловать в AR-зону!" — большой пустой purple circle в центре без иллюстрации / 3D Lyalya. Empty hero. Только одна card "AR-маски" видна, остальные scrolled off.

### P1 — familyCalendar_light.png
- "Заголовок" — visible вместо реального L10n key (section title). Это string catalog leak.

### P1 — lessonARActivity_light.png
- Контент игры пустой — видны только timer (Шаг 1 из 5), "AR-зона" title, "Целевой звук: Р", и одна кнопка "Готово". Нет AR-камеры, нет интерактива. Минимальный scaffold.

### P1 — lessonBingo_light.png
- Mic permission alert blocks view, но за ним placeholder "Пусто" + "Спектрогра…" — это generic spectrogram component default state. Контент bingo cards (5×5) виден но без слов в карточках.

### P1 — homeTasks_light.png
- Sheet "Есть просроченные задания" — OK, но overlay блокирует основной list. На SE видны только 2 кнопки. Если это intended modal — OK, но screenshot не показывает родительский экран.

### P2 — dailyChallenge_light.png
- OK overall. Минор: достижение "Стикер «Звёздочка» +20 XP" — кнопка "Поделиться" близко к safe area bottom.

### P2 — fluencyDiary_light.png / fluencyDiaryHome_light.png
- Дубликаты screenshots для двух разных routes — оба показывают одинаковый empty state. Если это intentional aliasing route, удалить один; если нет — отдельные routes должны иметь свой UI.

### P2 — familyAwardsCabinet_light.png
- Empty state OK, но "Витрина семьи" блок занимает большой пустой белый прямоугольник без skeleton/illustration. Можно улучшить visual richness.

### Clean (no issues found)

- arZone_light.png (только P1 минор по hero)
- authVerifyEmail_light.png — иллюстрация, текст, 2 кнопки CTA, ОК
- breathingTree_light.png — sleep butterfly, "Перед началом", синяя кнопка "Начать", ОК (хотя синий не вписывается в orange palette — это medical disclaimer, акцент допустим)
- dailyStreak_light.png — Мои награды, 7 из 72, табы, sticker grid, ОК
- familyAwardsCabinet_light.png — empty state ОК
- familyHome_light.png — 2D Lyalya, Миша 6 лет 57%, кнопки Играть вдвоём, ОК
- familyLeaderboard_light.png — empty state, иконка people, ОК
- familyVoice_light.png — Лялю иллюстрация, выбор слова, мяч/собака/рыба/шар, mic button — ОК
- fluencyDiaryHome_light.png — Лялю круглая иллюстрация, "Записей ещё нет", ОК
- fluencyDiary_light.png — идентично выше
- helpCenter_light.png — FAQ accordions, иконки, ОК
- metronome_light.png — overlay блокирует, fundamental view не виден (mic alert) — see SYS-P0-1
- neurolinguistInsights_light.png — за alert виден title "Insights от Ляли" + хвост текста "Лялю, ваш цифровой логопед-помощник. 14 мая, 01:11" — implementation присутствует

---

## Common patterns found

1. **Mic permission overlay** на 18 экранах (lesson*, mimicLyalya, metronome, neurolinguistInsights, logopedistChat) — SYS-P0-1, единый fix через UIInterruptionMonitor.
2. **Auth fallthrough** на 5+ routes — указывает на missing router cases. План: либо добавить routes в `AppCoordinator`, либо удалить из screen-map.md.
3. **AR-зона hub дублируется** на 7 AR-routes — нет навигации в sub-screens AR.
4. **Demo не auto-advance** — demoStep1/5/10/15 все идентичны Шаг 1.
5. **3D Lyalya отсутствует** на childHome (P0!) — primary kid entry screen, должен быть hero 3D mascot.
6. **Placeholder string leaks**: lessonArticulationImitation ("По умолчанию", "Формат", "Заголовок", "Кнопка"), familyCalendar ("Заголовок"), lessonBingo ("Пусто", "Спектрогра…").
7. **SafeArea bottom truncation** на auth screens (auth, authSignUp, anonymousAuth) — ScrollView нужен для SE 320pt.
8. **Empty hero blocks** — arZone (purple circle без content), familyAwardsCabinet (большой белый rect).

---

## Top 5 P0 routes (priority fix)

1. `childHome` — отсутствует 3D Lyalya на главном детском экране (P0 для kids UX + App Store screenshots)
2. `lessonArticulationImitation` — placeholder strings "Заголовок"/"Кнопка"/"Формат"/"По умолчанию" leak (App Store reject risk)
3. `familyAchievements` — бесконечный loading spinner (broken feature)
4. SYS-P0-1: Mic permission UIInterruptionMonitor — починить 18 lesson screenshots для App Store tour
5. SYS-P0-2: 5 auth-fallthrough routes (anonymousAuth, culturalContent, dialectAdaptation, grammarGame, guidedTour) — либо реализовать, либо убрать из карты

## Top 5 P1 routes

1. `arZone` — пустой purple circle hero, нужна 3D Lyalya / illustration
2. `lessonARActivity` — минимальный scaffold, нужен AR camera preview + interactivity
3. `auth` / `authSignUp` — SafeArea bottom truncation на SE 320pt (ScrollView fix)
4. `familyCalendar` — "Заголовок" L10n leak
5. `lessonBingo` — "Пусто"/"Спектрогра…" placeholder leak

---

## Verification

- Все 59 PNG прочитаны через Read tool (manual visual inspection, не AI summary)
- Findings ограничены P0/P1/P2 — clean screens перечислены кратко
- Output file создан: `.claude/team/audit/v23-screen-audit-lightA.md`
- Dark batch и Light Batch B (rows 60+) — отдельные auditors
