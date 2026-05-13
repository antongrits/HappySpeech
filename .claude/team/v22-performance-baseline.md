# Performance Baseline v22

**Дата:** 2026-05-13
**Tag target:** v1.0.0-final-v22
**Block:** 5.2

## Instrumentation Status

**Total `HSSignpost.pointsOfInterest` calls:** 17 (verified via grep)
**Categories:** ColdStart (Block 0.5), ML Inference (Block 1.4)

## Cold Start Phases (Block 0.5 v22)

Os.signpost markers в порядке cold start lifecycle:

| Phase | Marker | Source File |
|---|---|---|
| 1 | `AppLaunch` | `HappySpeechApp.swift` (begin) → root `.onAppear` (end) |
| 2 | `LaunchScreenAppear` | `SplashView.onAppear` |
| 3 | `LaunchScreenDisappear` | `SplashView.onDisappear` |
| 4 | `AuthInit` | `AppCoordinator.bindAuthState` |
| 5 | `MLWarmup` | `MLModelWarmupService.warmupModels` |
| 6 | `ChildHomeFirstFrame` | `ChildHomeView.onAppear` |

## ML Inference Markers (Block 1.4 v22)

| Phase | Marker | Source File |
|---|---|---|
| 7 | `PhonemeInference` | `RussianPhonemeClassifierWrapper.classify` |
| 8 | `Wav2Vec2Inference` | `Wav2Vec2ServiceLive.embed` |
| 9 | `PronunciationScoring` | `PronunciationScorer.score` |

## How to Profile

```bash
# 1. Build Release
xcodebuild -project HappySpeech.xcodeproj -scheme HappySpeech \
  -configuration Release \
  -destination 'platform=iOS,name=<device>' build

# 2. Launch Instruments → Points of Interest template
# 3. Filter by category: ColdStart / ML
# 4. Cold start = AppLaunch begin → ChildHomeFirstFrame end
```

## Target Metrics

| Metric | Target | Status |
|---|---|---|
| Cold start (iPhone SE 3) | < 3.0s | Instrumented, not measured |
| Cold start (iPhone 15) | < 1.5s | Instrumented, not measured |
| ML warmup duration | < 800ms | Instrumented |
| Phoneme inference | < 50ms / window | Instrumented |
| Wav2Vec2 forward | < 200ms / 16kHz window | Instrumented |

## Sub-Agent Limitation

Actual hardware profiling requires physical iPhone connected to Instruments. Sub-agent в этой session работает только через Bash/Xcode CLI — Instruments live profiling недоступен.

**Status:** Fully instrumented v22, baseline measurement deferred to user device session.

## Verification

```bash
grep -rn "HSSignpost.pointsOfInterest" HappySpeech/ --include="*.swift" | wc -l
# Expected: 17 (verified 2026-05-13)
```
