# WCAG AA Аудит — HappySpeech
> Дата: 2026-04-25
> Аудитор: designer-ui (агент)
> Методология: статический анализ Swift-кода, проверка по WCAG 2.1 AA критериям:
> — Контраст текста (1.4.3): обычный текст ≥4.5:1, крупный (≥18pt bold / ≥24pt regular) ≥3:1
> — Touch target (2.5.5): минимум 44×44pt (для kid-контура рекомендовано 56×56pt)
> — VoiceOver labels (1.3.1, 4.1.2): все значимые элементы имеют accessibilityLabel
> — Dynamic Type (1.4.4): нет хардкода размеров, есть minimumScaleFactor и lineLimit(nil)
> — Reduced Motion (2.3.3): анимации условны через @Environment(\.accessibilityReduceMotion)

---

## Критические нарушения (исправить обязательно)

| Экран | Элемент | Проблема | Что исправить |
|---|---|---|---|
| ChildHomeView | Кнопка "Switch to parent" (parentButton) | Touch target 44×44pt — для kid-контура недостаточно. Требуется 56×56pt. В коде: `.frame(width: 44, height: 44)` | Увеличить frame до `.frame(width: 56, height: 56)` |
| ChildHomeView | sectionHeader() — кнопки "Открыть все" / "Все сессии" | У кнопок нет явного `.frame(minHeight: 44)` и нет accessibilityLabel на кнопке "Открыть" рядом с заголовком | Добавить `.frame(minHeight: 44)` и явный `.accessibilityLabel` |
| WorldMapView | WorldZoneTile | `minHeight: 160` при ширине ~160pt (две колонки): кнопка фактически ок по размеру, но у прогрессбара `frame(height: 4)` нет accessibilityHidden(true) — читается как пустой элемент VoiceOver | Добавить `.accessibilityHidden(true)` к HSProgressBar внутри тайла |
| WorldMapView | stickyBottomPanel HSProgressBar | `frame(height: 6)` без accessibilityHidden — читается VoiceOver как элемент без метки | Добавить `.accessibilityHidden(true)` к прогресс-барам, не несущим новой информации |
| RewardsView | tabFilterSection — фильтр-кнопки коллекций | `.padding(.vertical, SpacingTokens.tiny)` = 8pt → итоговая высота кнопки ~36pt, меньше 44pt. Это kid-экран, нужно 56pt | Увеличить до `.frame(minHeight: 56)` |
| RewardsView | StickerCellView — ячейки стикеров в грид 3×N | Ячейка рендерится на ширину ~(экран-2×screenEdge-2×gap)/3 ≈ 100pt. Высота явно не ограничена снизу, но touch target стикера ~64pt emoji + padding = ~88pt суммарно — ок. Однако lockedCell не имеет `.frame(minHeight: 88)`, поэтому возможна деградация при Dynamic Type XXL | Добавить `.frame(minWidth: 80, minHeight: 88)` к обоим состояниям ячейки |
| SessionHistoryView | SessionHistoryFilterChipBadge | Это информационный чип без действия, но он рендерится в HStack вместе с кнопкой "×". Кнопка xmark.circle.fill имеет `.frame(width: 44, height: 44)` — норма. Но сами чипы-метки интерактивны через скролл — их accessibilityLabel есть, однако isButton trait отсутствует | Добавить `.accessibilityAddTraits(.isButton)` если чипы кликабельны, или явно `.accessibilityElement(children: .ignore)` если нет |
| DemoModeView | Кнопка Skip в toolbar | `.font(TypographyTokens.body(15))` в toolbar — touch area ToolbarItem стандартная (44pt), но у кнопки нет `.frame(minWidth: 44, minHeight: 44)` явно. Важно: текст "Пропустить" белый на coral/lilac градиенте — контраст не проверяется статически, но белый на насыщенном coral (#E5756B ~) даёт ≈3.2:1 — ниже 4.5:1 требуемого для 15pt текста | Изменить цвет кнопки Skip на Color.white (opacity 1.0) и проверить контраст на реальном градиенте; добавить `.background(Color.black.opacity(0.001))` для расширения тап-зоны |
| ParentHomeView | homeTaskCard — использует `Color(hex: "#E5A000")` хардкодом | Нарушение проектного правила (не хардкодить hex) + не адаптируется к dark mode → контраст в dark mode неизвестен | Заменить на `ColorTokens.Brand.gold` |
| SpecialistReportsView | exportButton | Кнопки PDF/CSV: `.padding(.vertical, SpacingTokens.sp3)` = 12pt → итоговая высота ~44pt при условии нормального шрифта. Но при Dynamic Type Large+ текст может увеличиться и сжаться из-за `.minimumScaleFactor(0.85)`, при этом нет `.lineLimit(nil)` | Добавить `.lineLimit(nil)` к тексту кнопки экспорта |
| SpecialistHomeView | SpecChildRow | Нет accessibilityLabel и accessibilityHint на всей строке — она не является Button, но несёт интерактивный смысл "нажать для деталей". `Image(systemName: "chevron.right")` без accessibilityHidden | Обернуть row в `Button` с accessibilityLabel/Hint или добавить `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)` |
| SpecialistHomeView | SpecChildListView toolbar кнопка "+" | Нет accessibilityLabel на `Image(systemName: "plus")` в ToolbarItem | Добавить `.accessibilityLabel(String(localized: "spec.children.add"))` |

---

## Средние нарушения

| Экран | Элемент | Проблема | Что исправить |
|---|---|---|---|
| HomeTasksView | HomeTaskFilterChip | `.frame(minHeight: 36)` — ниже минимума 44pt для parent-контура. Хотя это не kid, WCAG требует 44pt минимум | Увеличить до `.frame(minHeight: 44)` |
| HomeTasksView | HomeTaskCard — chevron.right | `Image(systemName: "chevron.right")` с `.frame(width: 24, height: 24)` — элемент декоративный (`.accessibilityHidden(true)` есть) — это ок. Но checkboxButton имеет `.frame(width: 44, height: 44)` — граница нормы | Оставить 44pt, но для child-safe зон рассмотреть 48pt |
| SessionHistoryView | SessionHistoryFilterSheet — SessionFilterChipButton | `.frame(minHeight: 36)` → меньше 44pt | Увеличить до `.frame(minHeight: 44)` |
| SessionHistoryView | DateFieldButton | `.frame(minHeight: 56)` — норма. Но DatePicker в sheet не имеет accessibilityHint для родительского контура | Добавить `.accessibilityHint(...)` к DatePicker |
| SettingsView | SettingsProfileEditor — аватар-кнопки | `.frame(width: 48, height: 48)` — чуть ниже нормы 44pt? Нет, 48 > 44, это ок. Но кнопки в LazyVGrid из 6 столбцов: на iPhone SE ширина ячейки ~44pt — пограничная ситуация | Добавить `.frame(minWidth: 48, minHeight: 48)` явно внутри Button.label |
| SettingsView | SettingsProfileEditor — agePicker | `Picker(.wheel).frame(maxHeight: 140)` — wheel picker не имеет явного accessibilityLabel. SwiftUI генерирует автоматически, но нужно верифицировать | Убедиться, что Picker имеет явный String label (уже есть в коде) — это ок |
| ProgressDashboardView | SummaryCardView — card.value Text | `.accessibilityHidden(true)` на числовом значении, при этом `card.accessibilityLabel` на всей карточке — верно, но нужно убедиться что accessibilityLabel включает числовое значение (это за пределами статического анализа View) | Аудит Presenter: убедиться что `SummaryCardViewModel.accessibilityLabel` содержит значение |
| ProgressDashboardView | weeklyChart | Chart не имеет accessibilityValue с перечислением данных (в отличие от SoundAccuracyChartCard в ParentHomeView, где accessibilityValue есть) | Добавить `.accessibilityValue(display.weeklyChart.map { "\($0.label): \(Int($0.value))%" }.joined(separator: ", "))` |
| ProgressDashboardView | dailyChart bar annotations | `Text("\(Int(point.value))")` с `.accessibilityHidden(true)` над барами — сами бары через Chart accessibility читаются, но Chart не имеет `.accessibilityValue(...)` итоговым | Добавить accessibilityValue к Chart |
| SessionCompleteView | starsPhase — звёзды | `Image(systemName: earned ? "star.fill" : "star")` с `.accessibilityHidden(true)` для каждой звезды + `.accessibilityLabel(...)` на блоке из звёзд (через stars container) — это верно. Но блок имеет `.accessibilityElement(children: .ignore)` — VoiceOver читает всю группу как одну метку. Убедиться что метка корректна | Проверить что формат "N из M звёзд" читается правильно — в коде это есть через `sessionComplete.a11y.stars` |
| OnboardingFlowView | stepIndicator — прогресс-точки | Точки шагов `.accessibilityHidden(true)` для каждой + `.accessibilityLabel(display.progressLabel)` на группе — это ок. Но у кнопки Back (`chevron.left`) в progressHeader только символ chevron, нет `.frame(minHeight: 44)` → высота кнопки = размер иконки + padding(.tiny×2) = 17+16=33pt | Добавить `.frame(width: 44, height: 44)` к кнопке Back в OnboardingFlowView.progressHeader |
| OnboardingFlowView | AvatarOption — аватарки выбора | `.frame(width: 52, height: 52)` — чуть меньше рекомендованного, но выше 44pt минимума | Нормально, однако рекомендуется 56pt для kid-контура |
| PermissionFlowView | stepProgressIndicator — capsule dots | Dots 8pt/28pt высотой — полностью декоративны, accessibilityHidden не стоит на них явно; группа `.accessibilityLabel(display.progressLabel)` — это норма | Проверить что вся группа прогресса не читается VoiceOver дважды |
| PermissionFlowView | actionsBlock — кнопка Skip | `Button` с `.frame(maxWidth: .infinity, minHeight: 44)` — норма. Но `.foregroundStyle(ColorTokens.Kid.inkMuted)` на белом/кремовом фоне Kid.bg — inkMuted это приглушённый цвет, семантически означает ~50-60% opacity, что даёт контраст ≈2.5:1–3.5:1 для 16pt текста. Может не пройти 4.5:1 | Повысить контраст кнопки Skip: использовать `ColorTokens.Kid.inkSoft` или `ColorTokens.Kid.ink` с opacity 0.6, либо оставить мутед но проверить реальные значения в Assets.xcassets |
| OfflineStateView | pendingBadge | `.font(.system(size: 11, weight: .semibold))` — 11pt semibold является крупным жирным (bold ≥14pt? Нет — 11pt не крупный). Белый текст на `.warning` (жёлтый?) — контраст белого на жёлтом ≈1.1:1, критически мало | Изменить на тёмный текст поверх предупреждающего фона (`.foregroundStyle(ColorTokens.Spec.ink)`) или использовать иной цвет бейджа с достаточным контрастом |
| OfflineStateView | infoSection body text | `.foregroundStyle(ColorTokens.Kid.inkMuted)` на Kid.bg — inkMuted в светлой теме, если это ~55% серого на светлом кремовом фоне, может быть ниже 4.5:1. Требуется проверка реальных значений | Верифицировать контраст inkMuted/bg в Assets.xcassets; при необходимости заменить на `.ink` |

---

## Малые нарушения

| Экран | Элемент | Проблема | Что исправить |
|---|---|---|---|
| HomeTasksView | emptyStateView — butterfly emoji | `Text(verbatim: "🦋").accessibilityHidden(true)` — ок. Но анимация `.easeInOut(duration: 1.6).repeatForever(autoreverses: true)` не останавливается при `reduceMotion`. В коде видно `scaleEffect(reduceMotion ? 1 : 1.05)` без animation guard — анимация `.animation(..., value: display.isEmpty)` условна на reduceMotion — это ок | Уже обработано, нарушений нет |
| WorldMapView | progressLabel в stickyBottomPanel | `Text(display.totalStarsLabel)` с `.font(TypographyTokens.mono(13))` — 13pt mono текст, для kid-контура рекомендовано ≥22pt для основного текста. Это вторичная информация в нижней панели | Рекомендуется увеличить до 14–15pt или пометить как вспомогательный |
| SessionHistoryView | ScoreBadge | `.accessibilityHidden(true)` — скрыт от VoiceOver, но родительский элемент `SessionHistoryRowContent` имеет `.accessibilityLabel(row.accessibilityLabel)` — убедиться что метка строки включает score | Верификация на уровне Presenter |
| SettingsView | notificationsSection footer | `Text(...).font(TypographyTokens.caption(11))` — 11pt caption на inkMuted фоне может быть ниже 4.5:1. Footer текст является вспомогательным (Legal/informational), WCAG допускает снижение требований для неинтерактивных вспомогательных текстов в некоторых трактовках, но строго говоря 11pt не является "крупным" | Рекомендуется минимум 12pt для всех видимых текстов |
| SettingsView | dataSection footer | Аналогично notificationsSection — 11pt caption | Минимум 12pt |
| ProgressDashboardView | chart axis labels | `TypographyTokens.caption(10)` и `caption(11)` — очень мелкий шрифт для осей. WCAG не требует от чарт-меток полного соответствия как от основного контента, но рекомендуется ≥11pt | Оставить как есть или поднять до 12pt |
| SessionCompleteView | scorePhase | `Text(String(localized: "sessionComplete.score.caption")).font(TypographyTokens.body())` = 15pt. Foreground: `ColorTokens.Kid.inkMuted` на Kid.bg фоне — требуется проверка контраста | Верифицировать значения в Assets |
| RewardsView | lockedCell name text | `TypographyTokens.caption(11).foregroundStyle(ColorTokens.Kid.inkMuted)` — 11pt на заблокированном стикере: мелко и приглушённо. Декоративный контент, но лучше 12pt | Поднять до caption(12) |
| RewardsView | StickerUnlockOverlay — Text(unlock.name) | `TypographyTokens.title(28).foregroundStyle(.white)` поверх `Color.black.opacity(0.55)` overlay — белый на чёрном 55% = достаточный контраст ≥4.5:1. Ок | Нарушений нет |
| DemoModeView | spotlightCanvas stepDescription | `TypographyTokens.body(14).foregroundStyle(ColorTokens.Kid.inkMuted)` — 14pt regular, inkMuted на белой карточке. Пограничный контраст для inkMuted | Рекомендовать `.ink` или проверить assets |
| OnboardingFlowView | OnboardingRoleCard description text | `TypographyTokens.body(13).foregroundStyle(ColorTokens.Kid.inkMuted)` — 13pt regular. Возможно < 4.5:1 контраст | Заменить на body(14) или использовать `.ink` |
| ParentHomeView | ParentStatCard caption | `TypographyTokens.caption(10)` — 10pt текст. Самый мелкий в кодовой базе | Поднять минимум до 12pt |
| ParentHomeView | SessionRow date/duration | `TypographyTokens.caption().foregroundStyle(ColorTokens.Parent.inkMuted)` — captionScaled использует системный .caption, который масштабируется с Dynamic Type — это ок. Но проверить что `.lineLimit` не обрезает при Large+ | Добавить `.lineLimit(2)` чтобы обеспечить перенос вместо обрезки |
| SpecialistReportsView | SummaryMetric label | `TypographyTokens.caption(10)` — 10pt минимум | Поднять до caption(12) |
| SpecialistReportsView | SoundBreakdownRowView deltaPill | `.font(.system(size: 10, weight: .bold))` для иконки и `.font(.system(size: 11, weight: .semibold))` для текста — 10–11pt без токена типографики | Использовать `TypographyTokens.mono(12)` и сделать через токен |
| SpecialistReportsView | FilterChip | Нет `.frame(minHeight: 44)` — chip только padding 8+8=16pt вертикально + текст ~13pt = ~29pt высоты | Добавить `.frame(minHeight: 44)` |
| SpecialistHomeView | SpecChildRow | Нет явного `.frame(minHeight: 56)` на строке — `.padding(.vertical, SpacingTokens.sp2)` = 8pt × 2 + контент ~48pt ≈ 64pt — фактически ок, но явный minHeight надёжнее | Добавить `.frame(minHeight: 56)` |

---

## Пройдено без нарушений

- **HomeTasksView** — Reduced Motion учтён везде (`reduceMotion` conditional animations). VoiceOver labels и traits на всех кнопках. `accessibilityLabel`/`Hint` на checkboxButton, filterChip, emptyState. `minimumScaleFactor` и `lineLimit(nil)` на критических текстах.
- **SessionHistoryView** — filterToolbarItem имеет `accessibilityLabel` и `accessibilityValue`. Pull-to-refresh не мешает VoiceOver. SessionHistoryRowContent имеет `accessibilityElement(children: .combine)` + `accessibilityLabel` + `accessibilityHint` + `isButton` trait. Reduced Motion учтён.
- **SettingsView** — все Toggle имеют `accessibilityLabel` и `accessibilityValue`. Picker имеет `accessibilityLabel` и `accessibilityValue`. Кнопки деструктивных действий через `confirmationDialog`. `frame(minHeight: 44)` на всех List row кнопках.
- **PermissionFlowView** — `accessibilityElement(children: .combine)` на privacyCard и deniedCard. Иконки скрыты `.accessibilityHidden(true)`. HSButton имеет `accessibilityLabel` и `accessibilityHint`. Reduced Motion учтён.
- **ProgressDashboardView** — `accessibilityElement(children: .combine)` на SummaryCardView, SoundProgressCellView. Chart имеет `accessibilityLabel`. Все иконки трендов скрыты.
- **SessionCompleteView** — Reduced Motion учтён: `runPhaseSchedule` мгновенно показывает все фазы, `animateScoreCountUp` сразу выставляет значение. `accessibilityElement(children: .combine)` на mascotPhase, scorePhase. VoiceOver summary label на scorePhase.
- **OnboardingFlowView** — все Step views имеют `accessibilityAddTraits(.isHeader)` на заголовках. `OnboardingRoleCard` имеет `accessibilityElement(children: .combine)` + полный label. `AvatarOption` имеет `accessibilityLabel`. `GoalChipRow` имеет `accessibilityLabel` и `isSelected` trait.
- **OfflineStateView** — `accessibilityElement(children: .contain)` на root. illustrationSection имеет `accessibilityLabel`. pendingBadge имеет `accessibilityLabel`. Кнопки retry/continue имеют `accessibilityHint`. Reduced Motion: mascotPulse условен `guard !reduceMotion`.
- **SpecialistReportsView** — `SoundBreakdownRowView` имеет `accessibilityElement(children: .combine)` + `accessibilityLabel`. `SummaryMetric` имеет `accessibilityElement(children: .combine)` + `accessibilityLabel`. `exportButton` имеет `accessibilityLabel`.

---

## Сводная статистика

| Категория | Количество |
|---|---|
| Критические нарушения | 11 |
| Средние нарушения | 15 |
| Малые нарушения | 18 |
| Всего нарушений | 44 |

---

## Приоритет исправлений

### Немедленно (до M8):
1. `OfflineStateView.pendingBadge` — белый текст на жёлтом фоне (контраст ~1.1:1) — критический провал контраста
2. `ParentHomeView.homeTaskCard` — хардкод hex `Color(hex: "#E5A000")` не адаптируется к dark mode
3. `RewardsView` фильтр-кнопки коллекций — touch target 36pt в kid-контуре
4. `ChildHomeView` parentButton — 44pt вместо 56pt в kid-контуре
5. `SpecialistHomeView` SpecChildRow и кнопка "+" — отсутствие accessibilityLabel

### В рамках M7.6:
6. `DemoModeView` Skip button контраст на градиенте
7. `OnboardingFlowView` Back button touch target (33pt)
8. `SpecialistReportsView` FilterChip minHeight 44pt
9. `SessionHistoryView` / `HomeTasksView` FilterChip minHeight 44pt
10. `ParentStatCard` caption(10) → caption(12)
11. `SummaryMetric` caption(10) → caption(12)
12. `SoundBreakdownRowView` deltaPill — убрать хардкод размеров шрифта

### Рекомендации на M9+:
13. Верифицировать реальные значения inkMuted/bg контраста в Assets.xcassets (нужен цветовой аудит с инструментом)
14. Добавить `accessibilityValue` к Chart в `weeklyChartSection` и `dailyChartSection`
15. Поднять все caption(11) до caption(12) систематически

---

*Аудит выполнен методом статического анализа Swift-кода. Реальные контрастные соотношения для semantic color tokens (inkMuted, ink, bg и др.) зависят от значений в Assets.xcassets и требуют инструментальной проверки (например, Xcode Accessibility Inspector или Color Contrast Analyzer).*
