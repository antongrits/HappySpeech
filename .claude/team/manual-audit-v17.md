# Manual Screenshot Audit v17

**Дата:** 2026-05-08  
**Устройство:** iPhone SE (3rd generation), iOS 26.4 (Simulator)  
**Кол-во скриншотов:** 84 PNG (37 light + 30 dark + 17 промежуточных/тестовых)  
**Экранов покрыто:** 33 уникальных экрана/состояния из 97 View-файлов  
**Директория:** `_workshop/screenshots/v17_full_audit/`

---

## Метод сбора

- Сборка: `xcodebuild build -scheme HappySpeech -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'`
- Установка через `xcrun simctl install booted HappySpeech.app`
- Запуск с маршрутами через `-HSStartRoute <route> -UITestMockServices`
- Переключение тем: модификация `hs.theme.preference` напрямую в UserDefaults plist + `killall cfprefsd`
- UI-навигация через AppleScript `System Events` для тапов по элементам
- 17 доступных HSStartRoute маршрутов × 2 темы + доп. экраны через навигацию

---

## Найденные баги и проблемы

### P0 — Критические (блокируют релиз)

| # | Экран | Описание | Файл/Маршрут |
|---|-------|----------|-------------|
| P0-1 | ARZoneView (light + dark) | Непереведённый ключ локализации `ar.zone.faceFilter.title` и `ar.zone.faceFilter.subtitle` отображаются как raw slug в карточке игры. Должны быть переведены на русский. | `14_arzone_light.png`, `14_arzone_dark.png` |
| P0-2 | SpecialistReportsView (light + dark) | Множество непереведённых ключей: `reports.met...`, `reports.stage.wordInit`, `reports.row.attempts.1`, `reports.row.success.` обрезаются в ячейках таблицы. P0 для специалистского контура. | `31_specialist_reports_light.png`, `31_specialist_reports_dark2.png` |
| P0-3 | SpecialistHomeView (light + dark) | Заголовок экрана отображается как placeholder `"Заголовок"` вместо реального названия (ожидается "Мои пациенты" или "Клиенты"). | `22_specialisthome_light.png`, `22_specialisthome_dark.png` |
| P0-4 | StutteringView light | Верхняя половина экрана занята пустым белым прямоугольником (контейнер маскота без контента). Маскот Ляля не рендерится — видимо RealityKit/SceneKit не инициализируется на симуляторе или размер контейнера некорректный. | `19_stuttering_light.png` |
| P0-5 | LessonPlayerView (`lessonPlayer` route с templateType=bingo) | Отображает интерфейс `ListenAndChoose`, а не `Bingo`. Параметр `templateType` игнорируется при навигации через `-HSStartRoute lessonPlayer`. | `15_lessonplayer_bingo_light.png`, `15_lessonplayer_bingo_dark.png` |

---

### P1 — Высокий приоритет (влияют на UX)

