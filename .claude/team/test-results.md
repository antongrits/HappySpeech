# Test Results — HappySpeech

**Последнее обновление:** 2026-04-27  
**QA агент:** ios-debugger  

---

## M10.1 v9 Coverage Report (2026-04-28)

**Дата:** 2026-04-28
**Инструмент:** xcrun xccov (xcresult: `_workshop/coverage/result_v9.xcresult`)
**Симулятор:** iPhone 17 Pro
**Цель:** aggregate Interactors+Presenters ≥70%, Combined ViewModels+Services ≥90% (объяснённые пробелы задокументированы)

### Покрытие по ключевым файлам (до / после v9)

| Файл | До v9 | После v9 |
|---|---|---|
| SettingsInteractor | 29.6% | 84.7% |
| SettingsPresenter | 15.2% | 99.0% |
| SessionReviewInteractor | 25.4% | 88.9% |
| ChildHomeInteractor | 68.8% | 92.1% |
| HomeTasksInteractor | 59.3% | 94.7% |

### Aggregate

| Группа | До v9 | После v9 |
|---|---|---|
| Interactors + Presenters | 56.5% | 64.3% |
| Services | 23.2% | 23.5% |
| Combined ViewModels + Services | 51.2% | 57.8% |

### Добавленные тестовые файлы

| Файл | Новых тестов |
|---|---|
| `HappySpeechTests/Unit/Features/SettingsPresenterTests.swift` (NEW) | 39 |
| `HappySpeechTests/Unit/Interactors/SettingsInteractorTests.swift` (расширен с 10 до 28) | +18 |
| `HappySpeechTests/Unit/Features/SessionReviewInteractorTests.swift` (расширен +24) | +24 |
| `HappySpeechTests/Unit/Interactors/HomeTasksInteractorTests.swift` (расширен с 8 до 17) | +9 |
| `HappySpeechTests/Unit/Interactors/ChildHomeInteractorTests.swift` (расширен с 3 до 15) | +12 |
| **Итого новых тестов** | **102** |

### Explained gaps (объяснённые непокрытые зоны)

Следующие файлы не покрыты тестами по техническим причинам — не баги QA, а объективные ограничения:

| Файл / Класс | Причина |
|---|---|
| `ARSessionService`, `FaceAnalysisService` | ARKit Face Tracking требует TrueDepth камеры — недоступно в симуляторе |
| `ARMirrorInteractor.updateFrame(_:)` | Живые AR-кадры (CVPixelBuffer) — только физическое устройство |
| `LiveAuthService` | Firebase Auth — требует Firebase Emulator (не настроен в CI) |
| `LiveSyncService` | Firestore — требует Firebase Emulator |
| `WhisperKitModelManager` (inference) | Neural Engine — только физическое устройство, не симулятор |
| `LLMModelManager` (загрузка) | Сетевые запросы к HuggingFace — заблокированы в test runner |
| `ClaudeAPIClient` | Живые HTTP-запросы к Anthropic API |
| `NotificationServiceLive.requestPermission` | Системный диалог разрешений — недоступен в XCTest |
| `AVCaptureDevice` permission prompts | Аналогично — системные диалоги |
| `AudioAnalysisService` (AVAudioEngine live tap) | Требует аудио-устройство — симулятор без mic input |

### Статус Sprint 12

- S12-009 P1: Unit тесты ListenAndChooseInteractor, RepeatAfterModelInteractor, SortingInteractor — ранее покрыты (M10.1)
- S12-010 P1: BingoInteractor, MemoryInteractor — покрыты; SyncService, AdaptivePlannerService — explained gap (Firebase/CoreData)
- S12-011 P2: LLMDecisionServiceTests — explained gap (network)
- Unit coverage Interactors: **64.3%** (цель 70% — не достигнута, ближайшие кандидаты: BreathingInteractor 54.6%, RhythmInteractor 41.3%)

---

## M10.1 v9 Batch 2 Coverage Report (2026-04-28)

**Дата:** 2026-04-28  
**Инструмент:** xcrun xccov (xcresult: `_workshop/coverage/result.xcresult`)  
**Симулятор:** iPhone 17 Pro  
**Цель батча:** Combined ViewModels+Services ≥75%

### Покрытие по файлам батча 2 (до / после)

| Файл | До батча 2 | После батча 2 | +новых тестов |
|---|---|---|---|
| `BreathingInteractor.swift` | 54.6% | 58.8% | +17 (в Features/BreathingInteractorTests.swift) |
| `RhythmInteractor.swift` | 41.3% | 46.2% | +13 (в Games/RhythmInteractorTests.swift) |

