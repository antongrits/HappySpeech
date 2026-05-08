# HappySpeech v18 — Audit Baseline (2026-05-08)

> **Источник:** 3 параллельных Explore агента (UI quality + ML/CV/Audio + Project structure/Firebase/Cleanup), 2 из 3 завершены детальными отчётами; 3-й (project structure) собран самостоятельно через Bash. Plus comprehensive audit во время написания Plan v18 (7126 строк).

## Краткие метрики

| Метрика | Значение |
|---|---|
| Total commits | 520 |
| Author antongrits | 519 |
| Commits с Co-Author Claude | 229 (старая история — НЕ rewrite) |
| Last commit | `4418daee` (docs(release): AL v17 — Final report v1.0.0-final-v17) |
| Last tag | `v1.0.0-final-v17` |
| Branch | `main` |
| Project size total | ~27 GB (включая Yandex.Disk копии) |
| _workshop размер | 620 MB (мусор для cleanup) |
| Resources size | 1.32 GB (target ~1.5 GB через depth) |
| Total Swift LOC | ~115,000+ |

## Files inventory

| Категория | Файлов | LOC est |
|---|---|---|
| Features *View.swift | 100 | ~30,000 |
| Features *Interactor.swift | 40 | ~12,000 |
| Features *Presenter.swift | 40 | ~8,000 |
| Features *Router.swift | 40 | ~3,000 |
| Features *Models.swift | 40 | ~6,000 |
| DesignSystem Components | 40+ HSCustom* | 7,760 |
| ML Swift code | 42 | 10,489 |
| Services | ~30 | ~10,000 |
| Tests (Unit + UI) | ~127 | ~25,000 |

## Resources sizes (target +180 MB через depth до ~1.5 GB)

| Категория | Текущий | Target v18 | Delta |
|---|---|---|---|
| Models | 956 MB | ~990 MB | +30 MB (RussianPhonemeClassifier retrain + EmotionDetection augmented + Wav2Vec2RuChildLogopedic real fine-tune) |
| Audio | 220 MB | ~250 MB | +30 MB (Voice expansion 13344 → 14500+) |
| Assets.xcassets | 97 MB | ~130 MB | +30 MB (Illustrations RGBA regen + new) |
| Videos | 47 MB | ~107 MB | +60 MB (Real Remotion videos 60+ professional) |
| ARAssets | 5.4 MB | ~55 MB | +50 MB (Blender 3D scenes 20+ logopedic USDZ) |
| Animations | 4.3 MB | ~25 MB | +20 MB (Real Bodymovin Lottie 23+) |
| **Total** | **1.32 GB** | **~1.5 GB** | **+180 MB** |

## ML Models inventory (audit findings от Explore #2)

| Model | File Size | Status |
|---|---|---|
| Wav2Vec2RuChild.mlpackage | **302 MB** | ✅ REAL (jonatasgrosman/wav2vec2-large-xlsr-53-russian fine-tuned) — v17 жаловался что stub, **уже исправлено** |
| Wav2Vec2RuChildLogopedic.mlpackage | 804 KB | ⚠️ stub (нужен real fine-tune в Block E) |
| RussianPhonemeClassifier.mlpackage | 736 KB | ⚠️ val acc **83.9%** (нужно ≥85% — Block E retrain +1ч augmented) |
| EmotionDetection.mlpackage | 272 KB | ⚠️ нужно verify accuracy ≥75% |
| SpeakerVerification.mlpackage | 164 KB | ✅ d-vector CNN |
| PronunciationScorer × 4 | 108 KB each | ✅ INT8 (whistling/hissing/sonants/velar) |
| TonguePostureClassifier.mlpackage | 12 KB | ⚠️ обучена только на синтетике 1800 examples 100% acc (переобучение) — Block E real children data |
| SileroVAD.mlpackage | 52 KB | ✅ real CNN (не energy stub) |
| SoundClassifier.mlpackage | 20 KB | ✅ |

## Speech Analyzer state (Block E — depth)

