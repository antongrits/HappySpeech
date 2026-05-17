# HappySpeech — Claude Code project guide

> Этот файл читается Claude Code при каждой сессии в этом репозитории. Он описывает проект, архитектуру, правила кода и рабочие процессы. **Обновляй его при каждом крупном изменении архитектуры.**

---

## 📚 Память проекта — в Obsidian LLM-Wiki

Вся накопленная **память проекта** (бывшие `.claude/team/`, `HappySpeech/ResearchDocs/`,
`HappySpeech/ProductSpecs/`) перенесена в персистентную LLM-Wiki по методу Andrej Karpathy:

**`/Users/antongric/Documents/Obsidian Vault/HappySpeech/`**

- `index.md` — каталог знаний (читать первым при поиске)
- `wiki/` — синтез: `entities/`, `concepts/`, `timeline/`, `overview.md`, `synthesis.md`
- `raw/` — неизменяемые исходники (`team/`, `research-docs/`, `product-specs/`, `claude-memory/`)
- `CLAUDE.md` хранилища — схема wiki и workflow (ingest/query/lint)

Новые командные артефакты (отчёты, аудиты, спеки) агенты пишут в `…/HappySpeech/raw/team/`.
В этом репозитории кода файлов памяти больше нет.

---

## 1. Что это за проект

**HappySpeech** — русскоязычное логопедическое iOS-приложение для детей 5–8 лет.

Цели:
- коррекция и развитие речи;
- домашняя практика для родителей;
- инструменты для специалистов (логопедов);
- полная offline-first работа;
- App Store готовность (Kids Category compliant);
- защита в качестве дипломного проекта.

**Целевая аудитория:** дети 5–8 лет (первичные пользователи), родители, логопеды-специалисты.

**Язык приложения:** русский (primary), английский (secondary для App Store).

**Платформа:** iOS 17+ (SwiftUI-first, Swift 6.x).

---

## 2. Архитектура

**Паттерн:** Clean Swift (VIP) для фич + SwiftUI-рендер + протокол-ориентированный DI.

**Каждая фича:**
```
Features/<FeatureName>/
├── <Feature>View.swift       — SwiftUI root view (без бизнес-логики)
├── <Feature>Interactor.swift — бизнес-логика, dispatch запросов
├── <Feature>Presenter.swift  — формирование ViewModel из response
├── <Feature>Router.swift     — навигация (через координатор)
├── <Feature>Models.swift     — Request / Response / ViewModel типы
└── Workers/                  — изолированные сервисные вызовы
```

**Слои проекта:**
- `App/` — `@main`, DI-контейнер, coordinator
- `Core/` — базовые утилиты, логгер, расширения, ошибки, типы
- `DesignSystem/` — токены (цвет/типо/спейс/радиус/тень/моушн), тема, компоненты
- `Shared/` — переиспользуемые модификаторы и view-хелперы
- `Features/` — фичи по Clean Swift
- `Services/` — AudioService, ASRService, ARService, PermissionService, NotificationService, HapticService, SyncService, ContentService, AdaptivePlannerService, AnalyticsService, NetworkMonitor
- `Data/` — Realm-модели, репозитории, миграции
- `Content/` — ContentEngine, схемы, seed-паки
- `ML/` — обёртки над WhisperKit / Silero VAD / PronunciationScorer / LocalLLM
- `Sync/` — Firestore-мост, очередь, конфликт-резолвер
- `Analytics/` — локальная событийная шина (без внешних SDK)
- `Resources/` — Assets.xcassets, звуки, Core ML модели, локализации

> Методология логопедии и продуктовые спецификации (бывшие `ResearchDocs/`,
> `ProductSpecs/`) теперь в Obsidian LLM-Wiki — см. баннер вверху файла.

**Зависимости между слоями** (стрелки — разрешённый импорт):
```
Features ─→ DesignSystem, Shared, Core, Services (через протоколы)
Services ─→ Data, ML, Sync, Core
Data      ─→ Core
Sync      ─→ Data, Core
ML        ─→ Core
DesignSystem ─→ Core
```

