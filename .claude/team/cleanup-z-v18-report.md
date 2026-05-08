# Block AC v18 — Cleanup Audit Final Report

**Date:** 2026-05-08
**Status:** COMPLETE (audit + safe cleanup applied)
**Approach:** Conservative — verify before delete

## AC.5 — _workshop cleanup (executed)

Removed:
- `_workshop/screenshots/v17_full_audit/` (deprecated, replaced by v18 verification)
- `_workshop/scripts/audit_localization_keys_v18.py` (retired post-Block L use)
- `_workshop/**/__pycache__/` (Python cache)
- `_workshop/**/*.pyc` files
- Empty audit subdirs

Total saved: ~26 MB. _workshop now 617 MB.

## AC.6 — Localizable.xcstrings unused keys

- Total ru keys: 3827
- Used in code (literal): 3214
- Potentially unused: 615
- **Decision:** NOT deleted. Many a11y/accessibility keys loaded dynamically через `Label("text", systemImage:)` или format strings. Manual triage required post-v1.0.
- Audit log: `_workshop/audit/v18-unused-xcstrings-keys.txt`

## AC.3 — Illustrations RGBA audit

- Total imagesets in Assets.xcassets/Illustrations/: 154
- Whitelist patterns matched: 114 (skip — likely dynamic loading)
- Non-whitelist with 0 grep refs: 38
- **Decision:** NOT deleted. May be loaded via `Image(named:)` или Asset name reference. Block Q (Illustrations RGBA regen) has authority on illustrations changes.
- Audit log: `_workshop/audit/v18-unused-illustrations.txt`

## AC.1 — Dead code

- Private functions без callers: 0
- **Result:** Project clean. No dead code findings.

## AC.2 — SPM packages

| Package | Direct imports |
|---|---|
| RealmSwift | 17 ✅ |
| FirebaseAuth | 1 ✅ |
| FirebaseFirestore | 3 ✅ |
| FirebaseStorage | 1 ✅ |
| WhisperKit | 3 ✅ |
| Lottie | 1 ✅ |
| GoogleSignIn | 2 ✅ |
| RiveRuntime | 0 ⚠️ |
| Down | 1 ✅ |
| MLX | 2 ✅ |
| Pulse | 1 ✅ |
| KeychainAccess | 1 ✅ |
| SwiftCollections | 2 ✅ |
| SwiftAsyncAlgorithms | 1 ✅ |
| SwiftNumerics | 0 ⚠️ |
| SwiftSyntax | 0 ⚠️ |
| SwiftUIShimmer | 0 ⚠️ |
| FloatingButton | 0 ⚠️ |

**Decision:** Conservative — KEEP all 20 packages. 0-import packages могут быть:
1. Transitive dependencies в Package.resolved (FirebaseSDK pulls some)
2. Used through Skill/wrapper (LottieView wraps Lottie)
3. Future-ready (Block J Group C может использовать SwiftUIShimmer/FloatingButton)
4. Used in private SPI (SwiftSyntax часто for build tools)

Manual remove только after detailed transitive analysis post-v1.0.

## AC.4 — Content packs

- 25 content packs в HappySpeech/Content/Seed/
- All packs показывают 0 direct refs в Swift code
- **Reason:** All packs loaded dynamically через `ContentEngine.swift` Bundle resources iteration
- **Result:** All 25 packs USED (false positive grep). ContentEngine pattern: `Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Content/Seed")`.
- **Decision:** KEEP all 25 packs.

## Block AC v18 — Final summary

- ✅ AC.5: Removed deprecated workshop files (-26 MB)
- ✅ AC.6: Audit complete (615 potentially unused keys, NOT deleted)
- ✅ AC.3: Audit complete (38 potential unused illustrations, NOT deleted — Block Q authority)
- ✅ AC.1: 0 dead code
- ✅ AC.2: All 20 SPM packages KEPT (conservative)
- ✅ AC.4: All 25 content packs verified used (dynamic loading)

**Project clean assessment:** Generally healthy. Minor potential cleanup opportunities (illustrations, xcstrings) deferred к Block Q (authority) и post-v1.0 manual review.

