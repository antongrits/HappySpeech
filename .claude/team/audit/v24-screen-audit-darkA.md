# v24 Manual Screen Audit — Dark Batch A (59 PNGs)

**Date:** 2026-05-15
**Method:** Read tool на каждый PNG из `_workshop/v24_uitest_tour/dark/` (alphabetical first half)
**Source:** `/tmp/v24_batch_darkA.txt` (59 files, anonymousAuth → mimicLyalya)
**Criteria:** 12 with Dark theme accent (per v24 BG-verified `-HSForceDarkTheme` launchArg)

---

## Sum­mary counts

| Metric | Count | Notes |
|---|---|---|
| Total PNGs read | 59 | All processed |
| Dark theme actually applied (bg dark) | 59 | Zero Light-leak — `-HSForceDarkTheme` works |
| 3D Lyalya present where expected | ~25 | auth flow, family, fluency, dailyChallenge, lessons |
| Russian-only text | 59 | Zero English leakage |
| No эмодзи | 59 | Clean |
| No overflow 320pt | 59 | Width OK on all |
| Text readable (contrast) | 59 | Light text on dark bg everywhere |
| Hardcoded light-color CTA in dark | 2 | `breathingTree`, `metronome` — bright-blue «Начать» |
| Truncation visible | 1 | `lessonSorting` — «Разложи слова по количеству сло...» |
| Route fallback to AR-zone (partial PNG) | 8 | arFaceFilter, arMirror, arStoryQuest, arZone, breathingAR, butterflyCatch, holdThePose, mimicLyalya |
| Route fallback to Auth | 6 | auth, comparisonDashboard, culturalContent, dialectAdaptation, grammarGame, logopedistChat |
| Demo-card pink/violet gradient | 5 | demoMode, demoStep1/5/10/15 — content card, not bg leak |

---

## Dark-specific issues (P-grade)

### P1 — Hardcoded blue CTA in Dark theme (2 screens)
- `breathingTree_dark.png` — кнопка «Начать» рендерится ярко-голубой (`#5DA9FF`-like), вместо token `Color.surface.primary` (orange) или dark-adapted variant.
- `metronome_dark.png` — то же самое preface-screen («Перед началом» с заиканием), та же blue-CTA.

**Suspected source:** оба route'ятся на `StutteringPrefaceView` или похожий wrapper с хардкодным `.background(Color.blue)` или системным `Color.accentColor` который не respect'ит app theme. Нужен `git grep` на `Color.blue\|accentColor` в Features где «Перед началом» рисуется.

### P2 — Truncation (1 screen)
- `lessonSorting_dark.png` — заголовок «Разложи слова по количеству слогов» обрезан до «Разложи слова по количеству сло...». Нужен `.lineLimit(2)` + `.minimumScaleFactor(0.85)`.

### P3 — Demo-card pink/violet gradient (5 screens, не баг)
`demoMode`, `demoStep1/5/10/15` показывают одну и ту же розово-фиолетовую gradient-карточку — это **дизайн самой demo-card** (промо-карточка туториала), а не light-leak фона. Фон вокруг card тёмный. **Не issue**, но визуально card очень контрастит — возможно стоит добавить dark-variant gradient (recommendation, не P1).

### P-info — Route fallbacks (без issue для dark audit)
- AR-фичи (8 шт) → `ARZoneRootView` (partial screenshot — мелкая высота, видимо deep-link не отработал и screenshot taken до full layout)
- Аналитика/чат (6 шт) → `AuthView` (deep-link недоступен без auth)
- Все эти fallback-screens сами по себе dark-correct.

---

## 3D Lyalya presence (where expected)

Корректно отображается на: anonymousAuth, authForgotPassword, authSignUp, authVerifyEmail, familyVoice, fluencyDiary, fluencyDiaryHome, dailyChallenge, lessonRepeatAfterModel, lessonNarrativeQuest, lessonRhythm, lessonBreathingExercise, lessonVisualAcoustic, lessonBingo, lessonMemory, lessonListenAndChoose, lessonStoryCompletion, lessonArticulationImitation, lessonDragAndMatch.

Не отображается там, где её **не должно быть**: chart-screens (comparisonDashboard route→auth), preface (breathingTree/metronome use butterfly resting illustration вместо Lyalya 3D — by design).

---

## Touch targets ≥56pt

Спот-проверка primary CTA на 12 экранах: anonymousAuth «Начать» (~88pt), auth «Войти» (~80pt), authForgotPassword «Отправить ссылку» (~80pt), authVerifyEmail «Я подтвердил» (~76pt), childHome event card (~88pt), familyCalendar day pills (~88pt), helpCenter FAQ rows (~80pt), homeTasks «Напомнить»/«Позже» (~64pt), lessonListenAndChoose play button (~88pt), lessonRepeatAfterModel «Послушать» (~64pt). All ≥56pt.

---

## Layout/alignment

No misalignments detected. Все cards/sections выровнены grid'ом DesignSystem spacing tokens.

---

## Comparison to v23 audit

v23 audit reported **Light leak 117/117 dark screens** (тема не применялась). v24 c `-HSForceDarkTheme` launchArg confirmed BG-verified — **0/59 light leak** в этом батче. Fix работает.

---

## Recommendations

1. **P1 fix:** grep `Color.blue` / `.tint(.blue)` / `Color.accentColor` в Features → StutteringPreface/MetronomePreface → заменить на `DesignSystem.colors.accent.primary` с dark variant.
2. **P2 fix:** добавить `.lineLimit(2)` в title `lessonSorting` view.
3. **P3 recommendation:** рассмотреть dark-variant gradient для demoCard (низкий приоритет — это эталонный screenshot, не interactive).

---

**Commit hash:** TBD (после `git commit`)
