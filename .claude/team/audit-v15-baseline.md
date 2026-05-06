# HappySpeech — Audit v15 Baseline (2026-05-06)

После Block A v15 cleanup. Source of truth для последующих блоков.

## Configuration ✅

| Item | Status |
|------|--------|
| Bundle ID | `com.mmf.bsu.HappySpeech` ✅ |
| Firebase project | `happyspeech-dfd95` (eur3, antongric132@gmail.com) ✅ |
| GoogleService-Info.plist | Обновлён 2026-05-06, новый OAuth client `5n7g0begs0ocu270brlrmvce2emc8vag` ✅ |
| TARGETED_DEVICE_FAMILY | `"1"` (iPhone only) ✅ |
| Mac (Designed for iPhone) | Опционально для self-test |
| Marketing Version | 1.0.0 (НЕ повышать) |
| iOS Deployment | 17.0 |
| Russian-only | 0 en, 1601+ ru ключи ✅ |
| App display name | HappySpeech ✅ |
| App category | public.app-category.education ✅ |
| Team | current ✅ |
| RealmSwift | Embed & Sign ✅ |

## HealthKit ✅

- ✅ `BreathingHealthKitWorker.swift` deleted
- ✅ `BreathingMetricsWorker.swift` created (no HKHealthStore — local logging only)
- ✅ `BreathingInteractor.swift` refactored (`metricsWorker` instead of `healthKitWorker`)
- ✅ `BreathingView.swift` refactored
- ✅ Info.plist: NSHealthShareUsageDescription / NSHealthUpdateUsageDescription removed earlier
- ✅ `com.apple.developer.healthkit` entitlement removed earlier
- ✅ `grep -rln "HealthKit\|HKHealthStore"` returns only Settings comment line + new MetricsWorker comment

## Downloads ✅

- ✅ `/Users/antongric/Downloads/HappySpeech/` deleted
- ✅ `/Users/antongric/Downloads/HappySpeech_workshop/` deleted
- ✅ `/Users/antongric/Downloads/__pycache__/` deleted
- ✅ `/Users/antongric/Downloads/download_whisper_base.py` deleted
- ✅ `/Users/antongric/Downloads/GoogleService-Info.plist` → перенесён в проект, удалён из Downloads
- ✅ `/Users/antongric/Downloads/deep-research-report-happyspeech.md` → архивирован в HappySpeech/ResearchDocs/archive/

## _workshop/ (4.4 GB → 3.8 GB после cleanup) ⚠️

Локально, в .gitignore (НЕ в git):
- `_workshop/datasets/` 2.9 GB (raw 1.9 GB + clean 1.0 GB) — оставлен для retrain в Block B
- `_workshop/remotion/` 537 MB — оставлен для videos
- `_workshop/screenshots/` 296 MB — оставлен для screenshot tour
- `_workshop/illustrations/` 27 MB
- `_workshop/ml/` 8.2 MB
- ✅ Удалены: `_workshop/remotion-v14/` (482 MB) + `_workshop/coverage/` (152 MB)

## Stub Core ML Models — REAL TRAINING REQUIRED (Block B) 🔴

| Model | Текущий size | Real expected | Status |
|-------|--------------|---------------|--------|
| Wav2Vec2RuChild.mlpackage | 336 KB | ~200 MB | STUB ❌ |
| Wav2Vec2RuChildLogopedic.mlpackage | 804 KB | ~370 MB int8 | STUB ❌ |
| SileroVAD.mlpackage | 16 KB | ~2 MB CNN | STUB ❌ ("energy stub" comment) |
| RussianPhonemeClassifier.mlpackage | 2.6 MB | ~10 MB | вероятно STUB |
| TonguePostureClassifier.mlpackage | 12 KB | ~3 MB | STUB ❌ |
| PronunciationScorer_*.mlpackage (×4) | 20 KB each | ~3 MB each | STUB ❌ |
| SpeakerVerification.mlpackage | 496 KB | ~30 MB d-vector | вероятно STUB |
| EmotionDetection.mlpackage | 884 KB | ~5 MB | возможно real |
| SoundClassifier.mlpackage | 20 KB | ~5 MB | STUB ❌ |

`PronunciationScorerLive.swift` имеет heuristic fallback к RMS energy (`heuristicScore = min(1.0, rms * 8.0)`). При stub model — silent fallback к RMS scaling = НЕТ реальной оценки произношения.

## Missing Service Wrappers — Block C 🔴

