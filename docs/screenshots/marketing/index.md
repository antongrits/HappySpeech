# Marketing Screenshots — HappySpeech

> M11.3 — Кураторский отбор hero screenshots для App Store и диплома  
> Дата: 2026-04-26  
> Исполнитель: pm

Исходные файлы — `docs/screenshots/`. Итого скриншотов в туре: 43 (iPhone 17 Pro).  
Для iPhone SE скриншоты не сняты (Rive crash блокировал live capture) — S13.

## Отобранные hero screenshots (10 iPhone 17 Pro)

| Позиция | Файл (источник) | Экран | Качество |
|---------|----------------|-------|---------|
| 01 | `../01_splash.png` | Splash — брендовый экран "HappySpeech / Говорим волшебно" | Отличное |
| 02 | `../02_onboarding_welcome.png` | Онбординг — Привет! Я Ляля (шаг 1 из 10) | Отличное |
| 03 | `../11_child_home.png` | Детский главный экран — миссия дня, достижение | Отличное |
| 04 | `../10_childHome_dark.png` | Детский главный экран — dark mode | Отличное |
| 05 | `../13_worldMap.png` | Карта миров — выбор звуковой группы | Отличное |
| 06 | `../12_rewards.png` | Мои награды — стикеры и звёзды | Отличное |
| 07 | `../15_sessionComplete.png` | Завершение сессии — 3 звезды, результат | Отличное |
| 08 | `../04_demoMode.png` | Demo / GuidedTour — Ляля показывает экраны | Хорошее |
| 09 | `../08_settings.png` | Настройки — тема, профиль, напоминания | Хорошее |
| 10 | `../09_offlineState.png` | Offline state — работает без интернета | Хорошее |

## Не вошли (причина)

| Файл | Причина |
|------|---------|
| `16_parent_home.png` | Mock data: "0 лет", empty state "Занятий пока нет" |
| `17_specialist_home.png` | Показывает Auth экран (redirect без авторизации) |
| `07_ar_zone.png` | Показывает Auth экран вместо AR |
| `15_session_complete.png` | Дублирует `15_sessionComplete.png`, кольцо точности пустое |

## Что нужно доснять в S13

- ChildHome с реальными данными (ребёнок с историей занятий)
- LessonPlayer — хотя бы 3 типа игр (ListenAndChoose, DragAndMatch, Memory)
- AR Zone (после фикса Rive)
- ParentHome с populated данными (streak, charts)
- 10 скриншотов на iPhone SE (3rd gen, 375pt) — для App Store требований
- Screening экран
- Specialist tools

## App Store требования к скриншотам

App Store требует минимум 1 скриншот для каждого поддерживаемого размера экрана:
- iPhone 6.9" (iPhone 17 Pro / 16 Pro Max) — 1320×2868px
- iPhone 6.7" (iPhone 16 Plus) — 1290×2796px  
- iPhone 5.5" (iPhone SE context) — минимально 621×1104px

Текущие скриншоты сняты в симуляторе iPhone 17 Pro при нативном разрешении.
Для submission потребуется проверить соответствие размеров через `sips -g pixelWidth -g pixelHeight`.
