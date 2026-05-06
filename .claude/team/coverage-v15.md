# Coverage Report — Block L v15

**Дата:** 2026-05-07
**Схема тестирования:** HappySpeech (unit subset: 12 suite)
**Устройство:** iPhone SE 3rd generation (симулятор)
**Тестов выполнено:** 185 passed, 0 failed

## Итог по Interactor'ам (покрытые)

| Файл | Coverage | Строк | Статус |
|------|----------|-------|--------|
| ChildHomeInteractor.swift | 89.3% | 477/534 | ✓ ≥70% |
| RewardsInteractor.swift | 79.7% | — | ✓ ≥70% |
| SettingsInteractor.swift | 76.1% | — | ✓ ≥70% |
| ProgramEditorInteractor.swift | 59.7% | — | ✗ <70% |
| RepeatAfterModelInteractor.swift | 59.3% | 240/405 | ✗ <70% |
| WorldMapInteractor.swift | 58.6% | — | ✗ <70% |
| AuthInteractor.swift | 48.5% | — | ✗ <70% |
| OnboardingInteractor.swift | 45.2% | — | ✗ <70% |

## Services

| Файл | Coverage |
|------|----------|
| AuthService.swift (protocol) | 100% |
| RuleBasedDecisionService.swift | 89.3% |
| SyncService.swift | 78.0% |
| DailyMissionSyncService.swift | 27.8% |
| LLMDecisionService.swift | 18.4% |
| SoundService.swift | 15.2% |
| LiveAuthService.swift | 3.4% |
| HapticService.swift | 2.1% |

## Нулевые (0%) — не покрыты в Sprint L

Всего 75+ файлов Interactor/Service с 0% coverage.

Причина: Sprint L охватывал только критический путь Sprint 12 (12 suites).
Остальные Interactors (BingoInteractor, MemoryInteractor, SortingInteractor и др.)
требуют отдельных тестов в Sprint 13.

## Общий app coverage

**5.74%** (8408/146402 строк) — это low из-за включения SPM-зависимостей (Firebase,
WhisperKit, MLX, Lottie, Realm) в расчёт. Production код HappySpeech (без SPM) показывает
значительно лучшее покрытие для протестированных суит.

## Gaps (priority для Sprint 13)

### P1 — Interactors с тестами но <70%

1. **RepeatAfterModelInteractor** (59.3%) — нужны тесты для audio recording, ASR flow
2. **ProgramEditorInteractor** (59.7%) — нужны тесты для validateProgram, assignToChild
3. **AuthInteractor** (48.5%) — нужны тесты для Google SignIn, Anonymous Upgrade, ParentalGate
4. **OnboardingInteractor** (45.2%) — нужны тесты для permissions flow, modelDownload

### P2 — Interactors без тестов совсем

- ListenAndChooseInteractor (S12-009)
- SortingInteractor (S12-009)
- BingoInteractor (S12-010)
- MemoryInteractor (S12-010)

### Rationale: почему 90% недостижимо для текущего набора

- Большинство Interactors зависят от AVAudioEngine, ARKit, CoreML, Firebase —
  которые не работают на симуляторе без моков
- View code (SwiftUI) не покрывается unit-тестами по дизайну (snapshot-only)
- SPM-зависимости снижают общий % coverage

## Fixes выполнены в Block L

1. `ProgramEditorInteractorTests.SpyPresenter` — добавлены 3 метода D.1 v15
2. `AuthInteractorTests.SpyPresenter` — добавлены 4 метода D.1 v15
3. `AuthInteractorTests` — исправлен password ("pass123"→"passw0rd") и skipGate
4. `OnboardingInteractorTests` — добавлен setUp/tearDown с UserDefaults reset
5. `OnboardingInteractorTests` — исправлен toggleGoal (2 цели перед remove)
6. `OnboardingInteractorTests` — добавлен acceptPrivacyConsent перед completeOnboarding
