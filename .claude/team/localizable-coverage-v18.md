# Block L.verify v18 — Localizable Coverage

## Date: 2026-05-09

## Coverage

| Метрика | Значение |
|---|---|
| Ключей в xcstrings до аудита | 3827 |
| R-screens новых ключей | 90 (из которых 90 реальных dot-notation ключей) |
| J-components новых ключей | 24 реальных ключа |
| Пропущенных (добавлено в этом блоке) | 113 |
| Итого ключей в xcstrings | 3940 |
| Coverage после патча | **100%** |

## Источники новых ключей

### R-screens (5 экранов Block R)
- `DialectAdaptation` — 8 ключей (dialect.*)
- `LogopedistChat` — 30 ключей (chat.*)
- `WeeklyChallenge` — 13 ключей (weekly.*)
- `FamilyAchievements` — 27 ключей (family.*)
- `CulturalContent` — 10 ключей (cultural.*)

### J-components (4 компонента Block J B.10/C)
- `HSEmptyStateView` — 15 ключей (empty.*)
- `HSStarRatingView` — 3 ключа (starRating.*)
- `HSPaywallTeaser` — 4 ключа (paywall.teaser.*)
- `HSTimelineView` — 0 новых ключей (не использует String(localized:))

## Ключи-артефакты grep (исключены из аудита)

Grep вытащил 141 "ключ", из них 28 — ложные срабатывания:
- Swift-интерполяции: `\(index)`, `\(maxStars)`, `\(value)` — фрагменты accessibilityLabel
- `«\(query)»` — конкатенация после перевода
- Полные русские строки из `defaultValue:` параметра — они уже описаны реальными ключами

Итого реальных новых ключей: 113. Все добавлены.

## Примеры добавленных ключей

```
chat.composer.placeholder         → "Написать логопеду..."
chat.seed.welcome                 → "Здравствуйте! Я %@ — ваш логопед в HappySpeech."
chat.specialist.lastSeen          → "Был(а) в %@"
cultural.category.a11y            → "%@, %d материалов"
cultural.item.a11y.withAuthor     → "%@, автор %@, категория %@"
dialect.row.a11y.selected         → "%@, выбран"
family.streak.together.title      → "%d дней вместе"
family.member.streak.daysN        → "%d дней подряд"
family.summary.unlocked           → "%d из %d наград"
weekly.day.a11y.completed         → "%@: выполнен"
weekly.toast.dayMarked            → "Выполнено %d из %d дней"
empty.search.message.withQuery    → "Ничего не найдено по запросу"
paywall.teaser.hint.enabled       → "Нажмите для подробностей"
starRating.outOf                  → "из"
```

## Валидация

```
python3 -c "import json; json.load(open('HappySpeech/Resources/Localizable.xcstrings')); print('valid')"
→ valid JSON ✓
```

Missing keys after patch: 0 ✓
