# HappySpeech — Audit v17 Baseline (2026-05-07)

> Audit от 3 параллельных Phase 1 Explore агентов перед написанием Plan v17.
> Источник: `/Users/antongric/.claude/plans/valiant-wondering-sonnet.md` (Plan v17, Context section).

---

## Executive Summary

Plan v16 завершил 17 блоков из 22 (5 deferred), но критические проблемы решены частично:

- ❌ Полный screenshot audit 100+ экранов НЕ сделан (Block M v16 deferred — только 22 sample)
- ❌ 3D героев не видно на экранах (на онбординге пустое место)
- ❌ Light/Dark адаптация поверхностна (1/97 файлов с @Environment(.colorScheme); 18 hardcoded Color.white/black)
- ❌ Custom UI elements (12 HSCustom*) созданы но НЕ применены в Features (только 1 HSCustomAlert активен)
- ❌ AppIcon Any/Dark/Tinted имеют разные drawings (должны быть identical, отличаться только bg+tint)
- ❌ EN-keys в UI (missing translations в Localizable.xcstrings)
- ❌ 2D героев нужно убрать + анимации 2D-героев убрать
- ❌ Vertical orientation only verify
- ❌ _workshop/datasets/ 3.5 GB мусора
- ❌ Wav2Vec2 stub 312 KB (должно быть ~370 MB real)
- ❌ Lottie tutorials генератор unknown (могут быть python-lottie procedural)
- ❌ Firebase Cloud Functions / Installations / Dynamic Links missing
- ❌ Browser-based Firebase Console setup НЕ сделано

---

## Audit Findings (3 Phase 1 Explore Agents, 2026-05-07)

### Agent #1 — UI Quality

**Метрики:**
- 97 *View.swift files (target 100+, gap −3)
- 1/97 файлов с `@Environment(\.colorScheme)` — критично мало
- 18 hardcoded Color.white/black в Features/ARFaceFilter, ARZone, Customization
- 9 Custom UI components (Block O v16 создал 12, но только 1 фактически применён)
- 0 эмодзи в production strings ✅
- Lip-sync ARMirror реализован ✅
- Vertical orientation only verified ✅
- Mac destinations removed verified (`SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO`)

**Critical files:**
- `/HappySpeech/Features/ARFaceFilter/ARFaceFilterView.swift` — Color.white.opacity(0.30)
- `/HappySpeech/Features/ARZone/ARZoneViewCards.swift` — Color.white
- `/HappySpeech/Features/Customization/CustomizationViewCards.swift`

### Agent #2 — Assets Quality

**Метрики:**
- Project size 26 GB (3.5 GB мусора в _workshop/datasets/)
- 464 PNG illustrations — mix RGB/RGBA (RGB issues: `reward_heart`, `reward_scientist`, `word_chair`, `scene_space`, `emotion_kind`)
- 22 USDZ — большинство stubs (3-7 KB), реальные только `scene_solar_panels.usdz` 4.7 MB и `lyalya3d_v2.usdz` 106 KB
- 77 MP4 videos (47 MB) — Remotion-generated
- 13 344 audio (213 MB) — 174 файла с wrong sample rate
- 24 AppIcon PNG (Any/Dark/Tinted × 8 sizes) — все 3 варианта имеют **identical RGB encoding** (нет реальной differentiation Dark/Tinted!)
- 58 Lottie JSON — НЕТ meta.generator field (могут быть python-lottie)
- 956 MB Models (74% Resources) — Wav2Vec2 312 KB stub (должен быть ~370 MB)

**Bundle Resources breakdown:**
- Models 956 MB (74%)
- Audio 213 MB
- Illustrations 95 MB
- Videos 47 MB
- ARAssets 5.4 MB
- Animations 3.8 MB
- Total 1.3 GB → target 1.5 GB

**AppIcon issue:** все 24 файла Any/Dark/Tinted идентичны, должны:
- Any: оригинальный красивый рисунок
- Dark: identical drawing с Any, только background dark navy/black
- Tinted: identical drawing с Any, tint filter применён по Apple HIG

### Agent #3 — Code Health + Firebase

**Метрики:**
- 0 TODO/FIXME/HACK ✅
- 0 force unwraps в Features ✅
- 0 print() statements ✅
- Build clean (0 warnings/errors)
- 119 unit tests + 8 UI tests = 127 test files
- Coverage 35.9% (target 90%, gap ~600 unit tests)
- 20 SPM packages active
- 24 content seed JSON files
- 22 screenshots в _workshop/screenshots/v16_qa/

**Firebase services status:**
- ✅ Auth (Email/Google/Anonymous) — `LiveAuthService.swift`
- ✅ Firestore (10 Cloud Functions deployed)
- ✅ FCM (`FCMService.swift`)
- ✅ Storage (`ContentPackDownloadService.swift`)
- ✅ Remote Config (`RemoteConfigService.swift`)
- ✅ App Check DeviceCheck (`HappySpeechApp.swift`)
- ✅ Performance Monitoring (parent opt-in COPPA)
- ❌ Cloud Functions callable — stub only, no actual invocations from Swift
- ❌ Firebase Installations — missing
- ❌ Firebase Dynamic Links — missing

**MLX-Swift Qwen status:**
- LocalLLMService integrated, но fallback rule-based only
- Block H v16 не подключён в kid circuit полностью

**Speech analyzer:**
- ✅ RealMFCCExtractor (39-dim MFCC)
- ✅ RussianPhonemeClassifier (CoreML, 1.35 MB)
- ✅ EnsembleASRService (Tier A/B weighted voting)
- ❌ G2P/IPA mapping для русского отсутствует (нужен per phonetic analysis requirement)

---

## Top 5 Critical для Plan v17

1. **AppIcon Single Size + identical drawings** — Block E
2. **Real Wav2Vec2 + G2P/IPA** — Block B (replace 312 KB stub → 370 MB real)
3. **Light/Dark systematic 97 экранов** — Block F (только 1/97 имеет colorScheme adaptation)
4. **Apply 12 HSCustom* в Features** — Block G (созданы, но не применены)
5. **Manual screenshot audit 100+ экранов** — Block M (deferred v16, теперь критично)

---

## Cleanup potential

- _workshop/datasets/raw/ (1.9 GB) → удалить (Block C)
- _workshop/datasets/clean/train/ (1.0 GB) → удалить (Block C)
- _workshop/screenshots/ (старые v15/v16) → удалить (Block C)
- _workshop/coverage/ (старые) → удалить (Block C)
- Total потенциал: 3.5 GB → 22 GB project size

---

**Создано:** 2026-05-07 в Plan v17 Block A (на основе 3 параллельных Phase 1 Explore agents)
