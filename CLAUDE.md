# HappySpeech — Claude Code project guide

> Этот файл читается Claude Code при каждой сессии в этом репозитории. Он описывает проект, архитектуру, правила кода и рабочие процессы. **Обновляй его при каждом крупном изменении архитектуры.**

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
- `ResearchDocs/` — методологические документы (от speech-methodologist)
- `ProductSpecs/` — продуктовые спецификации
- `Resources/` — Assets.xcassets, звуки, Core ML модели, локализации

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
- Никаких `TODO`, `FIXME`, `HACK`, `XXX` в коде — задачи трекаются только в `~/.claude/team/backlog.md`.
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

**Источник методики:** `HappySpeech/ResearchDocs/` (методологические документы русской логопедии) + `~/.claude/team/speech-methodology.md`.

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

В репозиторий попадают **только финальные `.mlpackage`** (в `HappySpeech/Resources/Models/`) и реестр моделей (`~/.claude/team/ml-models.md`).

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

Артефакты команды: `~/.claude/team/`.

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
- [ ] Запись в `~/.claude/team/decisions.md` если принято архитектурное решение

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

- Методология: `HappySpeech/ResearchDocs/speech-methodology.md`
- Продуктовая спецификация: `HappySpeech/ProductSpecs/product-spec.md`
- Карта экранов: `~/.claude/team/screen-map.md`
- API-контракты: `~/.claude/team/api-contracts.md`
- Дизайн-токены: `HappySpeech/DesignSystem/Tokens/`
- Реестр моделей: `~/.claude/team/ml-models.md`
- Журнал решений: `~/.claude/team/decisions.md`
- Исходный research-отчёт: `happyspeech-design/project/uploads/deep-research-report-happyspeech.md` (локально, не в репо)
- Дизайн-прототип: `happyspeech-design/project/*.jsx` (локально, не в репо)

---

## 13. Быстрый старт для нового контрибьютора (и для Claude Code в новой сессии)

1. Прочитай этот файл целиком.
2. Прочитай `HappySpeech/ResearchDocs/speech-methodology.md`.
3. Прочитай `HappySpeech/ProductSpecs/product-spec.md` и `screen-map.md`.
4. Посмотри текущие TODO в `~/.claude/team/sprint.md`.
5. Не добавляй новых зависимостей без обновления этого файла.

---

## 14. CTO — Запуск команды агентов

**Когда пользователь говорит "запусти проект", "начни разработку", "старт":**

```bash
# Прочитать текущее состояние фаз
cat "$(pwd)/.claude/team/orchestration/phases.json"

# Запустить оркестратор в фоне (он сам ведёт все 5 фаз)
bash ~/.claude/scripts/orchestrator.sh "$(pwd)" &
ORCH_PID=$!
echo "Оркестратор запущен (PID $ORCH_PID)"
```

**Одновременно запусти параллельные агенты** (они не в phases.json):
```python
import json, time, fcntl, os
PROJECT_DIR = os.getcwd()
ORCH = f"{PROJECT_DIR}/.claude/team/orchestration"
os.makedirs(f"{ORCH}/mailbox", exist_ok=True)
os.makedirs(f"{ORCH}/locks", exist_ok=True)

def send(agent, message, task_id):
    mailbox = f"{ORCH}/mailbox/{agent}.jsonl"
    lock_path = f"{ORCH}/locks/{agent}.mailbox.lock"
    msg = {"from":"cto","to":agent,"task_id":task_id,"message":message,
           "timestamp":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())}
    with open(lock_path,'w') as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        with open(mailbox,'a') as f: f.write(json.dumps(msg,ensure_ascii=False)+'\n')
        fcntl.flock(lf, fcntl.LOCK_UN)
    print(f"→ {agent}: {task_id}")

# Параллельные задачи (не зависят от фаз оркестратора)
send("ml-data-engineer",
     "Read ProductSpecs/master-plan.md Phase 4 ML requirements. Collect Russian speech datasets. Save to ~/Downloads/datasets/. Write registry to .claude/team/ml-datasets.md",
     "ml-data-001")
send("research",
     "Research iOS speech therapy app market, WhisperKit integration examples, ARKit blendshapes for mouth tracking. Save to .claude/team/decisions.md under ## Research Findings",
     "research-001")
send("anthropic-docs",
     "Look up Claude Code best practices for iOS simulator, xcodebuild, Swift code review. Save to .claude/team/decisions.md under ## Claude Code Best Practices",
     "docs-001")
```

**Проверить прогресс:**
```bash
# Статус фаз
python3 -c "import json; d=json.load(open('.claude/team/orchestration/phases.json')); [print(f'Phase {p[\"id\"]} ({p[\"name\"]}): {p[\"status\"]}') for p in d['phases']]"

# Статус всех агентов
for f in .claude/team/orchestration/status/*.status; do echo "$(basename $f .status): $(cat $f)"; done
```

**Порядок фаз (orchestrator.sh управляет автоматически):**
- Phase 0: speech-methodologist + speech-analyst → пишут ТЗ игр и анализ конкурентов
- Phase 1: pm + designer-ui + backend-lead + speech-content-curator → план, дизайн, API
- Phase 2: ios-dev-arch → архитектура (SEQUENTIAL — ждёт Phase 1)
- Phase 3: ios-lead + backend-dev-api → реализация в git worktrees
- Phase 4: qa-simulator + qa-unit → тестирование

**После Phase 1 designer-ui finished** — отправь designer-visual:
```python
send("designer-visual",
     "design-specs.md ready. Create ColorTokens.swift, TypographyTokens.swift, SpacingTokens.swift, MotionTokens.swift. Read .claude/team/design-specs.md",
     "design-visual-001")
```

**После ml-data-engineer finished** — отправь ml-trainer:
```python
send("ml-trainer",
     "Dataset ready at ~/Downloads/datasets/. Read .claude/team/ml-datasets.md. Train Core ML pronunciation scorer. Save to ~/Downloads/models/. Write .claude/team/ml-models.md",
     "ml-train-001")
```
6. Не трогай `ResearchDocs/` и `ProductSpecs/` без согласования с `speech-methodologist` / `pm`.
