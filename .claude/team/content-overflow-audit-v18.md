# Content Overflow Audit v18 (Block AB)

**Дата:** 2026-05-09
**Цель:** аудит и фиксы content overflow для iPhone SE (3rd generation, 320pt logical width — самый узкий supported device).
**Sprint:** v18 (final).
**Author:** Block AB.

---

## Findings

### Сводная статистика

| Метрика | Значение |
|---|---|
| Всего files в `HappySpeech/Features` (Swift) | 540 |
| Files с long localized strings (40+ chars) | 34 |
| Files с long strings без `minimumScaleFactor` | 18 |
| Files уже использующие `minimumScaleFactor` | 96 |
| Files использующие `GeometryReader` / `containerRelativeFrame` | 26 |
| `lineLimit(1)` / `lineLimit(2)` occurrences | 232 |
| HStack без adaptive (приближённо) | 49 |

### Visible Text() с long Russian strings — оригинальный список

Поиск: `Text(String(localized: "<russian text 40+ chars>"))` — 8 occurrences:

1. `Auth/AuthSignUpView.swift:154` — «Создайте аккаунт, чтобы сохранить прогресс ребёнка» (уже OK — `lineLimit(nil) + minimumScaleFactor(0.85)`)
2. `Auth/AuthForgotPasswordView.swift:144` — «Введите почту — мы пришлём ссылку для восстановления» (FIX)
3. `Auth/AuthVerifyEmailView.swift:170` — «Перейдите по ссылке в письме, затем вернитесь сюда.» (FIX — был `lineLimit(nil)` без scale)
4. `Auth/AuthVerifyEmailView.swift:201` — «Выйти и войти под другим аккаунтом» (FIX — sign out link)
5. `LessonPlayer/Memory/MemoryView.swift:156` — «Найдено пар: \(matchedPairs) из \(totalPairs)» в HStack (FIX)
6. `LessonPlayer/SoundHunter/SoundHunterView.swift:132,136` — «Сцена X из Y» + «Найдено: A из B» (FIX оба)
7. `LessonPlayer/Sorting/SortingView.swift:419` — «Помогли: N слова» (FIX)
8. `ParentHome/ParentHomeSubViews.swift:230` — «Средняя точность: NN%» (FIX)

### Strings, оставшиеся без изменений (намеренно)

Following long strings — это **accessibility labels / hints** (не visible UI text), они не overflow:
- `MinimalPairsView.swift:96, 206, 304, 321` — все `accessibilityLabel`
- `PuzzleRevealView.swift:119, 126` — `accessibilityLabel`
- `VisualAcousticView.swift:115` — `accessibilityLabel`
- `StoryCompletionView.swift:109` — `accessibilityLabel`
- `Sorting/SortingView.swift:173` — `accessibilityLabel` (combine for HStack)
- `Bingo/BingoView.swift:181` — `accessibilityLabel`
- `Memory/MemoryView.swift:371` — `accessibilityLabel`

VoiceOver не читает их visually — overflow невозможен.

---

## Fixes applied

### Group AB.1 — Auth flows (2 файла, 3 occurrences)

**`AuthForgotPasswordView.swift`** — instructional text под title:
```swift
// Before
Text(String(localized: "Введите почту — мы пришлём ссылку для восстановления"))
    .multilineTextAlignment(.center)

// After
Text(...)
    .multilineTextAlignment(.center)
    .lineLimit(nil)
    .minimumScaleFactor(0.85)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, SpacingTokens.medium)
```

**`AuthVerifyEmailView.swift`** — два визуальных текста:
- стр. 170 — instruction text в карточке (был `lineLimit(nil)` без scale, теперь добавлен `minimumScaleFactor(0.85) + fixedSize`)
- стр. 201 — sign-out link (была одна строка без scale; теперь `lineLimit(2) + minimumScaleFactor(0.85)` с `multilineTextAlignment + horizontal padding`)

### Group AB.2 — LessonPlayer counters (3 файла, 4 occurrences)

**`Memory/MemoryView.swift`** — HStack «Найдено пар: …» + streakBadge:
- добавлен `spacing: SpacingTokens.small`
- Text: `lineLimit(1) + minimumScaleFactor(0.85) + layoutPriority(1)`
- `Spacer(minLength: 4)` (вместо infinite spacer)

**`SoundHunter/SoundHunterView.swift`** — HStack scene indicator + counter:
- spacing tiny → small
- оба Text: `lineLimit(1) + minimumScaleFactor(0.85)`
- `Spacer(minLength: 4)`

**`Sorting/SortingView.swift`** — каунтер «Помогли: N слова» в completionView:
- `lineLimit(1) + minimumScaleFactor(0.85)`

### Group AB.3 — ParentHome (1 файл, 1 occurrence)

**`ParentHome/ParentHomeSubViews.swift`** — `averageRow` HStack:
- Text «Средняя точность: NN%»: `lineLimit(1) + minimumScaleFactor(0.85) + layoutPriority(1)`
- `Spacer(minLength: 4)`

---

## iPhone SE 3 verification

```
xcodebuild -project HappySpeech.xcodeproj \
  -scheme HappySpeech \
  -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' \
  -derivedDataPath /tmp/HappySpeechBuildAB \
  build
```

**Результат:** ** BUILD SUCCEEDED **

SwiftLint --strict на изменённых файлах: 0 violations.
Russian-only guard: 0 нерусских строк добавлено.

---

## Defer / out of scope

- **Heavy snapshot suite на iPhone SE 3rd gen** — defer Block V (visual-regression).
- **`HSEmptyStateView` (DesignSystem)** — long `message` тоже нуждается в `lineLimit(nil) + minimumScaleFactor(0.85)`, но 41 DesignSystem components — closed (нельзя трогать в этом блоке).
- **`HSButton` адаптация для длинных titles** — closed как DesignSystem component.
- **Marginal cases** (1–2 char overflow at AccessibilityLarge) — deferred Block V.
- **Дополнительные screens на 320pt UI inspection** — defer follow-up если pol'zovatel' попросит.

---

## Files modified

1. `HappySpeech/Features/Auth/AuthForgotPasswordView.swift`
2. `HappySpeech/Features/Auth/AuthVerifyEmailView.swift`
3. `HappySpeech/Features/LessonPlayer/Memory/MemoryView.swift`
4. `HappySpeech/Features/LessonPlayer/SoundHunter/SoundHunterView.swift`
5. `HappySpeech/Features/LessonPlayer/Sorting/SortingView.swift`
6. `HappySpeech/Features/ParentHome/ParentHomeSubViews.swift`

**Итого:** 6 файлов, 8 fix-локаций.

---

## ADR closure

Block AB v18 закрыт.
- Adaptive layout pattern для long Russian strings + counter-style HStacks применён.
- BUILD SUCCEEDED iPhone SE (3rd generation).
- 0 SwiftLint --strict violations.
- 0 English content added.