### Добавленные тестовые файлы

| Файл | Что изменено | Новых тестов |
|---|---|---|
| `HappySpeechTests/Unit/Features/BreathingInteractorTests.swift` | Расширен (добавлены секции 9: advanceTutorial, cancel, submitAttempt, scoring edge cases, scene totalPetals, objectScale midpoint, normalise edge cases) | +17 |
| `HappySpeechTests/Games/RhythmInteractorTests.swift` | Расширен (добавлены секции 9: hissing, indexWraps, diffTwo, beatsWasHit, noCurrentPattern, nextPatternLastPattern, complete scoring, cancel, allPatternsNonEmpty, lowercase mapping, unknown mapping, pushRMS edge cases) | +13 |
| **Итого батч 2** | | **+30** |

### Aggregate батч 2

| Группа | Батч 1 | Батч 2 |
|---|---|---|
| Interactors + Presenters | 64.3% | 64.3%* |
| Services | 23.5% | 23.5% |
| Combined | 57.8% | ~58.5% (est.) |

*Aggregate пересчитан из полного xcresult, включающего все предыдущие тесты + батч 2. Прирост BreathingInteractor +4.2ppt, RhythmInteractor +4.9ppt.

### Explained gaps батча 2 (новые)

| Файл | Зона | Причина |
|---|---|---|
| `BreathingInteractor.startWarmUp()` | AVAudioEngine tap installation | Требует live microphone — симулятор без mic input |
| `BreathingInteractor.scheduleProgressTimer()` | Timer tick race | Таймер-тик флейки в unit-тестах без RunLoop; тестируем через `_test_forceState` |
| `RhythmInteractor.startRecord()` | AVAudioEngine + tap installation | Живой audioEngine не стартует в симуляторе без mic |
| `RhythmInteractor.playPattern()` | TTS + Task.sleep | AVSpeechSynthesizer + async sleep = объяснённый gap |
| `RhythmInteractor.scheduleRecordingTimer()` | Timer cadence | Аналогично BreathingInteractor — Timer флейки |

### Следующие приоритеты (батч 3)

По coverage report, топ некрытых Interactors/Presenters:
1. `RhythmPresenter.swift` 22.8% (71 uncovered/92) — testable rendering logic
2. `DragAndMatchPresenter.swift` 23.4% (36/47) — testable
3. `PuzzleRevealPresenter.swift` 24.4% (62/82) — testable
4. `VisualAcousticPresenter.swift` 25.2% (77/103) — testable
5. `ArticulationImitationInteractor.swift` 38.6% (97/158) — state machine testable
6. `ARZoneInteractor.swift` 45.0% (94/171) — ARKit live = explained gap, но scoring/state testable

---

## Screenshot Tour M10.7

**Дата:** 2026-04-27  
**Симулятор:** iPhone 17 Pro (8B5BFF2B-304B-4F40-ADF2-A770E4D9E1F1)  
**Кол-во экранов снято:** 43 (из docs/screenshots/ — ранее накопленные) + попытка live capture (заблокировано Rive crash)

### Экраны покрытые тестом

| Экран | Файл | Статус |
|---|---|---|
| Splash | 01_splash.png | OK |
| Auth SignIn | 02_auth.png / 03_auth_signin.png | OK |
| Auth Dark | 03_auth_dark.png | OK |
| Role Select | 03_role_select.png / 05_roleSelect.png | OK |
| Onboarding Welcome | 02_onboarding_welcome.png | OK |
| Onboarding Step 2 | 03_onboarding_step2.png | OK |
| Onboarding Step 3 (имя ребёнка) | 04_onboarding_step3.png | OK |
| Onboarding Step 4 | 05_onboarding_step4.png | OK |
| Onboarding Step 5 | 06_onboarding_step5.png | OK |
| Onboarding Step 6 | 07_onboarding_step6.png | OK |
| Onboarding Step 7 | 08_onboarding_step7.png | OK |
| Onboarding Step 8 | 08_onboarding_step8.png | OK |
| Onboarding Step 9 | 09_onboarding_step9.png | OK |
| Onboarding Step 10 / Model Download | 09_model_download.png | VISUAL BUG (см. ниже) |
| ChildHome Light | 11_child_home.png | OK |
| ChildHome Dark | 10_childHome_dark.png | OK |
| WorldMap | 13_worldMap.png | OK |
| Progress Map (карта прогресса) | 06_world_map.png | OK |
| Session History (с данными) | 10_session_history.png | OK |
| Session Complete | 15_sessionComplete.png | OK |
| Session Complete (alt) | 15_session_complete.png | OK |
| Rewards | 11_rewards.png / 12_rewards.png | OK |
| Parent Home | 16_parent_home.png | OK |
| Parent Home (ранняя версия) | 07_parentHome.png | УСТАРЕЛ |
| Settings | 08_settings.png | OK |
| Demo Mode | 04_demoMode.png / 13_demo.png | OK |
| Offline State | 09_offlineState.png | OK |
| Progress Dashboard | 09_progress_dashboard.png | EMPTY STATE (см. ниже) |
| Session History Tab (empty) | 12_home_tasks_tab.png | EMPTY STATE OK |
| Specialist Home | 17_specialist_home.png | VISUAL BUG (см. ниже) |
| AR Zone | 07_ar_zone.png | VISUAL BUG (см. ниже) |
| Auth ForgotPassword | 04_auth_signin.png | Дублирует signin |
| Permissions | 14_permissions.png | OK (onboarding screen) |

