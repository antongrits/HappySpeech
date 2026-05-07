# Coverage Report — Block Q v16

**Дата:** 2026-05-07
**Схема:** HappySpeech (unit: HappySpeechTests target)
**Устройство:** iPhone SE (3rd generation) — симулятор
**Тестов:** 140 выполнено, 129 passed, 11 failed
**Xcresult:** .build_test/Logs/Test/Test-HappySpeech-2026.05.07_23-06-02-+0300.xcresult

---

## Сводка по слоям (production-код HappySpeech)

| Слой | Coverage | Покрытых строк | Всего строк | Файлов | ≥70% | ≥90% | Target |
|------|----------|----------------|-------------|--------|------|------|--------|
| **Interactors** | **45.1%** | 11182 | 24778 | 68 | 18 | 2 | 90% |
| **Services+Sync** | **30.6%** | 1488 | 4858 | 30 | 4 | 3 | 90% |
| **DesignSystem** | **22.8%** | 1553 | 6825 | 47 | 12 | 6 | — |
| **ML layer** | **48.0%** | 2815 | 5863 | 37 | 12 | 6 | — |
| **HappySpeech (all prod)** | **35.9%** | 55021 | 153069 | — | — | — | — |

**Итог:** Target ≥90% для Services + ViewModels **НЕ ДОСТИГНУТ** (Services: 30.6%, Interactors: 45.1%).

---

## Interactors — детально

### Выше 70% (прошли критерий Sprint 12)
| Interactor | Coverage |
|---|---|
| ProgressDashboardInteractor | 99.41% |
| HomeTasksInteractor | 94.70% |
| ChildHomeInteractor | 89.70% |
| OfflineStateInteractor | 88.05% |
| SoundHunterInteractor | 84.25% |
| RewardsInteractor | 79.68% |
| SettingsInteractor | 76.32% |
| CustomizationInteractor | 68.17% |
| SortingInteractor | 66.53% |
| RepeatAfterModelInteractor | 61.48% |
| ProgramEditorInteractor | 59.74% |
| WorldMapInteractor | 58.58% |
| GuidedTourInteractor | 56.40% |
| DragAndMatchInteractor | 53.24% |
| MemoryInteractor | 52.74% |
| PuzzleRevealInteractor | 53.77% |

### Ниже 70% — нужны дополнительные тесты
| Interactor | Coverage | Gap |
|---|---|---|
| ARZoneInteractor | 46.02% | -23.98pp |
| AuthInteractor | 48.48% | -21.52pp |
| OnboardingInteractor | 45.17% | -24.83pp |
| RhythmInteractor | 45.72% | -24.28pp |
| FluencyAnalyzerWorker | 45.40% | N/A (Worker) |
| GuidedTourInteractor | 56.40% | -13.60pp |
| ScreeningInteractor | 23.45% | -46.55pp |
| SpecialistInteractor | 16.04% | -53.96pp |
| ArticulationImitationInteractor | 25.42% | -44.58pp |

### Нулевые (0%) — отсутствуют тесты
- ARActivityInteractor (507 lines)
- ObjectHuntInteractor (788 lines)
- SoftOnsetInteractor (299 lines)
- ARFaceFilterInteractor (22 lines)
- SharePlayInteractor
- PoseSequenceInteractor
- BreathingARInteractor
- AchievementsInteractor
- FamilyHomeInteractor
- ComparisonDashboardInteractor
- ButterflyCatchInteractor
- ARStoryQuestInteractor
- MetronomeInteractor
- LetterTracingInteractor
- HoldThePoseInteractor
- FluencyDiaryInteractor
- FamilyLeaderboardInteractor
- DailyStreakInteractor

---

## Services+Sync — детально

