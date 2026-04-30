# Design System

Токены, компоненты и правила использования визуальной системы HappySpeech.

## Overview

Design System HappySpeech состоит из пяти групп токенов и 34 готовых компонентов.
Все токены переведены из дизайн-прототипа (`tokens.jsx`) в Swift-перечисления.

> Important: Никогда не используй hex-цвета в фичах. Только токены из `ColorTokens`.

## Токены

### Цвет — ``ColorTokens``

Семантические цвета разделены на три пространства имён:

```swift
ColorTokens.Brand.primary   // coral-apricot (CTA, крылья Ляли)
ColorTokens.Kid.bg           // тёплый кремовый фон детского контура
ColorTokens.Parent.surface   // нейтральная поверхность родительского контура
ColorTokens.Spec.accent      // акцент специалистского контура
```

### Типография — ``TypographyTokens``

SF Pro Rounded для детского контура; SF Pro Text для родительского/специалистского.

```swift
TypographyTokens.kidDisplay()   // 40pt, Black, Rounded — героический заголовок
TypographyTokens.headline()     // 18pt, Semibold, Rounded — заголовки карточек
TypographyTokens.body()         // 15pt, Regular — основной текст
```

### Отступы — ``SpacingTokens``

Базовая сетка 4pt.

```swift
SpacingTokens.regular      // 16pt — стандартный отступ
SpacingTokens.screenEdge   // 24pt — горизонтальные поля экрана
SpacingTokens.cardPad      // 20pt — внутренние отступы карточки
```

## Компоненты

### Кнопки

``HSButton`` — единственная кнопка-CTA в приложении. Поддерживает стили
`.primary`, `.secondary`, `.ghost`, `.danger` и три размера.

```swift
HSButton("Начать урок", style: .primary, size: .large) {
    interactor.startLesson()
}
```

### Карточки

``HSCard`` — базовая карточка с тенью/flat/tinted вариантами.

``HSLiquidGlassCard`` — glassmorphism-карточка с нативным `.glassEffect()` на iOS 26
и fallback через `.ultraThinMaterial` на iOS 17–25.

### Маскот

``LyalyaMascotView`` — высокоуровневая обёртка с 10 состояниями и lip-sync.

``HSMascotView`` — 7-слойный рендер Rive + SwiftUI с MoodAura и EmotionParticles.

## Правила доступности

- Все CTA: `.lineLimit(nil)` + `.minimumScaleFactor(0.85)`
- Dynamic Type: от `.small` до `.accessibilityLarge`
- `@Environment(\.accessibilityReduceMotion)` учитывается во всех анимациях
- Каждый экран тестируется в Light и Dark темах

## Темы

### Токены
- ``ColorTokens``
- ``TypographyTokens``
- ``SpacingTokens``

### Компоненты
- ``HSButton``
- ``HSCard``
- ``HSLiquidGlassCard``
- ``LyalyaMascotView``
- ``HSMascotView``
