# V23 Phase 6.2 — Independent Code Review

**Date:** 2026-05-14
**Reviewer:** code-reviewer Opus xhigh (independent, не видел cto report)
**Plan:** v23
**Scope:** Sample 5 Features (ChildHome, Bingo, Settings, ProgramEditor, FamilyAchievements) +
core services (AppContainer, AppError, AuthService, PronunciationScorer) + 3 test files.

---

## Summary

- Total findings: 14
- P0: 0
- P1: 6
- P2: 8
- Verdict: **READY (with cleanup)** — критических блокеров нет, но 6 важных замечаний
  стоит закрыть в следующем спринте (или v24 plan).

---

## Clean Swift VIP Compliance

| Feature              | View | Interactor | Presenter | Router | Models | Verdict |
|----------------------|:---:|:---:|:---:|:---:|:---:|:---:|
| ChildHome            | OK  | OK  | OK  | OK  | OK  | PASS  |
| LessonPlayer/Bingo   | OK  | OK  | OK  | OK  | OK  | PASS  |
| Settings             | OK  | OK  | OK  | OK  | OK  | PASS  |
| Specialist/ProgramEditor | OK | OK | OK | OK | OK | PASS (минор) |
| FamilyAchievements   | OK  | OK  | OK  | OK  | OK  | PASS  |

Architecture compliance: Все 5 фич следуют Clean Swift VIP. View не содержит бизнес-логики
(только bootstrap + биндинг state → render). Interactor — `@MainActor final class`, владеет
draft-стейтом и dispatch к presenter. Presenter трансформирует Response → ViewModel без
прямого знания View (через protocol displayLogic). Router использует `AppCoordinator`
для всех переходов (single source of truth для navigation). Models — структурированные
Request / Response / ViewModel namespaces.

Особо хорошо:
- `ChildHomeInteractor` — корректно делит helper-методы на static + instance.
- `BingoInteractor.cancel()` + `deinit` aggressively cancel tasks (avoidance memory leak).
- `ProgramEditorInteractor` — встроенная валидация программ (30-min cap, prerequisites).
- `FamilyAchievementsView` — `@Observable` holder вместо `ObservableObject`.

---

## Findings

### P1 — Design system violations

**P1.1 — Hardcoded `.red` в ProgramEditorView**
`HappySpeech/Features/Specialist/ProgramEditor/ProgramEditorView.swift:92`
```swift
.foregroundStyle(isValid ? ColorTokens.Kid.ink : .red)
```
Должно быть `ColorTokens.Semantic.error`. Прямо рядом на line 100 уже используется
корректный токен — налицо забытый рефакторинг. Дисперсия цветовых решений по приложению.

### P1 — Localization

**P1.2 — Interpolated localization key (потенциальный xcstrings spam)**
`HappySpeech/Features/ChildHome/ChildHomeInteractor.swift:604`
```swift
let description = String(localized: "\(mission.requiredReps) раундов")
```
Каждое разное значение `requiredReps` создаёт новый ключ в Localizable.xcstrings. Должно
быть `String.localizedStringWithFormat(String(localized: "child.home.widget.rounds.count"),
mission.requiredReps)` с правилом плюрализации в xcstrings (`%d раунд / %d раунда /
%d раундов`).

**P1.3 — Русский хардкод как localization key (Bingo)**
`HappySpeech/Features/LessonPlayer/Bingo/BingoView.swift:57,81`
```swift
.accessibilityLabel(String(localized: "Бинго: ищи слово на карточке"))
Text(String(localized: "Готовим карточку…"))
```
sourceLanguage = "ru" допускает такую запись, но это нарушает project convention
(в ChildHome все ключи в формате `child.home.*`). Создаёт inconsistency и блокирует
английский перевод в будущем.

**P1.4 — Аналогичная проблема в PronunciationScorer**
`HappySpeech/ML/PronunciationScorer.swift:33-36`
```swift
case .whistling: return String(localized: "Свистящие (С, З, Ц)")
```
ML слой — НЕ user-facing, но всё равно стоит ключи `phoneme.group.whistling` и т.д.

### P1 — Pluralization

**P1.5 — Hardcoded plural в widget title (косвенно через P1.2)**
"раундов" — winning case для 5+, но `requiredReps == 1` даст «1 раундов».
xcstrings поддерживает Plural Variations — это надо использовать.

### P1 — Architecture

**P1.6 — DailyMissionSyncService используется в Interactor (Features → Sync)**
`HappySpeech/Features/ChildHome/ChildHomeInteractor.swift:617-623` вызывает
`missionSyncService.updateMission(...)`. Это допустимо т.к. идёт через protocol
`DailyMissionSyncServiceProtocol` (Services-слой), но необходимо проверить что под капотом
сервис НЕ читает Realm напрямую из Sync-слоя. По CLAUDE.md `Features → Services (протоколы)`
разрешено, поэтому формально OK — но в PR-описании нужно явно отметить, что widget
получает только анонимные данные (line 591-592 комментарий верно фиксирует COPPA-safety).

---

### P2 — Suggestions

**P2.1 — `\u{1F525}` детектор для emoji** — UI tour rerun уже отрабатывает, но в
`BingoView.swift` и других есть фрагменты с emoji-like SF symbols (`"party.popper.fill"`
etc.). Стоит явно отделить SF Symbol names от emoji через type alias `SymbolName = String`.

