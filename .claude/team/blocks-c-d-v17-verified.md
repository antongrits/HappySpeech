# Block C + D v17 Verification (2026-05-07)

## Block C — _workshop cleanup (-3.2 GB)

**Удалено:**
- `_workshop/datasets/raw/` (1.9 GB)
- `_workshop/datasets/clean/train/` (1.0 GB)
- `_workshop/screenshots/` (16 MB старых v15/v16)
- `_workshop/coverage/` (старые reports)

**Метрики:**
- _workshop: 3.8 GB → 595 MB (-3.2 GB)
- Project total: 26 GB → 23 GB (-3 GB)

**Сохранено в _workshop (полезное):**
- audit/ (536 KB) — audit reports
- audio_refs/ (7.9 MB) — TTS reference audio для ML
- generated_masters/ (1.6 MB) — voice generation masters
- icons/ (1.2 MB)
- illustrations/ (27 MB) — generated illustrations
- ml/ (14 MB) — ML training scripts/configs
- remotion/ (537 MB) — Remotion video projects
- design-specs / lottie_attributions / lyalya_phrases — manifests

`_workshop/` уже в `.gitignore` (line 1) — git операции не нужны.

## Block D — iPhone-only verification

**Verified:**
- ✅ `TARGETED_DEVICE_FAMILY = "1"` (iPhone only, NOT iPad)
- ✅ `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO` (visionOS NOT supported)
- ✅ Нет `SUPPORTS_MACCATALYST` (Mac Catalyst NOT supported)
- ✅ Нет `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD` (Mac Designed for iPhone NOT supported)
- ✅ `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]` only (NO landscape)
- ✅ Entitlements clean (только App Groups, не Mac-specific)
- ✅ BUILD SUCCEEDED iPhone SE (3rd generation)

**Платформы:** **ТОЛЬКО iPhone, portrait orientation only.**

Plan v17 Block D requirements выполнены — никакие изменения в project.yml не нужны.