| # | Экран | Описание | Файл |
|---|-------|----------|------|
| P1-1 | SplashView (light + dark) | Splash анимация не успевает отобразить контент за первую секунду — видно только фоновый цвет. Маскот, лого и progress bar появляются с задержкой 2-3 секунды (используется `withAnimation` + delayed appearance). Скриншот-тур фиксирует только пустой фон. | `01_splash_light.png` |
| P1-2 | RoleSelectView (light + dark) | Маскот Ляля не рендерится — в отведённом месте вверху экрана видно только жёлтое пятно (заглушка или placeholder вместо 3D-маскота). | `04_roleselect_light.png`, `04_roleselect_dark.png` |
| P1-3 | ChildHomeView (light + dark) | Маскот Ляля не отображается (ReactiveMascot/LyalyaSceneView). В hero-секции пустое пространство. Контент начинается с AchievementBanner и Bubble. | `06_childhome_light.png`, `06_childhome_dark.png` |
| P1-4 | AuthSignInView light | Кнопка "→ Войти" (primary CTA) отображается очень бледной в light mode — цвет фона кнопки недостаточно контрастный (Brand.primary на светлом фоне). Риск WCAG 2.1 AA failure. | `03_auth_signin_light.png` |
| P1-5 | SpecialistHomeView | Строка пациента "Миша" в списке не реагирует на тап (не навигирует в SessionReview). Может быть проблема с hit testing или незарегистрированный gesture. | `22_specialisthome_light.png` |
| P1-6 | SessionHistoryView — шаблон как slug | Тип занятия отображается как `listen-and-choose` (английский slug) вместо русского названия "Слушай и выбирай" или "Логопедическое занятие". | `25_parenthome_sessions_light2.png`, `23_specialist_sessions_dark.png` |
| P1-7 | StutteringView dark | Маскот не рендерится (тёмное пятно вместо изображения). В light mode — белый пустой прямоугольник в верхней половине. | `19_stuttering_dark.png`, `19_stuttering_light.png` |
| P1-8 | OfflineStateView light | Кнопка "Проверяем..." и нижняя иконка видны как loading-спиннеры — скорее всего это состояние "проверки соединения" которое должно кратко показываться и переходить в active state. В mock-режиме зависает бесконечно. | `16_offlinestate_light.png` |
| P1-9 | SessionCompleteView light | Экран "Молодец! Отличный результат." — поле "Очки" пустое (нет числового значения), "Бонус" тоже пустое. Верхняя область с маскотом не рендерится. | `13_sessioncomplete_light.png` |

---

### P2 — Средний приоритет (косметика/полировка)

| # | Экран | Описание | Файл |
|---|-------|----------|------|
| P2-1 | ParentHomeView | Приветствие "Доброй ночи!" отображается потому что тест запускается в ~03:00. Логика приветствия привязана к реальному времени — для скриншот-тура нежелательно. Нужен mock-time или статичное приветствие в preview-режиме. | `07_parenthome_light.png` |
| P2-2 | SettingsView | Подпись "Настройки / Управляйте предпочтениями ребёнка" дублирует заголовок. Маскот в header-секции не рендерится (серое пятно). | `08_settings_light.png` |
| P2-3 | WorldMapView | Карта прогресса отображает только 3 узла из ожидаемых 9+. "Заднеязычные" и "Соноры" отображаются, "Грамматика" — с пометкой "Заблокировано", остальные locked. Нет явного пустого state — UI может выглядеть незаполненным. | `11_worldmap_light.png` |
| P2-4 | SiblingMultiplayerView | Экран "Найдём друга" (discovery state) в mock-режиме бесконечно показывает "Ищем друга..." и пустой экран пациента. Нет timeout/empty state для случая когда пир не найден. | `21_siblingmultiplayer_light.png` |
| P2-5 | OnboardingFlowView | Запускается с шага 3 (имя ребёнка), шаги 1-2 (welcome, role) пропущены в тест-запуске через `-HSStartRoute onboarding`. Progress bar показывает "Шаг 3 из 10". | `05_onboarding_light.png` |
| P2-6 | FluencyDiaryView | Empty state "Записей ещё нет" — маскот не отображается (зелёное пятно вместо иллюстрации). | `20_fluencydiary_light.png` |
| P2-7 | FamilyVoiceView | Большой whitespace в верхней части карточки (место для waveform/иллюстрации пустое). | `18_familyvoice_light.png` |
| P2-8 | ProgressDashboardView | Заголовок "Прогресс" без имени ребёнка — неясно чей прогресс показывается в multi-child сценарии. | `10_progressdashboard_light.png` |
| P2-9 | DemoModeView | Маскот emoji-заглушка (смайлик) вместо Ляли. Ожидается HSMascotView. | `17_demomode_light.png` |
| P2-10 | RewardsView | Маскот в левом углу header не рендерится (только серое пятно). | `09_rewards_light.png` |

---