- ❌ `HappySpeech/Services/EnsembleASRService.swift`
- ❌ `HappySpeech/Services/SpeakerVerificationServiceLive.swift`
- ❌ `HappySpeech/Services/EmotionDetectionServiceLive.swift`

## 23 Stub Interactors <250 LOC — Block D 🔴

```
50  ButterflyCatchInteractor (AR — VIP-thin OK)
55  BreathingARInteractor (AR — VIP-thin OK)
56  SoundAndFaceInteractor (AR), FamilyHomeInteractor
64  ProfileEditorInteractor
65  HoldThePoseInteractor (AR — VIP-thin OK)
95  MimicLyalyaInteractor (AR — VIP-thin OK)
98  OfflineMiniGameInteractor
101 OfflineStateInteractor
109 ARMirrorInteractor (AR — VIP-thin OK)
113 ReportsInteractor (Specialist)
116 ProgramEditorInteractor (Specialist)
131 ComparisonDashboardInteractor (Family)
147 AuthInteractor
168 PoseSequenceInteractor (AR — VIP-thin OK)
188 SharePlayInteractor
195 BreathingExtendedInteractor (Stuttering)
197 AchievementsInteractor (Extensions)
212 ARZoneInteractor (close to 250), FluencyDiaryInteractor (Stuttering)
215 SoftOnsetInteractor (Stuttering)
245 MetronomeInteractor (Stuttering — close to 250)
```

**Стратегия:**
- Углубить до 350+ LOC (real domain logic): Auth, Achievements, BreathingExtended, FluencyDiary, SoftOnset, ProgramEditor, Reports, ComparisonDashboard, ProfileEditor, FamilyHome, OfflineState, SharePlay, Metronome (13 файлов)
- Document как `// VIP-thin: orchestration only`: AR Interactors (9 файлов)

## 254 RGB Illustrations — Block E 🔴

`Assets.xcassets/Illustrations/` :
- 192 RGBA (with alpha) ✅
- 254 RGB (rectangle background) ❌
- 18 not-PNG ❌

`reward_night_owl.png` — JPEG masquerading as .png ❌

## View Files >1000 LOC — Block H ⚠️

| View | LOC | Plan |
|------|-----|------|
| SettingsView | 1449 | Split *ViewComponents.swift |
| OnboardingFlowView | 1431 | Split |
| FamilyCalendarView | 1345 | Split |
| SessionHistoryView | 1281 | Split |
| GrammarGameView | 1157 | Split |
| SpecialistHomeView | 1125 | Split |
| ARZoneView | 1078 | Split |
| CustomizationView | 1062 | Split |
| ProgressDashboardView | 1052 | Split |

## USDZ Logopedic Relevance — Block F 🔴

Нерелевантные (заменить):
- kitchen_pancakes.usdz (30 MB)
- music_guitar_stratocaster.usdz (14 MB)
- sport_glove_boxing.usdz (9.6 MB)
- toy_drummer.usdz (13 MB)
- animal_hummingbird.usdz (20 MB)

Создать релевантные (10 USDZ):
- apple_red.usdz (А)
- mouse_grey.usdz (Ы)
- fox_orange.usdz (Ль/Ф)
- snake_green.usdz (С/Ш)
- cup_steaming.usdz (К/Ч/П)
- bell_brass.usdz (Л/Н)
- truck_red.usdz (Р/Г)
- whale_blue.usdz (Х/В)
- rocket_silver.usdz (Р/Т)
- drum_wooden.usdz (Д/Б)

## Bundle Size

Текущий: ~1.2 GB (Audio 169 + Animations 3.8 + Models 657 + Videos 47 + ARAssets 231 + Assets.xcassets 111).

Цель: ~1.5 GB через GLубину (Block B + I + J).

## Git ✅

- Author = antongrits ✅
- Last commit: 8fbad7a2 (chore(cleanup): A v15) — БЕЗ Co-Author Claude ✅
- 228 commits в истории с Co-Author — НЕ rewrite (destructive)

## SwiftLint

Текущий: 0 errors, ≤10 warnings (per audit deeper). Post-Block H ожидается 0 errors, 0 warnings.

## Tests

110 test files, 915 test functions. Coverage: измерение в Block L.

## Next Block

**Block B — Real ML training** через `ml-engineer` agent (Sonnet @ high). Выполнение: 7 моделей × ≤3ч training each. Может занять много времени (пользователь предупреждён).