Features **никогда** напрямую не импортируют Data, ML, Sync — только через Services-протоколы.

---

## 3. Технологический стек

| Задача | Решение |
|---|---|
| UI | SwiftUI 6.0 + UIKit wrappers где нужно |
| Архитектура | Clean Swift + DI |
| Локальная БД | Realm Swift |
| Auth | Firebase Auth + Sign in with Apple |
| Облако | Firebase Firestore + Storage + App Check |
| ASR | WhisperKit (русская модель) |
| VAD | Silero-VAD через Core ML |
| AR | ARKit Face Tracking |
| Аудио | AVAudioEngine (16kHz mono), AVAudioRecorder |
| DSP | Accelerate / vDSP |
| ML | Core ML + опциональный MLC-LLM (Qwen2.5-1.5B) |
| Логгирование | OSLog (никаких `print`) |
| Тесты | XCTest + Swift Testing + SnapshotTesting |
| Локализация | String Catalog (`Localizable.xcstrings`) |

**Запрещённые зависимости:** сторонние трекеры, рекламные SDK, Crashlytics, Firebase Analytics (Kids Category).

---

## 4. Правила кода

### Swift-стиль
- **Swift 6** strict concurrency, `async/await` везде для I/O.
- `@Observable` (iOS 17+) вместо `ObservableObject` для новых моделей.
- Протоколы — для всех сервисов и репозиториев (→ тестируемость).
- Никаких force-unwrap (`!`) в production-коде кроме сгенерированных `@IBOutlet` (если они есть) и тестов.
- Никаких `TODO`, `FIXME`, `HACK`, `XXX` в коде — задачи трекаются только в бэклоге wiki (`…/Obsidian Vault/HappySpeech/raw/team/backlog.md`).
- Никаких `print(...)` — только `Logger` через OSLog.
- Никакого закомментированного кода.
- Никаких debug-строк в user-facing UI (ошибки — через `LocalizedError` с русскими сообщениями).

### SwiftUI-стиль
- Никаких хардкодных hex-цветов в фичах — только через `DesignSystem/Tokens/Colors`.
- Все строки — через `String(localized: ...)` (String Catalog).
- Все CTA имеют `.lineLimit(nil)` + `.minimumScaleFactor(0.85)` для безопасных переносов.
- Dynamic Type поддерживается от `.small` до `.accessibilityLarge`.
- Reduced Motion — `@Environment(\.accessibilityReduceMotion)` учитывается в анимациях.
- Каждый экран тестируется в light и dark.

### Имена
- Типы: `PascalCase` (`ChildProfileView`).
- Функции/переменные: `camelCase` (`fetchDailyRoute()`).
- Константы: `camelCase` (`defaultSessionDuration`).
- Файлы: имя типа (`ChildProfileView.swift`).
- Protocol с `protocol`-suffix только если конфликтует с дефолтной реализацией: `ChildRepository` + `LiveChildRepository` / `MockChildRepository`.

### DI и композиция
- `AppContainer` в `App/DI/AppContainer.swift` — один entry-point сервисов.
- Features получают зависимости через инициализаторы, не через синглтоны.
- Для Preview'ев — `AppContainer.preview` с мок-реализациями.

---

## 5. Структура контента и методологии

**Источник методики:** Obsidian LLM-Wiki — `wiki/concepts/speech-methodology.md` (синтез) и `raw/research-docs/` (исходники методологии русской логопедии).

**Контент-движок:** `HappySpeech/Content/`:
- `Schemas/content-pack.schema.json` — формат пака
- `Seed/` — начальные паки звуков
- `ContentEngine.swift` — сборка `Lesson` из пака через комбинаторы

