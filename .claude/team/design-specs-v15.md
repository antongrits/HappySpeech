# HappySpeech — Design Specs v15 (2026-05-04)

> Единый источник дизайн-спецификаций. Основан на tokens.jsx + аудите v15.
> Этот файл обязателен для чтения ios-developer перед любым UI-изменением.

---

## 1. Цветовая система

### Брендовые токены (перевод из tokens.jsx OKLCH → ассеты)
| Swift-токен | OKLCH | Hex-эквивалент | Назначение |
|---|---|---|---|
| ColorTokens.Brand.primary | oklch(0.72 0.17 35) | ~#E8704A | CTA, маскот, главный акцент |
| ColorTokens.Brand.primaryHi | oklch(0.82 0.14 45) | ~#F5936A | hover, splash gradient |
| ColorTokens.Brand.primaryLo | oklch(0.58 0.19 32) | ~#C4522E | pressed, shadow overlay |
| ColorTokens.Brand.mint | oklch(0.82 0.11 165) | ~#7ECBA8 | success, progress |
| ColorTokens.Brand.sky | oklch(0.80 0.10 230) | ~#7AB8E8 | info, AR accent, links |
| ColorTokens.Brand.lilac | oklch(0.78 0.11 305) | ~#B39CD9 | magic, AR zone |
| ColorTokens.Brand.butter | oklch(0.90 0.12 90) | ~#F5E080 | rewards, streaks |
| ColorTokens.Brand.rose | oklch(0.82 0.10 15) | ~#F0A090 | warmth on cards |
| ColorTokens.Brand.gold | oklch(0.78 0.15 85) | ~#D4A030 | achievement gold |

### Kid контур (тёплый, кремовый)
| Swift-токен | OKLCH | Назначение |
|---|---|---|
| ColorTokens.Kid.bg | oklch(0.975 0.012 80) | основной фон |
| ColorTokens.Kid.bgDeep | oklch(0.955 0.020 75) | AR/Game тёмный фон |
| ColorTokens.Kid.surface | #ffffff | карточки, поля |
| ColorTokens.Kid.ink | oklch(0.22 0.025 60) | основной текст |
| ColorTokens.Kid.inkMuted | oklch(0.50 0.020 60) | подзаголовки |
| ColorTokens.Kid.inkSoft | oklch(0.65 0.015 60) | placeholder, hint |
| ColorTokens.Kid.line | oklch(0.91 0.010 70) | разделители, borders |

### Parent контур (холодный, нейтральный)
| Swift-токен | OKLCH | Назначение |
|---|---|---|
| ColorTokens.Parent.bg | oklch(0.985 0.004 250) | основной фон |
| ColorTokens.Parent.bgDeep | oklch(0.965 0.006 250) | глубокий фон |
| ColorTokens.Parent.surface | #ffffff | карточки |
| ColorTokens.Parent.ink | oklch(0.22 0.015 250) | основной текст |
| ColorTokens.Parent.inkMuted | oklch(0.50 0.012 250) | подзаголовки |
| ColorTokens.Parent.accent | oklch(0.62 0.14 240) | CTA, links |

### Specialist контур (нейтральный, data-dense)
| Swift-токен | OKLCH | Назначение |
|---|---|---|
| ColorTokens.Spec.bg | oklch(0.98 0.003 250) | основной фон |
| ColorTokens.Spec.accent | oklch(0.55 0.13 250) | CTA, акцент |
| ColorTokens.Spec.waveform | oklch(0.55 0.14 200) | waveform |
| ColorTokens.Spec.target | oklch(0.72 0.17 140) | правильный ответ |

### Цвета звуковых семей
| Семья | Hue токен | BG токен | OKLCH hue |
|---|---|---|---|
| Свистящие (С,З,Ц) | SoundWhistlingHue | SoundWhistlingBg | oklch(0.78 0.12 200) teal |
| Шипящие (Ш,Ж,Ч,Щ) | SoundHissingHue | SoundHissingBg | oklch(0.76 0.13 305) lilac |
| Сонорные (Л,Р) | SoundSonorantHue | SoundSonorantBg | oklch(0.72 0.16 35) coral |
| Заднеязычные (К,Г,Х) | SoundVelarHue | SoundVelarBg | oklch(0.76 0.13 135) green |

---

## 2. Типографика

