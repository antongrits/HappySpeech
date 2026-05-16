# V25 Coverage Progress

## Финальное измерение Phase 2.9 (2026-05-16)

resultBundle: _workshop/v25_cov.xcresult

| Слой | Baseline (2.5a) | Phase 2.9 | Target |
|------|-----------------|-----------|--------|
| HappySpeech.app (всё, incl. Views) | 39.10% | 47.03% | — |
| BUSINESS LOGIC (Interactor+Presenter+Worker+Service+ML, без Views) | 51.75% | **76.92%** | 90% |
| Interactor | 62.14% | **83.44%** | 90% |
| Presenter | 45.16% | **95.05%** | 90% ✅ |
| Worker | 40.71% | 68.15% | 90% |
| Service | 38.94% | 40.10% | 90% |

## Остаток работы
- Services 40% — Firebase/ML/AR Live-сервисы (LiveServices, CloudFunctions, FamilyInvite,
  NotificationServiceLive, DynamicLinks, RealtimeDatabase, LocalLLM, LiveAuth, ContentPackDownload,
  Installations, ARSessionService, RemoteConfig, FaceAnalysis, EnsembleASR, ASRServiceLive, LLMDecisionService).
  Часть — genuinely SDK-bound (ADR-V25-COVERAGE).
- Worker residual: KidHintProvider, MetronomeWorker, HandwritingRecognitionWorker и др.
- Interactor: FamilyVoiceInteractor 21%, VoiceCloningInteractor 22%, BreathingExtendedInteractor 13%
  (тесты написаны, но падают/абортят в полном прогоне — нужен фикс).
