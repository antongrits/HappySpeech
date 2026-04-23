# Design Specifications — HappySpeech

> Управляется: designer-ui, designer-visual.
> Последнее обновление: M7.1–M7.5 (2026-04-23).
> Токены из: `HappySpeech/DesignSystem/Tokens/` — не хардкодить значения в фичах.

---

## Дизайн-токены (справочник)

### Цвета — ColorTokens.swift

| Неймспейс | Токен | Назначение |
|---|---|---|
| Brand | `.primary` | Coral-apricot — CTA, крылья маскота |
| Brand | `.primaryHi / .primaryLo` | Hover/pressed состояния CTA |
| Brand | `.mint` | Успех, прогресс |
| Brand | `.sky` | Инфо, ссылки |
| Brand | `.lilac` | AR-акцент, магия |
| Brand | `.butter` | Награды, стрики |
| Brand | `.rose` | Тепло на карточках |
| Brand | `.gold` | Золото — ачивки, домашние задания |
| Kid | `.bg / .bgDeep / .bgSoft / .bgSofter` | Фоны детского контура |
| Kid | `.surface / .surfaceAlt` | Поверхности карточек |
| Kid | `.ink / .inkMuted / .inkSoft` | Текст детского контура |
| Kid | `.line` | Разделители |
| Parent | `.bg / .bgDeep / .surface` | Фоны родительского контура |
| Parent | `.ink / .inkMuted / .inkSoft / .line / .lineStrong / .accent` | Текст, акцент |
| Spec | `.bg / .surface / .panel / .ink / .inkMuted / .line / .grid / .accent / .waveform / .target` | Специалист |
| Semantic | `.success / .successBg / .error / .errorBg / .warning / .warningBg / .info / .infoBg` | Статусы |
| SoundFamilyColors | `.Whistling / .Hissing / .Sonorant / .Velar / .Vowels` | Hue + Bg по группам звуков |
| Games | `.listenAndChoose / .repeatAfterModel / .memory / .breathing / .rhythm / .sorting / .puzzle / .arGames` | Акценты игр |
| Feedback | `.correct / .incorrect / .neutral / .excellent` | Ответы в играх |
| Session | `.progressBar / .progressBackground / .fatigueWarning` | Прогресс сессии |

### Типографика — TypographyTokens.swift

| Функция | Размер | Вес | Дизайн | Применение |
|---|---|---|---|---|
| `kidDisplay(40+)` | 40pt+ | Black | Rounded | Герои-заголовки детского экрана |
| `display(36)` | 36pt | Bold | Rounded | Дисплей-заголовки |
| `title(24)` | 24pt | Semibold | Rounded | Заголовки секций |
| `headline(18)` | 18pt | Semibold | Rounded | Названия карточек |
| `body(15)` | 15pt | Regular | Default | Основной текст |
| `caption(12)` | 12pt | Regular | Default | Лейблы, подсказки |
| `mono(13)` | 13pt | Medium | Monospaced | Счёт, технические данные |
| `cta()` | 17pt | Bold | Rounded | Кнопки CTA |

Минимум для детского контура: body = 22pt (переопределяется на `kidDisplay` или `title`).
Line spacing: `LineSpacing.relaxed (1.5)` для всего детского контура.

### Отступы — SpacingTokens.swift (base 4pt)

`xs=4, s=8, m=12, l=16, xl=20, xxl=24, xxxl=32`
`contentMarginH=16` (20pt на larger screens), `cardPadding=16`, `sectionSpacing=24`

### Радиусы — RadiusTokens.swift

`card=12, button=10, input=8, chip=6, large=16`

### Анимации — MotionTokens.swift

| Токен | Параметры | Применение |
|---|---|---|
| `outQuick` | timingCurve(0.16,1,0.3,1, 0.20s) | Микро-взаимодействия |
| `spring` | response:0.45, damping:0.7 | Карточки, плитки |
| `bounce` | response:0.4, damping:0.55 | Награды, стикеры |
| `page` | easeOut 0.35s | Навигационные переходы |
| `hero` | response:0.5, damping:0.8 | Hero-переходы игр |
| `idlePulse` | easeInOut 1.8s, forever | Маскот в idle |

Reduced Motion: `spring` → nil, `bounce` → nil, `page` → `.linear(0.15)`.

### Детский контур — особые требования

- Min touch target: **56×56pt**
- Шрифт body: минимум 22pt (`title` или `kidDisplay`)
- Маскот «Ляля» присутствует на всех игровых экранах
- Haptic: `.success` при правильном ответе, `.warning` при неправильном
- Reduced Motion: spring → opacity fade 0.15s

---

## M7.1 — Аудит экранов

### Существующие фичи и их экраны

| Feature | Экраны сейчас (View-файлы) | Статус View |
|---|---|---|
| ChildHome | `ChildHomeView` | Есть VIP, View реализован |
| ParentHome | `ParentHomeView` | Есть VIP, View реализован |
| Onboarding | `OnboardingFlowView` | Есть VIP, нет отдельных шагов |
| ARZone | `ARZoneView` | Есть VIP + 16 игровых папок |
| Demo | `DemoModeView` | Есть VIP |
| GuidedTour | (из CLAUDE.md) | Реализован |
| HomeTasks | (папка существует) | Есть VIP |
| LessonPlayer | `LessonPlayer` + 16 игр | Есть VIP + игры |
| OfflineState | (папка) | Есть VIP |
| Permissions | (папка) | Есть VIP |
| ProgressDashboard | `ProgressDashboardView` | Есть VIP |
| Rewards | `RewardsView` | Есть VIP |
| Screening | `ScreeningView` | Есть VIP + engine |
| SessionComplete | (папка) | Есть VIP |
| SessionHistory | `SessionHistoryView` | Есть VIP |
| SessionShell | (папка) | Есть VIP |
| Settings | `SettingsView` | Есть VIP |
| Specialist | `SpecialistHomeView` + ProgramEditor / Reports / SessionReview | Есть VIP |
| WorldMap | `WorldMapView` | Есть VIP |
| Auth | (папка) | Есть VIP |
| AR | (папка) | Есть VIP |

**Итого существующих фич:** 21. VIP-каркасы есть везде. **Спек экранов нет ни для одного.**

### Недостающие спеки (цель M7.2)

| Feature | Нужны спеки экранов |
|---|---|
| Onboarding | 10 шагов: welcome, role, about, child-creation, goals, preferences, screening-intro, permissions, pack-download, complete |
| Demo | 15 шагов: splash → ChildHome → Lesson → AR → Reward → Parent → Settings |
| ParentHome | 8 карточек-дашборд + session detail + weekly chart |
| Specialist | program editor, reports list, session review list, session detail |
| WorldMap | 5 зон (свистящие, шипящие, соноры, велярные, йот) |
| Rewards | album grid, sticker detail, streak modal |
| ProgressDashboard | deep view по звуку |
| Settings | 7 разделов |
| Permissions | 4 экрана (mic, camera, notifications, face tracking) |
| Screening | intro + 3 block transitions |
| SessionHistory | list + detail |
| HomeTasks | list + detail + completed view |
| OfflineState | полный экран |

**Итого: 39+ экранов без спек.**

---

## M7.2 — Спеки отсутствующих экранов

### ОНБОРДИНГ

---

#### Шаг 1 — Приветствие (OnboardingWelcomeView)
**Контур:** universal (до выбора роли)
**Статус:** спека M7.2

**Layout**
- Background: `Kid.bg` (warm cream)
- Safe area: top 0pt, horizontal 0pt (full bleed)
- Структура: `ZStack` — градиентный фон + `VStack(spacing: SpacingTokens.xxl)`