### Все стили через TypographyTokens (ОБЯЗАТЕЛЬНО)
| Метод | Размер | Weight | Design | Назначение |
|---|---|---|---|---|
| `kidDisplay(40)` | 40pt | Black | Rounded | Splash hero, большие цифры |
| `kidDisplay(96)` | 96pt | Black | Rounded | Emoji-слова в играх |
| `display(36)` | 36pt | Bold | Rounded | Hero-заголовки |
| `title(28)` | 28pt | Semibold | Rounded | Имя пользователя, section heroes |
| `title(24)` | 24pt | Semibold | Rounded | Заголовки секций, диалоги |
| `title(22)` | 22pt | Semibold | Rounded | Подзаголовки, tour tips |
| `headline(18)` | 18pt | Semibold | Rounded | Card titles, CTA secondary |
| `headline(17)` | 17pt | Semibold | Rounded | Кнопки HSButton |
| `body(16)` | 16pt | Regular | Default | Form fields |
| `body(15)` | 15pt | Regular | Default | Основной текст kid |
| `body(14)` | 14pt | Regular | Default | Parent тело |
| `body(13)` | 13pt | Regular | Default | Компактные описания |
| `caption(13)` | 13pt | Regular | Default | Слоганы, tagline |
| `caption(12)` | 12pt | Regular | Default | Метки, hints |
| `caption(11)` | 11pt | Regular | Default | Spec labels uppercase |
| `mono(13)` | 13pt | Medium | Monospaced | Счёт, время, технические данные |
| `cta()` | 17pt | Bold | Rounded | Все HSButton primary |

### Правила
- НИКОГДА `.font(.system(size:...))` в фичах — только `TypographyTokens.*`
- НИКОГДА `.font(.title)` / `.font(.body)` — только именованные методы
- Все CTA: `.lineLimit(nil)` + `.minimumScaleFactor(0.85)` — обязательно
- Kid контур минимальный body: 15pt
- Dynamic Type: использовать `.bodyScaled` / `.headlineScaled` / `.captionScaled` для системных текстов

---

## 3. Spacing (4pt-сетка)

### Числовые токены
| Токен | pt | Назначение |
|---|---|---|
| SpacingTokens.micro (sp1) | 4 | иконка+текст gap |
| SpacingTokens.tiny (sp2) | 8 | внутри компонента |
| SpacingTokens.small (sp3) | 12 | между элементами списка |
| SpacingTokens.regular (sp4) | 16 | стандартный отступ |
| SpacingTokens.medium (sp5) | 20 | padding карточки |
| SpacingTokens.large (sp6) | 24 | горизонтальный экранный margin |
| SpacingTokens.xLarge (sp8) | 32 | между секциями |
| SpacingTokens.xxLarge (sp10) | 40 | page top inset |
| SpacingTokens.xxxLarge (sp12) | 48 | большой bottom |
| SpacingTokens.screenEdge | 24 | горизонтальные поля экрана |
| SpacingTokens.cardPad | 20 | внутри карточек |
| SpacingTokens.listGap | 12 | gap между строками списка |
| SpacingTokens.sectionGap | 32 | gap между секциями |
| SpacingTokens.pageTop | 40 | отступ от top safe area |

---

## 4. Радиусы

### Все через RadiusTokens
| Токен | pt | Назначение |
|---|---|---|
| RadiusTokens.xs (chip) | 8 | чипы, маленькие теги |
| RadiusTokens.sm | 12 | небольшие элементы, иконки |
| RadiusTokens.md | 18 | input fields, средние карточки |
| RadiusTokens.lg (card) | 24 | карточки, крупные контейнеры |
| RadiusTokens.xl (button/sheet) | 32 | кнопки, sheet corners |
| RadiusTokens.full (avatar) | 9999 | круги, аватары |

---

## 5. Тени

### Через ShadowTokens (View Modifiers)
| Метод | Назначение |
|---|---|
| `.kidCardShadow()` | основная карточка kid |
| `.kidTileShadow()` | маленький тайл kid |
| `.parentCardShadow()` | карточка parent |
| `.parentElevatedShadow()` | поднятый элемент parent |

### НИКОГДА inline `.shadow(color: .black.opacity(...), radius: ..., ...)` в фичах
Исключение: AR-оверлеи с `.black.opacity(0.45)` в Capsule — стандартный iOS AR pattern, не является Design-нарушением.

---

## 6. Градиенты

