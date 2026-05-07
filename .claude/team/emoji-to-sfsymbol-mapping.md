# Emoji → SF Symbol / Illustration mapping (Block D v16)

**Дата:** 2026-05-07
**Scope:** замена эмодзи в UI strings 47 файлов Features/
**Стратегия:** трёхкатегорийная (см. ниже)

---

## Стратегия категорий

### Категория A — UI chrome (декоративные иконки)
**Решение:** SF Symbol через `Image(systemName:)` + `foregroundStyle(ColorTokens.*)`.
**Затрагивает файлы:** ChildHomeView, ProgressDashboardView, SessionHistoryView, ARZoneViewComponents, и confetti `🎉` в Bingo/PuzzleReveal/Rhythm/SharePlay/ARStoryQuestView.

### Категория B — Игровой контент (наглядные изображения слов)
**Решение:** замена `let emoji: String` → `let illustrationName: String` + `Image(<asset>)`.
**Принцип:** для логопедических упражнений ребёнку нужна узнаваемая иллюстрация объекта (сова, собака). SF Symbols (`bird.fill` для совы) методически неверны.
**Если иллюстрации нет** → запись в `illustrations-needed-block-d.md` для последующей генерации.

### Категория C — Аватары пользователей
**Решение:** preset = существующая иллюстрация (`mascot_lyalya_*`, `word_*`, `reward_*`). Поле `emoji` → `illustrationName`.

### StoryLibrary.swift (119 эмодзи) — DEFER
ADR-V16-STORY-EMOJI-DEFER. Narrative content, не UI chrome. Будет переработан в отдельном Block S через StoryIllustrationGenerator (post-v1.0).

---

## Категория A — SF Symbol mapping (проверено, существует в iOS 17+)

| Emoji | SF Symbol | Контекст | Tint |
|-------|-----------|----------|------|
| 🎯 | `target` | mission/goal | Brand.primary |
| 🎮 | `gamecontroller.fill` | quick play | Accent.fun |
| ✨ | `sparkles` | actions/highlight | Accent.warm |
| 🗺 / 🗺️ | `map.fill` | world map | Accent.cool |
| 📈 | `chart.line.uptrend.xyaxis` | progress trend | Success.primary |
| 📊 | `chart.bar.fill` | analytics dashboard | Brand.primary |
| 🏅 | `medal.fill` | rewards/achievements | Accent.warm |
| 📚 | `books.vertical.fill` | recent lessons / library | Brand.secondary |
| 📝 | `square.and.pencil` | today words | Kid.ink |
| 📋 | `list.bullet.clipboard.fill` | home tasks | Kid.ink |
| 🔎 / 🔍 | `magnifyingglass` | search empty | Kid.inkMuted |
| 📅 | `calendar` | date filter | Kid.inkMuted |
| 🎉 | `party.popper.fill` | celebration confetti | Accent.warm |
| ✅ | `checkmark.circle.fill` | success | Success.primary |
| 💬 | `bubble.left.fill` | dialog/say | Brand.primary |
| 🏆 | `trophy.fill` | achievement final | Accent.warm |
| 💫 | `sparkle` | shimmer | Accent.warm |
| 🦋 | `Image("mascot_lyalya_wave")` | Lyalya идл/декор (Lyalya — бабочка) | n/a |

**Не использованные из исходного mapping (несуществующие в SF Symbols):**
- `butterfly` — не существует, заменено на иллюстрацию `mascot_lyalya_wave`
- `ribbon` — не существует, заменено на `medal.fill`
- `cat.fill` — iOS 26+, требует fallback → `pawprint.fill` (iOS 17+)
- `rainbow` — заменено на `sparkles` или `Image("reward_rainbow")`

---

## Категория B — Illustration mapping (existing assets only)

Для замены `emoji` на `Image(<illustrationName>)` используются существующие assets из
`HappySpeech/Resources/Assets.xcassets/Illustrations/`.

### Animals
| Emoji | Word (ru) | illustrationName | Status |
|-------|-----------|------------------|--------|
| 🦉 | сова | `word_bird` | OK (generic bird) |
| 🐶 | собака | `word_dog` | OK |
| 🐱 | кот | `word_cat` | OK |
| 🦊 | лиса | `word_fox` | OK |
| 🐻 | медведь | `word_bear` | OK |
| 🐰 | заяц | `word_hare` | OK |
| 🐍 | змея | (нет) | NEEDED → `word_snake` |
| 🐝 | пчела | (нет) | NEEDED → `word_bee` |
| 🐐 | коза | (нет) | NEEDED → `word_goat` |
| 🐢 | черепаха | (нет) | NEEDED → `word_turtle` |
| 🐌 | улитка | (нет) | NEEDED → `word_snail` |
| 🦓 | зебра | (нет) | NEEDED → `word_zebra` |
| 🦢 | цапля | (нет) | NEEDED → `word_heron` |
| 🦟 | комар | (нет) | NEEDED → `word_mosquito` |
| 🐤 / 🐣 | цыплёнок | (нет) | NEEDED → `word_chick` |
| 🦋 | бабочка | `word_butterfly_insect` | OK |
| 🐘 | слон | `word_elephant` | OK |
| 🐸 | лягушка | `word_frog` | OK |
| 🐮 | корова | `word_cow` | OK |
| 🐓 | петух | `word_rooster` | OK |
| 🐔 | курица | `word_hen` | OK |
| 🐠 | рыба | `word_fish` | OK |