**Иерархия**
```
ZStack {
    // Фон: радиальный градиент Kid.bg → Kid.bgDeep
    VStack(spacing: SpacingTokens.xxl) {
        Spacer()
        HSMascotView(state: .celebrating)   // 160×160pt, центр
        Text("Привет! Я Ляля")              // kidDisplay(40), Kid.ink
        Text("Вместе научимся говорить красиво!") // title(24), Kid.inkMuted
        Spacer()
        HSButton("Начать", style: .primary) // .infinity × 56pt
            .padding(.horizontal, SpacingTokens.l)
            .padding(.bottom, SpacingTokens.xxl)
    }
}
```

**Анимации**
- Маскот появляется: scale 0→1 + opacity, `.bounce`
- Текст: opacity 0→1, задержка 0.4s, `.outQuick`
- Кнопка: slide снизу, задержка 0.7s, `.spring`

**Accessibility**
- VoiceOver: маскот label "Ляля, логопедический помощник"
- Кнопка: "Начать знакомство"
- Reduced Motion: все анимации заменить на opacity fade 0.15s

---

#### Шаг 2 — Выбор роли (OnboardingRoleView)
**Контур:** universal
**Статус:** спека M7.2

**Layout**
- Background: `Kid.bg`
- Горизонтальные отступы: `SpacingTokens.l (16pt)`

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    Text("Кто будет заниматься?")  // title(24), Kid.ink
    HStack(spacing: SpacingTokens.l) {
        HSCard(role: .child)   // 156pt wide × 180pt, иконка + «Ребёнок»
        HSCard(role: .parent)  // 156pt wide × 180pt, иконка + «Родитель»
    }
    HSCard(role: .specialist)  // .infinity × 80pt, иконка + «Специалист»
    Spacer()
}
.padding(.top, SpacingTokens.xxxl)
```

**Карточки выбора роли**
- Corner radius: `RadiusTokens.large (16pt)`
- Border: 2pt `Kid.line`, при выборе: 2pt `Brand.primary`
- Background: `Kid.surface`
- Иконка: 48×48pt SF Symbol (person.fill / person.2.fill / stethoscope)
- Label: `headline(18)`, `Kid.ink`
- Touch target: 156×180pt (>56pt) / .infinity×80pt

**Анимации**
- Выбор карточки: scale 1→1.04→1, `.bounce`, border color transition `.outQuick`

**Accessibility**
- Каждая карточка: accessibilityRole(.button), label "Ребёнок, выбрать роль"

---

#### Шаг 3 — О приложении (OnboardingAboutView)
**Контур:** parent / specialist (kid пропускает)
**Статус:** спека M7.2

**Layout**
- Background: `Parent.bg`
- Scrollable `VStack`

**Иерархия**
```
ScrollView {
    VStack(alignment: .leading, spacing: SpacingTokens.xxl) {
        Text("Как работает HappySpeech")  // title(24), Parent.ink
        ForEach(features) { f in
            HStack(spacing: SpacingTokens.l) {
                Image(systemName: f.icon)  // 32×32pt, Brand.primary
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: SpacingTokens.xs) {
                    Text(f.title)   // headline(18), Parent.ink
                    Text(f.body)    // body(15), Parent.inkMuted
                }
            }
        }
        HSButton("Продолжить", style: .primary)  // .infinity × 56pt
    }
    .padding(.horizontal, SpacingTokens.l)
    .padding(.vertical, SpacingTokens.xxl)
}
```

**Accessibility**
- Каждый пункт: accessibilityElement(children: .combine)
- Dynamic Type: layout переключается на `VStack` при `sizeCategory >= .accessibilityMedium`

---

#### Шаг 4 — Создание профиля ребёнка (OnboardingChildCreationView)
**Контур:** parent / child
**Статус:** спека M7.2

**Layout**
- Background: `Kid.bg`
- Form-like `VStack`, не `Form` (для стилизации)

**Иерархия**
```
VStack(spacing: SpacingTokens.xl) {
    // Аватар-пикер
    Button { } label: {
        Circle()
            .fill(Kid.surfaceAlt)
            .frame(width: 96, height: 96)
            .overlay(Image(systemName: "camera.fill").foregroundStyle(Kid.inkSoft))
    }
    // Имя
    HSTextField("Имя ребёнка", text: $name)  // height 56pt, radius input(8)
    // Возраст
    HStack(spacing: SpacingTokens.s) {
        ForEach([5,6,7,8], id: \.self) { age in
            HSChip("\(age) лет", selected: selectedAge == age)  // 56×40pt
        }
    }
    Spacer()
    HSButton("Создать профиль", style: .primary)
}
.padding(.horizontal, SpacingTokens.l)
```

**Accessibility**
- Поле имени: label "Введите имя ребёнка"
- Чипы возраста: accessibilityRole(.button), label "5 лет, выбрать"

---

#### Шаг 5 — Цели занятий (OnboardingGoalsView)
**Контур:** parent / specialist
**Статус:** спека M7.2

**Layout**
- Background: `Parent.bg`
- Multi-select список целей

**Иерархия**
```
VStack(spacing: SpacingTokens.l) {
    Text("Что хотите развить?")  // title(24), Parent.ink
    ScrollView {
        LazyVStack(spacing: SpacingTokens.s) {
            ForEach(goals) { g in
                HSCard {
                    HStack {
                        Image(systemName: g.icon).frame(width: 44, height: 44)
                        Text(g.title)  // headline(18)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Brand.primary : Parent.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
            }
        }
    }
    HSButton("Далее", style: .primary)
}
.padding(.horizontal, SpacingTokens.l)
```

---

#### Шаг 6 — Предпочтения (OnboardingPreferencesView)
**Контур:** parent
**Статус:** спека M7.2

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    Text("Настройки занятий")  // title(24), Parent.ink
    // Длительность сессии
    VStack(alignment: .leading, spacing: SpacingTokens.s) {
        Text("Длительность сессии")  // headline(18)
        HStack(spacing: SpacingTokens.s) {
            ForEach([10,15,20], id: \.self) { min in
                HSChip("\(min) мин", selected: duration == min)
            }
        }
    }
    // Напоминания
    Toggle("Ежедневные напоминания", isOn: $reminders)
        .tint(Brand.primary)
    // Время напоминания
    DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
        .disabled(!reminders)
    Spacer()
    HSButton("Продолжить", style: .primary)
}
.padding(.horizontal, SpacingTokens.l)
```

---

#### Шаг 7 — Введение в скрининг (OnboardingScreeningIntroView)
**Контур:** universal
**Статус:** спека M7.2

**Layout**
- Background: `Kid.bg`
- Hero иллюстрация + объяснение

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    HSLottieContainer(animation: "screening_intro")  // 200×200pt, autoplay, loop: false
    Text("Проверим, как говорит малыш")  // title(24), Kid.ink, center
    Text("Ляля попросит повторить несколько слов. Это займёт 2–3 минуты.")
        // body(15) → 22pt в kid контуре, Kid.inkMuted, center, lineSpacing relaxed
    HSButton("Начать проверку", style: .primary)
    HSButton("Пропустить", style: .ghost)  // .infinity × 44pt
}
.padding(.horizontal, SpacingTokens.l)
```

**Маскот «Ляля»**
- Состояние: `speaking` → затем `listening`
- Триггер: `riveViewModel.triggerInput("speak")` при появлении экрана

---

#### Шаг 8 — Разрешения (OnboardingPermissionsView)
**Контур:** universal → см. отдельные спеки Permissions
**Статус:** спека M7.2

Переадресует на 4 последовательных экрана `PermissionsMicView`, `PermissionsCameraView`, `PermissionsNotificationsView`, `PermissionsFaceTrackingView`.

---

#### Шаг 9 — Загрузка контент-пака (OnboardingPackDownloadView)
**Контур:** universal
**Статус:** спека M7.2

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    HSMascotView(state: .thinking)  // 120×120pt
    Text("Готовим упражнения")  // title(24), Kid.ink
    HSProgressBar(progress: downloadProgress)  // .infinity × 8pt
    Text("Загружаем первый пак звуков…")  // caption(12), Kid.inkMuted
    // После завершения:
    HSMascotView(state: .celebrating)  // автопереход
}
.padding(.horizontal, SpacingTokens.l)
```

**Анимации**
- Progress bar: анимированный fill, `outQuick`
- При complete: маскот celebrating + auto-переход через 1.5s

---

#### Шаг 10 — Готово (OnboardingCompleteView)
**Контур:** universal
**Статус:** спека M7.2

**Иерархия**
```
ZStack {
    Kid.bg  // full bleed
    VStack(spacing: SpacingTokens.xxl) {
        HSMascotView(state: .celebrating)  // 180×180pt
        Text("Всё готово!")  // kidDisplay(40), Kid.ink
        Text("Начинаем заниматься!")  // title(24), Kid.inkMuted
        HSButton("Поехали!", style: .primary)  // .infinity × 56pt, bounce animation
    }
}
```

**Анимации**
- HSSticker конфетти: появляется за 0.5s после старта экрана
- Кнопка: scale 0.9→1, `.bounce`, задержка 1.0s

---

### ДЕМО-РЕЖИМ

---

#### Демо — Сплеш (DemoSplashView)
**Контур:** kid (демо)
**Статус:** спека M7.2

**Layout**
- Full screen, `Kid.bg`
- Логотип HappySpeech 120×120pt (центр)
- Маскот: `celebrating`, 200×200pt снизу логотипа
- Текст «Попробуй бесплатно»: `title(24)`, `Kid.ink`
- Кнопка «Начать демо»: `.infinity × 56pt`, style `.primary`
- Кнопка «Войти»: `.infinity × 44pt`, style `.ghost`

---

#### Демо — Детский главный (DemoChildHomeView)
**Контур:** kid
**Статус:** спека M7.2

Использует стандартный `ChildHomeView` с `isDemo: true`. Баннер вверху:
- `HSCard` — `Brand.butter` background, 16pt padding
- Text «Демо-режим • 3 упражнения»: `caption(12)`, `Kid.ink`
- Кнопка «Зарегистрироваться»: `caption(12)`, `Brand.primary`, bold

---

#### Демо — Урок (DemoLessonView)
**Контур:** kid
**Статус:** спека M7.2

Стандартный `LessonPlayer` с ограничением до 1 игры. После завершения — переход на `DemoRewardView`.

---

#### Демо — AR (DemoARView)
**Контур:** kid
**Статус:** спека M7.2

`ARZoneView` с locked-оверлеем на 80% игр. Оверлей:
- Полупрозрачный `Kid.bgDeep` 0.7 opacity
- Text «Разблокируй в полной версии»: `title(24)`, Kid.ink
- HSButton «Зарегистрироваться»: `.primary`, .infinity × 56pt

---

#### Демо — Награда (DemoRewardView)
**Контур:** kid
**Статус:** спека M7.2

Полный `SessionCompleteView` с одной наградой. Кнопка «Продолжить» ведёт на `DemoParentView`.

---

#### Демо — Родительский (DemoParentView)
**Контур:** parent
**Статус:** спека M7.2

Стандартный `ParentHomeView` с заглушками данных (имитация недели). Баннер «Полный прогресс доступен после регистрации».

---

#### Демо — Настройки (DemoSettingsView)
**Контур:** parent
**Статус:** спека M7.2

`SettingsView` с disabled-состояниями для всех критических разделов кроме темы.

---

### РОДИТЕЛЬСКИЙ КОНТУР

---

#### ParentHome — Дашборд (8 карточек)
**Контур:** parent
**Статус:** спека M7.2

**Layout**
- Background: `Parent.bg`
- `NavigationStack` + `ScrollView`
- Horizontal padding: `SpacingTokens.l (16pt)`
- Vertical spacing между карточками: `SpacingTokens.l (16pt)`

**Иерархия**
```
NavigationStack {
    ScrollView {
        VStack(spacing: SpacingTokens.l) {
            // 1. Сегодня
            HSCard { TodayCardContent() }
                .frame(maxWidth: .infinity, minHeight: 120)
            // 2. Неделя
            HSCard { WeekChartContent() }    // HSChart, высота 160pt
                .frame(maxWidth: .infinity, minHeight: 200)
            // 3. Лучший звук недели
            HSCard { BestSoundContent() }
                .frame(maxWidth: .infinity, minHeight: 80)
            // 4. Рекомендации
            HSCard { RecommendationContent() }
                .frame(maxWidth: .infinity, minHeight: 100)
            // 5. Запланированные упражнения
            HSCard { PlannedExercisesContent() }
                .frame(maxWidth: .infinity, minHeight: 120)
            // 6. История сессий (лента)
            HSCard { SessionTimelineContent() }  // HSSessionTimeline
                .frame(maxWidth: .infinity, minHeight: 100)
            // 7. Переключатель режима специалиста
            HSCard { SpecialistModeToggle() }
                .frame(maxWidth: .infinity, minHeight: 72)
            // 8. Модельные паки
            HSCard { ModelPacksContent() }
                .frame(maxWidth: .infinity, minHeight: 80)
        }
        .padding(.horizontal, SpacingTokens.l)
        .padding(.vertical, SpacingTokens.l)
    }
    .navigationTitle("Прогресс")
    .navigationBarTitleDisplayMode(.large)
}
```

**Карточка 1 «Сегодня»**
- Иконка: `calendar.circle.fill`, 32pt, `Parent.accent`
- Title: `headline(18)` «Сегодня»
- Subtitle: `body(15)` «Завершено 2 из 3 заданий»
- Progress bar: `HSProgressBar(progress: 0.67)`, высота 6pt
- Background: `Parent.surface`

**Карточка 2 «Неделя»**
- `HSChart(data: weeklyData)` — линейный график, высота 120pt
- X-ось: 7 дней, Y-ось: 0–100% success rate
- Цвет линии: `Parent.accent`

**Карточка 3 «Лучший звук»**
- `HSSoundMapCell(sound: bestSound)` встроенный в карточку
- Бейдж «Лучший прогресс»: `Brand.mint`

**Карточка 4 «Рекомендации»**
- Иконка: `lightbulb.fill`, `Brand.butter`
- Text до 3 строк: `body(15)`, `Parent.ink`, `lineLimit(3)`

**Карточка 5 «Запланированные упражнения»**
- Список до 3 пунктов `HStack(icon, title, time)`
- "Посмотреть все" link: `caption(12)`, `Parent.accent`

**Карточка 6 «История»**
- `HSSessionTimeline(sessions: recentSessions)` — горизонтальный скролл

**Карточка 7 «Режим специалиста»**
- `Toggle("Режим специалиста", isOn: $specialistMode)`, tint `Spec.accent`
- caption: «Дополнительные инструменты анализа»

**Карточка 8 «Модельные паки»**
- Название активного пака: `headline(18)`
- Кнопка «Сменить»: style `.ghost`, `.infinity × 44pt`

**Accessibility**
- Все карточки: `accessibilityElement(children: .contain)`
- Заголовки карточек: `accessibilityAddTraits(.isHeader)`
- Min touch target: 44pt (parent контур)

---

#### ParentHome — Детали сессии (SessionDetailView)
**Контур:** parent
**Статус:** спека M7.2

**Layout**
- `NavigationStack` с `.navigationTitle(sessionDate)`
- Background: `Parent.bg`

**Иерархия**
```
ScrollView {
    VStack(alignment: .leading, spacing: SpacingTokens.xxl) {
        // Шапка
        HStack {
            VStack(alignment: .leading) {
                Text(sessionDate)     // headline(18), Parent.ink
                Text(sessionDuration) // caption(12), Parent.inkMuted
            }
            Spacer()
            HSBadge(score: overallScore)  // процент
        }
        .padding(SpacingTokens.l)
        .background(Parent.surface, in: RoundedRectangle(radius: RadiusTokens.card))
        // Звуки — список
        Text("Результаты по звукам")  // title(24)
        ForEach(soundResults) { r in
            HSSoundMapCell(sound: r.sound, progress: r.score, stage: r.stage)
        }
        // График
        HSChart(data: sessionTimeline)
            .frame(height: 180)
        // Заметки логопеда (если есть)
        if hasNotes {
            HSCard { Text(notes).body(15) }
        }
        // Кнопки
        HSButton("Сохранить в PDF", style: .secondary)
        HSButton("Поделиться", style: .ghost)
    }
    .padding(.horizontal, SpacingTokens.l)
}
```

---

#### ParentHome — Недельный график (WeeklyChartView)
**Контур:** parent
**Статус:** спека M7.2

- Full-screen sheet / `.presentationDetents([.large])`
- `HSChart` на всю ширину, высота 280pt
- Фильтры периода: 7 / 30 / 90 дней (`HSChip` горизонтальный список)
- По звукам: `LazyVGrid(columns: 2)` с `HSSoundMapCell` для каждого звука
- Background: `Parent.bg`

---

### СПЕЦИАЛИСТСКИЙ КОНТУР

---

#### Specialist — Главный (SpecialistHomeView)
**Контур:** specialist
**Статус:** спека M7.2

**Layout**
- `NavigationSplitView` (iPad-ready) или `NavigationStack` (iPhone)
- Background: `Spec.bg`
- Sidebar (iPad): список пациентов
- Detail: текущий пациент

**Иерархия (iPhone)**
```
NavigationStack {
    List {
        Section("Активные программы") {
            ForEach(programs) { p in
                NavigationLink(destination: ProgramEditorView(program: p)) {
                    SpecProgramRow(program: p)
                }
            }
        }
        Section("Отчёты") {
            NavigationLink("Все отчёты") { ReportsListView() }
        }
        Section("История сессий") {
            NavigationLink("Сессии") { SessionReviewListView() }
        }
    }
    .navigationTitle("Панель специалиста")
}
```

**Палитра**
- List background: `Spec.bg`
- Row background: `Spec.surface`
- Separator: `Spec.line`
- Accent: `Spec.accent`

---

#### Specialist — Редактор программы (ProgramEditorView)
**Контур:** specialist
**Статус:** спека M7.2

**Layout**
- `NavigationStack` с toolbar «Сохранить»
- Background: `Spec.bg`

**Иерархия**
```
Form {
    Section("Данные пациента") {
        TextField("Имя", text: $name)
        DatePicker("Дата рождения", ...)
        Picker("Группа звуков", ...) { ForEach(SoundFamily.allCases) }
    }
    Section("Этапы работы") {
        ForEach(stages, editActions: .all) { s in
            SpecStageRow(stage: s)  // drag-to-reorder
        }
        Button("Добавить этап") { }
    }
    Section("Расписание") {
        Stepper("Сессий в неделю: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
        Toggle("Домашние задания", isOn: $homeTasks)
    }
}
.background(Spec.bg)
```

**Accessibility**
- Все поля: accessibilityLabel на русском
- Drag handle: accessibilityAction для перемещения

---

#### Specialist — Список отчётов (ReportsListView)
**Контур:** specialist
**Статус:** спека M7.2

**Layout**
- `List` с `Section` по месяцам
- Background: `Spec.bg`

**Строка отчёта**
```
HStack {
    VStack(alignment: .leading) {
        Text(reportTitle)   // headline(18), Spec.ink
        Text(dateRange)     // caption(12), Spec.inkMuted
    }
    Spacer()
    Image(systemName: "chevron.right")  // Spec.inkSoft
}
.frame(minHeight: 44)
.padding(.vertical, SpacingTokens.s)
```

---

#### Specialist — Детали сессии (SessionReviewDetailView)
**Контур:** specialist
**Статус:** спека M7.2

**Layout**
- `ScrollView` + `VStack`
- Background: `Spec.bg`

**Иерархия**
```
VStack(alignment: .leading, spacing: SpacingTokens.xxl) {
    // Метрики
    LazyVGrid(columns: 3) {
        SpecMetricCell(title: "Точность", value: "\(accuracy)%")
        SpecMetricCell(title: "Слов", value: "\(wordCount)")
        SpecMetricCell(title: "Длит.", value: "\(duration) мин")
    }
    // Waveform попытки
    HSAudioWaveform(audio: attempt.audio)
        .frame(height: 80)
    // Граф прогресса по звуку
    HSChart(data: soundProgress)
        .frame(height: 200)
    // Заметки
    TextEditor(text: $notes)
        .frame(minHeight: 120)
        .background(Spec.surface, in: RoundedRectangle(radius: RadiusTokens.input))
    // Действия
    HStack {
        HSButton("Экспорт PDF", style: .secondary)
        HSButton("Поделиться", style: .ghost)
    }
}
.padding(.horizontal, SpacingTokens.l)
```

---

### КАРТА МИРА

---

#### WorldMap — Главная (WorldMapView — 5 зон)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- Full-screen `ZStack`
- Background: `Kid.bgDeep` (тёмно-синий для ночного неба или мягкий) + Lottie фон
- Safe area insets уважаются, контент внутри

**Зоны**

| Зона | Цвет фона | Семейство | Позиция |
|---|---|---|---|
| Свистящие | `SoundFamilyColors.Whistling.bg` | С, З, Ц | Левый верх |
| Шипящие | `SoundFamilyColors.Hissing.bg` | Ш, Ж, Ч, Щ | Правый верх |
| Соноры | `SoundFamilyColors.Sonorant.bg` | Р, Рь, Л, Ль | Центр |
| Велярные | `SoundFamilyColors.Velar.bg` | К, Г, Х | Левый низ |
| Йот | `SoundFamilyColors.Vowels.bg` | Й, гласные | Правый низ |

**Компонент зоны `HSWorldMapZone`**
- Размер: 140×140pt
- Lottie hero-анимация зоны: autoplay, loop
- Progress indicator: `HSProgressBar` под зоной, ширина 120pt
- Label: `headline(18)`, `Kid.ink`, под progress
- Locked state: `Brand.lilac` overlay, иконка `lock.fill`
- Touch target: 140×140pt ≥ 56pt ✓

**Маскот «Ляля»**
- Плавает над картой, 80×80pt
- Состояние: `idle` → `speaking` при нажатии на зону
- Позиция: верхний центр экрана

**Анимации**
- Tap на зону: scale 1→1.1→1, `.spring`, + sound-family accent glow
- Новая зона разблокирована: `.bounce` + HSSticker confetti

**Accessibility**
- Каждая зона: accessibilityRole(.button), label "Зона свистящих звуков, прогресс 40%, нажмите для открытия"
- Locked: "Зона заблокирована, завершите предыдущий уровень"

---

#### WorldMap — Список уровней зоны (ZoneLevelsView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- Sheet `.presentationDetents([.large])`
- Background: звуковой `SoundFamilyColors.X.bg`

**Иерархия**
```
VStack {
    // Заголовок зоны
    Text("Свистящие звуки")  // title(24), Kid.ink
    Text("С · З · Ц")         // headline(18), Kid.inkMuted
    // Лента уровней
    ScrollView(.horizontal) {
        HStack(spacing: SpacingTokens.l) {
            ForEach(levels) { level in
                HSCard { LevelCell(level: level) }  // 120×140pt
            }
        }
        .padding(.horizontal, SpacingTokens.l)
    }
    // Кнопка начать
    HSButton("Начать занятие", style: .primary)  // .infinity × 56pt
}
.padding(.vertical, SpacingTokens.xxl)
```

**LevelCell**
- Locked: `Kid.surfaceAlt`, иконка `lock.fill` 24pt, label серый
- Unlocked: `Kid.surface`, номер уровня `kidDisplay(32)`, `Brand.primary`
- Completed: `Brand.mint` border 2pt, звёзды 3шт 16pt

---

### НАГРАДЫ

---

#### Rewards — Альбом наград (RewardsAlbumView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- `NavigationStack`
- Background: `Kid.bg`
- `LazyVGrid(columns: 3, spacing: SpacingTokens.l)` — `HSRewardAlbumGrid`

**Иерархия**
```
NavigationStack {
    ScrollView {
        VStack(alignment: .leading, spacing: SpacingTokens.xl) {
            // Счётчик
            Text("Собрано \(unlocked) из \(total)")  // headline(18), Kid.inkMuted
            // Грид наград
            HSRewardAlbumGrid(stickers: allStickers)
                .padding(.horizontal, SpacingTokens.l)
        }
        .padding(.top, SpacingTokens.l)
    }
    .navigationTitle("Мои награды")
}
```

---

#### Rewards — Детали стикера (StickerDetailView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- Sheet `.presentationDetents([.medium])`
- Background: `Kid.bg`

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    HSSticker(sticker: sticker)  // 180×180pt, animated если unlocked
    Text(sticker.name)           // title(24), Kid.ink
    Text(sticker.earnedDescription)  // body(22pt в kid), Kid.inkMuted
    if sticker.isLocked {
        HSCard {
            Text("Выполни ещё \(sticker.remaining) заданий для разблокировки")
                .body(15).multilineTextAlignment(.center)
        }
    }
    HSButton("Готово", style: .secondary)  // .infinity × 56pt
}
.padding(.horizontal, SpacingTokens.l)
.padding(.vertical, SpacingTokens.xxl)
```

---

#### Rewards — Стрик (StreakModalView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- `.sheet` `.presentationDetents([.medium])`
- Background: `Kid.bg` + `Brand.butter` gradient overlay

**Иерархия**
```
VStack(spacing: SpacingTokens.xl) {
    HSLottieContainer(animation: "streak_fire")  // 120×120pt, autoplay, loop
    Text("🔥 \(streakDays) дней подряд!")  // kidDisplay(40), Kid.ink
    Text("Так держать!")                      // title(24), Kid.inkMuted
    HSButton("Ура!", style: .primary)          // .infinity × 56pt, bounce anim
}
.padding(.horizontal, SpacingTokens.l)
.padding(.vertical, SpacingTokens.xxxl)
```

---

### ПРОГРЕСС (Deep View)

---

#### ProgressDashboard — Детальный вид по звуку (SoundProgressDetailView)
**Контур:** parent / specialist
**Статус:** спека M7.2

**Layout**
- `NavigationStack` с `.navigationTitle(soundName)`
- Background: `Parent.bg` / `Spec.bg`

**Иерархия**
```
ScrollView {
    VStack(alignment: .leading, spacing: SpacingTokens.xxl) {
        // Заголовок
        HStack {
            Circle()
                .fill(SoundFamilyColors.hue(for: family))
                .frame(width: 48, height: 48)
                .overlay(Text(soundSymbol).title(24).foregroundStyle(.white))
            VStack(alignment: .leading) {
                Text(soundName)     // title(24)
                Text(familyName)   // caption(12), inkMuted
            }
            Spacer()
            Text("\(accuracy)%")  // kidDisplay(32), Brand.primary (parent) / Spec.accent (spec)
        }
        // График за 30 дней
        Text("Прогресс за 30 дней")  // headline(18)
        HSChart(data: thirtyDayData)
            .frame(height: 200)
        // Этапы работы
        Text("Этапы")  // headline(18)
        ForEach(stages) { stage in
            HStack {
                Image(systemName: stage.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(stage.isComplete ? Semantic.success : Parent.inkSoft)
                Text(stage.name)  // body(15)
                Spacer()
                Text(stage.dateCompleted ?? "—")  // caption(12), inkMuted
            }
            .frame(minHeight: 44)
        }
        // Последние попытки
        Text("Последние попытки")  // headline(18)
        ForEach(recentAttempts) { attempt in
            HSCard {
                HStack {
                    HSAudioWaveform(audio: attempt.audio).frame(height: 40)
                    Spacer()
                    Text("\(attempt.score)%")  // mono(13)
                    HSBadge(score: attempt.score)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
    }
    .padding(.horizontal, SpacingTokens.l)
}
```

---

### НАСТРОЙКИ

---

#### Settings — Главный (SettingsView — 7 разделов)
**Контур:** parent
**Статус:** спека M7.2

**Layout**
- `NavigationStack` + `List`
- Background: `Parent.bg`

**Разделы**
```
List {
    // 1. Тема
    Section("Оформление") {
        Picker("Тема", selection: $colorScheme) {
            Text("Системная").tag(ColorScheme?.none)
            Text("Светлая").tag(ColorScheme?.some(.light))
            Text("Тёмная").tag(ColorScheme?.some(.dark))
        }
        .pickerStyle(.segmented)
    }
    // 2. Уведомления
    Section("Уведомления") {
        NavigationLink("Настройки напоминаний") { NotificationSettingsView() }
        Toggle("Ежедневные напоминания", isOn: $dailyReminders)
    }
    // 3. Модельные паки
    Section("Контент") {
        NavigationLink("Языковые паки") { ModelPacksView() }
    }
    // 4. Конфиденциальность
    Section("Конфиденциальность") {
        NavigationLink("Управление данными") { PrivacyView() }
    }
    // 5. Экспорт данных
    Section("Данные") {
        Button("Экспортировать прогресс") { exportData() }
        NavigationLink("История сессий") { SessionHistoryView() }
    }
    // 6. Удаление аккаунта
    Section {
        Button("Удалить аккаунт", role: .destructive) { showDeleteAlert = true }
    }
    // 7. О приложении
    Section("О приложении") {
        LabeledContent("Версия", value: appVersion)
        NavigationLink("Политика конфиденциальности") { PrivacyPolicyView() }
        NavigationLink("Условия использования") { TermsView() }
    }
}
.listStyle(.insetGrouped)
```

**Accessibility**
- Деструктивная кнопка: accessibilityLabel "Удалить аккаунт — необратимое действие"
- All toggle: accessibilityLabel с описанием действия

---

### РАЗРЕШЕНИЯ

---

#### Permissions — Микрофон (PermissionsMicView)
**Контур:** universal
**Статус:** спека M7.2

**Layout**
- Full-screen `VStack`, centred
- Background: `Kid.bg`

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    Spacer()
    HSLottieContainer(animation: "permission_mic")  // 160×160pt
    Text("Нужен микрофон")              // title(24), Kid.ink, center
    Text("Ляля слушает, как ты говоришь, и помогает улучшить звуки.")
        // body(22pt kid), Kid.inkMuted, center, lineSpacing relaxed
    Spacer()
    HSButton("Разрешить", style: .primary)   // .infinity × 56pt
    HSButton("Потом", style: .ghost)          // .infinity × 44pt
}
.padding(.horizontal, SpacingTokens.l)
```

**Accessibility**
- VoiceOver: "Разрешить доступ к микрофону"
- При отказе: `HSToast` с пояснением почему это важно

---

#### Permissions — Камера (PermissionsCameraView)
**Контур:** universal
**Статус:** спека M7.2

Аналогично `PermissionsMicView`, но:
- Lottie: `permission_camera` — анимация камеры 160×160pt
- Заголовок: «Нужна камера»
- Текст: «Для AR-упражнений с артикуляцией мы используем камеру. Видео не сохраняется.»
- Кнопка разрешить: «Разрешить камеру»

---

#### Permissions — Уведомления (PermissionsNotificationsView)
**Контур:** universal
**Статус:** спека M7.2

- Lottie: `permission_notifications` — колокольчик 160×160pt
- Заголовок: «Напомним о занятиях»
- Текст: «Разрешите уведомления, чтобы Ляля напомнила о ежедневных упражнениях.»

---

#### Permissions — Face Tracking (PermissionsFaceTrackingView)
**Контур:** universal
**Статус:** спека M7.2

- Lottie: `permission_face` — лицо с точками 160×160pt
- Заголовок: «Слежение за лицом»
- Текст: «Для упражнений на артикуляцию нам нужно видеть движения губ и языка. Данные не покидают устройство.»
- Дополнительный HSCard с иконкой щита: «Все данные остаются на вашем устройстве»

---

### СКРИНИНГ

---

#### Screening — Введение (ScreeningIntroView)
**Контур:** kid / parent
**Статус:** спека M7.2

**Layout**
- Background: `Kid.bg`
- Scrollable (для маленьких экранов)

**Иерархия**
```
ScrollView {
    VStack(spacing: SpacingTokens.xxl) {
        HSMascotView(state: .speaking)  // 140×140pt
        Text("Давай проверим звуки!")   // title(24), Kid.ink, center
        // 3 блока скрининга
        ForEach(blocks) { block in
            HSCard {
                HStack(spacing: SpacingTokens.l) {
                    Text(block.emoji).font(.system(size: 40))
                    VStack(alignment: .leading) {
                        Text(block.title)  // headline(18), Kid.ink
                        Text(block.hint)   // body(22pt), Kid.inkMuted
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
        }
        HSButton("Начать!", style: .primary)  // .infinity × 56pt
    }
    .padding(.horizontal, SpacingTokens.l)
    .padding(.vertical, SpacingTokens.xxl)
}
```

---

#### Screening — Переход блока (ScreeningBlockTransitionView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- Full-screen overlay, `Kid.bg`
- Длительность показа: 2.0s, затем auto-dismiss

**Иерархия**
```
ZStack {
    Kid.bg.ignoresSafeArea()
    VStack(spacing: SpacingTokens.xl) {
        HSMascotView(state: .encouraging)  // 120×120pt
        Text("Теперь слова с \(nextSound)!")  // title(24), Kid.ink
        Text("Блок \(blockIndex) из 3")        // caption(12), Kid.inkMuted
    }
}
```

**Анимации**
- Появление: opacity 0→1, `.outQuick`
- Исчезновение: opacity 1→0, `.outQuick` задержка 1.5s

---

### ИСТОРИЯ СЕССИЙ

---

#### SessionHistory — Список (SessionHistoryView)
**Контур:** parent / specialist
**Статус:** спека M7.2

**Layout**
- `NavigationStack` + `List`
- Background: `Parent.bg`

**Иерархия**
```
NavigationStack {
    List {
        ForEach(groupedByMonth) { month in
            Section(month.title) {
                ForEach(month.sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionHistoryRow(session: session)
                    }
                }
            }
        }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("История сессий")
    .searchable(text: $searchQuery, prompt: "Поиск по дате")
}
```

**SessionHistoryRow**
```
HStack(spacing: SpacingTokens.l) {
    // Дата
    VStack {
        Text(day)    // mono(13), Parent.ink
        Text(month)  // caption(12), Parent.inkMuted
    }
    .frame(width: 40)
    // Иконка типа
    Circle().fill(sessionTypeColor).frame(width: 32, height: 32)
        .overlay(Image(systemName: sessionIcon).foregroundStyle(.white))
    // Описание
    VStack(alignment: .leading) {
        Text(sessionTitle)  // headline(18), Parent.ink
        Text("\(duration) мин · \(wordCount) слов")  // caption(12), Parent.inkMuted
    }
    Spacer()
    HSBadge(score: score)
}
.frame(minHeight: 44)
```

**Accessibility**
- Строка: accessibilityElement(children: .combine)
- label: "Сессия \(date), \(duration) минут, оценка \(score) процентов"

---

#### SessionHistory — Детали (SessionDetailView)
**Контур:** parent
**Статус:** спека M7.2

Используется та же спека что и «ParentHome — Детали сессии» выше.

---

### ДОМАШНИЕ ЗАДАНИЯ

---

#### HomeTasks — Список (HomeTasksListView)
**Контур:** kid / parent
**Статус:** спека M7.2

**Layout (kid)**
- Background: `Kid.bg`
- `ScrollView` + `LazyVStack`

**Иерархия**
```
VStack(spacing: SpacingTokens.l) {
    // Маскот с подсказкой
    HStack {
        HSMascotView(state: .encouraging)  // 80×80pt
        HSCard {
            Text("Сегодня 2 задания от логопеда!")  // title(22pt), Kid.ink
        }
        .frame(maxWidth: .infinity)
    }
    // Список заданий
    ForEach(tasks) { task in
        HSCard {
            HStack {
                Image(systemName: task.icon).frame(width: 44, height: 44)
                    .foregroundStyle(task.isCompleted ? Semantic.success : Brand.primary)
                VStack(alignment: .leading) {
                    Text(task.title)    // headline(18), Kid.ink
                    Text(task.subtitle) // body(22pt), Kid.inkMuted
                }
                Spacer()
                if task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Semantic.success).font(.title2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .onTapGesture { router.push(task) }
    }
}
.padding(.horizontal, SpacingTokens.l)
```

---

#### HomeTasks — Детали (HomeTaskDetailView)
**Контур:** kid
**Статус:** спека M7.2

**Layout**
- Полноэкранный `VStack`
- Background: `Kid.bg`

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    // Задание
    HSCard {
        VStack(spacing: SpacingTokens.l) {
            Text(task.instruction)  // title(24), Kid.ink, center
            if let image = task.image {
                Image(image).resizable().scaledToFit().frame(height: 160)
            }
        }
    }
    .frame(maxWidth: .infinity)
    // Маскот
    HSMascotView(state: recordingState == .recording ? .listening : .idle)  // 120×120pt
    // Кнопка записи
    HSAudioRecorderView(state: $recordingState)  // 56×56pt центр
    Spacer()
    // Отправить
    HSButton("Отправить логопеду", style: .primary)
        .disabled(!hasRecording)
}
.padding(.horizontal, SpacingTokens.l)
```

---

#### HomeTasks — Выполненные (HomeTasksCompletedView)
**Контур:** kid / parent
**Статус:** спека M7.2

**Layout**
- `VStack` + `LazyVStack` выполненных
- Background: `Kid.bg`

Аналогично `HomeTasksListView` но с фильтром `task.isCompleted == true`.
Вверху: `HSBadge` «Выполнено: \(count)» в `Brand.mint`.
Пустое состояние: `HSLottieContainer(animation: "empty_tasks")` + Text «Пока нет выполненных заданий».

---

### ОФЛАЙН

---

#### OfflineState — Полный (OfflineStateView)
**Контур:** universal
**Статус:** спека M7.2

**Layout**
- Full-screen, intercepts navigation
- Background: `Kid.bg` (kid) / `Parent.bg` (parent)

**Иерархия**
```
VStack(spacing: SpacingTokens.xxl) {
    Spacer()
    HSLottieContainer(animation: "offline_cloud")  // 160×160pt, loop
    Text("Нет подключения")         // title(24), ink
    Text("Не переживай — можно заниматься офлайн! Прогресс сохранится и синхронизируется позже.")
        // body(22pt kid / 15pt parent), inkMuted, center
    Spacer()
    HSButton("Продолжить офлайн", style: .primary)   // .infinity × 56pt
    HSButton("Обновить подключение", style: .ghost)  // .infinity × 44pt
}
.padding(.horizontal, SpacingTokens.l)
```

**Маскот «Ляля»** (kid контур)
- `HSMascotView(state: .encouraging)` добавляется над текстом, 100×100pt

**Accessibility**
- VoiceOver первым читает: "Нет подключения к интернету"
- Автоматически исчезает при восстановлении сети

---

## M7.3 — Компоненты DesignSystem (11 новых)

### 1. HSChart

**Назначение:** линейный/барный график успеваемости по звукам (Swift Charts).

**Публичный API**
```swift
public struct HSChart: View {
    public enum Style { case line, bar }
    public init(
        data: [(date: Date, value: Double)],
        style: Style = .line,
        height: CGFloat = 200,
        accentColor: Color = ColorTokens.Parent.accent,
        showGrid: Bool = true,
        yDomain: ClosedRange<Double> = 0...100
    )
}
```

**Ключевые особенности**
- `Chart { LineMark / BarMark }` из Swift Charts (iOS 16+)
- Y-ось: 0–100%, метки «0%», «50%», «100%»
- X-ось: даты, локализованный формат «dd MMM»
- Цвет линии: `accentColor`, area fill с opacity 0.15
- Анимация данных: `.animation(.spring, value: data)` — при Reduced Motion отключить
- Accessibility: `chartAccessibilityLabel` «График прогресса за \(n) дней»

---

### 2. HSAudioRecorderView

**Назначение:** кнопка записи с визуальным waveform, 3 состояния.

**Публичный API**
```swift
public enum RecorderState { case idle, recording, scoring }

public struct HSAudioRecorderView: View {
    @Binding public var state: RecorderState
    public var onRecordingComplete: (URL) -> Void
    public init(state: Binding<RecorderState>, onRecordingComplete: @escaping (URL) -> Void)
}
```

**Состояния**

| State | Визуал |
|---|---|
| `idle` | Круглая кнопка 80×80pt, `Brand.primary`, иконка `mic.fill` |
| `recording` | Анимированный пульс `Brand.rose`, иконка `stop.fill`, waveform под кнопкой |
| `scoring` | Spinner `Brand.mint`, иконка `waveform`, «Анализируем…» |

- Waveform: `HSAudioWaveform` встроенный, показывается только в `recording`
- Haptic: `.impactOccurred(.medium)` при начале, `.notificationOccurred(.success)` при завершении
- Touch target: кнопка 80×80pt > 56pt ✓

---

### 3. HSSoundMapCell

**Назначение:** карточка одного звука с иконкой, progress ring, этапом.

**Публичный API**
```swift
public struct HSSoundMapCell: View {
    public init(
        sound: String,              // «Р», «Ш», «С»
        soundFamily: SoundFamily,
        progress: Double,           // 0.0–1.0
        stage: String,              // «Слоги», «Слова»
        isLocked: Bool = false,
        action: (() -> Void)? = nil
    )
}
```

**Визуал**
- Размер: 100×120pt (в гриде) / .infinity × 72pt (в списке)
- Background: `SoundFamilyColors.background(for: soundFamily)` opacity 0.3
- Иконка: Circle 48pt, fill `SoundFamilyColors.hue(for: soundFamily)`, Text(sound) `title(24)` white
- Progress ring: `Circle` stroke 4pt, `Brand.mint`, под иконкой
- Stage text: `caption(12)`, `Kid.inkMuted`
- Locked: overlay `Kid.surfaceAlt` opacity 0.8 + `lock.fill` 20pt

---

### 4. HSWorldMapZone

**Назначение:** интерактивная зона карты мира с Lottie + progress.

**Публичный API**
```swift
public struct HSWorldMapZone: View {
    public init(
        zoneName: String,
        soundFamily: SoundFamily,
        lottieAnimation: String,    // имя файла .json
        progress: Double,           // 0.0–1.0
        isLocked: Bool,
        action: @escaping () -> Void
    )
}
```

**Визуал**
- Размер: 140×160pt
- `HSLottieContainer` внутри, 100×100pt, autoplay, loop
- Progress bar: `HSProgressBar` ширина 120pt, высота 6pt
- Label: `caption(12)`, `Kid.ink`, center
- Locked overlay: `Kid.bgSoft` opacity 0.85 + `lock.fill` 32pt, `Kid.inkSoft`
- Tap animation: scale 1.0→1.08→1.0, `.spring`

---

### 5. HSSessionTimeline

**Назначение:** горизонтальная лента карточек сессий.

**Публичный API**
```swift
public struct HSSessionTimeline: View {
    public init(
        sessions: [SessionSummary],
        onTap: @escaping (SessionSummary) -> Void
    )
}

public struct SessionSummary: Identifiable {
    public let id: UUID
    public let date: Date
    public let durationMinutes: Int
    public let overallScore: Double
    public let soundsFocused: [String]
}
```

**Визуал**
- `ScrollView(.horizontal, showsIndicators: false)`
- Каждая карточка: 100×120pt, `Parent.surface`, `RadiusTokens.card`
- Содержимое карточки: дата `caption(12)`, длительность `mono(13)`, score `HSBadge`
- Горизонтальный padding: `SpacingTokens.l`

---

### 6. HSRewardAlbumGrid

**Назначение:** LazyVGrid стикеров с locked/unlocked состояниями.

**Публичный API**
```swift
public struct HSRewardAlbumGrid: View {
    public init(
        stickers: [StickerItem],
        columns: Int = 3,
        onTap: @escaping (StickerItem) -> Void
    )
}

public struct StickerItem: Identifiable {
    public let id: UUID
    public let imageName: String
    public let name: String
    public let isUnlocked: Bool
    public let earnedDescription: String
    public let remaining: Int       // для locked: сколько осталось
}
```

**Визуал**
- `LazyVGrid(columns: Array(repeating: .flexible(minimum: 100), count: columns))`
- Разблокированный: `HSSticker(imageName:)`, 96×96pt, полноцветный
- Заблокированный: та же картинка grayscale + `Kid.surfaceAlt` overlay opacity 0.6 + `lock.fill`
- Анимация разблокировки: scale 0→1.2→1, `.bounce` + confetti

---

### 7. HSLottieContainer

**Назначение:** обёртка `LottieAnimationView` с unified API.

**Публичный API**
```swift
public struct HSLottieContainer: View {
    public init(
        animation: String,          // имя файла без .json
        bundle: Bundle = .main,
        loopMode: LottieLoopMode = .playOnce,
        autoPlay: Bool = true,
        speed: Double = 1.0,
        onComplete: (() -> Void)? = nil
    )
}
```

**Ключевые особенности**
- `UIViewRepresentable` внутри → `LottieAnimationView`
- При Reduced Motion: показывает первый кадр (`currentProgress = 0`), не проигрывает
- `loopMode: .loop` для idle-анимаций, `.playOnce` для наград
- `bundle` параметр для поддержки тестов с mock-ресурсами

---

### 8. HSRiveView

**Назначение:** обёртка `RiveViewModel` с state machine API для маскота «Ляля».

**Публичный API**
```swift
public struct HSRiveView: View {
    public init(
        fileName: String,           // «lyalya» — имя .riv файла
        stateMachine: String,       // «LyalyaStateMachine»
        fit: RiveFit = .contain,
        alignment: RiveAlignment = .center
    )
}

// Управление из SwiftUI:
public class HSRiveController: ObservableObject {
    public func trigger(_ input: String)                          // celebrate, encourage, speak
    public func setBoolean(_ input: String, value: Bool)          // isListening, isTired
    public func setNumber(_ input: String, value: Float)          // emotionIntensity 0…1
}
```

**Состояния маскота**

| State | Trigger/Bool | Описание |
|---|---|---|
| `idle` | начальное | Лёгкое дыхание, `idlePulse` |
| `listening` | `setBoolean("isListening", true)` | Наклон к микрофону |
| `thinking` | `trigger("think")` | Вопросительный жест |
| `celebrating` | `trigger("celebrate")` | Прыжок + конфетти |
| `encouraging` | `trigger("encourage")` | Мягкое подбадривание |
| `speaking` | `trigger("speak")` | Рот движется |
| `tired` | `setBoolean("isTired", true)` | Зевает |

---

### 9. HSARSceneView

**Назначение:** UIViewRepresentable для RealityKit ARView с face tracking.

**Публичный API**
```swift
public struct HSARSceneView: UIViewRepresentable {
    public init(
        configuration: ARFaceTrackingConfiguration = .init(),
        onBlendShapesUpdate: @escaping ([ARFaceAnchor.BlendShapeLocation: Float]) -> Void,
        onError: @escaping (Error) -> Void
    )
}
```

**Ключевые особенности**
- Внутри: `ARView(frame: .zero)` + `ARSession`
- Делегат обновляет `onBlendShapesUpdate` при каждом кадре
- При недоступном Face Tracking: вызывает `onError`
- Освобождает ресурсы в `dismantleUIView` (pause session)
- Требует `NSCameraUsageDescription` в Info.plist

---

### 10. HSLiquidGlassCard

**Назначение:** карточка с iOS 26 Liquid Glass, fallback на материал для iOS 17–25.

**Публичный API**
```swift
public struct HSLiquidGlassCard<Content: View>: View {
    public init(
        cornerRadius: CGFloat = RadiusTokens.card,
        padding: CGFloat = SpacingTokens.cardPadding,
        @ViewBuilder content: () -> Content
    )
}
```

**Ключевые особенности**
- iOS 26+: `.background(.glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius)))` (или доступный API на момент релиза)
- iOS 17–25: `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))`
- Внутренний `content` не знает о платформе
- Тень: `ShadowTokens.card` на обоих платформах

**Применение (M7.5)**
- Parent dashboard cards
- Session summary modal
- Reward reveal overlay
- Specialist program editor palette

---

### 11. HSAccessibleText

**Назначение:** Text с автоматическим Dynamic Type, min scale factor, VoiceOver.

**Публичный API**
```swift
public struct HSAccessibleText: View {
    public init(
        _ text: String,
        font: Font,
        color: Color,
        lineLimit: Int? = nil,
        minimumScaleFactor: CGFloat = 0.75,
        voiceOverLabel: String? = nil,   // кастомный VoiceOver label
        accessibilityHint: String? = nil
    )
}
```

**Ключевые особенности**
- `.font(font)` + `.minimumScaleFactor(minimumScaleFactor)` + `.lineLimit(lineLimit)`
- `.foregroundStyle(color)`
- Если `voiceOverLabel` задан — `accessibilityLabel(voiceOverLabel)`
- Если `accessibilityHint` задан — `accessibilityHint(accessibilityHint)`
- Не переопределяет системный Dynamic Type — работает поверх него

---

## M7.4 — App Icon ТЗ

### Концепт

Маскот Ляля — девочка 5–6 лет с широкой тёплой улыбкой — в кругу на фоне волнового градиента. Иконка ассоциируется с теплотой, речью и детским развитием.

### Технические требования

- Мастер-файл: 1024×1024 PNG, без прозрачности (Any/Dark), с прозрачностью (Tint)
- Углы: Apple скругляет автоматически (не добавлять скругление в мастер)
- Текст в иконке: НЕТ (нарушение Apple guidelines)
- Шрифт элементов: нет текста, только иллюстрация

### Три appearance

#### Any (Light mode)
- Фон: тёплый кремовый градиент `#FFF5E4` → `#FFE4C8` (соответствует `KidBg`)
- Маскот Ляля: 680×680pt центр, плоский стиль, 2–3 цвета
  - Тело: coral-apricot `#FF8C69` (соответствует `BrandPrimary`)
  - Акценты (щёки, бантик): rose `#FFB4A0` (соответствует `BrandRose`)
  - Детали (глаза, рот): тёмный `#3D2C2C`
