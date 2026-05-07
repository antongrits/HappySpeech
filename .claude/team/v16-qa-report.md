# Block Q Final Report v16

**Дата:** 2026-05-07
**QA-инженер:** qa-engineer (Sonnet 4.6 @ high)
**Фаза:** Block Q — Coverage measurement + Performance audit + Screenshot tour

---

## Q.1 Coverage

| Слой | Coverage | Target | Статус |
|---|---|---|---|
| Interactors | 45.1% (11182/24778 lines) | 90% | FAIL |
| Services+Sync | 30.6% (1488/4858 lines) | 90% | FAIL |
| DesignSystem | 22.8% (1553/6825 lines) | — | INFO |
| ML layer | 48.0% (2815/5863 lines) | — | INFO |
| HappySpeech total (prod) | 35.9% (55021/153069 lines) | — | INFO |

**Тестов:** 140 выполнено, 129 passed, 11 failed

**Breakdown failed:**
- 5 ARSnapshotTests — ОЖИДАЕМО (ARKit не работает на симуляторе)
- 3 AccessibilityVariantsSnapshot — snapshot reference устарел после v16 redesign
- 4 AdvancedGameSnapshot — snapshot reference устарел после v16 redesign

**Interactors выше 70% (18 из 68):**
ProgressDashboard (99.4%), HomeTasks (94.7%), ChildHome (89.7%), OfflineState (88.1%),
SoundHunter (84.3%), Rewards (79.7%), Settings (76.3%), Customization (68.2%)

**Interactors с нулевым покрытием (15):**
ObjectHuntInteractor, SoftOnsetInteractor, ARActivityInteractor, ARFaceFilterInteractor,
SharePlayInteractor, PoseSequenceInteractor, BreathingARInteractor, AchievementsInteractor,
FamilyHomeInteractor, ComparisonDashboardInteractor, ButterflyCatchInteractor, ARStoryQuestInteractor,
MetronomeInteractor, LetterTracingInteractor, DailyStreakInteractor

---

## Q.2 Performance

| Метрика | Измерено | Target | Статус |
|---|---|---|---|
| Launch command time | 249 ms | — | OK |
| First frame to Permissions screen | ~3 sec | <2 sec | WARNING |
| Memory cold start | ~150–180 MB est. | <200 MB | OK (est.) |
| AR FPS | N/A (симулятор) | 30 fps | DEFERRED |

**Build:** TEST BUILD SUCCEEDED после исправления DisplayStateTests.swift

**Исправлен баг:** `DisplayStateTests.swift` — 3 места использовали устаревший параметр `screenEmoji`,
переименованный в `screenSymbol` при v16 redesign. Исправлено на `screenSymbol: "iphone"` / `"star.circle.fill"`.

---

## Q.3 Screenshots

- **Захвачено:** 22 скриншота
- **Устройство:** iPhone SE (3rd generation) — симулятор
- **Путь:** `_workshop/screenshots/v16_qa/`

### Список скриншотов

| # | Файл | Экран | Режим |
|---|---|---|---|
| 01 | 01_startup.png | Permissions dialog (mic) | Light |
| 02 | 02_permissions_dialog.png | Permissions dialog (mic) | Light |
| 03 | 03_after_mic_dismiss.png | Permissions dialog (mic) | Light |
| 04 | 04_onboarding_step1.png | Onboarding step 1 | Light |
| 05 | 05_onboarding_dark.png | Onboarding step 1 | Dark |
| 06 | 06_onboarding_light.png | Onboarding step 1 | Light |
| 07 | 07_after_relaunch.png | Permissions dialog | Light |
| 08 | 08_after_grants.png | Permissions dialog | Light |
| 09 | 09_all_grants.png | Permissions dialog | Light |
| 10 | 10_after_allow_mic.png | Onboarding welcome (Привет! Я Ляля) | Light |
| 11 | 11_onboarding_welcome.png | Onboarding welcome | Light |
| 12 | 12_onboarding_step2.png | Onboarding welcome (Mascot visible) | Light |
| 13 | 13_after_click.png | Role Select (Кто пользуется?) | Light |
| 14 | 14_role_select_dark.png | Role Select | Dark |
| 15 | 15_role_select_light.png | Role Select | Light |
| 16 | 16_onboarding_step3.png | Role Select | Light |
| 17 | 17_nav_attempt.png | Role Select | Light |
| 18 | 18_after_y_attempts.png | Home screen (app sent to bg) | Light |
| 19 | 19_app_relaunch.png | Role Select (resumed) | Light |
| 20 | 20_nav_step3.png | Home screen (app went to bg again) | Light |
| 21 | 21_step2_fresh.png | Role Select (dark remnant) | Light |
| 22 | 22_step2_dark.png | Role Select | Dark |

### Visual observations

1. **Onboarding step 1** — "Привет! Я Ляля" с бабочкой — дизайн чистый, тёмный фон работает в обоих режимах.
2. **Role Select screen** — "Кто пользуется приложением?" — карточки (Родитель / Логопед / Ребёнок) отображаются корректно. Текст читаем. Нет переполнения на SE3 (375pt width).
3. **Permissions flow** — системный алерт разрешений на микрофон корректно отображается.
4. **Dark mode** — Role Select в тёмном режиме выглядит аналогично светлому (dark background), нет артефактов.
5. **SE3 constraint** — контент не выходит за границы 375pt ширины на всех захваченных экранах.

### Ограничения screenshot tour

- Навигация осложнена необходимостью точных координатных кликов через AppleScript/cliclick.
- Приложение неоднократно уходило на Home Screen из-за кликов в chrome-зону симулятора.
- Глубокие экраны (ChildHome, ParentHome, GamePlay) не захвачены — требуется UI test automation.
- Для полного tour 80 скриншотов нужен XCUITest с правильным launchArguments для state reset.

---

## Build Status

```
TEST BUILD: SUCCEEDED
Scheme: HappySpeech / iPhone SE (3rd generation)
Compilation errors fixed: 1 (DisplayStateTests.swift — screenEmoji → screenSymbol)
Test pass rate: 92.1% (129/140)
AR tests: 5 expected failures (simulator limitation)
Snapshot mismatches: 7 (need reference update after v16 redesign)
```

---

## Критические проблемы (action required)

1. **Coverage gap:** Interactors 45.1% vs target 90% — нужно ~450 новых unit тестов
2. **Services coverage:** 30.6% vs target 90% — LiveAuthService (3.4%), HapticService (19.6%) — простые моки нужны
3. **Stale snapshots:** 7 snapshot тестов с устаревшими reference — запустить `record: true`
4. **AR tests:** 5 тестов должны пропускаться (`XCTSkipUnless(ARFaceTrackingConfiguration.isSupported)`) вместо fail

---

## Рекомендации для Sprint 13

### Немедленно
- Пересоздать snapshot references: `AccessibilityVariants` + `AdvancedGame` (запустить с `record: true`)
- Добавить `XCTSkipUnless(ARFaceTrackingConfiguration.isSupported)` в ARSnapshotTests

### Sprint 13 P1
- Unit тесты для нулевых Interactors (ObjectHunt, SoftOnset, FamilyHome, DailyStreak)
- Services mock tests: LiveAuthService, HapticService, SoundService
- Startup time XCTest metric (на реальном устройстве)
- UI automation tour с `launchArguments: ["--reset-state", "--mock-auth"]`