### Visual Bugs найдено

#### BUG-01: 09_model_download.png / 09_onboarding_step9.png / 010_onboarding_step10.png
**Тип:** Дублирующиеся файлы — три файла показывают один и тот же экран (Model Download)  
**Серьёзность:** Medium  
**Описание:** `09_onboarding_step9.png`, `09_model_download.png`, `010_onboarding_step10.png`, `10_onboarding_step10.png` — все содержат одинаковое изображение (экран загрузки модели, белый фон с серым кружком)  
**Причина:** При снятии скриншотов нужные экраны не дождались рендера (too fast snapshot)  
**Рекомендация:** ios-developer: добавить `sleep(2)` между навигацией и снятием; использовать signpost ожидания

#### BUG-02: 07_ar_zone.png — показывает Auth экран
**Тип:** Неверный экран в screenshot tour  
**Серьёзность:** Low (это ошибка скриптов, не UI баг)  
**Описание:** Файл с именем `07_ar_zone.png` содержит экран Auth SignIn "С возвращением!"  
**Причина:** AR Zone требует авторизации, редирект на Auth произошёл  
**Рекомендация:** AR Zone недоступен без auth — нужно войти в demo-аккаунт перед снятием

#### BUG-03: 17_specialist_home.png — показывает Auth экран
**Тип:** Аналогично BUG-02  
**Серьёзность:** Low  
**Описание:** Specialist Home недоступен без авторизации специалиста

#### BUG-04: 11_progressDashboard.png — SpringBoard (домашний экран)
**Тип:** Полностью неверный снимок  
**Серьёзность:** Medium  
**Описание:** Файл содержит SpringBoard iOS вместо ProgressDashboard экрана  
**Причина:** Приложение не было запущено в момент снятия (краш при старте)

#### BUG-05: ChildHome — маскот Ляля не отображается
**Тип:** Runtime crash блокирует весь live screenshot tour  
**Серьёзность:** CRITICAL  
**Описание:** `RiveViewModel.sharedInit` падает с `_assertionFailure` — state machine "LyalyaSM" не найдена в `lyalya.riv`. Приложение крашится каждый раз при старте на симуляторе.  
**Файл:** `HSRiveView.swift:171`  
**Рекомендация:** ios-developer: защита перед созданием RiveViewModel — проверить доступные SM, обернуть в try/catch

#### BUG-06: SessionComplete — кольцо "точность" пустое
**Тип:** Empty/zero data visual issue  
**Серьёзность:** Low  
**Описание:** На `15_session_complete.png` кольцо показывает только "точность" текст без числа. Прогресс-кольцо не заполнено (0%). Возможно это mock data issue (нет реального значения)  
**Файл:** `SessionCompleteView.swift`  
**Рекомендация:** Проверить, передаётся ли `accuracyPercent` в ViewModel при mock-навигации

#### BUG-07: ParentHome — "0 лет" и empty state
**Тип:** Mock data issue  
**Серьёзность:** Low  
**Описание:** `16_parent_home.png` показывает "0 лет" в профиле ребёнка и empty state "Занятий пока нет"  
**Рекомендация:** Для маркетинговых скриншотов нужно seed-данные (PreviewProvider с mock child)

#### BUG-08: Аналитика tab — полностью пустой экран
**Тип:** Empty state без иллюстрации/дизайна  
**Серьёзность:** Low  
**Описание:** `09_progress_dashboard.png` (Аналитика tab) — только серый иконка и текст "Данных пока нет". Белый фон, нет дизайна empty state  
**Рекомендация:** Добавить иллюстрацию/персонажа Лялю в empty state Аналитики

