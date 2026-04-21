# HappySpeech

Русскоязычное логопедическое iOS-приложение для детей 5–8 лет с родительским и специалистским контурами, адаптивным движком, AR-артикуляцией, визуально-акустической обратной связью и on-device ML.

Полностью offline-first, child-safe, без сторонних трекеров. Готовится к App Store.

## Быстрый старт

```bash
# Установить инструменты
brew install xcodegen swiftlint

# Сгенерировать Xcode-проект
xcodegen generate

# Открыть
open HappySpeech.xcodeproj
```

## Структура

- `HappySpeech/` — исходный код iOS-приложения (SwiftUI + Clean Swift)
- `HappySpeechTests/` — unit / integration / snapshot тесты
- `HappySpeechUITests/` — UI-тесты и ScreenshotTour
- `scripts/` — служебные скрипты сборки и тура скриншотов

Детали архитектуры, стандартов кода и процессов — см. [CLAUDE.md](CLAUDE.md).

## Технологии

SwiftUI · Clean Swift · Realm · Firebase (Auth / Firestore / Storage / App Check) · WhisperKit · ARKit Face Tracking · Core ML · Accelerate · XCTest / Swift Testing · SnapshotTesting

## Честные границы

Это педагогическая поддержка, не медицинская диагностика. Приложение помогает родителям и детям с домашней практикой и даёт специалистам инструменты для наблюдения. Подробнее — в `CLAUDE.md`, раздел «Что НЕ делает приложение».

## Лицензия

Все оригинальные ассеты и код — собственность автора. Используемые открытые модели — под лицензиями Apache-2.0 / MIT / CC, перечень в `~/.claude/team/ml-models.md`.
