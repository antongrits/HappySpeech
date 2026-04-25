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

---

## M7.2 Batch 2 — Детализированные спеки 10 экранов (2026-04-24)

> Токены из кода (актуальные): SpacingTokens.screenEdge=24pt, cardPad=20pt, sectionGap=32pt, large=24pt, regular=16pt, small=12pt, tiny=8pt, micro=4pt. RadiusTokens: card=24pt, button=32pt, chip=8pt, sheet=32pt. TypographyTokens: kidDisplay(40)=Black Rounded, display(36)=Bold Rounded, title(24)=Semibold Rounded, headline(18)=Semibold Rounded, body(15)=Regular Default, caption(12)=Regular Default, mono(13)=Medium Monospaced, cta()=17pt Bold Rounded.

---

## HomeTasks Screen (Детальная спека)

**Роль:** kid (основной) / parent (read-only просмотр)
**Навигация:** ChildHome → HomeTasks → HomeTaskDetail → SessionComplete
**Файл реализации:** Features/HomeTasks/HomeTasksView.swift

### Структура UI (top → bottom)

**NavBar**
- Стиль: inline title «Задания от логопеда»
- Шрифт: `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`
- Правая кнопка: `HSBadge` с числом невыполненных, `ColorTokens.Brand.gold`, 28×28pt
- Background: `ColorTokens.Kid.bg`, без separator
- Левая кнопка: chevron.left, 44×44pt touch target

**Секция маскота-подсказки**
- `HStack(spacing: SpacingTokens.regular)`, padding horizontal `SpacingTokens.screenEdge`
- `HSMascotView(state: tasks.isEmpty ? .encouraging : .idle)` — 80×80pt
- Речевой пузырь `HSCard`:
  - Background: `ColorTokens.Kid.surface`
  - Corner radius: `RadiusTokens.card` (24pt)
  - Padding: `SpacingTokens.cardPad` (20pt)
  - Text: «Сегодня N заданий!» / «Все выполнено! Молодец!»
  - Шрифт: `TypographyTokens.title(22)`, `ColorTokens.Kid.ink`
  - Line spacing: `TypographyTokens.LineSpacing.relaxed` (1.5)
- Высота секции: min 96pt

**Фильтры (только parent-контур)**
- `ScrollView(.horizontal)` с `HSChip` для «Все», «Сегодня», «Выполненные»
- Chip: `TypographyTokens.caption(12)`, высота 36pt, ширина авто, corner `RadiusTokens.chip`(8pt)
- Active chip: `ColorTokens.Brand.primary` background, white text
- Inactive chip: `ColorTokens.Kid.surfaceAlt` background, `ColorTokens.Kid.inkMuted` text
- Touch target чипа: min 56pt (kid контур)

**Список заданий — LazyVStack(spacing: SpacingTokens.listGap)**
- Padding horizontal: `SpacingTokens.screenEdge` (24pt)
- Padding vertical top: `SpacingTokens.regular` (16pt)

**HSCard задания**
```
HSCard {
    HStack(alignment: .top, spacing: SpacingTokens.regular) {
        // Иконка типа задания
        ZStack {
            Circle().fill(iconBgColor).frame(width: 56, height: 56)
            Image(systemName: task.icon).font(.system(size: 24))
                .foregroundStyle(iconFgColor)
        }
        // Контент
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(task.title)       // headline(18), Kid.ink, lineLimit 2
            Text(task.subtitle)    // body(15) → 22pt kid, Kid.inkMuted, lineLimit 3
            // Прогресс если есть попытки
            if task.hasAttempts {
                HSProgressBar(progress: task.attemptProgress)
                    .frame(maxWidth: .infinity, height: 4)
            }
        }
        Spacer()
        // Статус
        Group {
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .font(.system(size: 28))
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .frame(width: 44, height: 44)
    }
    .padding(SpacingTokens.cardPad)
}
.frame(maxWidth: .infinity, minHeight: 88)
```

- Corner radius: `RadiusTokens.card` (24pt)
- Background: невыполненное `ColorTokens.Kid.surface` / выполненное `ColorTokens.Semantic.successBg`
- Shadow: y=2, blur=8, `ColorTokens.Kid.bgDeep` opacity 0.08
- Touch target: весь card ≥ 88pt высота > 56pt ✓
- Иконка-фон по типу задания:
  - repeat-after-model: `ColorTokens.Games.repeatAfterModel` opacity 0.15
  - listen-and-choose: `ColorTokens.Games.listenAndChoose` opacity 0.15
  - breathing: `ColorTokens.Games.breathing` opacity 0.15

**Пустое состояние (.empty)**
- `HSMascotView(state: .celebrating)` 120×120pt, центр
- `Text("Все задания выполнены!")` `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`, center
- `Text("Ляля тобой гордится")` `TypographyTokens.body(15)`, `ColorTokens.Kid.inkMuted`, center
- `HSLottieContainer(animation: "confetti_small")` 200×100pt над маскотом, playOnce

**Состояние .loading**
- Skeleton placeholders: 3 rounded rectangles 88pt высота, shimmer анимация
- `ColorTokens.Kid.surfaceAlt` с opacity 0→1→0, duration 1.2s, repeat

**Состояние .error**
- `HSToast(message: "Не удалось загрузить задания", style: .error)`
- Кнопка «Повторить»: `HSButton(style: .ghost)`, .infinity × 44pt

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон экрана | `Kid.bg` (кремовый) | `Kid.bg` (тёмный кремовый) |
| Карточка невыполненного | `Kid.surface` | `Kid.surface` (адаптивный) |
| Карточка выполненного | `Semantic.successBg` | `Semantic.successBg` (dim) |
| Бейдж с числом | `Brand.gold` | `Brand.gold` |
| Иконка выполнено | `Semantic.success` | `Semantic.success` |

### Типографика

- NavBar title: `TypographyTokens.title(24)`, Semibold Rounded
- Задание title: `TypographyTokens.headline(18)`, Semibold Rounded
- Задание subtitle: минимум 22pt в kid контуре → `TypographyTokens.body(22)`, Regular
- Badge число: `TypographyTokens.mono(13)`, Medium Monospaced
- Пустое состояние: `TypographyTokens.title(24)` + `TypographyTokens.body(15)`

### Отступы

- Horizontal edge: `SpacingTokens.screenEdge` (24pt)
- Между карточками: `SpacingTokens.listGap` (12pt)
- Padding внутри карточки: `SpacingTokens.cardPad` (20pt)
- Между секциями: `SpacingTokens.sectionGap` (32pt)
- iPhone SE (width < 375pt): screenEdge → 16pt, cardPad → 14pt, маскот 64×64pt

### Компоненты DesignSystem

- `HSMascotView` — состояния idle / encouraging / celebrating
- `HSCard` — основной контейнер задания
- `HSProgressBar` — прогресс попыток (height 4pt)
- `HSBadge` — счётчик невыполненных в навбаре
- `HSToast` — ошибка загрузки
- `HSLottieContainer` — конфетти при пустом состоянии
- `HSButton` — CTA и ghost-кнопки

### Accessibility

- Весь card: `accessibilityElement(children: .combine)`
- VoiceOver label: «Задание: [title]. [subtitle]. [Выполнено / Не выполнено].»
- Badge: `accessibilityLabel("Невыполненных заданий: \(count)")`
- Маскот: `accessibilityLabel("Ляля, персонаж-помощник")`, `accessibilityHidden` если decorative
- Min touch target всех элементов: 56×56pt (kid контур)
- Dynamic Type: `headline(18)` → масштабируется системой, `lineLimit(nil)` на subtitle

### Анимации & Motion

- Появление карточек: каждая появляется с `opacity 0→1` + `offset(y: 20→0)`, `.spring` (response: 0.45, damping: 0.7), stagger 0.08s на карточку
- Выполнение задания: border flash `Semantic.success` + checkmark scale 0→1, `.bounce` (response: 0.4, damping: 0.55)
- Маскот переход idle → celebrating: при последнем выполненном задании, `trigger("celebrate")`
- Reduced Motion: все spring → `opacity` fade 0.15s linear, без stagger

---

## WorldMap Screen (Детальная спека)

**Роль:** kid
**Навигация:** ChildHome (tab) → WorldMap → ZoneLevels → LessonPlayer
**Файл реализации:** Features/WorldMap/WorldMapView.swift

### Структура UI (top → bottom)

**NavBar**
- Стиль: inline, title «Карта звуков»
- Шрифт: `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`
- Правая кнопка: профиль-аватар 36×36pt, corner full, touch target 44×44pt
- Background: прозрачный (контент под ним через ZStack)

**Hero — маскот Ляля (top center)**
- `HSMascotView(state: .idle)` 80×80pt, positioned absolute top
- Анимация: `idlePulse` (easeInOut 1.8s, forever) — мягкий scale 1.0→1.05→1.0
- При нажатии любой зоны: `trigger("speak")` на 2s, затем возврат в `idle`
- Пузырь-подсказка (появляется 3s при первом входе): «Выбери зону!», `caption(12)`, Kid.ink

**Фоновый слой**
- Background: `ColorTokens.Kid.bgDeep` + радиальный gradient overlay (светлее в центре)
- Lottie: `world_map_bg` — медленно движущиеся облака, loop, скорость 0.3x
- Safe area: уважается, контент внутри safe area bounds

**Сетка зон — `LazyVGrid(columns: 2, spacing: SpacingTokens.large)`**
- Padding horizontal: `SpacingTokens.screenEdge` (24pt)
- Padding top: 80pt (под маскота)
- Колонки: 2 равные `.flexible(minimum: 140)`
- 5 зон: первые 4 в гриде 2×2, пятая (Йот) — по центру под ними, .infinity × 160pt

**HSWorldMapZone — компонент зоны**
```
VStack(spacing: SpacingTokens.tiny) {
    ZStack {
        RoundedRectangle(cornerRadius: RadiusTokens.card)  // 24pt
            .fill(SoundFamilyColors.X.bg)
            .frame(width: 140, height: 140)
        HSLottieContainer(animation: zone.lottieFile, loopMode: .loop)
            .frame(width: 96, height: 96)
        // Locked overlay
        if zone.isLocked {
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.bgSoft.opacity(0.85))
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
    }
    HSProgressBar(progress: zone.progress)
        .frame(width: 120, height: 6)
    Text(zone.name)
        .font(TypographyTokens.caption(12))
        .foregroundStyle(ColorTokens.Kid.ink)
        .multilineTextAlignment(.center)
}
.frame(width: 156, height: 185)
```

**Таблица зон**

| Зона | Lottie-файл | Цвет фона | Звуки |
|---|---|---|---|
| Свистящие | `zone_whistling` | `SoundFamilyColors.Whistling.bg` | С, З, Ц |
| Шипящие | `zone_hissing` | `SoundFamilyColors.Hissing.bg` | Ш, Ж, Ч, Щ |
| Соноры | `zone_sonorant` | `SoundFamilyColors.Sonorant.bg` | Р, Рь, Л, Ль |
| Велярные | `zone_velar` | `SoundFamilyColors.Velar.bg` | К, Г, Х |
| Гласные/Йот | `zone_vowels` | `SoundFamilyColors.Vowels.bg` | Й, гласные |

**Нижняя панель — текущий прогресс**
- Sticky bottom, `ColorTokens.Kid.surface` + blur material
- `HStack(spacing: SpacingTokens.regular)`:
  - Иконка звезды: `Brand.butter`, 20pt
  - Text «Звёзд: \(totalStars)»: `TypographyTokens.mono(13)`, `Kid.ink`
  - Spacer
  - HSButton «Продолжить», style `.primary`, 160×48pt

### Состояния экрана

- `.loading`: Skeleton placeholder 5 зон, shimmer `Kid.surfaceAlt`
- `.populated`: основной контент как описано
- `.error`: `HSToast("Не удалось загрузить карту", style: .error)` снизу
- `.zoneUnlocked`: `HSSticker` конфетти + маскот `trigger("celebrate")` + `HSToast("Новая зона открыта!", style: .success)`

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Kid.bgDeep` | `Kid.bgDeep` (темнее) |
| Зона свистящих | `SoundFamilyColors.Whistling.bg` (голубоватый) | адаптивный |
| Зона шипящих | `SoundFamilyColors.Hissing.bg` (оранжеватый) | адаптивный |
| Зона сонорных | `SoundFamilyColors.Sonorant.bg` (зелёный) | адаптивный |
| Зона велярных | `SoundFamilyColors.Velar.bg` (фиолетовый) | адаптивный |
| Заблокированная | `Kid.bgSoft` overlay 0.85 | `Kid.bgSoft` overlay 0.85 |
| Progress bar | `Brand.mint` | `Brand.mint` |

### Типографика

- NavBar: `title(24)`, Semibold Rounded
- Название зоны: `caption(12)`, Regular Default, center
- Звёзды панель: `mono(13)`, Medium Monospaced
- Пузырь маскота: `caption(12)`, Regular

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Грид gap: `SpacingTokens.large` (24pt)
- Top под маскота: 80pt
- Bottom panel padding: `SpacingTokens.regular` (16pt) vertical
- iPhone SE (width < 375pt): грид → 1 колонка, зона → .infinity × 100pt

### Компоненты DesignSystem

- `HSMascotView` — idle с idlePulse
- `HSWorldMapZone` — каждая зона (см. M7.3 компонент)
- `HSLottieContainer` — Lottie фон + зоны
- `HSProgressBar` — прогресс под каждой зоной (height 6pt)
- `HSButton` — «Продолжить» в нижней панели
- `HSToast` — ошибка и успех разблокировки
- `HSSticker` — конфетти при разблокировке

### Accessibility

- Каждая зона: `accessibilityRole(.button)`
- Unlocked: `accessibilityLabel("\(zone.name). Прогресс \(Int(zone.progress * 100)) процентов. Нажмите чтобы открыть.")`
- Locked: `accessibilityLabel("\(zone.name). Заблокировано. Выполните задания в предыдущей зоне.")`
- Маскот: `accessibilityHidden(true)` (декоративный)
- Нижняя панель: `accessibilityElement(children: .combine)`, label «Всего звёзд: \(totalStars)»
- Min touch target зоны: 140×140pt > 56pt ✓

### Анимации & Motion

- Вход на экран: зоны появляются stagger 0.1s, `opacity 0→1` + `scale 0.9→1.0`, `.spring`
- Tap на зону: `scale 1.0→1.08→1.0`, `.spring` (response 0.45, damping 0.7) + sound-family haptic `.impactOccurred(.medium)`
- Разблокировка зоны: `scale 0→1.2→1.0`, `.bounce` (response 0.4, damping 0.55) + confetti + `HSMascotView` trigger celebrate
- Маскот idle: `idlePulse` scale 1.0→1.05→1.0, easeInOut 1.8s, forever
- Reduced Motion: все spring/bounce → `opacity` fade 0.2s, без scale

---

## Permissions Screen (Детальная спека)

**Роль:** universal (universal state machine, вызывается из Onboarding и Settings)
**Навигация:** OnboardingStep8 → [Mic → Camera → Notifications → FaceTracking] → OnboardingStep9
**Файл реализации:** Features/Permissions/PermissionsView.swift (+ отдельные step views)

### Структура UI (top → bottom) — общий шаблон для всех 4 экранов

**NavBar**
- Стиль: нет (full-screen, без nav bar) — экраны разрешений full-bleed
- Кнопка «Назад» (если из Settings): `chevron.left` левый верхний угол, 44×44pt, `ColorTokens.Kid.ink`
- Индикатор шага (из Onboarding): 4 dot-пики шириной 8pt, gap 6pt, активный `Brand.primary`, остальные `Kid.line`

**Центральный контент (VStack, centred)**
```
VStack(spacing: SpacingTokens.large) {   // large = 24pt
    Spacer()
    // Иллюстрация-анимация
    HSLottieContainer(animation: permissionType.lottieFile, loopMode: .loop)
        .frame(width: 160, height: 160)
    // Заголовок
    Text(permissionType.title)
        .font(TypographyTokens.title(24))
        .foregroundStyle(ColorTokens.Kid.ink)
        .multilineTextAlignment(.center)
    // Описание
    Text(permissionType.description)
        .font(TypographyTokens.body(22))   // 22pt для kid контура
        .foregroundStyle(ColorTokens.Kid.inkMuted)
        .multilineTextAlignment(.center)
        .lineSpacing(TypographyTokens.LineSpacing.relaxed)   // 1.5
    // Карточка с пояснением «Зачем» (только для Camera и FaceTracking)
    if permissionType.needsPrivacyNote {
        HSCard {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(ColorTokens.Brand.mint)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                Text(permissionType.privacyNote)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.cardPad)
        }
        .frame(maxWidth: .infinity)
    }
    Spacer()
    // Кнопки
    VStack(spacing: SpacingTokens.tiny) {
        HSButton(permissionType.allowTitle, style: .primary)
            .frame(maxWidth: .infinity, minHeight: 56)
        HSButton("Потом", style: .ghost)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
    .padding(.bottom, SpacingTokens.large)
}
.padding(.horizontal, SpacingTokens.screenEdge)
```

### Параметры 4 экранов

| Параметр | Микрофон | Камера | Уведомления | Face Tracking |
|---|---|---|---|---|
| `lottieFile` | `permission_mic` | `permission_camera` | `permission_bell` | `permission_face` |
| `title` | «Нужен микрофон» | «Нужна камера» | «Напомним о занятиях» | «Слежение за лицом» |
| `allowTitle` | «Разрешить микрофон» | «Разрешить камеру» | «Разрешить уведомления» | «Разрешить» |
| `needsPrivacyNote` | false | true | false | true |
| `privacyNote` | — | «Видео не сохраняется на сервер» | — | «Данные остаются на устройстве» |
| `description` размер | 22pt | 22pt | 22pt | 22pt |

### State Machine разрешений

```
.notDetermined → [Разрешить нажато] → SystemDialog → .authorized / .denied
.denied → [Потом нажато] → Toast «Можно разрешить в Настройках»
.authorized → auto-advance к следующему шагу (0.5s задержка)
```

При `.denied`: `HSToast("Разреши в Настройках → Конфиденциальность", style: .info)` + кнопка «Открыть Настройки»: `UIApplication.openSettingsURLString`.

### Состояния экрана

- `.requesting`: кнопка в loading состоянии (spinner вместо label)
- `.authorized`: иллюстрация меняется на checkmark Lottie `permission_granted`, auto-advance
- `.denied`: Toast + кнопка «Открыть Настройки»
- `.skipped`: advance к следующему шагу без разрешения

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Kid.bg` | `Kid.bg` (адаптивный) |
| Иллюстрация | full color | full color (Lottie адаптивный) |
| Карточка privacy | `Kid.surface` | `Kid.surface` |
| Иконка shield | `Brand.mint` | `Brand.mint` |
| Кнопка primary | `Brand.primary` | `Brand.primary` |
| Кнопка ghost | прозрачная, `Kid.ink` text | прозрачная, `Kid.ink` text |