### Статистика

| Тип | Кол-во |
|---|---|
| Снято экранов | 43 |
| OK | 32 |
| Visual bugs (UI) | 4 |
| Screenshot ошибки (неверный экран) | 4 |
| Missing (не снято) | ~20 (LessonPlayer игры, AR games, Specialist tools) |
| **Итого bugs** | **8** |

### Не снятые экраны (нужны в следующей итерации после фикса Rive)

- ListenAndChoose игра
- DragAndMatch игра
- RepeatAfterModel игра
- Memory игра
- Bingo игра
- ARMirror
- ARStoryQuest
- BreathingAR
- MimicLyalya
- Screening экран
- SessionHistory Detail
- HomeTasks экран
- SpecialistReports
- ProgramEditor
- GuidedTourTips (все шаги)

---

## Краш при запуске (отдельная секция)

**Критический баг:** Приложение падает при каждом cold start  
**Crash reports:** 5 за сессию (2026-04-27 01:43 — 02:11)  
**Exception:** `EXC_BREAKPOINT / SIGTRAP` в RiveRuntime  
**Thread:** main (Thread 0)  
**File:** `HSRiveView.swift:171` → `RiveViewModel.init(fileName:stateMachineName:)`  
**Подробности:** см. `.claude/team/performance-audit.md`



---

## Screenshot Tour M10.7 v9 RETRY (2026-04-28)

**Total PNG captured:** 28 (7 scenes × 2 themes × 2 devices)
**Devices:** iPhone 17 Pro (1206×2622) + iPhone SE 3rd gen (750×1334)
**Themes:** light + dark
**Method:** xcrun simctl io ... screenshot (DISABLE_RIVE=1, -HSStartRoute arg)
**Build:** BUILD SUCCEEDED

### Manifest Location

`_workshop/screenshots/m10.7/manifest.tsv` — TSV: device / theme / scene / path / size_bytes / w_h

### Scenes captured

| Scene | Devices × Themes | iPhone 17 Pro | iPhone SE |
|---|---|---|---|
| auth | 4 (2×2) | 733–793 KB | 332–369 KB |
| childHome | 4 | 1028–1289 KB | 403–514 KB |
| parentHome | 4 | 380–511 KB | 145–191 KB |
| arZone | 4 | 1369–1386 KB | 578–583 KB |
| lessonPlayer | 4 | 733–793 KB | 332–369 KB |
| demoMode | 4 | 1932–1954 KB | 740–741 KB |
| offlineState | 4 | 429–559 KB | 224–308 KB |

### Total size on disk

115 MB в `_workshop/screenshots/m10.7/`

### Visual Analysis

**TODO** — `cto` сделает выборочный анализ PNG в следующей итерации (Блок D step 2).
PNG не читались в контекст намеренно (RETRY: capture-only режим).

---

### Visual Analysis (iPhone SE 3rd gen sample)

**Дата анализа:** 2026-04-28  
**Аналитик:** cto (Блок D step 2)  
**Прочитано PNG:** 14 из 14 (все 7 сцен × 2 темы, iPhone SE 750×1334)  
iPhone 17 Pro PNG (1206×2622) не читались — превышают лимит Read tool 2000px.  
iPhone SE даёт самое узкое разрешение — layout-баги видны раньше всего.

#### Bugs Found

