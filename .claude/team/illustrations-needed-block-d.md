# Illustrations needed — Block D v16 fallback list

**Контекст:** в Block D эмодзи в UI заменены на иллюстрации из Assets.xcassets.
Для эмодзи без точного аналога в текущих 154 imageset'ах применён ближайший
существующий fallback. Этот файл — список illustrations, которые желательно
догенерировать (icon-generator/FLUX) для повышения визуальной точности.

**Приоритет:** P3 (post-v1.0). Текущие fallback'и работоспособны.

---

## Animals (нужны новые)

| Emoji | Word (ru) | illustrationName (target) | Текущий fallback | Где используется |
|-------|-----------|---------------------------|------------------|------------------|
| 🐍 | змея | `word_snake` | `word_fish` | VisualAcoustic, Memory, Rhythm |
| 🐝 | пчела | `word_bee` | `word_butterfly_insect` | WorldMap, VisualAcoustic |
| 🐐 | коза | `word_goat` | `word_cow` | StoryCompletion, Sorting |
| 🐢 | черепаха | `word_turtle` | `word_frog` | Settings avatars |
| 🐌 | улитка | `word_snail` | `word_butterfly_insect` | Sorting |
| 🦓 | зебра | `word_zebra` | `word_hare` | PuzzleReveal, ARStoryQuest |
| 🦢 | цапля | `word_heron` | `word_bird` | PuzzleReveal, Memory |
| 🦟 | комар | `word_mosquito` | `word_butterfly_insect` | VisualAcoustic |
| 🐤 / 🐣 | цыплёнок | `word_chick` | `word_hen` | NarrativeQuest, VisualAcoustic |
| 🐉 | дракон | `word_dragon` | `reward_brave_heart` | Family avatars |
| 🦁 | лев | `word_lion` | `reward_champion` | Settings avatars |
| 🐼 | панда | `word_panda` | `word_bear` | Settings avatars |
| 🐺 | волк | `word_wolf` | `word_fox` | (если используется) |

## Objects (нужны новые)

| Emoji | Word (ru) | illustrationName (target) | Текущий fallback | Где используется |
|-------|-----------|---------------------------|------------------|------------------|
| ✈️ | самолёт | `word_plane` | `word_kite` | PuzzleReveal, Rhythm |
| 🌰 | жёлудь | `word_acorn` | `word_apple` | StoryLibrary (defer) |
| 🌬️ | ветер | `word_wind` | `word_flower` | StoryLibrary (defer) |
| 🧃 | сок | `word_juice` | `word_cup` | Sorting |
| 🦷 | зуб | `word_tooth` | `word_bag` (generic) | RepeatAfterModel |
| 🥣 | миска | `word_bowl` | `word_cup` | MinimalPairs |
| 🧥 | куртка | `word_jacket` | `word_bag` (generic) | MinimalPairs |
| 🌀 | спираль | `word_spiral` | `word_flower` (decorative) | MinimalPairs |
| 🧲 | магнит | `word_magnet` | `word_bag` | Memory |
| 🍊 | апельсин | `word_orange_fruit` | `word_apple` | Memory |
| 💰 | монеты | `word_coins` | `reward_gold_star` | NarrativeQuest |
| 🐚 | ракушка | `word_shell` | `reward_diamond` | WorldMap |

## Notes
- Все fallback'и помечены в коде комментарием `// FALLBACK: emoji <X>` для будущей замены.
- Регенерация — через icon-generator agent с FLUX prompt'ами в стиле проекта (см. existing word_* assets).
- Целевой стиль: 1024×1024 PNG RGBA, transparent background, kid-friendly cartoon, сохраняет визуальный язык текущих word_* illustrations.