| Service | Coverage |
|---|---|
| AuthService.swift (protocol) | 100.00% |
| SpacedRepetitionEngine.swift | 91.00% |
| VoiceCloneService.swift | 94.29% |
| SyncService.swift | 84.16% |
| NetworkMonitor.swift | 67.86% |
| MockServices.swift | 62.31% |
| SpecialistExportServiceLive.swift | 66.94% |
| SoundService.swift | 36.36% |
| AudioService.swift | 34.62% |
| SyncSnapshots.swift | 33.33% |
| AudioAnalysisService.swift | 25.42% |
| ARSessionService.swift | 23.94% |
| LiveServices.swift | 23.57% |
| HapticService.swift | 19.58% |
| PerformanceMonitorService.swift | 18.00% |
| RemoteConfigService.swift | 12.12% |
| NetworkClient.swift | 12.00% |
| FCMService.swift | 5.80% |
| LiveAuthService.swift | 3.42% |
| SpeakerVerificationServiceLive.swift | 2.84% |
| NotificationServiceLive.swift | 4.00% |
| EmotionDetectionServiceLive.swift | 2.65% |
| ContentPackDownloadService.swift | 1.36% |
| EnsembleASRService.swift | 4.23% |
| BiometricGateService.swift | 0.00% |
| FaceAnalysisService.swift | 0.00% |
| ClaudeAPIClient.swift | 0.00% |
| VideoPlayerService.swift | 0.00% |
| AmbientSoundService.swift | 0.00% |
| AirStreamDetector.swift | 0.00% |

---

## Test Failures (11)

### ARSnapshotTests (5 failures) — ОЖИДАЕМО
- `test_arMirror_smoke` — ARKit не поддерживается на симуляторе
- `test_arZone_darkMode_largePro`
- `test_arZone_smoke`
- `test_arZoneTutorial_smoke`
- `test_mimicLyalya_smoke`

**Причина:** ARKit требует real device. Тесты корректно падают на симуляторе.

### AccessibilityVariantsSnapshotTests (3 failures) — snapshot mismatch
- `test_onboardingStep1_dynamicTypeAccessibilityLarge`
- `test_onboardingStep1_dynamicTypeLarge`
- `test_parentHome_dynamicTypeAccessibilityLarge_light`

**Причина:** snapshot reference устарел после редизайна v16. Нужно пересоздать reference snapshots (`record: true`).

### AdvancedGameSnapshotTests (4 failures) — snapshot mismatch
- `test_articulationImitation_bothThemes`
- `test_memory_hard_bothThemes`
- `test_repeatAfterModel_bothThemes`
- `test_sorting_hard_bothThemes`

**Причина:** UI изменился в v16 (kavsoft redesign), reference snapshots устарели.

---

## Исправления в ходе QA

- `DisplayStateTests.swift`: исправлено `screenEmoji` → `screenSymbol` (3 места) — DemoStep API change в v16.

---

## Build

```
** TEST BUILD SUCCEEDED ** (после исправления DisplayStateTests.swift)
Compile target: iPhone SE (3rd generation) / iOS simulator
```

---

## Gap-анализ (приоритеты для Sprint 13)

### P1 — Достичь 70% на критических Interactors
1. AuthInteractor (48% → нужно +22pp)
2. OnboardingInteractor (45% → нужно +25pp)
3. ARZoneInteractor (46% → нужно +24pp)
4. ScreeningInteractor (23% → нужно +47pp)
5. ArticulationImitationInteractor (25% → нужно +45pp)

### P2 — Первичный тест coverage для нулевых
- ObjectHuntInteractor (0%, 788 lines) — наибольший риск
- SoftOnsetInteractor (0%, 299 lines)
- ARActivityInteractor (0%, 507 lines) — ожидаемо сложный (AR)

### P3 — Services
- LiveAuthService (3.4%) — критически важен для Firebase Auth flow
- HapticService (19.6%) — простые тесты
- SoundService (36%) — AudioEngine mock

### Пересоздать Reference Snapshots
- Запустить `record: true` для AccessibilityVariants + AdvancedGame snapshots после v16 UI freeze
