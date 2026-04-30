# Архитектура

Clean Swift (VIP) паттерн, слои проекта и правила зависимостей.

## Overview

HappySpeech использует **Clean Swift (VIP)** для каждой фичи в сочетании с
протокол-ориентированным DI через `AppContainer`.

## Clean Swift — структура фичи

Каждая фича располагается в `Features/<FeatureName>/` и содержит:

```
Features/ChildHome/
├── ChildHomeView.swift         — SwiftUI root view (нет бизнес-логики)
├── ChildHomeInteractor.swift   — бизнес-логика, вызывает Workers и Services
├── ChildHomePresenter.swift    — формирует ViewModel из Response
├── ChildHomeRouter.swift       — навигация через координатор
├── ChildHomeModels.swift       — Request / Response / ViewModel типы
└── Workers/
    └── DailyRouteWorker.swift  — изолированный вызов AdaptivePlannerService
```

## Слои и разрешённые зависимости

```
Features   →  DesignSystem, Shared, Core, Services (только через протоколы)
Services   →  Data, ML, Sync, Core
Data       →  Core
Sync       →  Data, Core
ML         →  Core
DesignSystem → Core
```

> Important: Features **никогда** не импортируют `Data/`, `ML/`, `Sync/` напрямую.

## Три пользовательских контура

| Контур | Аудитория | Особенности |
|--------|-----------|-------------|
| `kid` | Дети 5–8 лет | Warm UI, маскот Ляля, без LLM Tier B |
| `parent` | Родители | Аналитика, настройки, домашние задания |
| `specialist` | Логопеды | PDF-экспорт, расширенная аналитика |

Контур передаётся через `@Environment(\.circuitContext)`.

## LLM Tier Routing

Детский контур **всегда** использует Tier A (on-device Qwen2.5-1.5B) или Tier C (RuleBased).
HuggingFace (Tier B) вызывается **только** из родительского и специалистского контуров.

```swift
// Правило из ADR-001-REV1 (COPPA)
// Kid circuit → Tier A (MLX) или Tier C (RuleBased)
// Parent/Specialist → Tier A / B / C
```

## Темы

### Ключевые типы
- ``AppContainer``
- ``RealmActor``
- ``SyncService``
- ``HSLogger``
- ``AppError``