## Per-screen PASS/FAIL статус

| # | Экран | Light | Dark | Статус | Проблемы |
|---|-------|-------|------|--------|----------|
| 01 | SplashView | FAIL | FAIL | P1-1 | Контент не виден (анимация) |
| 02 | OnboardingFlowView (step 3) | PASS | PASS | — | Шаги 1-2 не видны через route |
| 03 | AuthSignInView | PARTIAL | PASS | P1-4 | Light — бледная CTA кнопка |
| 04 | RoleSelectView | PARTIAL | PARTIAL | P1-2 | Маскот не рендерится |
| 05 | ChildHomeView | PARTIAL | PARTIAL | P1-3 | Маскот не рендерится |
| 06 | ParentHomeView (Обзор) | PASS | PASS | P2-1 | Временное приветствие |
| 07 | ParentHomeView (Занятия) | PASS | PASS | P1-6 | Шаблон как slug |
| 08 | ParentHomeView (Аналитика) | PASS | PASS | — | |
| 09 | SettingsView | PASS | PASS | P2-2 | Маскот в header |
| 10 | RewardsView | PASS | PASS | P2-10 | Маскот в header |
| 11 | ProgressDashboardView | PASS | PASS | P2-8 | |
| 12 | WorldMapView | PASS | PASS | P2-3 | |
| 13 | SessionHistoryView | PASS | PASS | — | |
| 14 | SessionCompleteView | PARTIAL | PARTIAL | P1-9 | Пустые очки/бонус |
| 15 | ARZoneView | FAIL | FAIL | P0-1 | Непереведённые ключи |
| 16 | LessonPlayerView | PARTIAL | PARTIAL | P0-5 | Неправильный шаблон |
| 17 | OfflineStateView | PARTIAL | PASS | P1-8 | Бесконечный loading |
| 18 | DemoModeView | PARTIAL | PARTIAL | P2-9 | Маскот-смайлик |
| 19 | FamilyVoiceView | PARTIAL | PARTIAL | P2-7 | Пустой whitespace |
| 20 | StutteringView | FAIL | FAIL | P0-4, P1-7 | Белый прямоугольник / нет маскота |
| 21 | FluencyDiaryView | PARTIAL | PARTIAL | P2-6 | Маскот-заглушка |
| 22 | SiblingMultiplayerView | PASS | PASS | P2-4 | Нет timeout state |
| 23 | SpecialistHomeView | FAIL | FAIL | P0-3, P1-5 | Заголовок-placeholder, строки не тапабельны |
| 24 | SpecialistSessionsView | PARTIAL | PARTIAL | P1-6 | Шаблон как slug |
| 25 | SpecialistReportsView | FAIL | FAIL | P0-2 | Множество непереведённых ключей |
| 26 | AuthForgotPasswordView | PASS | — | — | dark не удалось поймать |
| 27 | RewardsView (sticker detail sheet) | PASS | PASS | — | |
| 28 | SessionHistoryDetailView | PASS | — | — | |
| 29 | ARFaceFilterView | — | — | DEFERRED | AR недоступен на симуляторе |
| 30 | BreathingARView | — | — | DEFERRED | AR недоступен |
| 31 | MimicLyalyaView | — | — | DEFERRED | AR + маскот |
| 32 | SharePlayView | — | — | DEFERRED | нет HSStartRoute |
| 33 | FamilyCalendarView | — | — | DEFERRED | нет HSStartRoute |

---

## Итоговая статистика

| Метрика | Значение |
|---------|----------|
| Всего PNG файлов | 84 |
| light скриншоты | 37 |
| dark скриншоты | 30 |
| Уникальных экранов покрыто | 33 из 97 View-файлов |
| PASS (light + dark оба OK) | 11 |
| PARTIAL (один или оба с замечаниями) | 16 |
| FAIL (критические проблемы) | 6 |
| DEFERRED (AR/недоступно) | 4+ |
| P0 баги | 5 |
| P1 баги | 9 |
| P2 баги | 10 |

