# HappySpeech Design Audit

**Дата:** 2026-04-23
**Проверено:** 10 JSX-файлов в `happyspeech-design/project/` + 5 Swift-файлов в `DesignSystem/Tokens/`.

---

## Итоговые цифры

| Показатель | Значение |
|---|---|
| Задизайнено экранов в JSX | ~61 |
| Нужно досоздать | ~62 |
| Покрытие от полного списка | ~50% |
| ColorTokens совпадение | 95% |
| TypographyTokens совпадение | 90% |
| SpacingTokens совпадение | 85% |
| RadiusTokens совпадение | 100% |
| MotionTokens совпадение | 70% |
| ShadowTokens совпадение | 100% |
| Компоненты реализованы | ~60% |

**Задизайнено в Claude Design:** ~61 уникальный экран/состояние:
- screens-kid.jsx — 18 экранов
- screens-kid2.jsx — 15 экранов + системные состояния (loading, offline, empty)
- screens-parent.jsx — 10 экранов
- screens-specialist.jsx — 8 экранов + 3 карточки-документации
- screens-v2.jsx — ~15–20 переработанных экранов

**Надо досоздать:** ~62 экрана/состояния.

---

## 1. Визуальные токены — Diff с кодом

### ColorTokens.swift (95% совпадение)
Отсутствует группа:
- `SoundFamilyColors.Vowels` (5-я группа, `oklch(0.82 0.13 85)`, bg `oklch(0.96 0.05 85)`) — в Swift 4 группы, надо добавить 5-ю (Vowels — тёплый жёлтый).

### TypographyTokens.swift (90%)
Расхождение:
- В JSX `display` имеет `fontWeight: 800`, в Swift — `.bold`. Нужен `.black` или `.heavy` для `display()`; `.black` уже есть только в `kidDisplay()`.

### SpacingTokens.swift (85%)
Расхождение:
- `screenEdge = 24pt` в Swift, но экраны JSX используют `16pt` как горизонтальный отступ. Добавить алиас `contentMarginH = 16pt` отдельно от `screenEdge`.

### RadiusTokens.swift (100% vs JSX)
Но `.claude/team/design-specs.md` содержит устаревшие значения (`card: 12pt, button: 10pt`), фактический код и JSX — `card: 24pt, button: 32pt`. `design-specs.md` надо обновить.

### MotionTokens.swift (70%)
Не хватает:
- ms-ступени из JSX: `micro=120ms`, `sm=180ms`, `md=240ms`, `lg=360ms` (в Swift: `instant=0.10, quick=0.20, standard=0.30, moderate=0.45, slow=0.60` — другие значения)
- Анимация `reward`: в system prompt `spring(duration: 0.6, bounce: 0.35)`, в коде ближайшая — `bounce = .spring(response: 0.4, dampingFraction: 0.55)`

### ShadowTokens.swift (100%) — OK.

---

## 2. Компоненты (из Claude Design)

**Реализованы (60%):**
| Имя | Файл JSX | Статус в коде |
|---|---|---|
| Button (KidCTA) | ui.jsx | HSButton ✓ |
| Card (KidTile) | ui.jsx | HSCard ✓ |
| MascotView (Butterfly) | mascot.jsx, mascot-v2.jsx | HSMascotView ✓ |
| ProgressBar (Ring + Bar) | ui.jsx | HSProgressBar ✓ |
| AudioWaveform | ui.jsx | HSAudioWaveform ✓ |
| Sticker | ui.jsx | HSSticker ✓ |
| Badge | ui.jsx | HSBadge ✓ |
| Toast | ui.jsx | HSToast ✓ |

**Не реализованы (нужно добавить в M7):**
- `Speech` bubble — для подсказок маскота (HIGH priority)
- `Pict` — иллюстрационный тайл с глифом
- `MiniSpark` — sparkline-чарт для Parent-контура
- Компаньоны звуков: **Zippy, Shushkin, Ryoka, Kuku, Aoko** — 5 отдельных персонажей для звуковых семей
- `RaysBg` — starburst-фон для героических состояний
- `KidTabBar` / `ParentTabBar` — как отдельные SwiftUI-компоненты

---

## 3. Задизайненные экраны в JSX

**Kid circuit (41 экранов):**
Splash, Welcome carousel, Role Select, SignUp, Add Child, Permissions, Kid Home, World Map, Warmup/Breathing/Articulation, Listen & Choose, Repeat After Model, Syllable Ladder, Story, Picture Description, Drag & Match, Rhythm, Pause, Try Again, Success, Lesson End, Streak, Rewards Collection, Kid Profile, AR Lobby/Permission/Mirror/Tongue/LowTracking/Success, Empty/Offline/Loading states.

**Parent circuit (10 экранов):**
Parent Dashboard, Child Detail, Sound Map, Weekly Plan, Analytics, Attempt History with waveform, Parent Settings, Parental Gate, Report Export, Tips Library, Home Practice.

**Specialist circuit (8 экранов):**
Specialist Dashboard, Specialist Case + Waveform + Spectrogram, Plan Builder, Session Comparison, Assessment/Screening.

**System (3 экрана):**
Lock-screen Notification, Loading, Error states.

---

## 4. Отсутствующие экраны (нужно создать в M7)

### Auth flow (10)
Auth Landing, Sign In, Forgot Password, Verify Email, Google redirect, Account Setup, Account Settings, Privacy Center, Sync State, Export Center

