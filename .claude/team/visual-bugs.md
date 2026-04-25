# M12 Visual Bugs Report — HappySpeech v1.0.0

## Дата: 2026-04-25

## Окружение
- Симулятор: iPhone 17 Pro (iOS 26.4)
- Конфигурация: Debug
- Скриншотов сделано: 17 (light + dark mode)

---

## Скриншоты

| Файл | Экран |
|---|---|
| `01_splash.png` | SplashView — первый кадр (background only) |
| `02_auth.png` | SplashView — с логотипом и анимацией загрузки |
| `03_auth_signin.png` | AuthSignInView (light mode) |
| `03_auth_dark.png` | AuthSignInView (dark mode) |
| `04_demoMode.png` | DemoModeView — шаг 1 из 15 |
| `05_roleSelect.png` | RoleSelectView — выбор профиля |
| `06_onboarding.png` | OnboardingFlowView — шаг 1 из 7 |
| `07_parentHome.png` | ParentHomeView — пустое состояние |
| `08_settings.png` | SettingsView |
| `09_offlineState.png` | OfflineStateView |
| `10_childHome.png` | ChildHomeView (light mode) |
| `10_childHome_dark.png` | ChildHomeView (dark mode) |
| `11_progressDashboard.png` | ProgressDashboardView — КРАШ (показан Home Screen) |
| `12_rewards.png` | RewardsView |
| `13_worldMap.png` | WorldMapView |
| `14_sessionHistory.png` | SessionHistoryView |
| `15_sessionComplete.png` | SessionCompleteView |

---

## Найденные проблемы

### КРИТИЧЕСКИЕ (блокируют запуск / показ экрана)

| # | Экран | Проблема | Причина | Приоритет |
|---|---|---|---|---|
| 1 | Запуск приложения | **CRASH при старте**: `Library not loaded: @rpath/RiveRuntime.framework` | Xcode кладёт `RiveRuntime.framework` в `Frameworks/` бандла, но `@rpath` бинарника прописывает `PackageFrameworks/`. dyld не находит фреймворк. Workaround: скопировать в `PackageFrameworks`. Постоянное исправление: добавить `@executable_path/Frameworks` в `LD_RUNPATH_SEARCH_PATHS` в Build Settings. | **Critical** |
| 2 | Запуск приложения | **CRASH при старте**: `+[FIRApp addAppToAppDictionary:]` SIGABRT | `GoogleService-Info.plist` содержит плейсхолдеры (`REPLACE_WITH_*`). Firebase бросает NSException. **Исправлено в рамках M12** — добавлена проверка в `HappySpeechApp.init()`. | **Critical (исправлен)** |
| 3 | ProgressDashboard | **CRASH** при открытии: `RLMRealm beginWriteTransaction` SIGABRT | Realm не успевает инициализироваться (`bootstrapApp()` асинхронный) до того как ProgressDashboardView пытается открыть write-транзакцию. Race condition. | **Critical** |

### СРЕДНИЕ (визуальный дефект, но экран работает)

| # | Экран | Проблема | Приоритет |
|---|---|---|---|
| 4 | ChildHome (light + dark) | **Маскот не рендерится**: большая пустая серая/белая область вверху вместо анимированного маскота Ляли | **High** |
| 5 | SplashView | При быстром захвате скриншота (первые ~200ms) экран — просто красный фон без логотипа. Реально это артефакт анимации (`titleOpacity=0`, `mascotScale=0.3`), но первое впечатление — blank screen | **Medium** |
| 6 | AuthSignInView dark mode | Кнопка "Войти" имеет тёмно-коричневый фон с текстом → низкий контраст (WCAG AA не пройден визуально) | **Medium** |
| 7 | OfflineState | Текст локализации `offline.auto_retry.2` показан как ключ вместо перевода | **Medium** |
| 8 | SessionComplete | Нижний блок "Следующее занятие" обрезан снизу (нет bottom padding / scroll) | **Low** |
| 9 | Rewards | Таб-бар обрезает часть текста `Живот...` (таб "Животные") — слово не помещается | **Low** |

### НИЗКИЕ (косметика / технический долг)

| # | Экран | Проблема | Приоритет |
|---|---|---|---|
| 10 | Все экраны | SwiftLint: 1 365 ошибок (`--strict`). Основные категории: `identifier_name`, `comma`, `sorted_imports`, `empty_count` | **Low** |
| 11 | Content/Seed | 21 JSON-файл seed контента имеют 0 упражнений (`items: []`) — контент не заполнен | **Low** |
| 12 | ParentHome | Аватар ребёнка — пустой серый круг "0 лет" — demo-данные не подставляются | **Low** |

---

## Экраны без проблем (ОК)

- RoleSelectView — чистый, читаемый, правильная навигация
- OnboardingFlowView — корректный прогресс-индикатор, текст Ляли
- SettingsView — все секции отображаются, переключатели работают
- WorldMapView — карточки звуков с процентами, кнопки страйк/стрик
- SessionHistoryView — список с датами и процентами, читаемый
- DemoModeView — тур по приложению, шаги 1 из 15

---

## Технические баги (runtime, не визуальные)

| Баг | Описание |
|---|---|
| RiveRuntime rpath | `@rpath` в бинарнике указывает на `PackageFrameworks/`, но фреймворк копируется в `Frameworks/`. Нужно: `LD_RUNPATH_SEARCH_PATHS += @executable_path/Frameworks` |
| Firebase placeholder | `GoogleService-Info.plist` = шаблон без реальных ключей. Добавлен guard в `HappySpeechApp.init()`. |
| Realm race condition | `ProgressDashboardView` обращается к Realm до `realmActor.open()`. Нужен `isLoading` стейт или `@State var isRealmReady`. |

---

## Итог

- Скриншотов сделано: 17
- Экранов охвачено: 15 (из 17 роутов в AppCoordinator)
- Критических багов: 3 (2 краша при запуске, 1 краш ProgressDashboard)
- Средних: 6
- Низких: 3
- **Общая оценка: Needs fixes**

### Приоритет исправлений перед диплом-защитой

1. `LD_RUNPATH_SEARCH_PATHS` — добавить `@executable_path/Frameworks` в Build Settings
2. Realm race condition в ProgressDashboard — добавить guard на готовность Realm
3. Маскот (HSMascotView) — проверить наличие `lyalya.riv` в бандле и fallback-рендер
4. Ключ локализации `offline.auto_retry.2` — добавить в `Localizable.xcstrings`
5. Контраст кнопки "Войти" в dark mode — проверить `ColorTokens`