**Шаблоны упражнений** (определены в `speech-games-tz.md`):
`listen-and-choose`, `repeat-after-model`, `drag-and-match`, `story-completion`, `puzzle-reveal`, `sorting`, `memory`, `bingo`, `sound-hunter`, `articulation-imitation`, `AR-activity`, `visual-acoustic`, `breathing`, `rhythm`, `narrative-quest`, `minimal-pairs`.

**Группы звуков:** свистящие (С, З, Ц), шипящие (Ш, Ж, Ч, Щ), соноры (Р, Рь, Л, Ль), заднеязычные (К, Г, Х).

**Этапы работы:** подготовка артикуляции → изолированный звук → слоги → слова по позициям → кластеры → фразы → предложения → рассказ → свободная речь → дифференциация.

---

## 6. Как работать с проектом

### Сборка и запуск
```bash
# Первый раз:
brew install xcodegen swiftlint
cd /Users/antongric/Downloads/HappySpeech
xcodegen generate

# Открыть в Xcode:
open HappySpeech.xcodeproj

# Командная сборка:
xcodebuild -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Тесты:
xcodebuild test -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Линтер
```bash
swiftlint --strict
```

### Скриншот-тур
```bash
./scripts/generate_screenshots.sh
```

### Работа с датасетами и ML
**Никогда не коммить датасеты, сырые аудио или чекпоинты в репо.**
Всё — в `/Users/antongric/Downloads/HappySpeech/_workshop/`:
```
_workshop/
├── datasets/raw/        # скачанные оригиналы
├── datasets/clean/      # нормализованные
├── datasets/augmented/  # с аугментациями
├── scripts/             # Python-скрипты (fetch, clean, augment, train, convert)
├── models/train/        # PyTorch чекпоинты
├── models/converted/    # финальные .mlpackage (копируются в репо)
├── screenshots/         # снимки симулятора
└── logs/
```

В репозиторий попадают **только финальные `.mlpackage`** (в `HappySpeech/Resources/Models/`); реестр моделей — в wiki (`raw/team/ml-models.md`, синтез — `wiki/entities/ml-models.md`).

---

## 7. Четыре пользовательских контура

1. **Детский (kid):** играющий, тёплый, low-text, безопасные фразы, маскот «Ляля».
2. **Родительский (parent):** спокойный, структурированный, аналитика без жаргона.
3. **Специалистский (specialist):** аналитический, инструменты scoring, экспорты.
4. **Скрытый адаптивный:** `AdaptivePlannerService` — собирает дневной маршрут, учитывает усталость, разносит повторения.

---

## 8. Команда агентов (внутренняя)

Оркестратор — **CTO** (Claude).

- `pm` — backlog, sprint, user stories
- `speech-methodologist` — русская методика, ТЗ на игры
- `speech-analyst` — анализ конкурентов и научной базы
- `speech-content-curator` — БД контента, Realm-схемы для контента
- `designer-ui` + `designer-visual` — дизайн-спеки, компоненты, полировка
- `team-lead` → `ios-lead` → {`ios-dev-arch`, `ios-dev-ui`, `ios-dev-perf`}
- `team-lead` → `backend-lead` → {`backend-dev-api`, `backend-dev-infra`}
- `team-lead` → `qa-lead` → {`qa-unit`, `qa-simulator`}
- `ml-data-engineer` + `ml-trainer` — датасеты и обучение
- `sound-curator` — CC0/royalty-free аудио-ассеты

Артефакты команды: Obsidian LLM-Wiki, `…/Obsidian Vault/HappySpeech/raw/team/`.

---

## 9. Критерии готовности фичи (DoD)

- [ ] Код следует Clean Swift структуре
- [ ] Все тексты через String Catalog (ru + en)
- [ ] Light + Dark темы проверены
- [ ] Dynamic Type от Small до AccessibilityLarge не ломает layout
- [ ] VoiceOver-метки на интерактивных элементах
- [ ] Reduced Motion учтён
- [ ] Unit-тесты на Presenter/Interactor
- [ ] Snapshot-тесты на View (оба темы)
- [ ] Release-билд без варнингов
- [ ] Нет `print`, `TODO`, `FIXME`, debug-текстов в UI
- [ ] Запись в журнал решений wiki (`raw/team/decisions.md`) если принято архитектурное решение

---

## 10. Git workflow

- `main` — основная ветка, всегда зелёная.
- Фичи коммитятся логическими атомарными коммитами (`feat(scope): description`).
- Каждый коммит — компилирующийся билд.
- Тэги версий: `v0.x.y`.
- PRы не обязательны для диплома, но структура `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:` соблюдается.

---

## 11. Что НЕ делает приложение

Честные границы — критично для App Store и для этики продукта:

- ❌ Медицинская диагностика (это педагогическая поддержка).
- ❌ Клиническое распознавание нарушений речи (это интерпретируемые эвристики).
- ❌ Полное tongue-tracking внутри рта (ARKit даёт только внешние blendshapes).
- ❌ Гарантия клинических результатов.
- ❌ Замена живого логопеда.
- ❌ Сторонние трекеры и аналитика.
- ❌ Реклама и 3rd-party in-app.
- ❌ Открытые внешние ссылки без parental gate.

---

## 12. Где искать ответы

Память проекта — в Obsidian LLM-Wiki (`…/Obsidian Vault/HappySpeech/`). Начинать
с `index.md`. Ключевые места:

- Обзор и текущий статус: `wiki/overview.md`, `wiki/synthesis.md`
- Методология логопедии: `wiki/concepts/speech-methodology.md` (исходники — `raw/research-docs/`)
- Карта экранов: `wiki/entities/screens.md` (исходник — `raw/team/screen-map.md`)
- API-контракты: `wiki/entities/firebase-backend.md` (исходник — `raw/team/api-contracts.md`)
- Реестр ML-моделей: `wiki/entities/ml-models.md` (исходник — `raw/team/ml-models.md`)
- Журнал решений: `raw/team/decisions.md`
- Хронология версий: `wiki/timeline/version-timeline.md`
- Дизайн-токены (код): `HappySpeech/DesignSystem/Tokens/`
- Исходный research-отчёт: `happyspeech-design/project/uploads/deep-research-report-happyspeech.md` (локально, не в репо)
- Дизайн-прототип: `happyspeech-design/project/*.jsx` (локально, не в репо)

---

## 13. Быстрый старт для нового контрибьютора (и для Claude Code в новой сессии)

1. Прочитай этот файл целиком.
2. Открой Obsidian LLM-Wiki (`…/Obsidian Vault/HappySpeech/`), прочитай `index.md`, `wiki/overview.md`, `wiki/synthesis.md`.
3. Методика и продукт — `wiki/concepts/speech-methodology.md`, карта экранов — `wiki/entities/screens.md`.
4. Текущие задачи — бэклог в `raw/team/backlog.md`, хронология — `wiki/timeline/version-timeline.md`.
5. Не добавляй новых зависимостей без обновления этого файла.

---

## 14. Запуск команды агентов

Команда агентов оркеструется через **Agent tool** (15 локальных агентов из
`.claude/agents/`). Прежний tmux/mailbox-механизм отменён.

**Когда пользователь говорит «запусти проект», «старт»:**
1. Открой Obsidian LLM-Wiki, прочитай `index.md`, `wiki/overview.md`, `wiki/synthesis.md`,
   бэклог `raw/team/backlog.md` — пойми текущее состояние.
2. Декомпозируй задачу и спавни нужных агентов через Agent tool (фоном для параллельных).
3. Новые артефакты агенты пишут в `…/Obsidian Vault/HappySpeech/raw/team/`.
4. Крупные решения — фиксируй в `raw/team/decisions.md`; затем обнови wiki-страницы
   (`wiki/`) и журнал `log.md` хранилища (ingest по схеме wiki).

**Не трогать без согласования с `speech-methodologist` / `pm`:** методологию
(`raw/research-docs/`) и продуктовые спецификации (`raw/product-specs/`).