**P2.2 — `displayedName` fallback в ChildHomeView:268** — `"\(viewModel.displayedName)!"`
хардкодит восклицательный знак (нарушение pluralisation/локализации, если в EN перевод
будет без `!`). Лучше через String Catalog.

**P2.3 — `FirstFrameLogged` через `@State`** (ChildHomeView:55) — Block 0.5 v22
signpost OK, но стоит вынести cold-start fixture в отдельный `OnFirstFrameModifier`,
чтобы переиспользовать в ParentHomeView/SpecialistView.

**P2.4 — `seedRecentRewards()` использует `now.addingTimeInterval(-3600)` без
учёта timezone** (ChildHomeInteractor:457) — для seed data OK, но если переезжаешь
на тесты — frozen Date.

**P2.5 — `ColorTokens.Brand.butter` повторно используется для `quickaction_rewards`
и `quickaction_cultural`** (ChildHomeView:651, 683) — повторение цвета в одном grid.
Mascot/Color designer должен подтвердить, что это намеренно (или взять `.sage` для
cultural).

**P2.6 — BingoInteractor.wordCatalog — 4×30 hardcoded слов** (BingoInteractor:61-86)
дублирует логику из ContentEngine. После M10 (ContentEngine.dailyWords) этот словарь
должен уйти.

**P2.7 — `ProgramEditorDisplayBridge` strong-владение через @State** —
`ProgramEditorView.swift:25` хорошо документировано в комментарии, но решение нестандартное
(обычно presenter удерживает view через protocol). Лучше: presenter `weak var display`
+ view-state удерживается через `@Observable` holder (как в FamilyAchievements).

**P2.8 — `BingoView.bootstrap()` обрабатывает SwiftUI lifecycle вручную** —
`bootstrapped` flag дублирует логику `@State private var interactor: ...` пустой проверки.
Можно убрать.

---

## Verified passing

- Clean Swift VIP — все 5 фич ✓
- `@Observable` вместо `ObservableObject` — ChildHomeView, FamilyAchievementsView ✓
- `@MainActor` на всех Interactor/Presenter ✓
- `Logger` (OSLog) с `privacy: .public` правильно используется ✓
- Нет `print(...)`, `TODO`, `FIXME` в просмотренных файлах ✓
- Нет force-unwrap `!` в production коде (только в тестах) ✓
- Task cancellation: `advanceTask?.cancel()` + `deinit` cleanup ✓
- `[weak self]` в closures (BingoInteractor:288, 298) ✓
- Localized error messages через `AppError: LocalizedError` ✓
- COPPA: widget sync передаёт только анонимные данные (комментарий line 591-592) ✓
- WhisperKit — НЕТ упоминаний GigaAM в просмотренных файлах ✓
- HFInferenceClient — НЕТ в коде (Tier B inference удалён или не используется) ✓
- Firebase mocks для тестов ✓
- `String(localized:)` повсеместно, но с замечаниями по convention (P1.3-P1.4) ✓
- Sound progress / world zones — Sendable values ✓
- Tests: meaningful assertions, no AI patterns (XCTAssertEqual / XCTAssertGreaterThan / Spy pattern) ✓

---

## Critical comparisons с потенциальным CTO audit

Что мог пропустить CTO (educated guess, я его репорта не видел):

1. **P1.2 (interpolated localization key)** — типичный «незаметный» баг, обычно ловится
   на code review, не на architecture audit. Может проявиться только в production xcstrings
   spam (плодит 5 ключей на каждое значение `requiredReps`).

2. **P1.1 (`.red`)** — выглядит как минорная косметика, но это **симптом**, что
   pre-commit hook на hardcoded colors не работает. Стоит проверить swiftlint custom
   rule `hex_colors` / `system_colors_in_features`.

3. **P1.6 (DailyMissionSyncService)** — formally OK по architecture, но требует явной
   проверки: НЕ читает ли implementation Realm напрямую? Если читает — это нарушение
   `Features → Sync` запрета.

4. **P2.7 (DisplayBridge strong @State)** — нестандартный паттерн в одной фиче из 5.
   Если cto проверял только архитектурный grep — мог не заметить. Это технический долг
   на консолидацию.

5. **P2.1 (SF Symbol vs emoji confusion)** — `"party.popper.fill"` хранится в поле
   `emoji` (ChildHomeInteractor:223, comment line 474). Это **legacy field name** —
   модель данных лжёт о содержимом. Riff potential для bugs если кто-то поменяет
   на реальный emoji.

---

## Recommendation

**READY** — критических блокеров нет, проект ready к v23 release. Все 6 P1 замечаний
можно адресовать в v24 cleanup sprint (≤ 4 часа работы суммарно).

Рекомендуемые next steps:
1. P1.1, P1.2 — quick fix (~10 минут), стоит закрыть в текущем релизе.
2. P1.3, P1.4 — рефакторинг localization keys (~1.5 часа), v24 backlog.
3. P1.6 — verify DailyMissionSyncService internals (~30 минут).
4. P2.* — добавить в v24 backlog.

Архитектурные decisions (Clean Swift VIP, @Observable, @MainActor, AppError, OSLog)
выглядят **stable и mature**. Команда явно довела до production-ready состояния.

---

## Commit

```
docs(audit): 6.2 v23 — Independent code review
```
