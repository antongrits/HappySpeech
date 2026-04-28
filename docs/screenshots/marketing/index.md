# HappySpeech — Marketing Screenshots

Курированный набор hero screenshots для дипломной защиты, README и App Store metadata.

Снято 2026-04-28 на симуляторах iPhone SE (3rd generation, 4.7", iOS 18.x) и iPhone 17 Pro (6.3", iOS 18.x).

## Hero Set

| # | Сцена | iPhone SE 3rd gen (375x667) | iPhone 17 Pro (393x852) | Описание |
|---|---|---|---|---|
| 01 | ChildHome | [01_childhome_se.png](01_childhome_se.png) | [11_child_home.png](../11_child_home.png) | Главный экран ребёнка с маскотом Лялей, миссия дня, достижение |
| 02 | LessonPlayer | [02_lesson_player_se.png](02_lesson_player_se.png) | [15_sessionComplete.png](../15_sessionComplete.png) | Завершение сессии — 3 звезды, результат точности |
| 03 | AR Mirror | [03_ar_mirror_se.png](03_ar_mirror_se.png) | — | AR-зона, 2D fallback с радугой (17 Pro версия не снята) |
| 04 | WorldMap | [04_worldmap_se.png](04_worldmap_se.png) | [13_worldMap.png](../13_worldMap.png) | Карта прогресса — выбор звуковой группы |
| 05 | SoundMap | [05_soundmap_se.png](05_soundmap_se.png) | — | История сессий, SoundMap fallback (17 Pro версия не снята) |
| 06 | Progress Dashboard | [06_progress_dashboard_se.png](06_progress_dashboard_se.png) | [16_parent_home.png](../16_parent_home.png) | ParentHome — прогресс (Swift Charts); 17 Pro версия в empty state |
| 07 | Rewards | [07_reward_se.png](07_reward_se.png) | [12_rewards.png](../12_rewards.png) | Мои награды — стикеры и звёзды |
| 08 | Specialist | [08_specialist_se.png](08_specialist_se.png) | — | RoleSelect (Логопед/Родитель/Ребёнок); 17 Pro версия показывает Auth редирект |
| 09 | Demo | [09_demo_se.png](09_demo_se.png) | [04_demoMode.png](../04_demoMode.png) | Demo walkthrough с Лялей — GuidedTour шаг 1 из 15 |
| 10 | Story Quest | [10_story_quest_se.png](10_story_quest_se.png) | [02_onboarding_welcome.png](../02_onboarding_welcome.png) | Анимированная история — онбординг с Лялей |

**Совпадений iPhone 17 Pro:** 6 из 10 (сцены 01, 02, 04, 06, 07, 09, 10 = 7 файлов; 06 — empty state, не hero-качество).

## Технические параметры

- **iPhone SE (3rd generation):** 375x667 pt x 2x = 750x1334 px native
- **iPhone 17 Pro:** 393x852 pt x 3x = 1179x2556 px native
- **Format:** PNG, sRGB, 76–152 KB / file (SE), 100–170 KB / file (17 Pro)
- **Capture:** `xcrun simctl io <device> screenshot` (DISABLE_RIVE=1 для стабильности)
- **SE capture date:** 2026-04-28 (agent ios-debugger a86892f2bed6127bc)
- **17 Pro capture date:** 2026-04-26 (Sprint 11)

## Что доснять в S13

| Сцена | Проблема | Действие |
|---|---|---|
| AR Mirror (17 Pro) | Rive crash при capture | Снять с DISABLE_RIVE=1 после fix |
| SoundMap (17 Pro) | Не снято | Снять на iPhone 17 Pro sim |
| Specialist (17 Pro) | Auth редирект без авторизации | Снять в авторизованной сессии |
| Progress Dashboard (17 Pro) | Empty state (0 лет, нет занятий) | Сидировать тестовые данные, переснять |

## App Store требования к скриншотам

App Store требует минимум 1 скриншот для каждого поддерживаемого размера экрана:

- iPhone 6.9" (iPhone 17 Pro / 16 Pro Max) — 1320x2868 px
- iPhone 6.7" (iPhone 16 Plus) — 1290x2796 px
- iPhone 5.5" (iPhone SE context) — минимально 621x1104 px

Текущие SE скриншоты (750x1334 px) покрывают 4.7" требование.
Для submission проверь размеры через `sips -g pixelWidth -g pixelHeight docs/screenshots/marketing/*.png`.

## Использование

- **README.md** — hero банер + features matrix (секция Screenshots)
- **App Store metadata** (`docs/appstore-metadata.md`) — listing screenshots
- **Дипломная презентация** (`docs/diploma-presentation.md`) — slides demo flow

## Связанные документы

- [README.md](../../../README.md) — production status, архитектура, статистика
- [appstore-metadata.md](../../appstore-metadata.md) — App Store listing (S12-019)
- [diploma-presentation.md](../../diploma-presentation.md) — структура дипломной защиты (S12-023)
- [../index.md](../index.md) — полный набор 43 iPhone 17 Pro скриншотов (Sprint 11)