### Objects
| Emoji | Word (ru) | illustrationName | Status |
|-------|-----------|------------------|--------|
| 🍎 | яблоко | `word_apple` | OK |
| ✈️ | самолёт | (нет) | NEEDED → `word_plane` |
| 🌳 | дерево | `word_tree` | OK |
| 🌲 | ёлка | `word_forest` | OK (ближайшее) |
| 🌰 | жёлудь | (нет) | NEEDED → `word_acorn` |
| ☀️ | солнце | `word_sun` | OK |
| 🌞 | солнце | `word_sun` | OK |
| 🌙 | луна | `word_moon` | OK |
| 🌸 / 🌿 | цветок/трава | `word_flower` | OK (ближайшее) |
| 🌬️ | ветер | (нет) | NEEDED → `word_wind` |
| 🧃 | сок | (нет) | NEEDED → `word_juice` |
| 🦷 | зуб | (нет) | NEEDED → `word_tooth` |
| 🥣 | миска | (нет) | NEEDED → `word_bowl` |
| 🧥 | куртка | (нет) | NEEDED → `word_jacket` |
| 🌀 | спираль | (нет) | NEEDED → `word_spiral` |
| 🧲 | магнит | (нет) | NEEDED → `word_magnet` |
| 🍊 | апельсин | (нет) | NEEDED → `word_orange_fruit` |
| 🚀 | ракета | `reward_rocket` | OK (reward set) |
| 💎 | алмаз | `reward_diamond` | OK |
| 💰 | монеты | (нет) | NEEDED → `word_coins` |
| 🐚 | ракушка | (нет) | NEEDED → `word_shell` |

### UI/Shapes (sorting categories)
| Emoji | Назначение | illustrationName / Solution |
|-------|-----------|----------------------------|
| 🔵 | категория «Звук С» | `Circle().fill(ColorTokens.Accent.cool)` (geometric) |
| 🟢 | категория «Звук Ш» | `Circle().fill(ColorTokens.Success.primary)` |
| 🟡 / 🟠 / 🔴 / 🟣 | sort categories | геометрия (Circle с tint) |

---

## Категория C — Avatar presets

### Onboarding/Family/Settings/Profile avatars
| Emoji | id | illustrationName |
|-------|-----|------------------|
| 🦋 | `lyalya_wave` | `mascot_lyalya_wave` |
| 🚀 | `rocket` | `reward_rocket` |
| 🐉 | `dragon` (нет dragon) | `reward_brave_heart` (символ силы) |
| 🦊 | `fox` | `word_fox` |
| 🐰 | `hare` | `word_hare` |
| 🦁 | `lion` (нет) | `reward_champion` (король зверей) |
| 🐼 | `panda` (нет) | `word_bear` (медведь fallback) |
| 🦉 | `owl` | `word_bird` |
| 🐢 | `turtle` (нет) | `word_frog` (амфибия fallback) |
| 👶/👦/👧/🧒 | child | `mascot_lyalya_happy` |
| 👨‍👩‍👧 | parent/family | `mascot_lyalya_read` (взрослая поза) |

### Reward category icons (Rewards filter)
| Emoji | Категория | illustrationName |
|-------|-----------|------------------|
| 🎁 | all | `reward_gift_box` |
| 🐾 | animals | `word_cat` (для бренда категории) |
| 🚀 | space | `reward_rocket` |
| 🌟 / ⭐ | stars | `reward_star` / `reward_gold_star` |
| 🌈 | rainbow | `reward_rainbow` |
| 🏆 | trophy | `reward_trophy` |
| 🎵 | music | SF Symbol `music.note` (UI chrome) |

### Confetti particle decoration (Onboarding/Permissions/Rewards)
**Решение:** заменить эмодзи-частицы на SF Symbol particles (party.popper.fill, sparkle, star.fill, heart.fill) + tint random из ColorTokens.confetti palette.

---

## Принципы реализации

1. SF Symbol использования: `Image(systemName: "<name>").foregroundStyle(ColorTokens.<token>).accessibilityLabel(String(localized: "<key>"))`
2. Illustration использования: `Image("<asset>").resizable().aspectRatio(contentMode: .fit).accessibilityLabel(<word>)`
3. Models: rename `emoji: String` → `illustrationName: String`
4. Если иллюстрации нет → fallback на ближайшую существующую + запись в `illustrations-needed-block-d.md`
5. Comments/docstrings/`/// 🎯` — оставляем как есть, не нарушает UI
6. StoryLibrary.swift — defer (ADR)