### Типографика

- Заголовок: `TypographyTokens.title(24)`, Semibold Rounded, center
- Описание: `TypographyTokens.body(22)` (22pt минимум для kid), Regular, center, lineSpacing 1.5
- Privacy note: `TypographyTokens.body(15)`, Regular, leading
- Кнопка primary: `TypographyTokens.cta()` (17pt Bold Rounded)
- Кнопка ghost: `TypographyTokens.body(17)`, Regular

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Между элементами: `SpacingTokens.large` (24pt)
- Между кнопками: `SpacingTokens.tiny` (8pt)
- Bottom padding: `SpacingTokens.large` (24pt) + safe area
- iPhone SE: lottie → 120×120pt, описание → body(18) (уменьшается gracefully)

### Компоненты DesignSystem

- `HSLottieContainer` — иллюстрация разрешения (loop)
- `HSCard` — privacy note карточка
- `HSButton` — primary (Разрешить) + ghost (Потом)
- `HSToast` — при denied или успехе

### Accessibility

- Lottie: `accessibilityHidden(true)` (декоративная), заголовок читается первым
- Privacy card: `accessibilityElement(children: .combine)`, label «Конфиденциальность: \(privacyNote)»
- Кнопка Разрешить: `accessibilityLabel("\(allowTitle), кнопка")`, `accessibilityHint("Откроет системный запрос разрешения")`
- Кнопка Потом: `accessibilityLabel("Пропустить")`, `accessibilityHint("Можно разрешить позже в Настройках")`
- Min touch target: 56×56pt (primary), 44×44pt (ghost) — kid контур требует 56pt для primary ✓

### Анимации & Motion

- Появление экрана: lottie fade in `opacity 0→1`, 0.3s `.page` (easeOut)
- Authorized state: lottie swap `permission_X` → `permission_granted`, crossfade 0.3s
- Auto-advance: `opacity 1→0` screen, 0.5s delay, `.page`
- Reduced Motion: lottie показывает первый кадр (не играет), transitions → instant

---

## SessionHistory Screen (Детальная спека)

**Роль:** parent / specialist
**Навигация:** ParentHome → SessionHistory → SessionHistoryDetail; Settings → SessionHistory
**Файл реализации:** Features/SessionHistory/SessionHistoryView.swift

### Структура UI (top → bottom)

**NavBar**
- `NavigationStack`, `.navigationTitle("История сессий")`, `.navigationBarTitleDisplayMode(.large)`
- Правая кнопка: `Image(systemName: "line.3.horizontal.decrease.circle")`, 44×44pt — открывает фильтр sheet
- Background: `ColorTokens.Parent.bg`, default UINavigationBar appearance

**Поиск**
- `.searchable(text: $searchQuery, placement: .navigationBarDrawer)`, prompt: «Дата или звук»
- При поиске: фильтрует по дате (`dd MMM yyyy`) и `soundFamily.name`

**Фильтр sheet (presentationDetents .medium)**
```
VStack(alignment: .leading, spacing: SpacingTokens.regular) {
    Text("Фильтры").font(TypographyTokens.headline(18))
        .padding(.bottom, SpacingTokens.tiny)
    // Период
    Text("Период").font(TypographyTokens.caption(12))
        .foregroundStyle(ColorTokens.Parent.inkMuted)
    HStack(spacing: SpacingTokens.tiny) {
        ForEach(["Неделя","Месяц","3 месяца","Всё"], id: \.self) { p in
            HSChip(p, selected: selectedPeriod == p)
        }
    }
    // Семейство звуков
    Text("Звуки").font(TypographyTokens.caption(12))
        .foregroundStyle(ColorTokens.Parent.inkMuted)
    LazyVGrid(columns: Array(repeating: .flexible(), count: 3)) {
        ForEach(SoundFamily.allCases) { f in
            HSChip(f.displayName, selected: selectedFamily == f)
        }
    }
    Spacer()
    HSButton("Применить", style: .primary).frame(maxWidth: .infinity, minHeight: 56)
}
.padding(SpacingTokens.screenEdge)
```

**Список сессий — сгруппированный по месяцам**
```
List {
    ForEach(groupedSessions) { group in
        Section {
            ForEach(group.sessions) { session in
                NavigationLink(destination: SessionHistoryDetailView(session: session)) {
                    SessionHistoryRowView(session: session)
                }
                .listRowBackground(ColorTokens.Parent.surface)
                .listRowSeparatorTint(ColorTokens.Parent.line)
            }
        } header: {
            Text(group.monthTitle)   // caption(12), Parent.inkMuted, uppercase
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        }
    }
}
.listStyle(.insetGrouped)
.background(ColorTokens.Parent.bg)
```

**SessionHistoryRowView**
```
HStack(spacing: SpacingTokens.regular) {
    // Дата-плитка
    VStack(spacing: 2) {
        Text(dayNumber)    // mono(13), Parent.ink, bold
        Text(monthAbbr)    // caption(12), Parent.inkMuted
    }
    .frame(width: 36, alignment: .center)
    // Тип сессии — цветной dot
    Circle()
        .fill(sessionTypeColor)   // Games.X цвет по типу первой игры
        .frame(width: 10, height: 10)
    // Описание
    VStack(alignment: .leading, spacing: SpacingTokens.micro) {
        Text(session.title)       // headline(18), Parent.ink, lineLimit 1
        Text(sessionMeta)         // caption(12), Parent.inkMuted — «14 мин · 23 слова · Звук Р»
    }
    Spacer()
    // Оценка
    HSBadge(score: session.overallScore)
    Image(systemName: "chevron.right")
        .foregroundStyle(ColorTokens.Parent.inkSoft)
        .font(.system(size: 13, weight: .semibold))
}
.frame(minHeight: 56)
.padding(.vertical, SpacingTokens.tiny)
```

### Детали сессии (SessionHistoryDetailView)

**Навигация:** push из списка
**Background:** `ColorTokens.Parent.bg`

```
ScrollView {
    VStack(alignment: .leading, spacing: SpacingTokens.sectionGap) {
        // Шапка
        HSCard {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(fullDate).font(TypographyTokens.headline(18))
                        Text(sessionMeta).font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    Spacer()
                    Text("\(Int(session.overallScore))%")
                        .font(TypographyTokens.display(36))
                        .foregroundStyle(scoreColor)
                }
            }
        }
        // По звукам
        Text("По звукам").font(TypographyTokens.title(24))
        LazyVGrid(columns: Array(repeating: .flexible(minimum: 100), count: 3)) {
            ForEach(session.soundResults) { r in
                HSSoundMapCell(sound: r.sound, soundFamily: r.family,
                               progress: r.score/100, stage: r.stageName)
            }
        }
        // Waveform лучшей попытки
        Text("Лучшая попытка").font(TypographyTokens.title(24))
        HSAudioWaveform(audio: session.bestAttemptAudio)
            .frame(maxWidth: .infinity, height: 80)
            .background(ColorTokens.Parent.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.card))
        // Действия
        HStack(spacing: SpacingTokens.regular) {
            HSButton("PDF", style: .secondary).frame(maxWidth: .infinity, minHeight: 44)
            HSButton("Поделиться", style: .ghost).frame(maxWidth: .infinity, minHeight: 44)
        }
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
    .padding(.vertical, SpacingTokens.large)
}
```

### Состояния экрана

