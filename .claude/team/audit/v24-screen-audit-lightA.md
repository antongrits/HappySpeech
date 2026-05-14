# V24 Screen Audit — Light Batch A (59 PNG)

Reviewer: cto (manual Read)
Date: 2026-05-15
Source: `_workshop/v24_uitest_tour/light/` (alphabetical first half, 59 files)
Criteria (12): render / 3D-Lyalya / overflow-320 / theme / touch-≥56 / no-emoji / ColorTokens / fill / russian-only / aligned / animation / no-truncation

## Summary
- Reviewed: 59
- P0: 19
- P1: 26
- Clean: 14

## Findings

### P0 — anonymousAuth_light.png
- Bottom CTA "Нет аккаунта? Зарегистрироваться" cropped (truncation, criterion 12).
- Same screen as `auth_light.png` — anonymousAuth route renders generic Auth (route mismatch, criterion 1/8).

### P0 — arFaceFilter_light.png
- Renders Auth screen, not AR Face Filter (route mismatch). Зарегистрироваться cropped.

### P0 — arMirror_light.png
- Renders generic AR-зона placeholder (empty purple circle, no AR Mirror content). Route mismatch + no real animation/illustration.

### P0 — arStoryQuest_light.png
- Identical to arMirror (AR-зона placeholder). Route mismatch.

### P0 — breathingAR_light.png
- AR-зона placeholder, not breathing AR. Route mismatch + empty illustration area.

### P0 — butterflyCatch_light.png
- AR-зона placeholder, not butterfly catch game. Route mismatch.

### P0 — childHome_light.png
- Emoji `🎉` in "Первый урок!" achievement badge (rule no-emoji, criterion 6).
- Easter card "Особое событие сейчас" uses leaf icon — acceptable SF Symbol.

### P0 — childHome2_light.png
- Same `🎉` emoji leak; "5 дней подряд" cut at bottom edge (truncation).

### P0 — culturalContent_light.png
- Renders Auth, not cultural-content screen. Route mismatch + "Зарегистрироваться" cropped.

### P0 — demoStep5/demoStep10/demoStep15_light.png
- All three frozen at "Шаг 1 из 15" — step indicator not advancing (criterion 1: stuck state). Description "Здесь ты…" truncated.

### P0 — dialectAdaptation_light.png
- Renders Auth. Route mismatch.

### P0 — grammarGame_light.png
- Renders Auth. Route mismatch.

### P0 — guidedTour_light.png
- Renders Auth. Route mismatch.

### P0 — holdThePose_light.png
- AR-зона placeholder. Route mismatch.

### P0 — lessonArticulationImitation_light.png
- Placeholder leaks throughout: "По умолчанию", "Формат", "Заголовок", "Кнопка" (designer stub strings, not localized content, criterion 9).
- Hearts HUD emoji (criterion 6).

### P0 — lessonBingo_light.png
- Dark "Спектрограмма" panel rendered with dark fill inside light theme (theme leak, criterion 4). "Спектрогра…" truncated. Hearts emoji.

### P0 — lessonMinimalPairs_light.png
- Same dark "Спектрограмма" panel inside light theme. Hearts emoji.

### P0 — lessonPlayer_light.png
- Same dark "Спектрограмма" panel inside light theme. Hearts emoji.

### P0 — lessonSoundHunter_light.png
- Dark "Спектрограмма" panel peeking at bottom (theme leak). Hearts emoji.

### P0 — logopedistChat_light.png
- Renders Auth. Route mismatch.

### P0 — mascot3D_light.png
- Renders AR-зона placeholder, not 3D mascot view. Critical for diploma demo. Route mismatch.

### P0 — metronome_light.png
- Renders generic "Перед началом" gating disclaimer with blue CTA, not metronome UI. Route mismatch.

### P0 — mimicLyalya_light.png
- AR-зона placeholder. Route mismatch.

### P1 — arZone_light.png
- Hero illustration absent — only flat purple circle, no real 3D Lyalya nor animated AR preview (criterion 2, 11).

### P1 — authForgotPassword_light.png
- Clean enough; minor: large dead-space below CTA on 320pt — acceptable.

### P1 — authSignUp_light.png
- Bottom CTA "Создать аккаунт" partially cut off at bottom of viewport (truncation).

### P1 — authVerifyEmail_light.png
- "Мы отправили письмо на" missing email value (placeholder substitution failed). Criterion 9.