| Component | LOC | Status |
|---|---|---|
| RussianG2P.swift | 457 | ✅ 7 phonetic rule categories |
| IPADictionary.swift | 462 | ✅ 49 Russian phonemes |
| RealMFCCExtractor.swift | 358 | ✅ vDSP FFT, 13 MFCC + Δ + ΔΔ = 39-dim |
| MelSpectrogramExtractor.swift | 290 | ✅ 1024-pt FFT, 40 Mel bands |
| PhonemeAnalysisServiceLive.swift | 264 | ⚠️ нужно расширить для phoneme-level scoring API |
| Wav2Vec2ServiceLive.swift | 211 | ✅ Wav2Vec2 inference pipeline |
| WhisperKitModelManager.swift | 392 | ✅ |
| SileroVAD.swift | 399 | ✅ real CNN wrapper |
| LLMDecisionService.swift | 612 | ✅ 25 decision points Tier A/B/C |
| RuleBasedDecisionService.swift | 939 | ✅ fallback engine |
| LLMModelManager.swift | 354 | ✅ Qwen2.5-1.5B download |
| LocalLLMService.swift | 257 | ✅ MLX-Swift inference |
| Spectrogram visualizer | существует | ⚠️ не интегрирован в game UI — Block E integrate |

## UI critical issues (audit findings от Explore #1)

| Issue | Severity | Block to fix |
|---|---|---|
| Только 1/100 файлов в Features использует @Environment(\.colorScheme) | P0 | Block F |
| LyalyaRealityKitView used только в 3 файлах из 100 | P0 | Block H + I |
| 10 файлов в Features имеют эмодзи | P0 | Block G |
| AppIcon: Any 806KB / Dark 810KB / Tinted 170KB разные размеры файлов = НЕ identical drawing | P0 | Block C |
| EN-keys в UI (некоторые String(localized:) calls без entries в xcstrings) | P0 | Block L |
| Только 1 из 12 HSCustom* компонентов фактически используется в Features | P0 | Block J |
| Onboarding: 3D героев нет (розовый прямоугольник вместо Lyalya) | P0 | Block I |
| 78 mp4 видео но не motion-design-level | P1 | Block O |
| Lottie infrastructure готова но фактическое использование 1 раз | P1 | Block N |

## Cleanup targets (Block B)

| Path | Size | Action |
|---|---|---|
| /Users/antongric/Downloads/HappySpeech | мусор | rm -rf |
| /Users/antongric/Downloads/HappySpeech_workshop | мусор (1 .py file) | rm -rf |
| /Users/antongric/Downloads/hs_appicon_dark_1024.png | мусор | rm -f |
| /Users/antongric/Downloads/hs_appicon_tinted_1024.png | мусор | rm -f |
| /Users/antongric/Downloads/hs_appicon_tinted_1024_grey.png | мусор | rm -f |
| _workshop/datasets/raw/ | ~1.9 GB (если есть) | rm -rf |
| _workshop/datasets/clean/train/ | ~1.0 GB (если есть) | rm -rf |
| _workshop/screenshots/v15_*, v16_* | старые | rm -rf |
| _workshop/coverage/v15_*, v16_* | старые | rm -rf |
| _workshop/audit/v15_*, v16_* | старые | rm -rf |
| _workshop/generate_lottie_tutorials.py | использован (68KB) | rm -f |
| .build_docc/, .build_test/ | temp | rm -rf |

## Localizable.xcstrings status

```
sourceLanguage: ru
total strings: 3806
en: 0 ✅
ru: 3806
```

Russian-only страж работает.

## Firebase services state (audit Block U expansion)

| Service | Active? | Notes |
|---|---|---|
| Auth (Email + Google + Anonymous) | ✅ | |
| Firestore | ✅ | rules + 14 indexes deployed |
| Cloud Functions | ⚠️ | 10 deployed, but callable functions stubs |
| Storage | ✅ | rules deployed |
| App Check (DeviceCheck) | ✅ | enforce |
| Remote Config | ✅ | template active |
| FCM | ✅ | parent-only opt-in |
| Performance Monitoring | ✅ | parent-only opt-in COPPA-safe |
| **Installations** | ❌ | NEW — Block U |
| **Dynamic Links** | ❌ | NEW — Block U |
| **A/B Testing** | ❌ | NEW — Block U |
| **Realtime Database** | ❌ | NEW — Block U |
| **Hosting** | ❌ | NEW — Block U (optional) |

## SPM packages (20 total)

Active в project.yml:
RealmSwift 20, FirebaseSDK 11, WhisperKit 0.9, SwiftTransformers 1.1.9, SnapshotTesting 1.17, Lottie 4.5, GoogleSignIn 7.1, RiveRuntime 6.0, Down 0.11, MLXSwift 0.31.3, MLXSwiftLM 3.31.3, SwiftuiParticles 1.0, Pulse 5.0, KeychainAccess 4.2.2, SwiftCollections 1.1.0, SwiftAsyncAlgorithms 1.0.0, SwiftNumerics 1.0.2, SwiftSyntax 600.0.0, SwiftUIShimmer 1.5.0, FloatingButton 1.4.0.