- Звуковые волны: 3 дуги за маскотом, `Brand.primary` opacity 0.3, stroke 8pt
- Тень маскота: мягкая, `#FF8C69` opacity 0.2, blur 20pt

#### Dark (Dark mode)
- Фон: тёмно-синий градиент `#1A1035` → `#2D1B5E` (глубокий индиго)
- Маскот: светлый вариант, тело `#FFD4B8`, акценты `#FF8C69`
- Звуковые волны: `Brand.lilac` opacity 0.4
- Свечение маскота: мягкое `Brand.lilac` glow, blur 30pt

#### Tint (Monochrome)
- Фон: прозрачный
- Маскот: outline-стиль, stroke 4pt, `#000000` (система применит tint цвет)
- Волны: thin stroke 2pt

### Стиль

- Flat design, не 3D
- Формы мягкие, округлые (радиус глаз ~30%, рот широкий дуга)
- Ляля смотрит чуть вправо-вверх, открытый рот показывает «говорит»
- Бантик на голове — дополнительный идентификатор персонажа

---

## M7.5 — Liquid Glass экраны

### Экраны с HSLiquidGlassCard (iOS 26)

| Экран | Компонент | Обоснование |
|---|---|---|
| ParentHome dashboard | 8 карточек-виджетов | Современный widget-like вид iOS 26 |
| SessionComplete modal | Итоговая карточка сессии | Поверх игрового фона — стекло не перекрывает контекст |
| RewardReveal overlay | Оверлей при разблокировке награды | Эффект «magic reveal», glass + confetti |
| ProgramEditor palette | Боковая панель инструментов | Профессиональный вид, не перекрывает контент программы |