### Все через GradientTokens
| Токен | Назначение |
|---|---|
| GradientTokens.kidBackground | фон ChildHome (iOS 17 fallback) |
| GradientTokens.kidHeroDecoration | Ellipse-декорация Auth-экранов |
| GradientTokens.kidDeep | Deep-вариант kid фона |
| GradientTokens.parentBackground | фон Parent-экранов |
| GradientTokens.celebrationGold | наградной золотой |
| GradientTokens.rewardBurst | burst-фон достижений |
| GradientTokens.storyMagic | история/AR magic фон |
| GradientTokens.arScene | AR-сцена фон |
| GradientTokens.glassMorphic | glass-эффект |
| GradientTokens.calmBlue | спокойный синий |
| GradientTokens.warmSunset | тёплый закат |
| GradientTokens.specBackground | фон специалиста |

### Новый токен — ДОБАВИТЬ в GradientTokens.swift
```swift
/// Фоновый fade для нижних action-панелей (SessionComplete, WorldMap, etc.)
public static func kidBottomFade(background: Color = ColorTokens.Kid.bg) -> LinearGradient {
    LinearGradient(
        colors: [background.opacity(0), background],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

---

## 7. Маскот «Ляля» — размеры по контексту

| Контекст | Размер | Компонент |
|---|---|---|
| Splash hero | 160×160pt | HSMascotView / LyalyaMascotView |
| Auth / Onboarding header | 96×100pt | LyalyaMascotView |
| RoleSelect header | 100×100pt | LyalyaMascotView |
| ChildHome (реактивный) | 120×120pt | ChildHomeReactiveMascot |
| SessionShell HUD inline | 60×60pt | HSMascotView |
| Game header (inline) | 80×80pt | HSMascotView |
| Rewards / StoryQuest bubble | 80×80pt | LyalyaMascotView |
| Permission flow header | 80×80pt | LyalyaMascotView |
| FluencyDiary completion | 120×120pt | LyalyaMascotView |
| Empty states | 80×80pt | LyalyaMascotView или HSMascotView |

---

## 8. Кнопки

### HSButton — обязателен для всех CTA
```swift
// Primary CTA (kid)
HSButton("Начать", style: .primary, icon: "play.fill") { ... }
// Высота: minHeight 56pt в kid контуре, 44pt в parent/spec
// Radius: RadiusTokens.xl (32pt) по умолчанию внутри HSButton

// Secondary
HSButton("Послушать", style: .secondary, icon: "speaker.wave.2.fill") { ... }

// Ghost (ссылки, destructive)
HSButton("Отмена", style: .ghost) { ... }
```

### Прямые кнопки (без HSButton)
- Минимальный touch target в kid-контуре: **56×56pt** через `.frame(width: 56, height: 56)` + `.contentShape(Circle())`
- Parent/Spec: **44×44pt** (стандарт HIG)
- Все кнопки: `.buttonStyle(.plain)` + `.tapFeedback()` в kid-контуре

---

## 9. Карточки

### HSLiquidGlassCard — обязателен для всех поверхностей
```swift
// Primary (белый glass)
HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) { content }

// Tinted (цветной акцент)
HSLiquidGlassCard(style: .tinted(ColorTokens.Brand.mint), padding: SpacingTokens.medium) { content }

