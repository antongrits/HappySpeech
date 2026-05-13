# v21 Tests Coverage Tracker

## Block Z — Coverage Baseline (from v20 deep audit)

- Test files at baseline: 119
- Test functions (func test): ~1151

## Block AA — Smoke Tests (+15 tests)

Added 15 smoke/sanity tests across critical paths.

## Block V — Presenter + Service + Domain Tests (+168 tests, +18 files)

| Файл | Новых тестов | Тип |
|---|---|---|
| DialectAdaptationPresenterTests.swift | 5 | Presenter |
| WeeklyChallengePresenterTests.swift | 6 | Presenter |
| LogopedistChatPresenterTests.swift | 7 | Presenter |
| FamilyAchievementsPresenterTests.swift | 7 | Presenter |
| CulturalContentPresenterTests.swift | 7 | Presenter |
| DailyStreakPresenterTests.swift | 9 | Presenter |
| RepeatAfterModelPresenterTests.swift | 8 | Presenter |
| AchievementsPresenterTests.swift | 7 | Presenter |
| ListenAndChoosePresenterTests.swift | 8 | Presenter |
| BreathingPresenterTests.swift | 6 | Presenter |
| RemoteConfigServiceTests.swift | 13 | Service |
| NotificationServiceExtTests.swift | 7 | Service |
| ASRServiceTests.swift | 6 | Service |
| SyncServiceExtTests.swift | 8 | Service |
| AnalyticsServiceTests.swift | 8 | Service |
| HapticIntensityLevelTests.swift | 9 | Service |
| DesignSystemTokensTests.swift | 23 | Tokens |
| DomainModelTests.swift | 24 | Domain Models |
| **ИТОГО** | **168** | |

Commits: 4c13b1d0, d9d79739, 36d5503c

## Block AB — Snapshot + Integration Tests (v21)

### Snapshot tests — BlockCComponentsSnapshotTests.swift

Файл: `HappySpeechTests/Snapshot/BlockCComponentsSnapshotTests.swift`

Покрытые компоненты (post Block C emoji→SF Symbol):

| Тест | Компонент | Вариантов |
|---|---|---|
| test_lyalya_idle_bothThemes | LyalyaMascotView .idle | 2 (Light+Dark) |
| test_lyalya_celebrating_bothThemes | LyalyaMascotView .celebrating | 2 |
| test_lyalya_thinking_bothThemes | LyalyaMascotView .thinking | 2 |
| test_lyalya_waving_bothThemes | LyalyaMascotView .waving | 2 |
| test_lyalya_encouraging_bothThemes | LyalyaMascotView .encouraging | 2 |
| test_customAlert_withSFSymbol_bothThemes | HSCustomAlertView symbol | 2 |
| test_customAlert_withMascot_bothThemes | HSCustomAlertView mascot | 2 |
| test_customAlert_destructive_bothThemes | HSCustomAlertView destructive | 2 |
| test_onboardingParallax_firstPage_bothDevices | HSOnboardingParallax page1 | 4 (2dev × 2theme) |

Итого новых PNG референсов: 20

Хранение: `__Snapshots__/BlockCComponents/`

### Integration tests — VIPFlowIntegrationTests.swift

Файл: `HappySpeechTests/Integration/VIPFlowIntegrationTests.swift`

| Тест | Flow | Описание |
|---|---|---|
| test_anonymousSignIn_then_adaptivePlannerReturnsDemoRoute | Auth→Demo | Anonymous signIn → AdaptivePlanner demo route |
| test_onboardingFlow_completes_andPersistsFlag | Onboarding VIP | load→setRole→setProfile→complete→flag |
| test_sessionLifecycle_startToCompletion | Session VIP | start→completeActivity×N→isSessionComplete |
| test_offlineSyncQueue_writeThenFlush_clearsQueue | Offline Sync | offline write → reconnect → flush |
| test_contentPack_savedInRealm_canBeFetchedByContentEngine | Content | Realm persist → ContentEngine |

5 новых integration тестов, все mock-based (нет сети/Firebase).

### Final Stats

| Метрика | До Block AB | После Block AB |
|---|---|---|
| Тестовых файлов | 137 | 139 (+2) |
| Snapshot тестов (функции) | ~60+ | ~69+ (+9 функций) |
| Snapshot PNG референсов | 477 | +20 (BlockCComponents) |
| Integration тестов | 5 (4 файла) | 6 файлов (+5 тестов) |
| Test functions (func test) | ~1319 | ~1343 |

### Build Status

Полная xcodebuild сборка невозможна в текущем окружении:
- gRPC binary artifact (openssl_grpc.zip) — сетевая ошибка Google CDN
- mlx-swift Metal shaders компиляция — OOM (слишком много RAM)

Pre-existing issue (Block 0.2 sprint-v21.md). Все файлы parse-clean (swiftc -parse: exit 0).

Syntax verification: PASSED (swiftc -parse exit 0)

### Следующие шаги

- Block 0.2 fix: resolve gRPC build issue + MLX defer
- После build fix: запустить тесты на iPhone SE 3, записать PNG референсы
- Full 208 snapshot suite: defer v22+