- `.loading`: `ProgressView()` centred, `Parent.inkMuted`
- `.empty`: иконка `clock.badge.xmark` 64pt `Parent.inkSoft` + «Сессий пока нет» `headline(18)` + «Начните первое занятие с Лялей» `body(15)` + `HSButton("Начать занятие", style: .primary)`
- `.populated`: список как описано
- `.filtered(0 results)`: «Ничего не найдено по запросу» `body(15)` + кнопка «Сбросить фильтры»
- `.error`: `HSToast("Ошибка загрузки истории", style: .error)` + «Повторить» button

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Parent.bg` | `Parent.bg` (системный тёмный) |
| List row bg | `Parent.surface` | `Parent.surface` |
| Separator | `Parent.line` | `Parent.line` |
| Section header | `Parent.inkMuted` | `Parent.inkMuted` |
| Score excellent (>80%) | `Feedback.excellent` | `Feedback.excellent` |
| Score ok (60–80%) | `Brand.mint` | `Brand.mint` |
| Score low (<60%) | `Feedback.incorrect` | `Feedback.incorrect` |

### Типографика

- NavBar large title: системный (NavigationStack стандарт)
- Section header: `caption(12)`, uppercase, `Parent.inkMuted`
- Row title: `headline(18)`, Semibold Rounded
- Row meta: `caption(12)`, Regular, `Parent.inkMuted`
- Score display: `display(36)`, Bold Rounded
- Detail title: `title(24)`, Semibold Rounded

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Row vertical: `SpacingTokens.tiny` (8pt) padding
- Between sections (detail): `SpacingTokens.sectionGap` (32pt)
- Card inner: `SpacingTokens.cardPad` (20pt)
- iPhone SE: row height min 56pt (не меняется), text `lineLimit(1)` на meta

### Компоненты DesignSystem

- `HSSoundMapCell` — звуки в деталях
- `HSAudioWaveform` — лучшая попытка
- `HSBadge` — оценка в строке
- `HSCard` — шапка детали
- `HSButton` — PDF, Поделиться, Повторить
- `HSToast` — ошибки

### Accessibility

- List row: `accessibilityElement(children: .combine)`, label «Сессия \(fullDate), \(duration) минут, оценка \(score) процентов»
- Section header: `accessibilityAddTraits(.isHeader)`
- Score цвет: не единственный индикатор — дублируется числом
- Min touch target row: 56pt ✓
- Dynamic Type: row title `lineLimit(2)` при `sizeCategory >= .accessibilityMedium`

### Анимации & Motion

- List появление: `.listRowInsets` + items fade in on scroll (стандартное iOS)
- Фильтр sheet: `.sheet` стандартный transition
- Detail push: NavigationStack стандартный push slide
- Score число в detail: `countUp` от 0 до значения, duration 0.8s, easing `.outQuick`
- Reduced Motion: countUp → instant display

---

## Settings Screen (Детальная спека)

**Роль:** parent (основной) / specialist (дополнительные разделы)
**Навигация:** TabBar → Settings; ParentHome → Settings
**Файл реализации:** Features/Settings/SettingsView.swift

### Структура UI (top → bottom)

**NavBar**
- `.navigationTitle("Настройки")`, `.navigationBarTitleDisplayMode(.large)`
- Background: `ColorTokens.Parent.bg`
- Без дополнительных кнопок

**Список разделов (7 секций)**
```
List {
    // СЕКЦИЯ 1 — Оформление
    Section {
        // Picker темы
        HStack {
            Label("Тема", systemImage: "paintpalette")
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.ink)
            Spacer()
            Picker("", selection: $colorScheme) {
                Text("Авто").tag(0)
                Text("Светлая").tag(1)
                Text("Тёмная").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .frame(minHeight: 44)
    } header: {
        Text("ОФОРМЛЕНИЕ")
    }

    // СЕКЦИЯ 2 — Профиль ребёнка
    Section {
        NavigationLink(destination: ChildProfileEditView()) {
            HStack(spacing: SpacingTokens.regular) {
                AvatarView(child: currentChild).frame(width: 40, height: 40)
                VStack(alignment: .leading) {
                    Text(currentChild.name).font(TypographyTokens.headline(18))
                    Text("Возраст: \(currentChild.age) лет").font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
        }
        .frame(minHeight: 56)
    } header: { Text("ПРОФИЛЬ") }

    // СЕКЦИЯ 3 — Уведомления
    Section {
        Toggle(isOn: $dailyReminders) {
            Label("Ежедневные напоминания", systemImage: "bell")
        }
        .tint(ColorTokens.Brand.primary)
        .frame(minHeight: 44)
        if dailyReminders {
            DatePicker("Время напоминания", selection: $reminderTime,
                       displayedComponents: .hourAndMinute)
            .frame(minHeight: 44)
        }
        NavigationLink("Звук напоминания") { NotificationSoundView() }
            .frame(minHeight: 44)
    } header: { Text("УВЕДОМЛЕНИЯ") }

    // СЕКЦИЯ 4 — Контент
    Section {
        NavigationLink(destination: ModelPacksView()) {
            HStack {
                Label("Языковые паки", systemImage: "arrow.down.circle")
                Spacer()
                Text(activePack.name).font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
        .frame(minHeight: 44)
        NavigationLink("Управление звуками") { SoundManagementView() }
            .frame(minHeight: 44)
    } header: { Text("КОНТЕНТ") }

    // СЕКЦИЯ 5 — Конфиденциальность и данные
    Section {
        NavigationLink(destination: PrivacyView()) {
            Label("Управление данными", systemImage: "hand.raised")
        }
        .frame(minHeight: 44)
        Button {
            exportData()
        } label: {
            Label("Экспорт прогресса (GDPR)", systemImage: "square.and.arrow.up")
                .foregroundStyle(ColorTokens.Parent.ink)
        }
        .frame(minHeight: 44)
        NavigationLink("Политика конфиденциальности") { PrivacyPolicyView() }
            .frame(minHeight: 44)
    } header: { Text("ДАННЫЕ") }

    // СЕКЦИЯ 6 — Специалист (только если specialist mode)
    if specialistModeEnabled {
        Section {
            NavigationLink("Панель специалиста") { SpecialistHomeView() }
                .frame(minHeight: 44)
            NavigationLink("Настройки программы") { ProgramSettingsView() }
                .frame(minHeight: 44)
        } header: { Text("СПЕЦИАЛИСТ") }
    }

    // СЕКЦИЯ 7 — О приложении + Удаление
    Section {
        LabeledContent("Версия", value: appVersion)
            .font(TypographyTokens.body(15))
            .frame(minHeight: 44)
        NavigationLink("Условия использования") { TermsView() }
            .frame(minHeight: 44)
        Button("Удалить аккаунт", role: .destructive) {
            showDeleteConfirmation = true
        }
        .frame(minHeight: 44)
    } header: { Text("О ПРИЛОЖЕНИИ") }
}
.listStyle(.insetGrouped)
.background(ColorTokens.Parent.bg)
.scrollContentBackground(.hidden)
```

**Alert удаления аккаунта**
```
.confirmationDialog("Удалить аккаунт?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
    Button("Удалить навсегда", role: .destructive) { deleteAccount() }
    Button("Отмена", role: .cancel) { }
} message: {
    Text("Весь прогресс и данные будут удалены. Это действие необратимо.")
}
```

**Toast экспорта**
- После успешного экспорта: `HSToast("Файл сохранён в приложение Файлы", style: .success)`, duration 3s
- Loading: row spinner `ProgressView(style: .circular)` вместо чевронa

### Состояния экрана

- `.loading(packDownload)`: ячейка «Языковые паки» — прогресс-бар inline, `HSProgressBar` height 4pt под label
- `.exportInProgress`: кнопка «Экспорт» — disabled + `ProgressView()` inline
- `.deleteConfirmation`: `confirmationDialog` как описано
- `.error`: `HSToast("Ошибка: \(message)", style: .error)` снизу

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Parent.bg` | `Parent.bg` |
| Row background | `Parent.surface` | `Parent.surface` |
| Separator | `Parent.line` | `Parent.line` |
| Toggle tint | `Brand.primary` | `Brand.primary` |
| Деструктивная | `Semantic.error` | `Semantic.error` |
| Section header | `Parent.inkMuted` | `Parent.inkMuted` |
| Label иконки | `Parent.accent` | `Parent.accent` |

### Типографика

- Large title: системный `largeTitle` (UIKit)
- Row label: `body(15)`, Regular Default
- Row secondary: `caption(12)`, Regular, `Parent.inkMuted`
- Profile name: `headline(18)`, Semibold Rounded
- Version: `body(15)`, Regular, `Parent.inkMuted`
- Section headers: `caption(12)`, uppercase, `Parent.inkMuted`

### Отступы

- List inset: стандартный `insetGrouped`
- Row минимальная высота: 44pt (parent контур)
- Picker темы: ширина 180pt, не растягивается
- Avatar: 40×40pt, corner `RadiusTokens.full`
- iPhone SE: Picker тема → `.menu` style вместо `.segmented` (экономит ширину)

### Компоненты DesignSystem

- `HSButton` — не используется, стандартный List Button
- `HSProgressBar` — inline под ячейкой пака (height 4pt)
- `HSToast` — экспорт, ошибки
- `HSSoundMapCell` — не используется в Settings напрямую

### Accessibility

- Toggle напоминаний: `accessibilityLabel("Ежедневные напоминания")`, `accessibilityValue(dailyReminders ? "Включено" : "Выключено")`
- Picker темы: `accessibilityLabel("Тема оформления")`, `accessibilityValue(selectedThemeName)`
- Кнопка удаления: `accessibilityLabel("Удалить аккаунт")`, `accessibilityHint("Необратимое действие. Откроет диалог подтверждения.")`
- Min touch target: 44pt (parent контур, не kid) ✓
- Dynamic Type: `LabeledContent` версии — однострочно, `lineLimit(1)`

### Анимации & Motion

- Появление секции Специалист: `withAnimation(.spring)` при включении `specialistModeEnabled`
- DatePicker появление: `withAnimation(.spring)` при включении напоминаний
- Reduced Motion: все анимации появления → instant

---

## ProgressDashboard Screen (Детальная спека)

**Роль:** parent / specialist
**Навигация:** ParentHome → ProgressDashboard → SoundProgressDetail; TabBar (parent)
**Файл реализации:** Features/ProgressDashboard/ProgressDashboardView.swift

### Структура UI (top → bottom)

**NavBar**
- `.navigationTitle("Прогресс")`, `.navigationBarTitleDisplayMode(.large)`
- Правая кнопка: `Image(systemName: "calendar.badge.clock")` — date range picker, 44×44pt
- Background: `ColorTokens.Parent.bg`

**Сводка верхнего уровня (Summary Cards HStack)**
```
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: SpacingTokens.regular) {
        // Карточка «Общая точность»
        HSCard {
            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text("Общая точность")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text("\(Int(overallAccuracy))%")
                    .font(TypographyTokens.display(36))
                    .foregroundStyle(ColorTokens.Parent.accent)
                HSProgressBar(progress: overallAccuracy/100)
                    .frame(height: 4)
            }
            .padding(SpacingTokens.cardPad)
        }
        .frame(width: 160, height: 120)
        // Карточка «Сессий»
        HSCard {
            VStack(alignment: .leading) {
                Text("Сессий").font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Text("\(totalSessions)").font(TypographyTokens.display(36))
                    .foregroundStyle(ColorTokens.Parent.accent)
                Text("за 30 дней").font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .padding(SpacingTokens.cardPad)
        }
        .frame(width: 140, height: 120)
        // Карточка «Стрик»
        HSCard {
            VStack(alignment: .leading) {
                Text("Стрик").font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.micro) {
                    Text("\(streakDays)").font(TypographyTokens.display(36))
                        .foregroundStyle(ColorTokens.Brand.butter)
                    Text("дней").font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
            .padding(SpacingTokens.cardPad)
        }
        .frame(width: 140, height: 120)
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
}

```

**График «Успеваемость по неделям»**
```
VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
    HStack {
        Text("Успеваемость").font(TypographyTokens.title(24))
        Spacer()
        // Переключатель период
        Picker("", selection: $period) {
            Text("7 дн").tag(Period.week)
            Text("30 дн").tag(Period.month)
            Text("90 дн").tag(Period.quarter)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }
    HSChart(data: progressData, style: .line, height: 200,
            accentColor: ColorTokens.Parent.accent)
}
.padding(.horizontal, SpacingTokens.screenEdge)
```

**График «По звукам» (bar chart)**
```
VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
    Text("По звукам").font(TypographyTokens.title(24))
        .padding(.horizontal, SpacingTokens.screenEdge)
    HSChart(data: soundData, style: .bar, height: 160,
            accentColor: ColorTokens.SoundFamilyColors.hue(for: dominantFamily))
        .padding(.horizontal, SpacingTokens.screenEdge)
}
```

**AI-сводка (LLM summary)**
```
HSCard {
    HStack(alignment: .top, spacing: SpacingTokens.regular) {
        Image(systemName: "sparkles")
            .font(.system(size: 20))
            .foregroundStyle(ColorTokens.Brand.lilac)
            .frame(width: 32, height: 32)
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text("Рекомендация").font(TypographyTokens.headline(18))
            Text(llmSummary)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineSpacing(TypographyTokens.LineSpacing.normal)
                .lineLimit(4)
            if summaryTruncated {
                Button("Читать полностью") { showFullSummary = true }
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.accent)
            }
        }
    }
    .padding(SpacingTokens.cardPad)
}
.padding(.horizontal, SpacingTokens.screenEdge)
```

**Грид звуков (HSSoundMapCell)**
```
Text("Звуки").font(TypographyTokens.title(24))
    .padding(.horizontal, SpacingTokens.screenEdge)
LazyVGrid(columns: Array(repeating: .flexible(minimum: 100), count: 3),
          spacing: SpacingTokens.regular) {
    ForEach(trackedSounds) { sound in
        HSSoundMapCell(sound: sound.symbol, soundFamily: sound.family,
                       progress: sound.accuracy, stage: sound.currentStage)
            .onTapGesture { router.push(.soundDetail(sound)) }
    }
}
.padding(.horizontal, SpacingTokens.screenEdge)
```

**SoundProgressDetailView — отдельный push-экран**
- `NavigationStack` push из грида
- Заголовок: символ звука + название, `display(36)`, цвет семейства
- 30-дневный `HSChart(style: .line)`, высота 200pt
- Этапы работы: `List` с `checkmark.circle.fill` / `circle`
- Последние попытки: `HSAudioWaveform` + score

### Состояния экрана

- `.loading`: Summary cards shimmer, графики shimmer placeholder
- `.empty(noSessions)`: `HSMascotView(state: .encouraging)` + «Данных пока нет. Начните первую сессию!» + `HSButton("Начать занятие")`
- `.populated`: контент как описано
- `.loadingSummary`: sparkles иконка анимированная пульсация `Brand.lilac`, текст «Анализируем…»
- `.error`: `HSToast("Ошибка загрузки данных", style: .error)`

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Parent.bg` | `Parent.bg` |
| Summary cards | `Parent.surface` | `Parent.surface` |
| Line chart color | `Parent.accent` | `Parent.accent` |
| Bar chart color | `SoundFamilyColors.hue` | `SoundFamilyColors.hue` |
| AI summary icon | `Brand.lilac` | `Brand.lilac` |
| Стрик accent | `Brand.butter` | `Brand.butter` |

### Типографика

- Large title: системный
- Summary число: `display(36)`, Bold Rounded
- Summary label: `caption(12)`, Regular
- Секция заголовок: `title(24)`, Semibold Rounded
- Chart axis labels: `caption(12)`, mono design
- Sound cell label: `caption(12)`
- LLM summary: `body(15)`, lineSpacing 1.35

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Summary cards gap: `SpacingTokens.regular` (16pt)
- Between sections: `SpacingTokens.sectionGap` (32pt)
- Card inner: `SpacingTokens.cardPad` (20pt)
- iPhone SE: summary cards → `width: 130pt`, грид → 2 колонки

### Компоненты DesignSystem

- `HSChart` — line + bar (Swift Charts wrapper, см. M7.3)
- `HSSoundMapCell` — грид звуков
- `HSCard` — summary cards + AI summary
- `HSProgressBar` — в summary card, height 4pt
- `HSMascotView` — empty state
- `HSAudioWaveform` — в detail попытках
- `HSToast` — ошибки

### Accessibility

- Chart: `chartAccessibilityLabel("График прогресса за \(period.name)")`, `chartAccessibilityValues(...)` для VoiceOver
- Summary cards: `accessibilityElement(children: .combine)`, label «Общая точность: \(value) процентов»
- Sound cell: `accessibilityLabel("\(sound.name), точность \(Int(sound.accuracy*100)) процентов, этап \(sound.currentStage)")`
- LLM summary: label «Рекомендация: \(llmSummary)»
- Min touch target (parent контур): 44pt

### Анимации & Motion

- Chart данные: `.animation(.spring, value: progressData)` при смене периода
- Summary числа: countUp анимация 0.6s при первом появлении
- Sound grид появление: stagger 0.05s per cell, `opacity 0→1` + `scale 0.95→1`, `.spring`
- Reduced Motion: countUp → instant, chart → no animation, grид → opacity fade

---

## SessionComplete Screen (Детальная спека)

**Роль:** kid
**Навигация:** LessonPlayer → SessionComplete → ChildHome / NextSession
**Файл реализации:** Features/SessionComplete/SessionCompleteView.swift

### Структура UI — последовательный reveal (4 фазы)

**Фаза 1 (0–0.8s): Hero reveal маскота**
```
ZStack {
    // Фон — gradient от Kid.bgDeep к Kid.bg
    LinearGradient(colors: [Kid.bgDeep, Kid.bg], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    VStack {
        HSMascotView(state: .celebrating)   // 180×180pt, trigger "celebrate"
            .scaleEffect(mascotScale)        // 0→1.2→1.0, .bounce
            .opacity(mascotOpacity)          // 0→1
    }
}
```

**Фаза 2 (0.8–1.6s): Score reveal**
```
// Поверх маскота появляется score bubble
Text("\(Int(score))%")
    .font(TypographyTokens.kidDisplay(56))
    .foregroundStyle(scoreColor)             // excellent→Brand.butter, good→Brand.mint, ok→Parent.accent
    .scaleEffect(scoreScale)                 // 0→1.1→1.0, .bounce, delay 0.8s
```

**Фаза 3 (1.6–2.4s): Звёзды**
```
HStack(spacing: SpacingTokens.regular) {
    ForEach(0..<3) { i in
        Image(systemName: i < earnedStars ? "star.fill" : "star")
            .font(.system(size: 40))
            .foregroundStyle(i < earnedStars ? ColorTokens.Brand.butter : ColorTokens.Kid.line)
            .scaleEffect(starScales[i])      // 0→1.3→1.0 каждая с stagger 0.2s
            .rotationEffect(.degrees(starRotations[i]))  // -15→0
    }
}
```

**Фаза 4 (2.4s+): Summary + CTA**
```
ScrollView {
    VStack(spacing: SpacingTokens.large) {
        // Summary карточки
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.regular) {
                // «Слов сказано»
                SessionSummaryCard(icon: "waveform", value: "\(wordCount)", label: "слов сказано")
                // «Точность»
                SessionSummaryCard(icon: "checkmark.circle", value: "\(Int(accuracy))%", label: "точность")
                // «Время»
                SessionSummaryCard(icon: "clock", value: "\(duration) мин", label: "сессия")
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        // Награда (если разблокирована)
        if let reward = newReward {
            HSLiquidGlassCard {
                VStack(spacing: SpacingTokens.tiny) {
                    Text("Новая награда!").font(TypographyTokens.headline(18))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    HSSticker(sticker: reward)
                        .frame(width: 96, height: 96)
                        .scaleEffect(rewardScale)   // 0→1.2→1.0, .bounce delay 2.8s
                    Text(reward.name).font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .padding(SpacingTokens.cardPad)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        // Превью следующего урока
        HSCard {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(ColorTokens.Brand.primary)
                VStack(alignment: .leading) {
                    Text("Следующее: \(nextLesson.title)")
                        .font(TypographyTokens.headline(18))
                        .lineLimit(1)
                    Text(nextLesson.description)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(SpacingTokens.cardPad)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SpacingTokens.screenEdge)
        // CTA кнопки
        VStack(spacing: SpacingTokens.tiny) {
            HSButton("Продолжить!", style: .primary)
                .frame(maxWidth: .infinity, minHeight: 56)
            HSButton("На главную", style: .ghost)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.xxLarge)
    }
    .padding(.top, SpacingTokens.large)
}
.opacity(summaryOpacity)   // 0→1, delay 2.4s, .outQuick
```

**SessionSummaryCard (internal)**
```
HSCard {
    VStack(spacing: SpacingTokens.micro) {
        Image(systemName: icon).font(.system(size: 24))
            .foregroundStyle(ColorTokens.Brand.primary)
        Text(value).font(TypographyTokens.display(36))
            .foregroundStyle(ColorTokens.Kid.ink)
        Text(label).font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
    }
    .padding(SpacingTokens.cardPad)
}
.frame(width: 120, height: 120)
```

**Конфетти (HSSticker confetti)**
- `HSLottieContainer(animation: "confetti_full")` — full screen overlay
- `loopMode: .playOnce`, запускается в фазе 1 одновременно с маскотом
- z-index поверх всего, `allowsHitTesting: false`

### Состояния экрана

- `.revealing`: последовательные фазы 1–4 как описано
- `.complete`: все элементы показаны, CTA активны
- `.noReward`: блок награды скрыт, layout схлопывается

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Kid.bgDeep` → `Kid.bg` gradient | тёмный вариант |
| Score excellent | `Brand.butter` | `Brand.butter` |
| Score good | `Brand.mint` | `Brand.mint` |
| Score ok | `Parent.accent` | `Parent.accent` |
| Звёзды earned | `Brand.butter` | `Brand.butter` |
| Звёзды unearned | `Kid.line` | `Kid.line` |
| Конфетти | multicolor Lottie | multicolor Lottie |

### Типографика

- Score: `kidDisplay(56)`, Black Rounded
- Звёзды: SF Symbol font size 40pt
- Summary number: `display(36)`, Bold Rounded
- Summary label: `caption(12)`, Regular, center
- Reward name: `caption(12)`, Regular
- Следующий урок: `headline(18)` + `body(15)`
- CTA кнопка: `cta()` (17pt Bold Rounded)

### Отступы

- Summary cards scroll horizontal padding: `SpacingTokens.screenEdge` (24pt)
- Summary cards gap: `SpacingTokens.regular` (16pt)
- Between sections: `SpacingTokens.large` (24pt)
- CTA bottom: `SpacingTokens.xxLarge` (40pt) + safe area
- iPhone SE: summary card width → 100pt, score font → `kidDisplay(40)`

### Компоненты DesignSystem

- `HSMascotView` — celebrating state
- `HSLottieContainer` — конфетти full screen
- `HSSticker` — reward reveal
- `HSLiquidGlassCard` — reward контейнер (iOS 26) / `HSCard` fallback
- `HSCard` — summary cards + следующий урок
- `HSButton` — Продолжить + На главную

### Accessibility

- Маскот: `accessibilityHidden(true)` (decorative)
- Score: `accessibilityLabel("Результат: \(Int(score)) процентов")`
- Звёзды: `accessibilityLabel("Получено звёзд: \(earnedStars) из 3")`
- Summary: `accessibilityElement(children: .combine)`, label «Сказано \(wordCount) слов, точность \(Int(accuracy)) процентов, длительность \(duration) минут»
- Reward: `accessibilityLabel("Новая награда: \(reward.name)")`
- «Продолжить!»: `accessibilityLabel("Продолжить к следующему уроку")`
- `accessibilityFocus` на Score после фазы 2

### Анимации & Motion

- Фаза 1 маскот: `scale 0→1.2→1.0`, `.bounce` (response 0.4, damping 0.55), + `trigger("celebrate")`
- Фаза 2 score: `scale 0→1.1→1.0`, `.bounce`, delay 0.8s + haptic `.notificationOccurred(.success)`
- Фаза 3 звёзды: stagger 0.2s каждая, `scale 0→1.3→1.0` + `rotation -15°→0°`, `.bounce`
- Фаза 4 summary: `opacity 0→1`, delay 2.4s, `.outQuick`
- Reward: `scale 0→1.2→1.0`, `.bounce`, delay 2.8s + haptic `.impactOccurred(.heavy)`
- Конфетти: старт в фазе 1, `playOnce`, z-index top
- Reduced Motion: все bounce/scale → instant, конфетти не играет, haptic сохраняется

---

## Rewards Screen (Детальная спека)

**Роль:** kid
**Навигация:** ChildHome → Rewards; SessionComplete → Rewards
**Файл реализации:** Features/Rewards/RewardsView.swift

### Структура UI (top → bottom)

**NavBar**
- `.navigationTitle("Мои награды")`, inline
- Шрифт: `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`
- Background: `ColorTokens.Kid.bg`
- Правая кнопка: share icon 44×44pt — шаринг альбома (screenshot)

**Счётчик + прогресс**
```
VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
    HStack {
        Text("Собрано: \(unlocked) из \(total)")
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
        Spacer()
        Text("\(Int(Double(unlocked)/Double(total)*100))%")
            .font(TypographyTokens.mono(13))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
    }
    HSProgressBar(progress: Double(unlocked)/Double(total))
        .frame(maxWidth: .infinity, height: 8)
}
.padding(.horizontal, SpacingTokens.screenEdge)
.padding(.top, SpacingTokens.regular)
```

**Табы коллекций**
```
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: SpacingTokens.tiny) {
        ForEach(collections) { c in
            HSChip(c.name, selected: selectedCollection == c.id)
                .frame(minHeight: 36)
                .onTapGesture { selectedCollection = c.id }
        }
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
}
.padding(.vertical, SpacingTokens.tiny)
```

Коллекции: «Все», «Свистящие», «Шипящие», «Соноры», «Велярные», «Особые».

**Грид наград — HSRewardAlbumGrid**
```
HSRewardAlbumGrid(
    stickers: filteredStickers,
    columns: 3,
    onTap: { sticker in
        selectedSticker = sticker
        showStickerDetail = true
    }
)
.padding(.horizontal, SpacingTokens.screenEdge)
```

Каждая ячейка грида:
```
VStack(spacing: SpacingTokens.tiny) {
    ZStack {
        RoundedRectangle(cornerRadius: RadiusTokens.card)
            .fill(sticker.isUnlocked ? sticker.bgColor : ColorTokens.Kid.surfaceAlt)
            .frame(width: 96, height: 96)
        if sticker.isUnlocked {
            Image(sticker.imageName)
                .resizable().scaledToFit()
                .frame(width: 72, height: 72)
        } else {
            Image(sticker.imageName)
                .resizable().scaledToFit()
                .frame(width: 72, height: 72)
                .grayscale(1.0)
                .opacity(0.4)
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
    }
    Text(sticker.name)
        .font(TypographyTokens.caption(12))
        .foregroundStyle(sticker.isUnlocked ? ColorTokens.Kid.ink : ColorTokens.Kid.inkSoft)
        .lineLimit(1)
}
.frame(width: 96 + SpacingTokens.tiny * 2, height: 120)
```

**Sheet детали стикера (StickerDetailSheet)**
- `.sheet`, `.presentationDetents([.medium])`
- Background: `ColorTokens.Kid.bg`
```
VStack(spacing: SpacingTokens.large) {
    // Тянущий индикатор
    Capsule().fill(ColorTokens.Kid.line).frame(width: 36, height: 4)
        .padding(.top, SpacingTokens.small)
    // Стикер
    ZStack {
        Circle().fill(sticker.bgColor.opacity(0.2)).frame(width: 160, height: 160)
        if sticker.isUnlocked {
            HSLottieContainer(animation: sticker.lottieName, loopMode: .loop)
                .frame(width: 120, height: 120)
        } else {
            Image(sticker.imageName).resizable().scaledToFit()
                .frame(width: 120, height: 120).grayscale(1.0).opacity(0.4)
        }
    }
    Text(sticker.name).font(TypographyTokens.title(24)).foregroundStyle(ColorTokens.Kid.ink)
    if sticker.isUnlocked {
        Text("Получен: \(sticker.earnedDate)")
            .font(TypographyTokens.body(15)).foregroundStyle(ColorTokens.Kid.inkMuted)
        Text(sticker.earnedDescription)
            .font(TypographyTokens.body(15)).foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
    } else {
        HSCard {
            Text("Ещё \(sticker.remaining) заданий для разблокировки")
                .font(TypographyTokens.body(15)).foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
            HSProgressBar(progress: sticker.unlockProgress)
                .frame(maxWidth: .infinity, height: 6)
                .padding(.top, SpacingTokens.tiny)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SpacingTokens.screenEdge)
    }
    Spacer()
    HSButton("Готово", style: .secondary)
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, SpacingTokens.screenEdge)
    .padding(.bottom, SpacingTokens.large)
}
```

**Анимация разблокировки нового стикера (overlay)**
- Вызывается из SessionComplete или HomeTasks
- Full-screen `ZStack`, background `Kid.bgDeep` opacity 0.9
- `HSSticker` 180×180pt `scale 0→1.3→1.0`, `.bounce`
- `HSLottieContainer("confetti_reward")` full-screen behind
- Text «Новая награда!» `kidDisplay(40)` появляется после стикера, delay 0.6s
- Тап по экрану → dismiss с `opacity 1→0`, `.outQuick`

### Состояния экрана

- `.loading`: Skeleton grid 9 ячеек, shimmer
- `.empty`: «Пока нет наград. Выполни первое задание!» + маскот encouraging
- `.populated`: грид как описано
- `.newReward(sticker)`: overlay unlock animation

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Фон | `Kid.bg` | `Kid.bg` |
| Locked cell | `Kid.surfaceAlt` | `Kid.surfaceAlt` |
| Unlocked cell | `sticker.bgColor` (уникальный) | адаптивный |
| Progress bar | `Brand.mint` | `Brand.mint` |
| Tab chip active | `Brand.primary` | `Brand.primary` |
| Lock icon | `Kid.inkSoft` | `Kid.inkSoft` |

### Типографика

- NavBar: `title(24)`, inline
- Счётчик: `headline(18)` + `mono(13)`
- Chip tab: `caption(12)`
- Sticker name (grid): `caption(12)`, `lineLimit(1)`
- Sheet title: `title(24)`
- Sheet body: `body(15)`, lineSpacing normal (1.35)

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Грид gap: `SpacingTokens.regular` (16pt)
- Tab chips gap: `SpacingTokens.tiny` (8pt)
- Progress bar height: 8pt (альбом) / 6pt (detail sheet)
- iPhone SE: колонки → 3 (держим, ячейка сжимается до 88pt)

### Компоненты DesignSystem

- `HSRewardAlbumGrid` — основной компонент (см. M7.3)
- `HSSticker` — отдельные стикеры
- `HSProgressBar` — общий прогресс + unlock progress в sheet
- `HSLottieContainer` — анимация стикера в sheet + confetti overlay
- `HSCard` — карточка "ещё N заданий" в sheet
- `HSButton` — «Готово» в sheet
- `HSChip` — табы коллекций
- `HSMascotView` — empty state

### Accessibility

- Грид: `LazyVGrid` каждая ячейка — `accessibilityRole(.button)`
- Unlocked: `accessibilityLabel("\(sticker.name). Получен \(sticker.earnedDate).")`
- Locked: `accessibilityLabel("\(sticker.name). Заблокировано. Осталось \(sticker.remaining) заданий.")`
- Progress top: `accessibilityLabel("Собрано \(unlocked) наград из \(total)")`
- Sheet dismiss: `accessibilityLabel("Закрыть")`, `accessibilityAddTraits(.isButton)`
- Min touch target: 96×96pt ячейки > 56pt ✓

### Анимации & Motion

- Unlock overlay появление: `opacity 0→1` + стикер `scale 0→1.3→1.0`, `.bounce`
- Конфетти: `HSLottieContainer("confetti_reward")`, playOnce
- Грид появление: stagger 0.04s, `opacity 0→1` + `scale 0.9→1.0`, `.spring`
- Sheet open: системный `.sheet` transition
- Tab switch: `opacity 0→1` новый контент, `.outQuick`
- Reduced Motion: все scale/bounce → instant opacity, конфетти не играет

---

## Demo Screen (Детальная спека)

**Роль:** kid (демо-пользователь)
**Навигация:** LaunchScreen → Demo → [Onboarding Auth или ChildHome (если demo завершён)]
**Файл реализации:** Features/Demo/DemoModeView.swift (coordinator + step views)

### Архитектура демо-флоу (15 шагов)

Demo реализован как `DemoCoordinator` с `NavigationStack` и последовательными шагами.

| Шаг | View | Контент |
|---|---|---|
| 1 | `DemoSplashView` | Логотип + маскот + «Попробуй бесплатно» |
| 2 | `DemoChildHomeView` | ChildHome с demo-баннером |
| 3 | `DemoLessonIntroView` | Карточка урока «Звук С» |
| 4 | `DemoListenAndChooseView` | 1 вопрос listen-and-choose |
| 5 | `DemoRepeatAfterModelView` | 1 вопрос repeat-after-model |
| 6 | `DemoBreathingView` | 1 упражнение breathing |
| 7 | `DemoARPreviewView` | AR с locked-оверлеем |
| 8 | `DemoSessionCompleteView` | Мини-результат с 1 звездой |
| 9 | `DemoRewardRevealView` | Разблокировка demo-стикера «Ляля» |
| 10 | `DemoParentHomeView` | Parent dashboard с заглушками |
| 11 | `DemoProgressView` | Мини-график 7 дней |
| 12 | `DemoWorldMapView` | WorldMap — открыта только 1 зона |
| 13 | `DemoSettingsView` | Settings — disabled секции |
| 14 | `DemoUpsellView` | Регистрация CTA |
| 15 | `DemoCompleteView` | «Понравилось? Начни бесплатно» |

### DemoSplashView (Шаг 1)

```
ZStack {
    ColorTokens.Kid.bg.ignoresSafeArea()
    VStack(spacing: SpacingTokens.large) {
        Spacer()
        // Логотип
        Image("AppLogo").resizable().scaledToFit().frame(width: 120, height: 120)
        // Маскот Ляля
        HSMascotView(state: .celebrating)
            .frame(width: 200, height: 200)
        // Заголовок
        Text("Попробуй бесплатно").font(TypographyTokens.title(24))
            .foregroundStyle(ColorTokens.Kid.ink).multilineTextAlignment(.center)
        Text("15 шагов — и ты узнаешь всё о HappySpeech")
            .font(TypographyTokens.body(22))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
        Spacer()
        VStack(spacing: SpacingTokens.tiny) {
            HSButton("Начать демо", style: .primary)
                .frame(maxWidth: .infinity, minHeight: 56)
            HSButton("Войти в аккаунт", style: .ghost)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
    }
}
```

### Demo-баннер (присутствует на шагах 2–13)

```
// Постоянный баннер вверху экрана
HSCard {
    HStack(spacing: SpacingTokens.regular) {
        Image(systemName: "play.rectangle.fill")
            .foregroundStyle(ColorTokens.Brand.butter)
            .font(.system(size: 16))
        Text("Демо-режим")
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.ink)
        Text("Шаг \(currentStep) из 15")
            .font(TypographyTokens.mono(13))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
        Spacer()
        Button("Зарегистрироваться") { skipToUpsell() }
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Brand.primary)
            .fontWeight(.bold)
    }
    .padding(.horizontal, SpacingTokens.regular)
    .padding(.vertical, SpacingTokens.small)
}
.frame(maxWidth: .infinity, minHeight: 44)
.padding(.horizontal, SpacingTokens.screenEdge)
```

### DemoARPreviewView (Шаг 7) — Locked overlay

```
ZStack {
    ARZoneView(isDemo: true)   // нормальный AR, но без scoring
    // Locked overlay на 80% экрана
    VStack {
        Spacer()
        HSLiquidGlassCard {
            VStack(spacing: SpacingTokens.regular) {
                Image(systemName: "lock.fill").font(.system(size: 40))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                Text("AR-упражнения в полной версии")
                    .font(TypographyTokens.title(24))
                    .multilineTextAlignment(.center)
                HSButton("Зарегистрироваться", style: .primary)
                    .frame(maxWidth: .infinity, minHeight: 56)
                HSButton("Продолжить демо", style: .ghost)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(SpacingTokens.cardPad)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
    }
}
```

### DemoUpsellView (Шаг 14) — Главный конверсионный экран

```
ZStack {
    // Gradient фон
    LinearGradient(
        colors: [ColorTokens.Brand.lilac.opacity(0.3), ColorTokens.Kid.bg],
        startPoint: .top, endPoint: .bottom
    ).ignoresSafeArea()
    VStack(spacing: SpacingTokens.large) {
        Spacer()
        HSMascotView(state: .celebrating).frame(width: 160, height: 160)
        Text("Понравилось?").font(TypographyTokens.kidDisplay(40))
            .foregroundStyle(ColorTokens.Kid.ink)
        Text("Зарегистрируйся и занимайся каждый день бесплатно!")
            .font(TypographyTokens.body(22))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
        // Feature list
        VStack(alignment: .leading, spacing: SpacingTokens.regular) {
            ForEach(features) { f in
                HStack(spacing: SpacingTokens.regular) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Brand.mint)
                        .font(.system(size: 20))
                    Text(f.text).font(TypographyTokens.body(15))
                }
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        Spacer()
        VStack(spacing: SpacingTokens.tiny) {
            HSButton("Зарегистрироваться бесплатно", style: .primary)
                .frame(maxWidth: .infinity, minHeight: 56)
            HSButton("Войти", style: .ghost)
                .frame(maxWidth: .infinity, minHeight: 44)
            Text("Данные карты не требуются")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
    }
}
```

### Состояния Demo-флоу

- `.stepN`: текущий шаг, прогресс-индикатор в баннере
- `.lockedSection`: overlay на AR / Premium фичах
- `.upsell`: шаг 14, конверсионный
- `.completed`: переход на Onboarding Auth

### Навигация Demo

- Кнопки «Далее»/«Продолжить демо» → `demoCoordinator.advance()`
- Кнопка «Зарегистрироваться» → `demoCoordinator.skipToUpsell()` или `demoCoordinator.goToAuth()`
- Кнопка «На главную» (шаг 15) → `demoCoordinator.complete()` → ChildHome (guest mode)
- Back gesture: `interactivePopGestureRecognizer` включён, возврат на предыдущий шаг

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Demo баннер | `Kid.surface` + `Brand.butter` icon | аналогично |
| AR locked overlay | `Brand.lilac` opacity 0.3 + glass | glass тёмный |
| Upsell gradient | `Brand.lilac` 30% → `Kid.bg` | dark variant |
| Features checkmark | `Brand.mint` | `Brand.mint` |

### Типографика

- Splash title: `title(24)`, Semibold Rounded
- Splash subtitle: `body(22)` (22pt kid), lineSpacing 1.5
- Demo баннер label: `caption(12)` + `mono(13)`
- Upsell hero: `kidDisplay(40)`, Black Rounded
- Upsell subtitle: `body(22)`, lineSpacing 1.5
- Feature items: `body(15)`, Regular

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Demo banner: padding H `SpacingTokens.regular` (16pt), V `SpacingTokens.small` (12pt)
- Between steps sections: `SpacingTokens.large` (24pt)
- iPhone SE: splash маскот → 160×160pt, upsell hero → `display(36)`

### Компоненты DesignSystem

- `HSMascotView` — splash + upsell
- `HSLiquidGlassCard` — AR locked overlay (iOS 26) / `HSCard` fallback
- `HSButton` — все CTA
- `HSCard` — demo баннер, feature cards
- `HSProgressBar` — не используется (баннер показывает шаг текстом)

### Accessibility

- Demo баннер: `accessibilityElement(children: .combine)`, label «Демо-режим, шаг \(n) из 15»
- «Зарегистрироваться»: `accessibilityLabel("Зарегистрироваться бесплатно")`, `accessibilityHint("Переход к созданию аккаунта")`
- Locked overlay: `accessibilityLabel("Эта функция доступна в полной версии")`, кнопки доступны
- Feature checkmarks: `accessibilityHidden(true)` (иконки декоративные), текст читается

### Анимации & Motion

- Splash маскот: `scale 0→1.2→1.0`, `.bounce`, delay 0.3s
- Demo баннер: slide-in сверху, `offset(y: -40→0)`, `.spring`
- Переход между шагами: `.page` (easeOut 0.35s), cross-dissolve
- Upsell появление: gradient fade in `opacity 0→1`, `.page`; маскот `scale 0→1.1→1.0`, `.spring`
- Reduced Motion: все переходы → `opacity` fade 0.2s

---

## Onboarding Screen (Детальная спека)

**Роль:** universal (шаги меняются по роли)
**Навигация:** LaunchScreen (first run) → Onboarding → ChildHome / ParentHome / SpecialistHome
**Файл реализации:** Features/Onboarding/OnboardingFlowView.swift

### Архитектура Onboarding (10 шагов)

```
OnboardingFlowView (NavigationStack coordinator)
├── Step 1: OnboardingWelcomeView         — universal
├── Step 2: OnboardingRoleView            — universal
├── Step 3: OnboardingAboutView           — parent / specialist (kid пропускает)
├── Step 4: OnboardingChildCreationView   — parent / kid
├── Step 5: OnboardingGoalsView           — parent / specialist (kid пропускает)
├── Step 6: OnboardingPreferencesView     — parent (kid + specialist → пропускают)
├── Step 7: OnboardingScreeningIntroView  — universal
├── Step 8: PermissionsFlowView           — universal (4 под-экрана)
├── Step 9: OnboardingPackDownloadView    — universal
└── Step 10: OnboardingCompleteView       — universal
```

### Общий шаблон шагов (OnboardingStepContainer)

```
VStack(spacing: 0) {
    // Прогресс-индикатор
    OnboardingProgressBar(
        totalSteps: visibleStepsCount,
        currentStep: currentStepIndex
    )
    .padding(.horizontal, SpacingTokens.screenEdge)
    .padding(.top, SpacingTokens.regular)
    // Контент шага
    currentStepView
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    // Нижняя кнопка «Назад» (если не первый шаг)
    if currentStepIndex > 0 {
        Button("Назад") { coordinator.back() }
            .font(TypographyTokens.body(15))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .frame(height: 44)
    }
}
.background(stepBackgroundColor)
.animation(.page, value: currentStepIndex)
```

**OnboardingProgressBar**
```
HStack(spacing: SpacingTokens.tiny) {
    ForEach(0..<totalSteps, id: \.self) { i in
        Capsule()
            .fill(i <= currentStep ? ColorTokens.Brand.primary : ColorTokens.Kid.line)
            .frame(height: 4)
            .animation(.outQuick, value: currentStep)
    }
}
.frame(maxWidth: .infinity)
```

### Step 1 — Welcome (OnboardingWelcomeView)

Background: `Kid.bg`, full-bleed radial gradient

```
ZStack {
    RadialGradient(
        colors: [ColorTokens.Kid.bgSofter, ColorTokens.Kid.bgDeep],
        center: .top, startRadius: 0, endRadius: UIScreen.main.bounds.height * 0.8
    ).ignoresSafeArea()
    VStack(spacing: SpacingTokens.large) {
        Spacer()
        HSMascotView(state: .celebrating)
            .frame(width: 180, height: 180)
            .scaleEffect(mascotScale)   // 0→1, .bounce delay 0.3s
        VStack(spacing: SpacingTokens.regular) {
            Text("Привет! Я Ляля")
                .font(TypographyTokens.kidDisplay(40))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .opacity(textOpacity)   // 0→1 delay 0.7s
            Text("Вместе научимся говорить красиво!")
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(TypographyTokens.LineSpacing.relaxed)
                .opacity(textOpacity)
        }
        Spacer()
        HSButton("Начать!", style: .primary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
            .opacity(ctaOpacity)   // 0→1 delay 1.0s, .spring
    }
}
```

### Step 2 — Выбор роли (OnboardingRoleView)

Background: `Kid.bg`

```
VStack(spacing: SpacingTokens.large) {
    Text("Кто будет заниматься?")
        .font(TypographyTokens.title(24))
        .foregroundStyle(ColorTokens.Kid.ink)
        .padding(.top, SpacingTokens.xxLarge)
    // Две карточки роли — дети и родители
    HStack(spacing: SpacingTokens.regular) {
        RoleCard(role: .child, selected: selectedRole == .child,
                 icon: "figure.child", title: "Ребёнок", subtitle: "6–8 лет")
        RoleCard(role: .parent, selected: selectedRole == .parent,
                 icon: "figure.2.and.child.holdinghands", title: "Родитель", subtitle: "Для мамы и папы")
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
    // Карточка специалиста — полная ширина
    RoleCard(role: .specialist, selected: selectedRole == .specialist,
             icon: "stethoscope", title: "Логопед", subtitle: "Профессиональные инструменты")
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.horizontal, SpacingTokens.screenEdge)
    Spacer()
    HSButton("Далее", style: .primary)
        .frame(maxWidth: .infinity, minHeight: 56)
        .disabled(selectedRole == nil)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.large)
}
```

**RoleCard**
```
VStack(spacing: SpacingTokens.small) {
    Image(systemName: icon).font(.system(size: 40))
        .foregroundStyle(selected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
        .frame(width: 56, height: 56)
    Text(title).font(TypographyTokens.headline(18))
        .foregroundStyle(selected ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
    Text(subtitle).font(TypographyTokens.caption(12))
        .foregroundStyle(ColorTokens.Kid.inkMuted)
        .multilineTextAlignment(.center)
}
.padding(SpacingTokens.cardPad)
.frame(maxWidth: .infinity, minHeight: 150)
.background(
    RoundedRectangle(cornerRadius: RadiusTokens.card)
        .fill(selected ? ColorTokens.Brand.primary.opacity(0.1) : ColorTokens.Kid.surface)
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .stroke(selected ? ColorTokens.Brand.primary : ColorTokens.Kid.line, lineWidth: 2)
        )
)
```

### Step 4 — Создание профиля (OnboardingChildCreationView)

Background: `Kid.bg`

```
ScrollView {
    VStack(spacing: SpacingTokens.large) {
        // Аватар-пикер
        Button { showAvatarPicker = true } label: {
            ZStack {
                Circle().fill(ColorTokens.Kid.surfaceAlt).frame(width: 96, height: 96)
                if let avatar = selectedAvatar {
                    Image(avatar).resizable().scaledToFill()
                        .frame(width: 96, height: 96).clipShape(Circle())
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
                // Бейдж редактирования
                Circle().fill(ColorTokens.Brand.primary).frame(width: 28, height: 28)
                    .overlay(Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(.white))
                    .offset(x: 32, y: 32)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Выбрать аватар ребёнка")
        // Имя ребёнка
        VStack(alignment: .leading, spacing: SpacingTokens.micro) {
            Text("Имя ребёнка").font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            TextField("Например, Маша", text: $childName)
                .font(TypographyTokens.headline(18))
                .padding(SpacingTokens.cardPad)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.chip)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(RoundedRectangle(cornerRadius: RadiusTokens.chip)
                            .stroke(nameFieldFocused ? ColorTokens.Brand.primary : ColorTokens.Kid.line, lineWidth: 1.5))
                )
                .frame(minHeight: 56)
                .focused($nameFieldFocused)
        }
        // Возраст
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text("Возраст").font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach([5, 6, 7, 8], id: \.self) { age in
                    Button {
                        selectedAge = age
                    } label: {
                        Text("\(age) лет").font(TypographyTokens.body(15))
                            .foregroundStyle(selectedAge == age ? .white : ColorTokens.Kid.ink)
                            .padding(.horizontal, SpacingTokens.regular)
                            .frame(height: 44)
                            .background(
                                Capsule().fill(selectedAge == age ? ColorTokens.Brand.primary : ColorTokens.Kid.surfaceAlt)
                            )
                    }
                    .accessibilityRole(.button)
                    .accessibilityLabel("\(age) лет")
                    .accessibilityAddTraits(selectedAge == age ? .isSelected : [])
                }
            }
        }
        Spacer(minLength: SpacingTokens.sectionGap)
        HSButton("Создать профиль", style: .primary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .disabled(childName.trimmingCharacters(in: .whitespaces).isEmpty || selectedAge == nil)
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
    .padding(.vertical, SpacingTokens.large)
}
```

### Step 9 — Загрузка пака (OnboardingPackDownloadView)

Background: `Kid.bg`

```
VStack(spacing: SpacingTokens.large) {
    Spacer()
    HSMascotView(state: downloadState == .complete ? .celebrating : .thinking)
        .frame(width: 120, height: 120)
    Text(downloadState == .complete ? "Всё готово!" : "Готовим упражнения…")
        .font(TypographyTokens.title(24))
        .foregroundStyle(ColorTokens.Kid.ink)
    // Progress
    VStack(spacing: SpacingTokens.tiny) {
        HSProgressBar(progress: downloadProgress)
            .frame(maxWidth: .infinity, height: 8)
        Text(downloadState.statusText)   // «Загружаем звуки… 45%»
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
    }
    .padding(.horizontal, SpacingTokens.screenEdge)
    // При ошибке — retry
    if downloadState == .error {
        HSButton("Повторить", style: .secondary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, SpacingTokens.screenEdge)
    }
    Spacer()
}
```

### Step 10 — Готово (OnboardingCompleteView)

Background: `Kid.bg` + confetti overlay

```
ZStack {
    ColorTokens.Kid.bg.ignoresSafeArea()
    // Confetti
    HSLottieContainer(animation: "confetti_full", loopMode: .playOnce)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    VStack(spacing: SpacingTokens.large) {
        Spacer()
        HSMascotView(state: .celebrating).frame(width: 200, height: 200)
            .scaleEffect(finalScale)   // 0→1.1→1.0, .bounce
        Text("Всё готово!").font(TypographyTokens.kidDisplay(40))
            .foregroundStyle(ColorTokens.Kid.ink)
        Text("Начинаем заниматься!").font(TypographyTokens.title(24))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
        Spacer()
        HSButton("Поехали!", style: .primary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
            .scaleEffect(ctaScale)   // 0.9→1.0, .bounce delay 1.0s
    }
}
```

### Состояния Onboarding-флоу

- `.stepN`: шаг N из total visible (3–10 в зависимости от роли)
- `.downloading`: шаг 9, прогресс 0→1
- `.downloadError`: кнопка retry
- `.complete`: конфетти + переход
- `.skippable`: кнопка «Пропустить» в правом углу прогресс-бара (шаги 3, 5, 6)

### Цветовая схема

| Элемент | Light | Dark |
|---|---|---|
| Steps 1,2,4,7,8,9,10 фон | `Kid.bg` | `Kid.bg` тёмный |
| Steps 3,5,6 фон | `Parent.bg` | `Parent.bg` тёмный |
| Прогресс-индикатор active | `Brand.primary` | `Brand.primary` |
| Прогресс-индикатор inactive | `Kid.line` | `Kid.line` |
| RoleCard selected | `Brand.primary` opacity 0.1 + border | адаптивный |
| TextField focused | `Brand.primary` border | адаптивный |

### Типографика

- Welcome hero: `kidDisplay(40)`, Black Rounded
- Step titles: `title(24)`, Semibold Rounded
- Role card title: `headline(18)`, Semibold Rounded
- Role card subtitle: `caption(12)`, Regular
- TextField label: `caption(12)`, Regular, `Kid.inkMuted`
- Download status: `caption(12)`, Regular
- Final «Поехали!» CTA: `cta()` (17pt Bold Rounded)

### Отступы

- Horizontal: `SpacingTokens.screenEdge` (24pt)
- Progress bar top: `SpacingTokens.regular` (16pt)
- Between major elements: `SpacingTokens.large` (24pt)
- CTA bottom: `SpacingTokens.large` + safe area
- iPhone SE: маскот Step 1 → 140×140pt, kidDisplay(40) → display(32)

### Компоненты DesignSystem

- `HSMascotView` — Steps 1, 7, 9, 10
- `HSButton` — все CTA
- `HSProgressBar` — прогресс-индикатор шагов + загрузка пака
- `HSLottieContainer` — confetti step 10 + permission animations step 8
- `HSCard` — role cards (custom styled)
- `HSChip` — возраст-пики, цели (step 5)

### Accessibility

- Прогресс-бар шагов: `accessibilityLabel("Шаг \(current) из \(total)")`, `accessibilityAddTraits(.updatesFrequently)`
- Маскот: `accessibilityHidden(true)` (декоративный на всех шагах)
- «Назад»: `accessibilityLabel("Назад к предыдущему шагу")`
- RoleCard: `accessibilityRole(.button)`, `accessibilityLabel("\(title), \(subtitle)")`, `accessibilityAddTraits(selected ? .isSelected : [])`
- Аватар-пикер: `accessibilityLabel("Выбрать аватар")`, `accessibilityRole(.button)`, target 96×96pt > 56pt ✓
- Возраст-чипы: `accessibilityRole(.button)`, `accessibilityLabel("\(age) лет")`, `accessibilityAddTraits(selected ? .isSelected : [])`
- Min touch target: 56pt для всех интерактивных элементов (kid контур) ✓

### Анимации & Motion

- Переход между шагами: `.asymmetric(insertion: .move(.trailing) + .opacity, removal: .move(.leading) + .opacity)`, `.page` (easeOut 0.35s)
- Step 1 маскот: `scale 0→1.2→1.0`, `.bounce`, delay 0.3s
- Step 1 текст: `opacity 0→1`, delay 0.7s, `.outQuick`
- Step 1 CTA: `opacity 0→1`, delay 1.0s, `.spring`
- Step 2 role select: `scale 1→1.04→1.0`, `.bounce` + border color change `.outQuick`
- Step 10 маскот: `scale 0→1.1→1.0`, `.bounce`
- Step 10 CTA: `scale 0.9→1.0`, `.bounce`, delay 1.0s
- Step 10 confetti: `playOnce` при появлении экрана
- Download progress: `HSProgressBar` animated fill, `.outQuick`
- Reduced Motion: все spring/bounce → `opacity` fade 0.15s, confetti не играет, переходы → `opacity` cross-fade

---

## M7.2 Batch 3 — Спеки 10 экранов (2026-04-25)

> Токены (актуальные из кода): SpacingTokens.screenEdge=24pt, cardPad=20pt, sectionGap=32pt, large=24pt, regular=16pt, small=12pt, tiny=8pt, micro=4pt. RadiusTokens: chip=8pt, sm=12pt, md=18pt, card=24pt, button=32pt. TypographyTokens: kidDisplay(40)=Black Rounded, display(36)=Bold Rounded, title(24)=Semibold Rounded, headline(18)=Semibold Rounded, body(15)=Regular, caption(12)=Regular, mono(13)=Medium Monospaced, cta()=17pt Bold Rounded.

---

## ChildHome Screen

**Роль:** kid
**Навигация:** Auth/Onboarding → ChildHome (tab root) → WorldMap | HomeTasks | Rewards | SessionShell | ARZone
**Файл реализации:** Features/ChildHome/ChildHomeView.swift

### Структура UI (top → bottom)

**NavBar**
- Стиль: `.large` title, отображает «Привет, [Имя]!»
- Шрифт: `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`
- Правая кнопка: аватар-кружок ребёнка 36×36pt, `RadiusTokens.full`, touch target 44×44pt → `ChildProfile`
- Background: `ColorTokens.Kid.bg`, без separator

**Hero-секция (HStack)**
- Padding horizontal: `SpacingTokens.screenEdge` (24pt)
- Padding top: `SpacingTokens.pageTop` (40pt) от safe area
- Левая колонка:
  - «Привет, [Имя]!» — `TypographyTokens.display(32)`, `ColorTokens.Kid.ink`, lineLimit 1
  - Дата: «Суббота, 25 апреля» — `TypographyTokens.caption(13)`, `ColorTokens.Kid.inkMuted`
  - `HSBadge` streak: огонёк + «N дней» — `ColorTokens.Brand.butter`, высота 28pt, corner `RadiusTokens.full`
- Правая колонка: `HSMascotView(state: .idle)` — 96×96pt, touch target 56×56pt

**AchievementBanner (условно — если `viewModel.hasAchievement`)**
- `HSCard`, padding `SpacingTokens.cardPad`
- Background: `ColorTokens.Brand.gold` opacity 0.12
- Border: `ColorTokens.Brand.gold` opacity 0.4, ширина 1.5pt
- Corner radius: `RadiusTokens.card` (24pt)
- HStack: звезда-иконка 32pt + текст ачивки (`TypographyTokens.headline(17)`) + кнопка «×» 44×44pt
- Появление: `.scale(0.92).opacity(0) → identity`, `.spring`, delay 0.2s после загрузки

**DailyMission-секция**
- Заголовок секции: «Задание дня» — `TypographyTokens.title(22)`, `ColorTokens.Kid.ink`, padding horizontal `SpacingTokens.screenEdge`
- `HSCard` миссии:
  - Background: `ColorTokens.Kid.surface`
  - Corner radius: `RadiusTokens.card`
  - Padding: `SpacingTokens.cardPad`
  - Иконка миссии: 48×48pt круг с `ColorTokens.Brand.primary` opacity 0.15, иконка SF Symbol 24pt
  - Название: `TypographyTokens.headline(18)`, `ColorTokens.Kid.ink`, lineLimit 2
  - Прогресс: «N из M повторений» — `TypographyTokens.body(15)`, `ColorTokens.Kid.inkMuted`
  - `HSProgressBar(progress: mission.progress)` height 8pt, `ColorTokens.Session.progressBar`
  - CTA «Начать» — `HSButton(style: .primary)` .infinity × 56pt

**QuickPlay-секция (горизонтальная карусель)**
- Заголовок: «Быстрые игры» — `TypographyTokens.title(22)`, `ColorTokens.Kid.ink`, padding horizontal `SpacingTokens.screenEdge`
- `ScrollView(.horizontal, showsIndicators: false)`
- `HStack(spacing: SpacingTokens.small)` с `LazyHStack`
- `HSCard` игры: 140×160pt, corner `RadiusTokens.card`
  - Фон: цвет из `ColorTokens.Games.*` opacity 0.18
  - Иллюстрация: SF Symbol или asset 56×56pt
  - Название: `TypographyTokens.headline(16)`, `ColorTokens.Kid.ink`, lineLimit 2
  - Touch target: весь card ≥ 56×56pt ✓
- Padding leading: `SpacingTokens.screenEdge`, trailing: `SpacingTokens.screenEdge`

**QuickActions-секция (2×2 grid)**
- `LazyVGrid(columns: 2, spacing: SpacingTokens.small)`
- Padding horizontal: `SpacingTokens.screenEdge`
- 4 действия: «Карта мира» | «Мои стикеры» | «AR-зона» | «Задания»
- Каждая кнопка: `HSCard`, высота 80pt, `HStack` иконка 28pt + текст `TypographyTokens.body(15)`
- Иконки SF Symbol, цвета из Brand-палитры, touch target ≥ 56pt ✓

**SoundProgress-секция**
- Заголовок: «Мои звуки» — `TypographyTokens.title(22)`, padding `SpacingTokens.screenEdge`
- `VStack(spacing: SpacingTokens.listGap)` из до 3 строк прогресса
- Строка: иконка-буква 40×40pt круг + название + `HSProgressBar` + процент `TypographyTokens.mono(13)`
- Цвет бара: `ColorTokens.SoundFamilyColors.hue(for:)`
- Кнопка «Подробнее» внизу: `HSButton(style: .ghost)` .infinity × 44pt → `ProgressDashboard`

**RecentSessions-секция**
- Заголовок: «Последние занятия» — `TypographyTokens.title(22)`, padding horizontal `SpacingTokens.screenEdge`
- До 3 `HSCard` сессий: `HStack` дата + звук + результат + accuracy `TypographyTokens.mono(13)`
- Фон карточки: `ColorTokens.Kid.surface`, corner `RadiusTokens.card`

### Состояния экрана

- **.loading**: skeleton 3 секции, shimmer `ColorTokens.Kid.surfaceAlt` opacity 0→1→0, 1.2s loop
- **.populated**: полный layout, данные из ViewModel
- **.empty** (первый вход без данных): только Hero + маскот `speaking` + CTA «Начать первое занятие»
- **.error**: `HSToast(.error)` снизу, данные из кэша если есть

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Kid.bg` |
| Карточки | `ColorTokens.Kid.surface` |
| Акцент CTA | `ColorTokens.Brand.primary` |
| Streak badge | `ColorTokens.Brand.butter` |
| Achievement border | `ColorTokens.Brand.gold` |
| Progress bar | `ColorTokens.Session.progressBar` |
| Ink (текст) | `ColorTokens.Kid.ink` |
| Muted текст | `ColorTokens.Kid.inkMuted` |

### Типографика

- Hero greeting: `TypographyTokens.display(32)`, Black Rounded
- Дата: `TypographyTokens.caption(13)`, Regular
- Заголовки секций: `TypographyTokens.title(22)`, Semibold Rounded
- Card titles: `TypographyTokens.headline(18)`, Semibold Rounded
- Body text: минимум 22pt в kid-контуре → `TypographyTokens.body(22)`
- Проценты/числа: `TypographyTokens.mono(13)`

### Отступы

- Горизонтальный edge: `SpacingTokens.screenEdge` (24pt)
- Между секциями: `SpacingTokens.sectionGap` (32pt)
- Внутри карточек: `SpacingTokens.cardPad` (20pt)
- Между элементами списка: `SpacingTokens.listGap` (12pt)
- Карусель gap: `SpacingTokens.small` (12pt)

### Компоненты DS

- `HSMascotView` — idle / speaking / celebrating
- `HSCard` — карточки миссии, игр, сессий
- `HSProgressBar` — прогресс миссии (8pt) и звуков (6pt)
- `HSBadge` — streak badge
- `HSButton(style: .primary)` — CTA миссии 56pt
- `HSButton(style: .ghost)` — «Подробнее»
- `HSToast` — ошибка

### Accessibility

- `accessibilityElement(children: .combine)` на card игры: «[название игры], кнопка»
- Streak badge: `accessibilityLabel("Серия: \(streak) дней")`, `accessibilityHint("Занимайся каждый день, чтобы не потерять серию")`
- Маскот: `accessibilityLabel("Ляля, твой помощник")`, `accessibilityHidden(true)` если декоративная
- Progress bar: `accessibilityValue("\(Int(progress * 100)) процентов")`
- Min touch target: 56×56pt (kid) ✓, QuickActions ≥ 80pt ✓

### Анимации

- Hero: `opacity 0→1` + `offset(y: -12→0)`, `.spring(duration: 0.45, bounce: 0.2)`, delay 0s
- Маскот: `scale 0.85→1.0`, `.spring(duration: 0.5, bounce: 0.25)`, delay 0.1s
- Секции: stagger 0.08s, `opacity 0→1` + `offset(y: 16→0)`, `.spring(duration: 0.4, bounce: 0.15)`
- AchievementBanner: `scale 0.92→1.0` + `opacity 0→1`, `.spring`, delay 0.3s
- QuickPlay карточки: hover `.scale(1.03)`, `.spring(duration: 0.25, bounce: 0.15)`
- Reduced Motion: все анимации → `opacity` fade 0.2s linear, без stagger

### iPhone SE адаптация (width < 375pt)

- screenEdge → 16pt
- Маскот: 80×80pt
- display(32) → display(28)
- QuickPlay карточки: 120×140pt
- QuickActions: grid spacing → `SpacingTokens.tiny` (8pt)

---

## ParentHome Screen

**Роль:** parent
**Навигация:** Auth → ParentHome (root TabView) → [Dashboard | Sessions | Analytics | Settings]
**Файл реализации:** Features/ParentHome/ParentHomeView.swift

### Структура UI (top → bottom)

**TabView (4 вкладки)**
- `.tint(ColorTokens.Parent.accent)`
- Вкладки: «Обзор» (house.fill) | «Занятия» (list.bullet.rectangle) | «Аналитика» (chart.xyaxis.line) | «Настройки» (gearshape.fill)
- TabBar background: `ColorTokens.Parent.bg`, separator `ColorTokens.Parent.line`

**Вкладка «Обзор» (ParentDashboardTab)**

NavBar:
- Inline title «Обзор» — `TypographyTokens.title(24)`, `ColorTokens.Parent.ink`
- Правая кнопка: иконка уведомления 24pt, touch target 44×44pt

ChildSwitcher (если несколько детей):
- `ScrollView(.horizontal)` с `HSChip` для каждого ребёнка
- Active chip: `ColorTokens.Parent.accent` bg, white text
- Chip: `TypographyTokens.caption(13)`, высота 36pt, corner `RadiusTokens.chip` (8pt)
- Padding horizontal: `SpacingTokens.screenEdge`

SummaryCards (LazyVGrid 2×2, spacing `SpacingTokens.small`):
- «Занятий на этой неделе»: число + трендовая стрелка
- «Точность»: % + HSProgressBar 6pt
- «Серия дней»: иконка огня + число
- «Звуков в работе»: список мини-бейджей
- Каждая карточка: `HSCard`, padding `SpacingTokens.cardPad`, corner `RadiusTokens.card`
- Число: `TypographyTokens.display(32)`, `ColorTokens.Parent.ink`
- Подпись: `TypographyTokens.caption(12)`, `ColorTokens.Parent.inkMuted`

TodayPlan-секция:
- Заголовок «На сегодня» — `TypographyTokens.headline(18)`, padding horizontal `SpacingTokens.screenEdge`
- `HSCard` план: список задач с чекбоксами, `ColorTokens.Parent.surface`
- Каждая задача: `HStack` чекбокс 24pt + текст `TypographyTokens.body(15)` + время `TypographyTokens.caption(12)` `ColorTokens.Parent.inkSoft`
- Min touch target чекбокса: 44×44pt

AIInsight-банер:
- Округлённый `HSCard` с gradient overlay: `ColorTokens.Brand.sky → ColorTokens.Brand.lilac`, opacity 0.15
- Иконка «sparkles» 20pt `ColorTokens.Brand.lilac` + текст AI-сводки `TypographyTokens.body(15)`
- lineLimit 3, `.minimumScaleFactor(0.9)`
- Кнопка «Подробнее» ghost → `ProgressDashboard`

**Вкладка «Занятия» (ParentSessionsTab)**
- `List` сессий, style `.insetGrouped`
- Группировка по дате («Сегодня», «Вчера», «2 дня назад»)
- Строка: `HStack` — звук 40×40pt + дата + accuracy badge `TypographyTokens.mono(13)`
- Background строки: `ColorTokens.Parent.surface`
- Separator: `ColorTokens.Parent.line`
- Touch target строки: ≥ 44pt ✓

**Вкладка «Аналитика» (ParentAnalyticsTab)**
- Swift Charts `BarMark` — занятия за 7 дней, `ColorTokens.Brand.mint`
- Swift Charts `LineMark` — точность по 4 неделям, `ColorTokens.Parent.accent`
- Звуковая карта: `HSCard` для каждого звука, `HSProgressBar` trend, `TypographyTokens.mono(13)` процент

### Состояния экрана

- **.loading**: `ProgressView()` по центру, `ColorTokens.Parent.accent`
- **.populated**: полный layout
- **.empty** (нет детей): иллюстрация + «Добавьте ребёнка» + CTA «Добавить»
- **.error**: `HSToast(.error)` + кнопка «Повторить»

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Parent.bg` |
| Карточки | `ColorTokens.Parent.surface` |
| Акцент | `ColorTokens.Parent.accent` |
| Ink | `ColorTokens.Parent.ink` |
| Muted | `ColorTokens.Parent.inkMuted` |
| TabBar tint | `ColorTokens.Parent.accent` |
| Charts bars | `ColorTokens.Brand.mint` |

### Типографика

- Dashboard числа: `TypographyTokens.display(32)`, Bold Rounded
- Заголовки секций: `TypographyTokens.headline(18)`, Semibold Rounded
- Body: `TypographyTokens.body(15)`, Regular Default
- Badge/метрики: `TypographyTokens.mono(13)`, Medium Monospaced
- Caption подписи: `TypographyTokens.caption(12)`, Regular

### Отступы

- Horizontal edge: `SpacingTokens.screenEdge` (24pt)
- Между секциями: `SpacingTokens.sectionGap` (32pt)
- Внутри карточки: `SpacingTokens.cardPad` (20pt)
- Grid gap: `SpacingTokens.small` (12pt)

### Компоненты DS

- `HSCard` — SummaryCards, TodayPlan, AIInsight
- `HSProgressBar` — accuracy и звуки, height 6pt
- `HSChip` — ChildSwitcher, высота 36pt
- `HSBadge` — accuracy badge в списке занятий
- `HSToast` — ошибка загрузки
- `HSButton(style: .ghost)` — «Подробнее»

### Accessibility

- SummaryCard: `accessibilityElement(children: .combine)` — label «[метрика]: [значение], [тренд]»
- ChildSwitcher chip: `accessibilityLabel("[Имя ребёнка]")`, `accessibilityAddTraits(.isSelected)` если активный
- Чекбокс задачи: `accessibilityLabel("[задача]. [Выполнено / Не выполнено]")`, `accessibilityAction(named:)` для toggle
- Min touch target: 44×44pt (parent) ✓

### Анимации

- Dashboard появление: `opacity 0→1`, `.easeOut(0.25)` без bounce (parent-контур)
- SummaryCards: stagger 0.05s, `offset(y: 8→0)` + `opacity 0→1`, `.easeOut(0.2)`
- Вкладки: стандартный iOS `.tabViewStyle(.automatic)`, без кастомных переходов
- Обновление данных (refreshable): spinner системный + fade обновлённых значений 0.15s
- Reduced Motion: нет изменений (анимации уже минимальны в parent-контуре)

### iPhone SE адаптация (width < 375pt)

- screenEdge → 16pt
- SummaryCards grid: 2 колонки → 1 колонка (VStack)
- display(32) → display(26)
- AIInsight: lineLimit 2

---

## SessionShell Screen

**Роль:** kid (primary), shared
**Навигация:** ChildHome/HomeTasks → SessionShell (fullscreen cover) → [LessonPlayer игры] → SessionComplete
**Файл реализации:** Features/SessionShell/SessionShellView.swift

### Структура UI (top → bottom)

**Шапка сессии (SessionHeader)**
- Высота: 56pt + safe area top
- Background: `ColorTokens.Kid.bg` с subtle border-bottom `ColorTokens.Kid.line` opacity 0.4
- Левая кнопка: «×» (xmark), 44×44pt, `ColorTokens.Kid.inkSoft` → Alert «Завершить занятие?»
- Центр: `HSProgressBar(progress: session.overallProgress)`, .infinity × 8pt, `ColorTokens.Session.progressBar`
- Правая: номер игры «N / M» — `TypographyTokens.mono(13)`, `ColorTokens.Kid.inkMuted`

**GameSlot (основная область)**
- `.ignoresSafeArea(.keyboard)` — игровая область занимает весь экран ниже шапки
- Контент: текущая игра-View из `LessonPlayer` — рендерится через `AnyView` или generic protocol
- Background: каждая игра задаёт свой фон через `.background(gameView.backgroundColor)`
- Переход между играми: `.asymmetric(insertion: .move(.trailing).combined(with: .opacity), removal: .move(.leading).combined(with: .opacity))`, `.spring(duration: 0.35, bounce: 0.1)`

**MascotOverlay (floating, bottom-left)**
- `HSMascotView` 72×72pt, offset x=16pt y=-24pt от safe area bottom
- Состояние реагирует на игровые события:
  - Ожидание ответа: `.listening`
  - Правильный ответ: `.celebrating` (2s) → возврат `.idle`
  - Неправильный ответ: `.encouraging` (1.5s) → возврат `.idle`
  - Воспроизведение модели: `.speaking`
- Touch on mascot: `.thinking` на 1s + `HSToast` с подсказкой

**FatigueWarning (условно)**
- Показывается через 15 мин или при низком engagement score
- `HSCard` overlay снизу: «Устал? Можно сделать паузу»
- Background: `ColorTokens.Semantic.warningBg`, border `ColorTokens.Semantic.warning`
- Кнопки: «Продолжить» (primary 56pt) + «Пауза» (ghost 44pt)

### Состояния SessionShell

- **.loading** (инициализация сессии): `ProgressView()` + «Загружаем занятие...» `caption(12)` по центру
- **.active** — полный layout с игрой
- **.between** (переход между играми): маскот `.celebrating` + `HSSticker` конфетти + 1.5s pause
- **.paused**: размытый (`.blur(radius: 8)`) background + pause sheet снизу
- **.finishing**: fade-out + переход на `SessionComplete`
- **.error**: `HSToast(.error)` + кнопка «Вернуться» (ghost)

### Цветовая схема

| Элемент | Токен |
|---|---|
| Header background | `ColorTokens.Kid.bg` |
| Progress bar fill | `ColorTokens.Session.progressBar` |
| Progress bar track | `ColorTokens.Session.progressBackground` |
| Fatigue warning | `ColorTokens.Semantic.warningBg` |
| Номер N/M | `ColorTokens.Kid.inkMuted` |

### Типографика

- Номер игры: `TypographyTokens.mono(13)`, Medium Monospaced
- Подсказка маскота: `TypographyTokens.body(15)`, lineLimit 3
- FatigueWarning title: `TypographyTokens.headline(18)`, Semibold Rounded
- FatigueWarning body: `TypographyTokens.body(15)`

### Отступы

- Header horizontal: `SpacingTokens.regular` (16pt)
- MascotOverlay от края: x=`SpacingTokens.regular`, y=`SpacingTokens.large` от safe area bottom
- FatigueWarning padding: `SpacingTokens.cardPad` (20pt)

### Компоненты DS

- `HSProgressBar` — прогресс сессии в шапке, height 8pt
- `HSMascotView` — floating overlay, все игровые состояния
- `HSSticker` — конфетти между играми
- `HSToast` — ошибки и подсказки маскота
- `HSCard` — FatigueWarning sheet

### Accessibility

- Close button: `accessibilityLabel("Закрыть занятие")`, `accessibilityHint("Двойное нажатие вернёт на главный экран")`
- Progress bar: `accessibilityLabel("Прогресс занятия: \(Int(progress * 100)) процентов")`
- Mascot: `accessibilityHidden(true)` — декоративный overlay
- FatigueWarning: `accessibilityElement(children: .combine)`, focus при появлении

### Анимации

- Между играми: `.asymmetric(insertion: .move(.trailing) + .opacity, removal: .move(.leading) + .opacity)`, `.spring(duration: 0.35, bounce: 0.1)`
- Progress bar fill: анимированный при смене значения, `.easeInOut(0.3)`
- MascotOverlay появление: `scale 0→1.1→1.0`, `.spring(duration: 0.45, bounce: 0.3)`, при первом входе
- Between-games confetti: `HSSticker` playOnce, задержка 0.2s после перехода
- Reduced Motion: все переходы → `opacity` cross-fade 0.2s, confetti не играет

### iPhone SE адаптация (width < 375pt)

- Маскот: 56×56pt
- Header high: 48pt
- FatigueWarning: padding → `SpacingTokens.regular` (16pt)

---

## SpecialistHome Screen

**Роль:** specialist
**Навигация:** Auth → SpecialistHome (root TabView) → [Children | Sessions | Reports | Settings]
**Файл реализации:** Features/Specialist/SpecialistHomeView.swift

### Структура UI (top → bottom)

**TabView (4 вкладки)**
- `.tint(ColorTokens.Spec.accent)`
- Вкладки: «Дети» (person.2.fill) | «Занятия» (waveform.path) | «Отчёты» (doc.text.fill) | «Настройки» (gearshape.fill)
- TabBar background: `ColorTokens.Spec.bg`

**Вкладка «Дети» (SpecChildListView)**

NavBar:
- Large title «Мои клиенты» — `TypographyTokens.display(32)`, `ColorTokens.Spec.ink`
- Правая кнопка: «+» (plus), 44×44pt → AddChildSheet
- Search bar: `searchable(text:)`, placeholder «Найти ребёнка», `ColorTokens.Spec.inkMuted`

ChildRow:
- `List` style `.plain`, separator `ColorTokens.Spec.line`
- Background строки: `ColorTokens.Spec.surface`
- Layout строки: аватар 44×44pt (инициалы на `Spec.accent` bg) + VStack (имя, возраст, список звуков) + trailing: последний визит `caption(12)` + chevron
- Имя: `TypographyTokens.headline(17)`, `ColorTokens.Spec.ink`
- Подзаголовок: «6 лет · Звуки: Р, Л, Ш» — `TypographyTokens.body(14)`, `ColorTokens.Spec.inkMuted`
- Последний визит: `TypographyTokens.caption(12)`, `ColorTokens.Spec.inkMuted`
- Touch target строки: ≥ 44pt ✓ → `SpecialistClientDetail`

Быстрые фильтры (chips под NavBar):
- «Все» | «Активные» | «Нет занятий 7д» | «Критичные»
- `HSChip`, высота 32pt, corner `RadiusTokens.chip`, `TypographyTokens.caption(12)`
- Active: `ColorTokens.Spec.accent`, white text
- Inactive: `ColorTokens.Spec.panel`, `ColorTokens.Spec.inkMuted`

**Вкладка «Занятия» (SpecSessionListView)**
- `List` grouped по клиентам
- Section header: имя ребёнка `TypographyTokens.headline(16)` + кол-во сессий badge
- Строка сессии: дата + звук + accuracy + duration `TypographyTokens.mono(13)` + `HSAudioWaveform` 60×20pt preview
- Цвет accuracy: `ColorTokens.Feedback.excellent` (>90%) / `ColorTokens.Semantic.success` (70–90%) / `ColorTokens.Semantic.warning` (<70%)

**Вкладка «Отчёты» (SpecReportsView) — см. SpecialistReports Screen ниже**

### Состояния экрана

- **.loading**: `List` с 5 skeleton rows, shimmer
- **.populated**: полный список
- **.empty**: иллюстрация + «Нет клиентов» + CTA «Добавить первого ребёнка» — `HSButton(style: .primary)` .infinity × 56pt
- **.error**: `HSToast(.error)` + кнопка «Обновить»

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Spec.bg` |
| Строки | `ColorTokens.Spec.surface` |
| Panel/chips | `ColorTokens.Spec.panel` |
| Accent | `ColorTokens.Spec.accent` |
| Grid | `ColorTokens.Spec.grid` |
| Waveform | `ColorTokens.Spec.waveform` |

### Типографика

- NavBar large title: `TypographyTokens.display(32)`, Bold Rounded
- Row name: `TypographyTokens.headline(17)`, Semibold Rounded
- Row subhead: `TypographyTokens.body(14)`, Regular Default
- Accuracy/metrics: `TypographyTokens.mono(13)`, Medium Monospaced
- Last visit: `TypographyTokens.caption(12)`, Regular

### Отступы

- List row height min: 64pt
- Row horizontal insets: `SpacingTokens.screenEdge` (24pt)
- Chip bar padding: `SpacingTokens.small` (12pt) top/bottom, `SpacingTokens.screenEdge` horizontal

### Компоненты DS

- `HSChip` — фильтры клиентов
- `HSAudioWaveform` — preview в списке занятий
- `HSBadge` — счётчик сессий в section header
- `HSToast` — ошибки
- `HSButton(style: .primary)` — empty state CTA

### Accessibility

- ChildRow: `accessibilityElement(children: .combine)` — «[Имя], [возраст] лет, звуки: [список], последний визит: [дата]»
- Filter chips: `accessibilityLabel("[название]")`, `.isSelected` trait если активен
- Search: системный `searchable` accessibility
- Min touch target: 44×44pt ✓

### Анимации

- Список появление: `opacity 0→1`, `.easeOut(0.2)`, без bounce (specialist-контур)
- Filter chip выбор: background color crossfade `.easeInOut(0.15)`
- Skeleton shimmer: `ColorTokens.Spec.panel` opacity 0.4→0.8→0.4, 1.4s loop
- Reduced Motion: без изменений (анимации уже минимальны)

### iPhone SE адаптация (width < 375pt)

- screenEdge → 16pt
- Аватар: 36×36pt
- Accuracy badge: убирается из строки сессии (показывается только в детальном виде)

---

## ARZone Screen

**Роль:** kid
**Навигация:** ChildHome (QuickActions) → ARZone → [ARActivity конкретная игра]
**Файл реализации:** Features/ARZone/ARZoneView.swift

### Структура UI (top → bottom)

**NavBar**
- Large title «AR-зона» — `TypographyTokens.display(32)`, `ColorTokens.Kid.ink`
- Background: прозрачный (контент под ним ScrollView)
- Нет правой кнопки

**Hero-секция (HeroSection)**
- `ZStack` высота 200pt
- Gradient background: `ColorTokens.Brand.lilac` → `ColorTokens.Brand.sky` opacity 0.2, corner `RadiusTokens.card`
- `HSMascotView(state: .idle)` — 96×96pt по центру-лево
- Приветственный текст (VStack, правая половина):
  - «Волшебная AR-зона!» — `TypographyTokens.title(22)`, `ColorTokens.Kid.ink`
  - «Смотри в камеру и повторяй!» — `TypographyTokens.body(15)`, `ColorTokens.Kid.inkMuted`, lineLimit 3
- Padding: `SpacingTokens.cardPad` (20pt) внутри

**InstructionsSection**
- `HSCard` с `VStack`:
  - Заголовок «Как играть» — `TypographyTokens.headline(18)`, `ColorTokens.Kid.ink`
  - 3 шага в `HStack`: иконка 28pt + текст `TypographyTokens.body(15)`, каждый шаг занимает треть ширины
  - Шаг 1: camera.fill «Разреши камеру» | Шаг 2: face.smiling «Смотри в зеркало» | Шаг 3: star.fill «Получи награду»
- Background: `ColorTokens.Kid.surface`, corner `RadiusTokens.card`

**UnsupportedNotice (условно, если !isFaceTrackingSupported)**
- `HSCard` с border `ColorTokens.Semantic.warning`
- Иконка: exclamationmark.triangle.fill `ColorTokens.Semantic.warning` 24pt
- Текст: «AR недоступна на этом устройстве. Попробуй другие игры!» — `TypographyTokens.body(15)`
- Высота: 80pt

**ActivitiesHeader**
- «Выбери упражнение» — `TypographyTokens.title(22)`, `ColorTokens.Kid.ink`
- Padding horizontal: `SpacingTokens.screenEdge`

**ActivitiesGrid (LazyVGrid 1 колонка, spacing `SpacingTokens.listGap`)**
- Каждая карточка AR-активности: `HSCard` высота 100pt
  - `HStack(spacing: SpacingTokens.regular)`:
    - Иконка-превью: 72×72pt `ZStack` — `ColorTokens.Games.arGames` opacity 0.15 + SF Symbol или asset 40pt
    - VStack(alignment: .leading):
      - Название: `TypographyTokens.headline(18)`, `ColorTokens.Kid.ink`, lineLimit 1
      - Описание: `TypographyTokens.body(15)`, `ColorTokens.Kid.inkMuted`, lineLimit 2
      - Pill «Уровень N» или «Доступно с 6 лет»: `TypographyTokens.caption(11)`, corner `RadiusTokens.chip` (8pt)
    - Trailing: chevron.right 17pt `ColorTokens.Kid.inkSoft` + lock если недоступна
  - Background: `ColorTokens.Kid.surface`
  - Corner: `RadiusTokens.card` (24pt)
  - Touch target: весь card ≥ 100pt ✓
  - Locked state: opacity 0.5, lock.fill поверх иконки

**CompactDevice fallback (width < 375pt)**
- Вместо 3D-превью: emoji-иконки 56×56pt
- Hero-секция: высота 160pt, маскот 72×72pt

### Состояния экрана

- **.loading**: skeleton placeholder для hero (rounded rect 200pt) + 3 карточки shimmer
- **.ready**: полный layout, все карточки кликабельны
- **.unsupported**: UnsupportedNotice показывается, карточки disabled
- **.error**: `HSToast(.error)` + retry

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Kid.bg` |
| Hero gradient | `Brand.lilac → Brand.sky` opacity 0.2 |
| Карточки | `ColorTokens.Kid.surface` |
| AR accent | `ColorTokens.Games.arGames` |
| Lock icon | `ColorTokens.Kid.inkSoft` |
| Warning notice | `ColorTokens.Semantic.warningBg` |

### Типографика

- NavBar / Hero title: `TypographyTokens.display(32)` / `title(22)`
- Card names: `TypographyTokens.headline(18)`, Semibold Rounded
- Card descriptions: `TypographyTokens.body(15)`, lineLimit 2
- Level pill: `TypographyTokens.caption(11)`, Regular

### Отступы

- Horizontal edge: `SpacingTokens.screenEdge` (24pt)
- Между карточками: `SpacingTokens.listGap` (12pt)
- Padding top ScrollView: `SpacingTokens.medium` (20pt)
- Padding bottom: `SpacingTokens.xxxLarge` (48pt)

### Компоненты DS

- `HSMascotView` — hero, state idle/celebrating
- `HSCard` — instructions, activity cards, unsupported notice
- `HSToast` — ошибки и предупреждения

### Accessibility

- Activity card: `accessibilityElement(children: .combine)` — «[Название]. [Описание]. [Уровень N / Заблокировано]. Кнопка»
- Lock: `accessibilityHint("Разблокируется при достижении уровня \(requiredLevel)")` если locked
- Маскот: `accessibilityHidden(true)`
- UnsupportedNotice: `accessibilityLabel("AR-режим недоступен. \(text)")`, `accessibilityAddTraits(.isStaticText)`
- Min touch target: 56×56pt (kid) ✓

### Анимации

- Hero появление: `opacity 0→1` + `scale 0.95→1.0`, `.spring(duration: 0.4, bounce: 0.15)`, delay 0s
- Маскот hero: `scale 0.8→1.05→1.0`, `.spring(duration: 0.5, bounce: 0.3)`, delay 0.15s
- Карточки: stagger 0.06s, `opacity 0→1` + `offset(y: 12→0)`, `.spring(duration: 0.38, bounce: 0.15)`
- Карточка нажатие: `.scale(0.97)`, `.spring(duration: 0.2, bounce: 0.1)` → release
- Locked card: shake animation `offset(x: -4→4→0)`, `.spring(duration: 0.3)` при попытке тапа
- Reduced Motion: все → `opacity` fade 0.15s, без stagger, без shake

### iPhone SE адаптация

- Hero height: 160pt (вместо 200pt)
- Маскот в hero: 72×72pt
- Card height: 88pt
- Иконка-превью карточки: 56×56pt

---

## OfflineState Screen

**Роль:** shared (kid primary — маскот присутствует)
**Навигация:** любой экран при потере сети → OfflineState (fullscreen overlay / NavigationStack root)
**Файл реализации:** Features/OfflineState/OfflineStateView.swift

### Структура UI (top → bottom)

**Фон**
- `ColorTokens.Kid.bg.ignoresSafeArea()` (всегда kid-warm, независимо от контура)
- Нет NavBar — fullscreen

**IllustrationSection (верхняя треть)**
- `ZStack` по центру:
  - Круг 200×200pt — `ColorTokens.Semantic.warning` opacity 0.08
  - `Image(systemName: "wifi.slash")` — font size 72pt, weight `.thin`, `ColorTokens.Semantic.warning` opacity 0.6
  - `HSMascotView(state: .encouraging)` — 80×80pt, offset x=+60pt y=+40pt от центра (маскот сбоку)
- PendingBadge (условно, если `pendingCount > 0`):
  - `Text("N изменений ждут синхронизации")` — `TypographyTokens.caption(12)`, white
  - Background: Capsule, `ColorTokens.Semantic.warning`
  - Padding horizontal `SpacingTokens.small`, vertical `SpacingTokens.micro`

**InfoSection**
- Заголовок: «Нет интернета» — `TypographyTokens.title(24)`, `ColorTokens.Kid.ink`, center
- Подзаголовок: «Ляля здесь. Можно играть в офлайн-режиме!» — `TypographyTokens.body(15)`, `ColorTokens.Kid.inkMuted`, center, lineLimit 3
- Отступ от IllustrationSection: `SpacingTokens.sectionGap` (32pt)

**ActionsSection (bottom)**
- Padding horizontal: `SpacingTokens.screenEdge` (24pt)
- Padding bottom: `SpacingTokens.sp16` (64pt от safe area)
- `VStack(spacing: SpacingTokens.small)`:
  - `HSButton(style: .primary)` «Попробовать снова» — .infinity × 56pt, trigger retry
  - `HSButton(style: .secondary)` «Играть офлайн» — .infinity × 56pt, переход в ChildHome offline mode
  - `HSButton(style: .ghost)` «Открыть настройки Wi-Fi» — .infinity × 44pt → `UIApplication.openSettingsURLString`

**RetryIndicator (при `isRetrying == true`)**
- Spinner `ProgressView()` 24pt + текст «Подключение...» `TypographyTokens.caption(12)`, `HStack` по центру
- Появляется между кнопками через `transition(.opacity.combined(with: .scale))`

### Состояния экрана

- **.offline**: полный layout как описано выше
- **.retrying**: кнопка «Попробовать снова» disabled, показывается RetryIndicator
- **.reconnected**: экран fade-out → автоматический возврат на предыдущий экран, маскот `.celebrating`

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Kid.bg` |
| Wifi icon | `ColorTokens.Semantic.warning` opacity 0.6 |
| Круг halo | `ColorTokens.Semantic.warning` opacity 0.08 |
| PendingBadge | `ColorTokens.Semantic.warning` |
| Primary CTA | `ColorTokens.Brand.primary` |
| Ink | `ColorTokens.Kid.ink` |
| Inkмuted | `ColorTokens.Kid.inkMuted` |

### Типографика

- Заголовок: `TypographyTokens.title(24)`, Semibold Rounded
- Подзаголовок: `TypographyTokens.body(15)`, Regular, lineLimit 3, center
- PendingBadge: `TypographyTokens.caption(12)`, Regular, white
- RetryIndicator: `TypographyTokens.caption(12)`

### Отступы

- Actions section horizontal: `SpacingTokens.screenEdge` (24pt)
- Между кнопками: `SpacingTokens.small` (12pt)
- Info от illustration: `SpacingTokens.sectionGap` (32pt)
- Bottom safe area inset: `SpacingTokens.sp16` (64pt)

### Компоненты DS

- `HSMascotView(state: .encouraging)` — иллюстрация, offset от иконки WiFi
- `HSButton(style: .primary)` — retry CTA, 56pt
- `HSButton(style: .secondary)` — offline mode CTA, 56pt
- `HSButton(style: .ghost)` — открыть настройки, 44pt
- `HSToast` — уведомление о reconnection

### Accessibility

- Заголовок: `accessibilityAddTraits(.isHeader)`
- Retry button: `accessibilityLabel("Попробовать снова")`, `accessibilityHint("Проверит наличие интернет-подключения")`
- Settings button: `accessibilityLabel("Открыть настройки Wi-Fi")`
- PendingBadge: `accessibilityLabel("\(pendingCount) изменений ожидают синхронизации при восстановлении связи")`
- Маскот: `accessibilityHidden(true)`
- При reconnect: `UIAccessibility.post(notification: .announcement, argument: "Подключение восстановлено")`

### Анимации

- Появление WiFi иконки: `opacity 0→1` + `scale 0.8→1.0`, `.spring(duration: 0.4, bounce: 0.2)`
- Маскот: `scale 0→1.1→1.0`, `.spring(duration: 0.5, bounce: 0.3)`, delay 0.2s
- WiFi иконка pulse (при `.retrying`): `opacity 0.4→1.0→0.4`, `.easeInOut(1.4)`, repeat forever
- RetryIndicator: `.opacity.combined(with: .scale(0.9))`, `.spring(duration: 0.3)`
- Reconnected: экран `opacity 1→0`, `.easeOut(0.4)`, delay 0.5s после маскот `.celebrating`
- Reduced Motion: нет pulse, маскот → `opacity` fade, transitions → `opacity` cross-fade

### iPhone SE адаптация (width < 375pt)

- WiFi иконка: 56pt
- Круг halo: 160×160pt
- Маскот: 64×64pt
- Bottom inset: `SpacingTokens.sp12` (48pt)

---

## ScreeningView Screen

**Роль:** kid (проходит ребёнок вместе с родителем/логопедом)
**Навигация:** Onboarding (шаг 7) → ScreeningView → ScreeningResult → ChildHome / ParentHome
**Файл реализации:** Features/Screening/ScreeningView.swift

### Структура UI (top → bottom)

**Header (прогресс скрининга)**
- Высота: 56pt + safe area top
- Background: `ColorTokens.Kid.bg`
- Левая кнопка: «Отмена» ghost, 44pt touch target → Alert «Прервать скрининг?»
- Центр: «Вопрос N из 20» — `TypographyTokens.caption(13)`, `ColorTokens.Kid.inkMuted`
- `HSProgressBar(progress: Double(currentIndex) / 20.0)` — под header, .infinity × 6pt

**BlockTitleBanner (при входе в новый блок, условно)**
- Полноэкранный toast-баннер на 2s: «Блок: [Свистящие / Шипящие / Соноры]»
- Background: цвет семейства `ColorTokens.SoundFamilyColors.*`, opacity 0.85, corner 0 (fullwidth)
- Шрифт: `TypographyTokens.title(22)`, white

**PromptCard (основная область, центр экрана)**
- `HSCard`, maxWidth .infinity, corner `RadiusTokens.card`
- Padding: `SpacingTokens.cardPad`
- `VStack(spacing: SpacingTokens.regular)`:
  - Иллюстрация: asset image 160×160pt (картинка слова), `clipShape(RoundedRectangle(RadiusTokens.sm))`
  - Слово-стимул: «РЫБА» — `TypographyTokens.kidDisplay(40)`, `ColorTokens.Kid.ink`, center
  - Кнопка «Послушать» (воспроизвести образец): `HSButton(style: .secondary)` 200×56pt, иконка speaker.wave.2.fill
- Background: `ColorTokens.Kid.surface`
- Shadow: y=4, blur=16, `ColorTokens.Kid.bgDeep` opacity 0.12

**ScoreRow (под PromptCard)**
- 4 кнопки самооценки: 0 / 1 / 2 / 3 балла
- Каждая кнопка: 72×72pt минимум, `HSButton`-like, corner `RadiusTokens.card`
- Иконки и цвета:
  - 0: xmark.circle.fill, `ColorTokens.Feedback.incorrect` opacity 0.15, text «Нет»
  - 1: minus.circle.fill, `ColorTokens.Semantic.warning` opacity 0.15, text «Почти»
  - 2: checkmark.circle.fill, `ColorTokens.Semantic.success` opacity 0.15, text «Да»
  - 3: star.circle.fill, `ColorTokens.Brand.gold` opacity 0.15, text «Отлично»
- Выбранная кнопка: border 2pt соответствующего цвета + scale 1.05
- Текст под иконкой: `TypographyTokens.caption(12)`, соответствующий цвет

**BlockTransitionView (fullscreen breather)**
- Показывается между блоками звуков (~5 секунд)
- `HSMascotView(state: .celebrating)` — 120×120pt, центр
- «Отлично! Переходим к следующему блоку» — `TypographyTokens.title(24)`, center
- Название следующего блока — `TypographyTokens.headline(18)`, `ColorTokens.Kid.inkMuted`
- Кнопка «Продолжить» — `HSButton(style: .primary)` 280×56pt
- Background: `ColorTokens.Kid.bgSoft`

**SummaryView (по завершении всех 20 вопросов)**
- Маскот `.celebrating` 120×120pt
- «Скрининг завершён!» — `TypographyTokens.display(36)`
- Карточки по блокам: `HSCard` с итогами (количество верных / всего, семейство звуков)
- Кнопка «Перейти к занятиям» — `HSButton(style: .primary)` .infinity × 56pt
- Кнопка «Посмотреть детально» — `HSButton(style: .ghost)` .infinity × 44pt

### Состояния экрана

- **.prompt**: PromptCard + ScoreRow — основной рабочий экран
- **.blockTransition**: BlockTransitionView fullscreen
- **.summary**: SummaryView
- **.cancelled**: dismissal без сохранения

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Kid.bg` |
| PromptCard | `ColorTokens.Kid.surface` |
| Балл 0 | `ColorTokens.Feedback.incorrect` opacity 0.15 |
| Балл 1 | `ColorTokens.Semantic.warning` opacity 0.15 |
| Балл 2 | `ColorTokens.Semantic.success` opacity 0.15 |
| Балл 3 | `ColorTokens.Brand.gold` opacity 0.15 |
| BlockBanner | `SoundFamilyColors.*` opacity 0.85 |
| Progress bar | `ColorTokens.Session.progressBar` |

### Типографика

- Слово-стимул: `TypographyTokens.kidDisplay(40)`, Black Rounded — максимальная читаемость
- Кнопка балла — label: `TypographyTokens.caption(12)`, Regular
- Header прогресс: `TypographyTokens.caption(13)`, Regular
- BlockTransition title: `TypographyTokens.title(24)`, Semibold Rounded
- Summary display: `TypographyTokens.display(36)`, Bold Rounded

### Отступы

- PromptCard horizontal: `SpacingTokens.screenEdge` (24pt)
- PromptCard top от header: `SpacingTokens.large` (24pt)
- ScoreRow gap: `SpacingTokens.small` (12pt) между кнопками
- ScoreRow от PromptCard: `SpacingTokens.large` (24pt)
- ScoreRow button min size: 72×72pt → touch target ≥ 56pt ✓

### Компоненты DS

- `HSProgressBar` — progress скрининга, height 6pt
- `HSCard` (PromptCard) — карточка вопроса
- `HSMascotView` — BlockTransition (celebrating), SummaryView (celebrating)
- `HSButton(style: .secondary)` — «Послушать» образец
- `HSButton(style: .primary)` — «Продолжить» / «Перейти к занятиям»
- `HSButton(style: .ghost)` — «Посмотреть детально»

### Accessibility

- Слово-стимул: `accessibilityLabel("Слово: \(word)")`
- ScoreRow кнопки: «Нет — 0 баллов», «Почти — 1 балл», «Да — 2 балла», «Отлично — 3 балла»
- «Послушать»: `accessibilityLabel("Прослушать образец слова \(word)")`
- Progress: `accessibilityLabel("Вопрос \(current) из \(total)")`
- Min touch target: 72×72pt ✓ (больше стандарта kid 56pt)

### Анимации

- PromptCard переход к следующему: `.asymmetric(insertion: .move(.trailing) + .opacity, removal: .move(.leading) + .opacity)`, `.spring(duration: 0.35, bounce: 0.1)`
- Выбор балла: выбранная кнопка `scale 1.0→1.05`, `.spring(duration: 0.25, bounce: 0.2)`, border fade-in
- BlockTransition появление: fullscreen `opacity 0→1`, `.easeIn(0.3)`; маскот `scale 0→1.1→1.0`, `.spring`
- Summary маскот: `scale 0→1.2→1.0`, `.spring(duration: 0.6, bounce: 0.35)` + confetti
- Reduced Motion: все переходы → `opacity` cross-fade, без scale на кнопках, без confetti

### iPhone SE адаптация (width < 375pt)

- kidDisplay(40) → kidDisplay(32)
- PromptCard иллюстрация: 120×120pt
- ScoreRow кнопки: 64×64pt
- screenEdge → 16pt

---

## LessonPlayer Screen

**Роль:** kid
**Навигация:** SessionShell → LessonPlayer (вложен как child view) → SessionShell (по завершении игры)
**Файл реализации:** Features/LessonPlayer/ (16 игровых шаблонов в подпапках)

### Структура UI (принцип)

LessonPlayer — не самостоятельный навигационный экран, а контейнер-координатор, который:
1. Получает `Lesson` объект (список `GameTemplate` с параметрами)
2. Рендерит текущую игру-View через game registry
3. Передаёт результат каждой игры обратно в `SessionShell`

**Общая GameFrame (обёртка каждой игры)**

GameHeader:
- Высота: 48pt
- Background: полупрозрачный `ColorTokens.Kid.bg` opacity 0.85, `ultraThinMaterial` в iOS 17+
- Иконка шаблона (левый угол): 28×28pt SF Symbol, цвет из `ColorTokens.Games.*`
- Название шаблона (центр): `TypographyTokens.headline(17)`, `ColorTokens.Kid.ink`
- Кнопка помощи «?» (правый угол): 44×44pt → shows HelpSheet

GameContent (основная область):
- `.ignoresSafeArea(.keyboard)` — для игр с полем ввода
- Фон: каждый шаблон задаёт через `gameBackgroundColor` проперти
- Content: специфичный UI конкретной игры (см. ниже)

FeedbackOverlay (поверх GameContent при результате):
- Correct: зелёный border 3pt + checkmark.circle.fill 80pt center + «Молодец!» `title(22)` + `HSSticker` конфетти
- Incorrect: мягкий coral border 3pt + `HSMascotView(state: .encouraging)` 80pt + «Попробуй ещё» `title(22)`
- Длительность показа: Correct 1.5s → автоматически следующий вопрос, Incorrect 1.2s → retry
- Haptic: `.success` при Correct, `.warning` при Incorrect

### Игровые шаблоны (общий дизайн-язык)

**ListenAndChoose** (слушай и выбирай):
- Фон: `ColorTokens.Games.listenAndChoose` opacity 0.08
- Воспроизведение: большая кнопка speaker 96×96pt, `ColorTokens.Brand.sky`
- 2–4 картинки-варианта: `HSCard` в LazyVGrid, равные по высоте ≥ 120pt
- Выбранная: border 3pt `ColorTokens.Brand.primary` + scale 1.03

**RepeatAfterModel** (повтори за героем):
- Фон: `ColorTokens.Games.repeatAfterModel` opacity 0.08
- Слово-иллюстрация: 180×180pt, corner `RadiusTokens.md`
- Кнопка «Послушать»: `HSButton(style: .secondary)` 200×56pt
- `HSAudioWaveform` при записи: 280×64pt, `ColorTokens.Spec.waveform`
- Кнопка «Записать»: 96×96pt круг, `ColorTokens.Brand.primary` + микрофон SF Symbol 40pt
- Accuracy ring по результату: `Circle().trim(from: 0, to: accuracy)` stroke 8pt `ColorTokens.Feedback.excellent/correct`

**Memory** (найди пары):
- Карточки: LazyVGrid 4×N, каждая ≥ 72×72pt
- Рубашка: `ColorTokens.Brand.lilac` opacity 0.2
- Открытая: `ColorTokens.Kid.surface` + asset
- Совпадение: border `ColorTokens.Semantic.success` + brief glow shadow

**Breathing** (дыхание):
- Фон: gradient `ColorTokens.Games.breathing → ColorTokens.Kid.bg`
- Анимированный круг: scale 1.0→1.6→1.0, duration соответствует фазам (вдох/задержка/выдох)
- Текст фазы: `TypographyTokens.title(22)`, center, fade между фазами

**ArticulationImitation** (имитация артикуляции):
- Использует ARKit face tracking — подробнее в ARZone
- Без GameHeader (занимает весь экран включая camera view)
- `HSMascotView` overlay 72pt bottom-right

### Состояния LessonPlayer

- **.idle** (до начала): splash с иллюстрацией игры + CTA «Начать» 56pt
- **.active**: GameFrame + текущий вопрос
- **.feedback**: FeedbackOverlay поверх содержимого
- **.complete**: передаёт `GameResult` в `SessionShell`, который решает next game или SessionComplete

### Цветовая схема

| Элемент | Токен |
|---|---|
| GameHeader bg | `ColorTokens.Kid.bg` opacity 0.85 |
| Correct feedback border | `ColorTokens.Feedback.correct` |
| Incorrect feedback border | `ColorTokens.Feedback.incorrect` |
| Конфетти | `HSSticker` |
| Шаблон-акцент | `ColorTokens.Games.*` для конкретного шаблона |

### Типографика

- GameHeader название: `TypographyTokens.headline(17)`, Semibold Rounded
- Слово-стимул: `TypographyTokens.kidDisplay(40)` или `display(36)` в зависимости от длины
- Feedback «Молодец!»: `TypographyTokens.title(22)`, Semibold Rounded
- Accuracy процент: `TypographyTokens.mono(13)`

### Отступы

- GameContent padding horizontal: `SpacingTokens.screenEdge` (24pt) по умолчанию (шаблоны могут переопределить)
- GameHeader padding horizontal: `SpacingTokens.regular` (16pt)
- FeedbackOverlay внутренний padding: `SpacingTokens.cardPad` (20pt)

### Компоненты DS

- `HSMascotView` — FeedbackOverlay (encouraging), ARZone overlay
- `HSAudioWaveform` — RepeatAfterModel запись
- `HSProgressBar` — accuracy ring (не стандартный, кастомный Circle)
- `HSSticker` — конфетти при Correct
- `HSCard` — ListenAndChoose варианты, Memory карточки
- `HSButton(style: .primary)` — CTA idle state
- `HSButton(style: .secondary)` — «Послушать» образец

### Accessibility

- Игровые кнопки-варианты: `accessibilityLabel("[текст или описание картинки]")`, `accessibilityHint("Двойное нажатие — выбрать")`
- Запись: `accessibilityLabel("Записать ответ, кнопка")`, `accessibilityHint("Нажмите и говорите")`, `accessibilityAddTraits(.startsMediaSession)`
- FeedbackOverlay: `UIAccessibility.post(notification: .announcement, argument: isCorrect ? "Верно! Молодец!" : "Попробуй ещё раз")`
- Min touch target: 72×72pt для игровых вариантов ✓ (kid ≥ 56pt)

### Анимации

- FeedbackOverlay появление: `opacity 0→1`, `.easeIn(0.2)`
- Checkmark correct: `scale 0→1.2→1.0`, `.spring(duration: 0.4, bounce: 0.35)` = `MotionTokens.reward`
- Конфетти: `HSSticker` playOnce, delay 0.1s
- Auto-dismiss: `.easeOut(0.3)`, delay correct=1.5s / incorrect=1.2s
- Memory flip: `rotation3DEffect` 0→90→0 по Y, `.easeInOut(0.35)`
- Breathing circle: `.easeInOut` с duration = inhale/hold/exhale тайминги (4s/4s/6s типично)
- Reduced Motion: FeedbackOverlay → только `opacity`, без scale, без flip, без breathing animation (статичный текст)

### iPhone SE адаптация (width < 375pt)

- ListenAndChoose: варианты 3 в ряд → 2 в ряд
- RepeatAfterModel: кнопка записи 80×80pt
- Memory grid: 3×N вместо 4×N
- screenEdge → 16pt

---

## GuidedTour Overlay

**Роль:** kid (основной), shared
**Навигация:** ChildHome (первый вход) → GuidedTourContainer wrapper → завершение → ChildHome (без overlay)
**Файл реализации:** Features/GuidedTour/GuidedTourContainer.swift + GuidedTourTipView.swift

### Структура UI

GuidedTourContainer — это не самостоятельный экран, а overlay-обёртка над произвольным контентом.

**SpotlightOverlay**
- Полноэкранный `Rectangle().fill(.ultraThinMaterial)` с `.blendMode(.normal)`, opacity 0.7
- Пробитое отверстие (highlight rect): `Canvas` с `.blendMode(.destinationOut)` над прямоугольником
  - Corner: `RadiusTokens.card` (24pt) если rect ≥ 80pt; `RadiusTokens.sm` (12pt) если меньше
  - Внешнее свечение: `shadow(color: ColorTokens.Brand.primary.opacity(0.25), radius: 16, x: 0, y: 0)`
- Background за overlay: `.ignoresSafeArea()`

**GuidedTourTipView (coach mark bubble)**
- Позиционирование: автоматически above / below spotlight rect (если rect нижняя половина → пузырь сверху)
- Форма: `RoundedRectangle(cornerRadius: RadiusTokens.md)` с хвостом-треугольником
- Background: `ColorTokens.Kid.surface`
- Shadow: y=4, blur=20, `ColorTokens.Kid.bgDeep` opacity 0.15
- Ширина: min(screenWidth - 2*screenEdge, 320pt)

TipView layout `VStack(spacing: SpacingTokens.small)`:
- «Шаг N из M» — `TypographyTokens.caption(12)`, `ColorTokens.Kid.inkMuted`, `HSMascotView(state: .speaking)` 32×32pt в `HStack`
- Текст подсказки — `TypographyTokens.body(15)`, `ColorTokens.Kid.ink`, lineLimit nil
- `HStack` кнопки:
  - «Назад» (ghost, 44pt, только если currentIndex > 0)
  - Spacer
  - «Далее» / «Понятно!» (primary, 120pt wide × 44pt)

**TourStep параметры:**
- `highlightKey: String` — ключ `SpotlightRegistry`
- `title: String` — `TypographyTokens.headline(18)` (если есть)
- `message: String` — основной текст
- `mascotState: MascotState` — состояние Ляли для этого шага
- `primaryActionLabel: String` — метка CTA

### Шаги тура ChildHome (7 шагов)

| Шаг | Highlight | Текст подсказки | Маскот |
|---|---|---|---|
| 1 | `mascot_header` | «Привет! Я Ляля, твой помощник. Нажми на меня в любой момент!» | `.speaking` |
| 2 | `daily_mission` | «Здесь твоё задание на сегодня. Начни прямо сейчас!» | `.pointing` |
| 3 | `quick_play` | «Быстрые игры — выбирай любую и играй!» | `.idle` |
| 4 | `world_map_preview` | «Карта звуков — исследуй новые звуки!» | `.thinking` |
| 5 | `sound_progress` | «Видишь прогресс? Вот как ты растёшь!» | `.celebrating` |
| 6 | `quick_actions_ar` | «AR-зона — говори перед камерой и получай очки!» | `.speaking` |
| 7 | dim all | «Молодец! Теперь ты знаешь всё. Начинай!» | `.celebrating` |

### Состояния overlay

- **inactive**: нет overlay, GuidedTourContainer прозрачен
- **active**: SpotlightOverlay + TipView видны
- **finished**: fade-out → сохранение `guidedTourCompleted = true` в UserDefaults

### Цветовая схема

| Элемент | Токен |
|---|---|
| Overlay background | `ultraThinMaterial` opacity 0.7 |
| Spotlight glow | `ColorTokens.Brand.primary` opacity 0.25 |
| TipView background | `ColorTokens.Kid.surface` |
| Tip ink | `ColorTokens.Kid.ink` |
| Next button | `ColorTokens.Brand.primary` |

### Типографика

- Шаг N из M: `TypographyTokens.caption(12)`, Regular, `ColorTokens.Kid.inkMuted`
- Подсказка: `TypographyTokens.body(15)`, Regular, lineLimit nil
- CTA: `TypographyTokens.cta()` (17pt Bold Rounded)
- Назад: `TypographyTokens.body(15)`, Regular ghost

### Отступы

- TipView padding внутренний: `SpacingTokens.cardPad` (20pt)
- TipView от края экрана: `SpacingTokens.screenEdge` (24pt)
- TipView от spotlight rect: `SpacingTokens.regular` (16pt) gap
- Кнопки в TipView: gap `SpacingTokens.small` (12pt)

### Компоненты DS

- `HSMascotView` — встроен в TipView, 32×32pt
- `HSButton(style: .primary)` — «Далее» / «Понятно!», 120pt × 44pt
- `HSButton(style: .ghost)` — «Назад», 80pt × 44pt

### Accessibility

- При активации overlay: `UIAccessibility.post(notification: .screenChanged, argument: tipView)`
- TipView: `accessibilityElement(children: .combine)`, focus при появлении
- «Назад»: `accessibilityLabel("Предыдущий шаг тура")`
- «Далее»: `accessibilityLabel("Следующий шаг тура")` / `"Завершить тур"` на последнем
- Spotlight: `accessibilityHidden(true)` — декоративный dim
- VoiceOver: при каждом шаге читает `message` полностью

### Анимации

- SpotlightOverlay появление: `opacity 0→0.7`, `.easeIn(0.3)`
- Spotlight rect переход между шагами: `withAnimation(.spring(duration: 0.45, bounce: 0.15))` новый rect
- TipView появление: `scale 0.9→1.0` + `opacity 0→1`, `.spring(duration: 0.35, bounce: 0.2)`
- TipView dismiss (шаг вперёд): `opacity 1→0` + `offset(y: -8→0)`, `.easeOut(0.2)` → новый TipView появляется
- Overlay final dismiss: `opacity 0.7→0`, `.easeOut(0.4)`
- Маскот: при смене шага — transition `.idle → mascotState`, анимируется через Rive state machine
- Reduced Motion: rect переход без анимации (instant), TipView → только `opacity`, без scale

### iPhone SE адаптация (width < 375pt)

- TipView max width: min(screenWidth - 2*16, 280pt)
- Маскот в TipView: 24×24pt
- Кнопки: «Далее» 100pt wide
- body(15) → body(14)

---

## SpecialistReports Screen

**Роль:** specialist
**Навигация:** SpecialistHome (вкладка «Отчёты») → SpecialistReports → ReportDetail | ExportSheet
**Файл реализации:** Features/Specialist/Reports/ (ReportsInteractor.swift + ReportsPresenter.swift)

### Структура UI (top → bottom)

**NavBar**
- Large title «Отчёты» — `TypographyTokens.display(32)`, `ColorTokens.Spec.ink`
- Правая кнопка: «+» (создать новый отчёт) 44×44pt → ReportBuilderSheet
- Нет search (отчёты фильтруются через chips)

**FilterSection**
- `ScrollView(.horizontal, showsIndicators: false)` с chips
- Чипы: «Все» | «Последние 7 дней» | «Последние 30 дней» | «По ребёнку» | «Экспортированные»
- `HSChip` высота 32pt, corner `RadiusTokens.chip`, `TypographyTokens.caption(12)`
- Active: `ColorTokens.Spec.accent` bg, white text
- Inactive: `ColorTokens.Spec.panel` bg, `ColorTokens.Spec.inkMuted` text
- Padding: `SpacingTokens.screenEdge` horizontal, `SpacingTokens.small` vertical

**ReportsList (`List` style `.insetGrouped`)**
- Группировка по ребёнку (section header = имя + возраст)
- Section header: `TypographyTokens.headline(16)`, `ColorTokens.Spec.ink`, background `ColorTokens.Spec.bg`

ReportRow (`HSCard`-подобный layout внутри List):
- Высота: min 80pt, touch target ≥ 44pt ✓
- `HStack(spacing: SpacingTokens.regular)`:
  - Левый индикатор (4×60pt) — цвет по типу отчёта:
    - Еженедельный: `ColorTokens.Spec.accent`
    - Экспорт PDF: `ColorTokens.Brand.mint`
    - AI-сводка: `ColorTokens.Brand.lilac`
  - VStack(alignment: .leading, spacing: SpacingTokens.micro):
    - Тип отчёта: `TypographyTokens.headline(16)`, `ColorTokens.Spec.ink`
    - Период: «15–22 апреля 2026» — `TypographyTokens.body(14)`, `ColorTokens.Spec.inkMuted`
    - Метрики-пиллы (HStack горизонтальный, overflow wrapping):
      - «Точность: 78%» | «Занятий: 12» | «Звук: Р»
      - Pill: `TypographyTokens.caption(11)`, `ColorTokens.Spec.panel` bg, corner `RadiusTokens.chip`
  - Trailing: дата создания `TypographyTokens.caption(12)` `ColorTokens.Spec.inkMuted` + chevron / export icon

**ExportSheet (half-sheet)**
- Презентация: `.sheet(isPresented:)`, detent `.medium`
- Background: `ColorTokens.Spec.bg`, corner `RadiusTokens.sheet` (32pt)
- Хендл: 4×36pt, `ColorTokens.Spec.line` opacity 0.4

ExportSheet layout `VStack(spacing: SpacingTokens.regular)`:
- Заголовок «Экспорт отчёта» — `TypographyTokens.title(22)`, `ColorTokens.Spec.ink`
- Описание: «Выберите формат для сохранения» — `TypographyTokens.body(15)`, `ColorTokens.Spec.inkMuted`
- Кнопки форматов (VStack, spacing `SpacingTokens.small`):
  - PDF: `HSButton(style: .primary)` .infinity × 56pt — иконка doc.fill + «Сохранить PDF»
  - CSV: `HSButton(style: .secondary)` .infinity × 56pt — иконка tablecells + «Таблица CSV»
  - Поделиться: `HSButton(style: .ghost)` .infinity × 44pt — иконка square.and.arrow.up + «Поделиться»
- Padding: `SpacingTokens.cardPad` (20pt) horizontal, `SpacingTokens.large` (24pt) top

**ReportBuilderSheet (создание нового отчёта)**
- Детент `.large`
- NavBar в sheet: «Новый отчёт» + кнопки «Отмена» / «Создать»
- Форма (`Form`):
  - «Ребёнок»: Picker из списка клиентов
  - «Период»: DateRangePicker (custom компонент, 2 `DatePicker`)
  - «Включить»: Toggle для Accuracy / Занятий / AI-сводки / Звуков
  - «Тип»: SegmentedPicker — «Еженедельный» / «Индивидуальный»

### Состояния экрана

- **.loading**: skeleton 4 строки shimmer, `ColorTokens.Spec.panel` opacity 0.4→0.8→0.4
- **.populated**: полный список
- **.empty** (нет отчётов): иконка doc.text.magnifyingglass 64pt `ColorTokens.Spec.inkMuted` + «Нет отчётов» + CTA «Создать первый»
- **.error**: `HSToast(.error)` + retry

### Цветовая схема

| Элемент | Токен |
|---|---|
| Фон | `ColorTokens.Spec.bg` |
| Строки | `ColorTokens.Spec.surface` |
| Panel / chips | `ColorTokens.Spec.panel` |
| Grid separators | `ColorTokens.Spec.grid` |
| Accent (weekly) | `ColorTokens.Spec.accent` |
| PDF индикатор | `ColorTokens.Brand.mint` |
| AI-индикатор | `ColorTokens.Brand.lilac` |

### Типографика

- NavBar large title: `TypographyTokens.display(32)`, Bold Rounded
- Section header: `TypographyTokens.headline(16)`, Semibold Rounded
- Row тип: `TypographyTokens.headline(16)`, Semibold Rounded
- Row период: `TypographyTokens.body(14)`, Regular Default
- Row метрики pills: `TypographyTokens.caption(11)`, Regular
- Дата создания: `TypographyTokens.caption(12)`, Regular

### Отступы

- Filter chips: horizontal `SpacingTokens.screenEdge`, vertical `SpacingTokens.small`
- List row height: min 80pt
- Left indicator width: 4pt
- ExportSheet top padding: `SpacingTokens.large` (24pt)
- ExportSheet horizontal: `SpacingTokens.cardPad` (20pt)

### Компоненты DS

- `HSChip` — filter chips
- `HSToast` — ошибки
- `HSButton(style: .primary)` — PDF export, Create CTA
- `HSButton(style: .secondary)` — CSV export
- `HSButton(style: .ghost)` — Share, Cancel

### Accessibility

- ReportRow: `accessibilityElement(children: .combine)` — «[Тип отчёта], [Период], Точность [N]%, Занятий [N]. Открыть детально»
- Filter chip: `accessibilityLabel("[Название фильтра]")`, `accessibilityAddTraits(.isSelected)` если активен
- Левый индикатор цвета: `accessibilityHidden(true)`
- ExportSheet: при появлении `UIAccessibility.post(notification: .screenChanged)` → focus на заголовке
- Min touch target: 44×44pt (specialist) ✓

### Анимации

- Список появление: `opacity 0→1`, `.easeOut(0.2)` — без bounce, specialist-контур
- Filter смена: crossfade цвета chips `.easeInOut(0.15)`
- ExportSheet: стандартный iOS sheet presentation
- Создание нового отчёта: добавление строки `.insertFromTop` List animation
- Skeleton shimmer: opacity 0.4→0.8→0.4, 1.4s loop
- Reduced Motion: нет изменений (анимации уже минимальны)

### iPhone SE адаптация (width < 375pt)

- screenEdge → 16pt
- Row метрики pills: wrapping на следующую строку
- ExportSheet кнопки высота: 48pt (вместо 56pt)

---

## M7.6 WCAG AA — Результаты аудита (2026-04-25)

Статический анализ 15 экранов (Swift-код). Полный отчёт: `.claude/team/wcag-audit.md`

**Сводка нарушений: 11 критических / 15 средних / 18 малых = 44 всего**

### Критические (исправить до M8)

1. `OfflineStateView.pendingBadge` — белый текст на `ColorTokens.Semantic.warning` (жёлтый фон) = контраст ~1.1:1. Заменить на тёмный текст или изменить цвет фона бейджа.
2. `ParentHomeView.homeTaskCard` — хардкод `Color(hex: "#E5A000")` вместо `ColorTokens.Brand.gold`. Не работает в dark mode.
3. `RewardsView` фильтр-кнопки коллекций — `frame(minHeight: 36)` в kid-контуре, нужно 56pt.
4. `ChildHomeView` кнопка "Переключить на родителя" — `frame(width: 44, height: 44)` в kid-контуре, нужно 56×56pt.
5. `SpecialistHomeView.SpecChildRow` — отсутствует accessibilityLabel + accessibilityAddTraits(.isButton) на всей строке.
6. `SpecialistHomeView` ToolbarItem "+" — отсутствует accessibilityLabel.
7. `DemoModeView` Skip button — белый текст на coral/lilac градиенте ≈3.2:1 (норма 4.5:1 для 15pt).
8. `HomeTasksView.HomeTaskFilterChip` — `frame(minHeight: 36)` вместо 44pt.
9. `SessionHistoryView.SessionFilterChipButton` — `frame(minHeight: 36)` вместо 44pt.
10. `OnboardingFlowView` Back button — высота ~33pt, нужно 44×44pt.
11. `SpecialistReportsView.FilterChip` — нет `frame(minHeight: 44)`.

### Экраны без критических нарушений
HomeTasksView (VoiceOver OK), SessionHistoryView (labels OK), SettingsView (toggles/pickers OK), PermissionFlowView (a11y OK), ProgressDashboardView (combine OK), SessionCompleteView (reduceMotion OK), OnboardingFlowView (header traits OK), OfflineStateView (containment OK — кроме pendingBadge), SpecialistReportsView (breakdown labels OK).

### Системные рекомендации
- Верифицировать контраст semantic color tokens (inkMuted/bg) инструментально через Xcode Accessibility Inspector.
- Поднять все `caption(10)` и `caption(11)` → минимум `caption(12)` систематически во всех экранах.
- Добавить `accessibilityValue` к Swift Charts в `weeklyChartSection` и `dailyChartSection` (ProgressDashboardView).
- display(32) → title(24)