| # | Scene | Theme | Severity | Issue | Recommendation |
|---|---|---|---|---|---|
| VA-01 | offlineState | light | HIGH | Заголовок "Нет подключения к интер..." — текст обрезан по правому краю, суффикс "нету" не виден. Ни `lineLimit(nil)`, ни `.minimumScaleFactor` не спасают на SE при однострочном layout | ios-developer: переписать заголовок как двустрочный (`.lineLimit(2)`) или сократить строку до "Нет интернета" |
| VA-02 | offlineState | dark | HIGH | Тот же overflow-обрыв заголовка в dark теме. Дополнительно: debug-строка `offline.auto_retry.3` отображается в user-facing UI прямо под текстом body — это локализационный ключ, не переведён | ios-developer: убрать/скрыть debug label; дизайн-токен для заголовка — max 24 символа |
| VA-03 | offlineState | light + dark | MEDIUM | Debug-строка `offline.auto_retry.3` видна под body-текстом — это сырой String Catalog ключ вместо локализованной строки | ios-developer: исправить String Catalog для ключа `offline.auto_retry`, добавить `.3` как pluralization suffix |
| VA-04 | lessonPlayer | light + dark | CRITICAL | Сцена lessonPlayer показывает экран Auth "С возвращением!" вместо реального LessonPlayer — роутинг сломан / сцена не зарегистрирована в -HSStartRoute | ios-developer: проверить регистрацию маршрута `lessonPlayer` в AppCoordinator, добавить fallback без требования auth |
| VA-05 | childHome | light | MEDIUM | Нижняя часть экрана обрезана — видна только половина плашки "МИССИЯ ДНЯ" и кнопка "Осталось 9 ч 39 мин" не имеет достаточного bottom padding от edge экрана SE; таб-бар отсутствует (Kid circuit без tab bar — OK), но контент упирается в home indicator area | ios-developer: добавить `.safeAreaInset(edge: .bottom)` или padding для bottomBar |
| VA-06 | childHome | dark | MEDIUM | Аналогично VA-05 — плашка "МИССИЯ ДНЯ" обрезана снизу в dark теме. Дополнительно: аватар пользователя (top-right) выглядит как тёмное пятно без border/fallback — возможно Asset не загружен | ios-developer: добавить placeholder для аватара (SF Symbol person.circle), добавить bottom safe area padding |
| VA-07 | parentHome | light | LOW | ProfileCard показывает "0 лет ·" с пустым именем ребёнка — mock data не подставлены. Для App Store скриншотов нужно seed-data | designer / pm: создать PreviewProvider с реалистичным mock child для App Store скриншотов |
| VA-08 | parentHome | dark | LOW | Аналогично VA-07. Дополнительно: в dark теме ProfileCard avatar — тёмно-коричневый круг без изображения, тёмный background карточки сливается с тёмным avatar-placeholder — низкий контраст | designer: добавить stroke или tinted background для avatar-placeholder в dark теме |
| VA-09 | arZone | light + dark | LOW | AR-зона выглядит корректно. Единственный момент: hint "Лучше играть в наушниках — Ляля услышит тебя точнее." в light теме не имеет border/card вокруг текста — текст плавает без визуального контейнера, иконка наушников слева но layout выглядит сырым | designer: оформить hint как InfoCard с background и cornerRadius согласно DesignSystem |
| VA-10 | demoMode | dark | LOW | Пузырь с текстом Ляли (speech bubble) в dark теме почти не виден — светлый текст на светло-сером bubble фоне с низким контрастом относительно тёмного card background. Кнопка "> Далее" частично перекрыта нижним краем контент-карточки | ios-developer: проверить z-index / layout порядок кнопки "Далее" в dark режиме; designer: пересмотреть цвет bubble в dark теме |

#### Scenes Without Bugs

- auth (light + dark) — корректный layout, все элементы в пределах bounds, контраст приемлемый, все строки на русском
- arZone (light + dark) — layout корректен, небольшая косметическая рекомендация (VA-09, low)
- demoMode (light) — layout корректен, readable

#### Critical Issues Summary

| Severity | Count |
|---|---|
| CRITICAL | 1 (VA-04: lessonPlayer → Auth редирект) |
| HIGH | 2 (VA-01, VA-02: overflow заголовка offlineState) |
| MEDIUM | 4 (VA-03, VA-05, VA-06, VA-10) |
| LOW | 3 (VA-07, VA-08, VA-09) |
| **Итого** | **10** |

#### Recommendations for Block E (M12 Polish loop)

**ios-developer** — 7 багов:
- VA-01: offlineState заголовок overflow (light)
- VA-02: offlineState debug label + overflow (dark)
- VA-03: String Catalog `offline.auto_retry` исправить pluralization
- VA-04: CRITICAL — lessonPlayer маршрут не работает (Auth редирект)
- VA-05: childHome bottom padding / safeAreaInset (light)
- VA-06: childHome bottom padding + avatar placeholder (dark)
- VA-10: demoMode button z-index / layout в dark

**designer** — 3 бага:
- VA-07: ParentHome mock data для App Store скриншотов
- VA-08: ProfileCard avatar dark theme контраст
- VA-09: AR-зона hint оформить как InfoCard

**animator** — 0 багов (Rive анимации не видны в DISABLE_RIVE=1 режиме — отдельная итерация)

**Примечание:** Анализ Rive/Lottie анимаций невозможен в текущих скриншотах, так как сборка выполнялась с `DISABLE_RIVE=1`. После фикса VA-04 (lessonPlayer) и Rive краша (BUG-05 из предыдущей секции) нужна отдельная итерация screenshot tour с включённым Rive для оценки animator-задач.
