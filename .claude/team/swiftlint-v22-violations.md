# SwiftLint v22 Custom Rules — Initial Scan (2026-05-13)

**Block 0.3** — Plan v22 SwiftLint custom rules baseline.
Run: `swiftlint --no-cache` (NOT --strict yet, just scan).

## Custom rules added

| Rule | Severity | Excluded | Initial violations |
|---|---|---|---|
| `forbidden_color_literal` | error | ColorTokens.swift, HappySpeechTests | **14** |
| `forbidden_color_hex` | error | HappySpeechTests | **13** |
| `forbidden_uikit_white_black` | warning | LyalyaSceneView.swift | **27** |
| `prefer_async_stream_over_polling` | warning | HappySpeechTests | **2** |

**Total v22 custom rule violations:** 56 (27 errors + 29 warnings)

## Handoff

- **forbidden_color_literal** (14 errors) → Block 2.1 — Hardcoded colors → ColorTokens migration
- **forbidden_color_hex** (13 errors) → Block 2.1 — Color(hex:) deprecation + ColorTokens
- **forbidden_uikit_white_black** (27 warnings) → Block 2.1 cleanup (warnings OK to fix later)
- **prefer_async_stream_over_polling** (2 warnings) → Block 2.3 — FamilyVoice AsyncStream migration

## Strict mode

NOT enforced yet. Block 2.2 будет run `swiftlint --strict` после Phase 2 fixes. Target: 0 errors (warnings acceptable если documented).

## Verify command

```bash
swiftlint --no-cache | grep -E "forbidden_color_literal|forbidden_color_hex|forbidden_uikit_white_black|prefer_async_stream_over_polling" | sort | uniq -c | sort -rn
```
