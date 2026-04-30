# Быстрый старт

Как развернуть проект HappySpeech и запустить его на симуляторе.

## Требования

- macOS 14.0 или новее
- Xcode 16.0 или новее
- iOS Simulator iPhone 16 Pro (iOS 17.0+)
- Swift 6.0
- Homebrew (для xcodegen и swiftlint)

## Установка зависимостей

Установить xcodegen и swiftlint через Homebrew:

```bash
brew install xcodegen swiftlint
```

## Генерация проекта

HappySpeech использует `project.yml` (xcodegen) вместо хранения `.xcodeproj` в git.
После клонирования репозитория нужно сгенерировать проект:

```bash
cd /путь/к/HappySpeech
xcodegen generate
open HappySpeech.xcodeproj
```

## Сборка и запуск

```bash
xcodebuild \
    -project HappySpeech.xcodeproj \
    -scheme HappySpeech \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    build
```

## Линтер

Перед каждым коммитом запустить SwiftLint в строгом режиме:

```bash
swiftlint --strict
```

Цель — 0 предупреждений и 0 ошибок.

## DI и сервисы

Все сервисы регистрируются в `AppContainer` (см. ``AppContainer``).
В Preview'ах используется `AppContainer.preview` с mock-реализациями.

## Первый запуск

При первом запуске приложение:
1. Показывает онбординг и запрашивает разрешение на микрофон
2. Создаёт профиль ребёнка (имя, возраст)
3. Загружает начальный контент-пак (С-группа звуков)
4. Открывает детский экран `ChildHome`

## Темы

### Ключевые компоненты
- ``AppContainer``
- ``HSLogger``
- ``ColorTokens``
- ``HSButton``