### Профили (5)
Child List, Edit Child, Avatar/Theme Preferences, Goals/Preferences, Sensitivity Settings

### Скрининг (6)
Screening Intro, Screening Task Flow (~8 шагов), Articulation Camera Step, Speech Sample Step, Baseline Result, Re-screening Compare

### Kid Home extensions (3)
Daily Mission детальный, Streak Overview (calendar view), Reward Preview

### Игровые шаблоны (8 отсутствуют)
MinimalPairs, Memory, Bingo, PuzzleReveal, SoundHunter, NarrativeQuest, VisualAcoustic, ArticulationImitation

### AR extensions (5)
AR Intro, Hold Pose game, Copy Face game, Breathing AR hybrid, AR Results summary

### Rewards (4)
Reward Reveal (анимированное), Sticker Album full, Achievements, Avatar Customization

### Parent extensions (7)
Per-Sound Analytics, Session History, Audio Archive, Recommendations, Guidance Library, Content/Model Packs detailed, Notifications Settings

### Specialist extensions (9)
Entry/Selector, Child Selector, Program Editor, Target Assignment, Attempt Review (labeling workspace), Acoustic Review, Monthly Report, Per-Sound Report, Exports

### Системные (5)
Launch Loading, Data Pack Loader, Model Pack Loader, Maintenance/Error, Demo Mode, Interactive Guided Tour

**Итого отсутствует:** ~62 экрана/состояния. Их надо создать в том же стиле что JSX.

---

## 5. Маскот Ляля — состояния

В JSX реализованы 9 состояний через prop `mood`:

| Состояние | Форма рта | Глаза | Контекст |
|---|---|---|---|
| `happy` | небольшая улыбка | открытые, блик | idle, главный экран |
| `celebrating` | широко открыт, розовый внутри | обычные | правильный ответ, успех |
| `excited` | то же что celebrating | обычные | экстремальная радость |
| `thinking` | прямая линия | обычные | пауза, ожидание |
| `focused` | прямая линия | обычные | концентрация на задании |
| `listening` | круглое «O», маленький язычок | обычные | запись голоса |
| `encouraging` | мягкая улыбка (меньше celebrating) | обычные | неправильный ответ |
| `shy` | нейтральный | смотрят вниз | первая встреча |
| `sleeping` | закрытый | закрытые (дуги) | пауза, конец сессии |

**Для Rive state-machine нужно добавить:** `speaking` (быстрое открытие/закрытие рта для lip-sync), `tired` (зевок — переходное от sleeping).

**Все ассеты — inline SVG в JSX, внешних файлов нет.** Для iOS нужно создать Rive-файл на основе JSX-описания (animator в M5+M9).

---

## 6. Стиль иллюстраций (guide)

**Линии:** органические bezier-кривые, контурная обводка 1.5–2pt в затемнённом цвете персонажа (не чёрная). Закруглённые формы.

**Палитра:** пастельная oklch, chroma 0.12–0.19. Кораллово-абрикосовый центр, акценты teal/lilac/green/butter по звуковым семьям. Радиальные градиенты с центром в 35–40% / 30–35% создают псевдо-3D объём. Белые блики (opacity 0.3–0.55) — обязательны.

**Характер:** «мягкий 3D» в flat-SVG. Персонажи с большими головами (голова ~40–45% высоты), round bodies, контактные тени-эллипсы. Глаза обязательно с белым световым пятном, щёки-румянец у всех.

**Эмоциональность:** живость через форму рта (5 форм), моргание 4s, покачивание 3.4s, взмахи крыльев 1.6s. Sparkles обязательны для celebrating. Компаньоны звуков носят letter-badge.

---

## 7. План работ на M7 (основано на этом audit)

### Приоритет P0 (M7 start):
- [ ] Добавить 5-ю группу в SoundFamilyColors (Vowels) в ColorTokens.swift
- [ ] Добавить `contentMarginH = 16pt` в SpacingTokens
- [ ] Обновить MotionTokens.swift: добавить ms-ступени (micro/sm/md/lg), fix `reward` spring параметры
- [ ] Обновить `design-specs.md` — исправить устаревшие radius values

### P1 (новые компоненты DesignSystem):
- [ ] HSSpeechBubble (для маскота)
- [ ] HSPictTile (иллюстрационный тайл)
- [ ] HSMiniSpark (sparkline chart для Parent)
- [ ] 5 звуковых компаньонов как отдельные View-components: ZippyView (С), ShushkinView (Ш), RyokaView (Р), KukuView (К), AokoView (гласные/йотированные)
- [ ] HSRaysBg (starburst backgrounds)
- [ ] HSKidTabBar + HSParentTabBar

### P2 (экранные реализации):
- [ ] Реализовать 62 отсутствующих экрана в Swift в стиле JSX
- [ ] Sound Map (по дизайну из JSX)
- [ ] Parental Gate (скрипт есть в JSX)

### P3 (маскот и анимация, отдаётся `animator`):
- [ ] Rive state-machine Ляли с 11 состояниями (9 существующих + speaking + tired)
- [ ] Lip-sync интеграция (амплитуда микрофона → mouthOpen blendshape)
- [ ] Готовые Lottie-анимации для rewards и transitions

### Критичные расхождения в existing docs:
- `design-specs.md` содержит устаревшие values: `card: 12pt` (актуально 24pt), `button: 10pt` (актуально 32pt). Секция типографики — пустая. Надо заполнить из кода.

---

*Report by designer agent, 2026-04-23*