### Fallback (iOS 17–25)

Все 4 экрана используют `.ultraThinMaterial` с `RadiusTokens.card` и `ShadowTokens.card`.
`HSLiquidGlassCard` инкапсулирует эту логику — фичи не содержат `if #available(iOS 26, ...)`.

---

## App Store скриншоты (Sprint 12)

Формат: iPhone 17 Pro, 1290×2796px. Русские заголовки, реалистичный контент.

| # | Экран | Заголовок вверху | Ключевой элемент |
|---|---|---|---|
| 1 | ChildHome — герой | «Учимся говорить вместе!» | Маскот Ляля + карта мира |
| 2 | RepeatAfterModel | «Повтори за Лялей» | Waveform + кнопка записи |
| 3 | ListenAndChoose | «Слушай и выбирай!» | 4 карточки-варианта с картинками |
| 4 | ARZone — артикуляция | «Следи за движениями» | ARView + face overlay |
| 5 | SessionComplete + награда | «Молодец! 94%» | Confetti + стикер-награда |
| 6 | ParentHome dashboard | «Прогресс Маши» | 3 карточки дашборда |
| 7 | WorldMap — зоны | «Исследуй мир звуков» | 5 зон на карте |
| 8 | Specialist — отчёт | «Детальный анализ» | График + waveform попытки |
| 9 | Onboarding — выбор звука | «Выбери с чего начать» | SoundFamily selection |
| 10 | ProgressDashboard — звук Р | «Звук Р: 78% за неделю» | HSChart + этапы работы |

Каждый скриншот: padding 0 (bleed), status bar с реалистичным временем (09:41), нет debug-текстов, нет placeholder-контента.
