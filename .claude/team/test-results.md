# Test Results — HappySpeech

**Последнее обновление:** 2026-04-27  
**QA агент:** ios-debugger  

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

