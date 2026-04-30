# HappySpeech

Логопедическое iOS-приложение для детей 5–8 лет.

## Overview

HappySpeech помогает детям отрабатывать произношение через интерактивные игры с маскотом Лялей.
Приложение работает полностью оффлайн, использует on-device ML для оценки речи и адаптирует
ежедневный маршрут занятий под возраст и усталость ребёнка.

**Целевая аудитория:** дети 5–8 лет (детский контур), родители (родительский контур),
логопеды-специалисты (специалистский контур).

**Платформа:** iOS 17.0+, Swift 6, SwiftUI.

## Topics

### Основы
- <doc:GettingStarted>
- <doc:Architecture>

### Design System
- <doc:DesignSystem>
- ``HSButton``
- ``HSCard``
- ``HSLiquidGlassCard``
- ``LyalyaMascotView``
- ``HSMascotView``
- ``ColorTokens``
- ``TypographyTokens``
- ``SpacingTokens``

### Machine Learning
- <doc:ML-Pipeline>
- ``PronunciationScorer``
- ``SileroVAD``
- ``LLMDecisionService``

### Сервисы
- ``HapticService``
- ``AmbientSoundService``
- ``VoiceCloneService``
- ``NotificationServiceLive``
- ``SyncService``

### Инфраструктура
- ``HSLogger``
- ``AppError``
- ``RealmActor``

### Audio и голос
- <doc:Audio-Voice>

### Туториалы
- <doc:tutorials/1-FirstSession>
- <doc:tutorials/2-AddingNewSound>
- <doc:tutorials/3-IntegratingNewGame>