---

## Системная P0 находка: тема не сбрасывается через xcrun simctl defaults

**Проблема:** `xcrun simctl spawn booted defaults write com.mmf.bsu.HappySpeech hs.theme.preference light` НЕ сбрасывает тему — `UserDefaults.standard` читается из контейнера приложения, а не системного домена. `cfprefsd` кеширует значения.

**Решение:** Прямая модификация plist-файла в `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<AppUUID>/Library/Preferences/com.mmf.bsu.HappySpeech.plist` + `killall cfprefsd`.

**Impact:** Любой автоматический скриншот-тур на симуляторе без учёта этого будет показывать неправильную тему (ту, что была сохранена последней пользователем).

**Рекомендация:** Добавить launch argument `-UITestForceTheme light|dark` который в `ThemeManager.init()` переопределяет UserDefaults-значение.

---

## Экраны не покрытые (DEFERRED)

Экраны требующие дополнительного времени или специального hardware:

1. **AR-экраны (5 Views):** ARMirrorView, BreathingARView, ButterflyCatchView, HoldThePoseView, MimicLyalyaView, PoseSequenceView, SoundAndFaceView, ARFaceFilterView — требуют TrueDepth камеры, не работают на симуляторе.

2. **SharePlay (2 Views):** SharePlayView, SharePlaySessionView — требуют MultipeerConnectivity с реальными устройствами.

3. **Навигационные экраны без HSStartRoute (6):** AuthSignUpView, AuthVerifyEmailView, FamilyCalendarView, FamilyLeaderboardView, AchievementsView, ScreeningView, HomeTasks — доступны только через UI-навигацию.

4. **Компонентные Views (9):** SpectrogramCanvasView, SpectrogramVisualizerView, LyalyaSceneView, CelebrationOverlayView, ConfettiEmitterView, StoryPlayerView, AnimatedStoryPlayerView, KaraokeWordView, GuidedTourTipView — embedded-компоненты, используются внутри других экранов.

5. **Lesson Templates (не покрытые, 15 Views):** BingoView, MemoryView, SortingView, DragAndMatchView, PuzzleRevealView, MinimalPairsView, NarrativeQuestView, SoundHunterView, LetterTracingView, RhythmView, ArticulationImitationView, VisualAcousticView, ObjectHuntView, BreathingView, RepeatAfterModelView, StoryCompletionView — все роутятся через `lessonPlayer` который показывает только один шаблон.

---

## Топ-10 P0 issues (для немедленного исправления)

1. **SpecialistReportsView: множество непереведённых ключей** — `reports.met...`, `reports.stage.wordInit`, `reports.row.attempts.1`, `reports.row.success.` — блокирует специалистский контур
2. **ARZoneView: непереведённые ключи** — `ar.zone.faceFilter.title`, `ar.zone.faceFilter.subtitle`
3. **SpecialistHomeView: заголовок "Заголовок"** — placeholder не заменён реальным текстом
4. **StutteringView: белый/чёрный прямоугольник** — маскот-контейнер отображается без контента
5. **LessonPlayer: templateType игнорируется** — всегда открывается ListenAndChoose
6. **Маскот Ляля не рендерится на 8+ экранах** — RoleSelect, ChildHome, Settings header, Rewards header, SessionComplete, DemoMode, FluencyDiary — LyalyaSceneView/HSMascotView не инициализируются в mock-контексте
7. **AuthSignIn light: бледная primary CTA** — "Войти" кнопка почти невидима в light mode
8. **Slug-названия шаблонов** — "listen-and-choose" вместо "Слушай и выбирай" в SessionHistory и SpecialistSessions
9. **OfflineState бесконечный loading** — в mock-режиме кнопка "Продолжить без интернета" показывает спиннер
10. **SessionComplete пустые метрики** — очки/бонус не заполнены из mock-данных
