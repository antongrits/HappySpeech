# V25 — Финальное покрытие тестами (Phase 2)

**Дата:** 2026-05-16
**resultBundle:** `_workshop/v25_cov.xcresult`
**Прогон:** `xcodebuild test -only-testing:HappySpeechTests`, iPhone SE (3rd gen), iOS 26.5

## Итоговые метрики

| Слой | Baseline v25 (2.5a) | Финал (Phase 2.9) | Цель |
|------|---------------------|-------------------|------|
| HappySpeech.app (всё, вкл. SwiftUI Views) | 39.10% | **47.07%** | — |
| HappySpeechTests.xctest (сами тесты) | — | 94.18% | — |
| **БИЗНЕС-ЛОГИКА** (Interactor+Presenter+Worker+Service+ML, без Views) | 51.75% | **77.68%** | 90% |
| Presenter | 45.16% | **95.12%** ✅ | 90% |
| Interactor | 62.14% | **83.77%** | 90% |
| Worker | 40.71% | 68.18% | 90% |
| Service | 38.94% | 43.25% | 90% |

## Что сделано в Phase 2 (v25)

- Phase 2.0 — починка сломанных тестов + перезапись snapshot-эталонов.
- Phase 2.1-2.4 — таргетные батчи (зеро-coverage Interactors, Services, sub-70% Interactors, DesignSystem+ML).
- Phase 2.6 — Presenters: 57 файлов в 3 батчах → 95.12%.
- Phase 2.7 — Workers: 34 файла в 2 батчах → 68.18%.
- Phase 2.8 — Interactors: 56 файлов в 4 батчах → 83.77%.
- Phase 2.10 — Services: батч тестируемой логики.
- Phase 2.9/2.11 — починка провалов полного прогона (см. ниже).

**Добавлено ~2500+ тест-функций** поверх baseline. Тест-таргет покрыт сам на 94.18%.

## Реальные баги, найденные тестами (не только покрытие)

Написание тестов вскрыло **production-баги**, которые были исправлены:
1. `%@` для Int-аргументов в `Localizable.xcstrings` → use-after-free segfault (5 ключей + `family_calendar.comparison.format` — аудит формат-строк по всему каталогу).
2. `1..<0` невалидный Range crash — `FluencyAnalyzerWorker.analyzeDysfluency`, `ProgramEditorInteractor.validateCurrentProgram` (пустой вход).
3. Testability-баг: `MetronomeInteractor`/`SoftOnsetInteractor` использовали конкретный `BreathingAudioWorker` → `AVAudioApplication.requestRecordPermission()` вешал test-process в headless-симуляторе. Переведены на `BreathingAudioWorkerProtocol`.
4. `MockEmotionDetectionService` data race (`@unchecked Sendable` + async) → защищён `NSLock`.
5. `SiblingInteractor` double-scoring, `StoryPlayer` mp4 URL flat-fallback, `KidSafetyFilter` подстрочный false-positive ("боль" в "большой").

## Цель 90% не достигнута — почему (ADR-V25-COVERAGE)

Бизнес-логика **77.68%**. Остаток до 90% (~7766 непокрытых строк в 47 файлах) — **genuinely SDK-/hardware-bound** код, недостижимый в unit-окружении симулятора без интеграционных стендов:

### Категория A — Firebase SDK (delegate/сеть)
`LiveServices`, `CloudFunctionsService`, `FamilyInviteService`, `DynamicLinksService`, `RealtimeDatabaseService`, `LiveAuthService`, `InstallationsService`, `ContentPackDownloadService`, `RemoteConfigService`, `FCMService` — требуют `FirebaseApp.configure()` + живые сетевые вызовы. Тестируется логика моделей/ошибок/построения запросов; SDK-callbacks — нет.

### Категория B — ML-инференс (CoreML/WhisperKit)
`LLMDecisionService`, `LocalLLMService`, `ASRServiceLive`, `Wav2Vec2ServiceLive`, `PhonemeAnalysisServiceLive`, `EnsembleASRService`, `MLModelWarmupService`, `VADService`, `EmotionDetectionServiceLive` — требуют `.mlpackage`/Whisper модели в тест-бандле (десятки–сотни МБ, не коммитятся). `MLModelWarmupService.warmUp()` аварийно завершает headless-процесс. Тестируется препроцессинг/постпроцессинг/routing; сам инференс — нет.

### Категория C — AR / камера / биометрия
`ARSessionService`, `FaceAnalysisService`, `BodyPoseWorker`, `SpeakerVerificationServiceLive`, `BiometricGateService` — ARKit face/body tracking + `LAContext` требуют железо.

### Категория D — аудио-железо (AVAudioEngine / микрофон)
`BreathingInteractor`, `MetronomeInteractor`, `RhythmInteractor`, `BreathingExtendedInteractor`, `FluencyDiaryInteractor`, `FamilyVoiceInteractor`, `VoiceCloningInteractor`, `LessonVoiceWorker`, `WhisperTranscriptionWorker`, `MetronomeWorker`, `HandwritingRecognitionWorker`, `AudioFileIO`, `AmbientSoundService`, `AudioAnalysisService`, `FamilyVoiceRecorderWorker`, `CustomizationVoicePreviewWorker` — запись/воспроизведение через `AVAudioEngine`/`AVAudioRecorder`, mic permission. Покрыта VIP-логика и mock-пути; live аудио — нет.

### Категория E — Multipeer / GroupActivities
`SiblingMPCWorker`, `FamilyShareplayController` — `MultipeerConnectivity`/`GroupActivities`, нужны несколько устройств.

**Вывод:** реалистичный потолок unit-покрытия для данной архитектуры — ~80-83%. Достигнуто 77.68%. Дальнейший рост требует Firebase Emulator integration-стенда и моделей в тест-бандле — за рамками v25 (риск регрессий перед сдачей). Functional UI tests (Phase 3) и manual MCP verification (Phase 4) покрывают эти слои на поведенческом уровне.