// Corner radius внутри: RadiusTokens.card (24pt) для крупных
// При вложенных субкарточках: RadiusTokens.md (18pt)
```

### Правила
- Фон карточки: всегда surface (#ffffff) + glass effect
- Никаких `.background(Color.white.opacity(...))` напрямую
- Никаких `.background(RoundedRectangle(...).fill(.white))` без HSLiquidGlassCard обёртки в kid-контуре

---

## 10. Анимации

### Через MotionTokens
| Токен | Параметры | Назначение |
|---|---|---|
| `MotionTokens.spring` | spring(duration:0.4, bounce:0.2) | стандартный spring |
| `MotionTokens.springFast` | spring(duration:0.25, bounce:0.15) | быстрый spring |
| `MotionTokens.reward` | spring(duration:0.6, bounce:0.35) | поощрение за правильный ответ |
| `MotionTokens.standard` | easeInOut(0.25) | стандартный переход |

### Правила
- ВСЕГДА проверять `@Environment(\.accessibilityReduceMotion)` перед анимацией
- Reduce Motion fallback: заменить spring → `.linear(duration: 0.15)` или nil
- Delay для stagger: `.delay(Double(index) * 0.08)` — стандарт для списков

---

## 11. Экранные спецификации

### SplashView
- Контур: splash (до авторизации)
- Background: LinearGradient(Brand.primary → Brand.primaryHi), top→bottom
- Маскот: HSMascotView(mood:.celebrating, size:160), scale 0.3→1.0 spring
- Логотип: TypographyTokens.kidDisplay(40), white, tracking:-1
- Слоган: TypographyTokens.caption(13), white.opacity(0.85), tracking:2.5, uppercase
- Прогресс-бар: Capsule width:80pt, height:3pt, white

### ChildHomeView
- Контур: kid
- Background: KidBackgroundView() — warm cream + ChildHomeCloudDecoration
- Section headers: emoji (caption 14pt) + Text uppercase tracking:1 caption(12) Kid.inkMuted
- Hero greeting: TypographyTokens.title(28) Kid.ink + body(15) Kid.inkMuted
- Маскот зона: 120×120pt, padding vertical sp3
- Quick Play: горизонтальный ScrollView, карточки без showsIndicators
- Quick Actions: LazyVGrid 2×2 (compact) / 4×4 (regular), spacing sp3
- Tab bar: HSKidTabBar

### RepeatAfterModelView
- Контур: kid
- Background: ColorTokens.Kid.bg
- Word card: HSLiquidGlassCard(style:.primary), emoji kidDisplay(96), слово highlight
- RecordButton: 80×80pt Capsule + pulse ring (Brand.primary)
- Кнопки: HSButton(style:.secondary/.primary)
- Результат: HSProgressBar + star rating

### ListenAndChooseView
- Контур: kid
- AudioPlayButton: 88×88pt Circle, 3× concentric ripple (Brand.primary)
- Options grid: LazyVGrid 2×2, HSLiquidGlassCard, stagger delay 0.1×n
- Shake animation: неправильный выбор

### SessionCompleteView
- Контур: kid
- Background: Kid.bg с bottom fade
- Маскот: 120×120pt, celebrating state
- Score: count-up animation, TypographyTokens.kidDisplay(48+)
- Stars: 3× последовательно, Brand.butter
- Action buttons: primary «Продолжить» + secondary «Играть ещё» + ghost «Поделиться»
- Высота кнопок: 56pt

### WorldMapView
- Контур: kid
- Маскот header: 100×100pt
- Зоны: цветные острова/кружки по SoundFamily палитре
- Sticky bottom panel: HSLiquidGlassCard с общим прогрессом
- Streak badge: Brand.butter

### ARZoneView
- Контур: kid
- Hero banner: sky→lilac gradient + ARHeroBanner
- Activities: LazyVGrid/HStack с карточками
- Tutorial sheet: presentationCornerRadius RadiusTokens.sheet

### ParentHomeView
- Контур: parent
- Tint: ColorTokens.Parent.accent
- TabView (iPhone) / NavigationSplitView (iPad)
- Background: Parent.bg

### ProgressDashboardView
- Контур: parent
- Background: Parent.bg
- Period picker: HSLiquidGlassCard(style:.primary)
- Charts: Swift Charts (bar + line)
- Summary cards: HSCard с Parent.surface

### SpecialistHomeView
- Контур: specialist
- Tint: ColorTokens.Spec.accent
- Background: Spec.bg
- List rowBackground: Spec.surface
- Charts: Swift Charts, spec.waveform цвет

---

## 12. Обязательные правила DoD для UI

- [ ] Никаких hex-литералов в фичах — только ColorTokens.*
- [ ] Никаких `.font(.system(size:...))` — только TypographyTokens.*
- [ ] Никаких `.cornerRadius(N)` без RadiusTokens
- [ ] Никаких inline `.shadow(...)` без ShadowTokens (кроме AR-оверлеев)
- [ ] Никаких inline LinearGradient без GradientTokens
- [ ] `@Environment(\.accessibilityReduceMotion)` проверяется везде, где есть анимация
- [ ] Min touch target: 56pt (kid), 44pt (parent/spec)
- [ ] Все CTA через HSButton, все карточки через HSLiquidGlassCard или HSCard
- [ ] Dark mode: использовать только семантические токены из Asset Catalog
- [ ] Dynamic Type: `.lineLimit(nil)` + `.minimumScaleFactor(0.85)` на всех CTA