## Agents v18 model state (после Block A)

| Agent | Model | Effort |
|---|---|---|
| cto | claude-opus-4-7 | xhigh |
| code-reviewer | claude-opus-4-7 | xhigh |
| ios-developer | claude-opus-4-7 | xhigh |
| ml-engineer | claude-opus-4-7 | xhigh |
| animator | claude-opus-4-7 | xhigh |
| designer | claude-opus-4-7 | xhigh |
| backend-developer | claude-opus-4-7 | high (UPGRADE v18) |
| pm | claude-sonnet-4-6 | high (UPGRADE v18 from medium) |
| speech-specialist | claude-sonnet-4-6 | high |
| researcher | claude-sonnet-4-6 | high |
| ios-debugger | claude-sonnet-4-6 | high (UPGRADE v18 from medium) |
| qa-engineer | claude-sonnet-4-6 | high |
| sound-curator | claude-sonnet-4-6 | high |
| icon-generator | claude-sonnet-4-6 | high (UPGRADE v18 from low) |
| docs | claude-sonnet-4-6 | high (UPGRADE v18 from medium) |
| anthropic-docs | claude-sonnet-4-6 | high (UPGRADE v18 from medium) |

**Итого:** 7 Opus + 9 Sonnet, all @ high или extra-high.

## Plan v18 priorities (P0/P1)

### P0 critical (Phase 1-2)
1. Cleanup мусора (Block B)
2. AppIcon Single Size identical drawing (Block C)
3. 3D Lyalya transparent bg на ≥85 файлах (Block H)
4. Onboarding 3D fix + 2D anims removed (Block I)
5. Light/Dark adaptation 100/100 files (Block F)
6. 12 HSCustom* applied везде (Block J)
7. Эмодзи в 10 files → SF Symbols (Block G)
8. EN-keys в UI → fix (Block L)
9. Plain Russian language (Block M)
10. Manual screenshot audit 100+ × 2 themes (Block Z)

### P1 important (Phase 2-3)
11. Real Lottie professional replace (Block N)
12. Real motion design videos via Remotion (Block O)
13. Voice expansion 14500+ (Block P)
14. Illustrations RGBA regen 100% (Block Q)
15. 5+ новых экранов (Block R)
16. Speech specialist neurolinguist content +500 (Block S)
17. Apple HIG + WCAG full audit fix (Block T)
18. RussianPhonemeClassifier retrain ≥85% (Block E)
19. TonguePostureClassifier real children data (Block E)
20. Spectrogram visualizer integrate в games (Block E)

### P2 polish (Phase 3-4-5)
- Apply M findings UI improvements (Block AA)
- Content overflow + adaptive layout iPhone SE 3 (Block AB)
- Cleanup unused (Block AC)
- Code review final pass (Block AD)
- Simulator cleanup (Block AE)
- Firebase Cloud Functions callable + Installations + Dynamic Links (Block U)
- Test coverage 90%+ (Block V)
- Performance audit (Block W)
- Bundle 1.5 GB через depth (Block X)
- Build 0 warnings + 0 errors (Block Y)
- Git author cleanup verify (Block AF)
- Blender 3D characters (Block AG)
- Chrome MCP Firebase Console setup (Block AH)
- Final audit + recursive spawn (Block AI)
- App Store metadata final (Block AJ)
- Final QA pass (Block AK)
- README + sprint + ADR-V18-FINAL (Block AL)
- Tag v1.0.0-final-v18 (Block AM)
- Recursive verification (Block AN)
- Final READY declaration (Block AO)

## Environment

- Working directory: `/Users/antongric/Yandex.Disk.localized/xcode_projects/Диплом/HappySpeech`
- Project: HappySpeech.xcodeproj
- Bundle ID: com.mmf.bsu.HappySpeech
- Marketing Version: 1.0.0
- iOS deployment target: 17.0
- Swift 6.0 strict concurrency
- Simulator: iPhone SE (3rd generation) только
- Mac removed из destinations
- Vertical orientation only
- Russian-only mandate (CFBundleDevelopmentRegion=ru)
- Firebase project: happyspeech-dfd95 (antongric132@gmail.com)

## End of audit baseline.

**Next step:** Block B — Cleanup мусора (Downloads + _workshop)