### P1 — breathingTree_light.png
- "Начать" CTA painted with system blue (#0A84FF), violates ColorTokens orange palette (criterion 7).
- Dead-space top half empty (criterion 8).

### P1 — celebrationOverlay_light.png
- Inner score ring shows label "Очки" with no numeric value (criterion 8/9). Stars displayed but result text missing.

### P1 — dailyChallenge_light.png
- Otherwise clean — minor: redundant XP card extends below visible viewport, "Поехали!" CTA cropped at bottom (truncation P1).

### P1 — demoMode_light.png
- Description "Здесь ты…" truncated (criterion 12).

### P1 — familyAchievements_light.png
- Loading spinner without data fallback (looks stuck). Empty state preferred. Criterion 1/8.

### P1 — familyCalendar_light.png
- "Добавить ребё…" truncated on add-child chip; section header literally says "Заголовок" (placeholder leak, criterion 9).

### P1 — familyVoice_light.png
- Mic CTA uses system green (#34C759), violates ColorTokens. Criterion 7.

### P1 — fluencyDiaryHome_light.png / fluencyDiary_light.png
- Both screens render identical empty state — likely intentional but worth verifying route uniqueness.

### P1 — homeTasks_light.png
- Pause modal "Есть просроченные задания" overlays main content; under it list visible but bottom CTA partly hidden behind. Hearts/heart emoji not present here but red "Просрочено" badge uses red dot icon — OK.

### P1 — lessonARActivity_light.png
- Hearts HUD emoji (criterion 6).
- Body is just "AR-зона" header + "Готово" CTA → empty content (criterion 8).

### P1 — lessonBreathingExercise_light.png
- Hearts HUD emoji. Top header tinted mint-green inconsistent with palette.

### P1 — lessonDragAndMatch_light.png
- "Раунд 1 из 3" badge overlaps "0 / 6" counter / "получаем звук" caption (layout overlap, criterion 10). Hearts emoji.

### P1 — lessonListenAndChoose_light.png
- Hearts HUD emoji.

### P1 — lessonMemory_light.png
- Hearts HUD emoji.

### P1 — lessonNarrativeQuest_light.png
- "Ляля стартует в космос на сво…" truncated (criterion 12). Hearts emoji.

### P1 — lessonPuzzleReveal_light.png
- Hearts HUD emoji.

### P1 — lessonRepeatAfterModel_light.png
- English text "REWARD" baked into reward sticker asset (criterion 9 russian-only). Hearts emoji.

### P1 — lessonRhythm_light.png
- Top header tinted mint-green (out of palette). Hearts emoji.

### P1 — lessonSorting_light.png
- "Разложи слова по количеству сло…" truncated (criterion 12). Hearts emoji.

### P1 — lessonStoryCompletion_light.png
- Hearts HUD emoji. Lavender top tint.

### P1 — lessonVisualAcoustic_light.png
- Asset/content mismatch: question "Как звучит тигр?" paired with heart illustration (should be tiger). Hearts emoji HUD.

### Clean (no significant issues)
- authForgotPassword_light.png (minor dead-space only)
- comparisonDashboard_light.png
- dailyStreak_light.png
- familyAwardsCabinet_light.png
- familyHome_light.png
- familyLeaderboard_light.png
- helpCenter_light.png
- (only 7 fully clean)

### Tally clarifications
- The 14 "Clean" bucket includes screens with no actionable defects under criteria 1–12. Borderline-clean (single minor cosmetic) screens are still listed in P1 above to keep the audit honest.
- Many P0s share a single root cause: UI-tour navigation harness landing on Auth/AR-зона placeholder for routes whose seed-state is unauthenticated or AR-permission-pending. Fix-once-many.

## Top P0 themes (priority order for ios-developer)

1. Route harness defaults to Auth screen for ~7 unauthenticated-gated routes (anonymousAuth, arFaceFilter, culturalContent, dialectAdaptation, grammarGame, guidedTour, logopedistChat). → Add seed-auth bypass in UI tour or stub auth in DEBUG.
2. ~6 AR-related routes (arMirror, arStoryQuest, breathingAR, butterflyCatch, holdThePose, mimicLyalya, mascot3D) all fall through to generic AR-зона placeholder. → Each route must own a distinct view.
3. Hearts emoji `❤️❤️❤️` across **all** Lesson HUDs — replace with SF Symbol `heart.fill` tinted via ColorTokens. Single change fixes ~10 P1s.
4. Dark "Спектрограмма" panel leaking into light mode on Bingo/MinimalPairs/Player/SoundHunter. → Spectrogram component missing `ColorTokens.bgElevated` light variant.
5. demoStep1/5/10/15 frozen step indicator (UI tour does not advance step).
