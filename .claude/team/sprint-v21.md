# Sprint v21 — HappySpeech (2026-05-13)

> **Plan:** [v21 humming-sprouting-sun.md](../../tmp/plans/plan-v21.md) (5115 lines, 45 blocks, 9 phases)
> **Baseline tag:** `v1.0.0-final-v19` (commit 9fb4f2e8)
> **Target tag:** `v1.0.0-final-v21`
> **Focus:** UI/UX-heavy (vs ML-heavy v19)

## Status

**Active phase:** Phase 0 — Preparation

### Phase 0 — Подготовка (4 blocks)

- [x] **Block 0.1** — Yandex.Disk skip-worktree + agent .md edits + Downloads cleanup (commit 006acb53)
  - 81 files skip-worktree (78 MP4 + 3 ML model artifacts)
  - 6 agent .md verified (5 Opus xhigh, designer Opus high)
  - Downloads cleaned
- [ ] **Block 0.2** — Build issues fix (in progress)
  - ✅ swift-syntax conflict resolved (apple/* → swiftlang/*)
  - ✅ Duplicate audio files removed (lyalya_daily_goal_b/c.m4a из settings/)
  - ⏳ MLXHuggingFaceMacros — нужен manual Xcode UI enable (defer ADR)
  - ⏳ Build Debug retry pending
- [x] **Block 0.3** — 8 new skills created
  - screen-by-screen-deep-audit-skill
  - cloud-functions-deep-features-skill
  - tongue-posture-classifier-retrain-skill
  - xcstrings-key-coverage-audit-skill
  - ipad-iphone-mac-removal-verify-skill
  - derived-data-auto-cleanup-hook-skill
  - competitor-feature-gap-analysis-skill
  - git-yandex-disk-recovery-skill
- [x] **Block 0.4** — Baseline audit copy + sprint.md v21 init

### Phase 1 — Manual Screenshot Audit (4 blocks)
- [ ] Block A — 208 PNG capture + read each manually
- [ ] Block B — UI redesign P0 fixes
- [ ] Block C — Эмодзи purge DesignSystem (11 places)
- [ ] Block D — Single UI theme verify

### Phase 2 — UI Polish & Redesign (7 blocks)
- [ ] Block E — 3D Lyalya migration top-30
- [ ] Block F — Light/Dark 99 screens
- [ ] Block G — kavsoft custom UI apply
- [ ] Block H — iPhone SE 3 overflow fix
- [ ] Block I — Localization key coverage
- [ ] Block J — HSMascotView anim removal
- [ ] Block K — 2D mascot cleanup unified

### Phase 3 — Code Quality & Cleanup (6 blocks)
- [ ] Block L — Dead code
- [ ] Block M — Whisper consolidation + backups
- [ ] Block N — _workshop pruning + DerivedData hook
- [ ] Block O — Hex colors → ColorTokens
- [ ] Block P — Real Lottie verify
- [ ] Block Q — DispatchQueue → Task

### Phase 4 — ML, CV, Speech (5 blocks)
- [ ] Block R — Phoneme 88.9 → 92%+
- [ ] Block S — Tongue retrain real
- [ ] Block T — G2P/IPA Russian
- [ ] Block U — Real-time CV
- [ ] Block V — Voice clone + warm-up

### Phase 5 — Firebase Deep (3 blocks)
- [ ] Block W — Audit Chrome MCP
- [ ] Block X — Cloud Functions deep
- [ ] Block Y — Remote Config A/B + Dynamic Links

### Phase 6 — Tests 100% (3 blocks)
- [ ] Block Z — Coverage baseline
- [ ] Block AA — 65 new test files
- [ ] Block AB — Snapshot 208 + integration

### Phase 7 — Content & Features (3 blocks)
- [ ] Block AC — +500 lessons + Big libs
- [ ] Block AD — Competitor gap
- [ ] Block AE — 6 new VIP screens (110+)

### Phase 8 — HIG & Accessibility (4 blocks)
- [ ] Block AF — HIG verify per screen
- [ ] Block AG — Performance audit
- [ ] Block AH — Plain Russian
- [ ] Block AI — Final project audit

### Phase 9 — Final (4 blocks)
- [ ] Block AJ — App Store metadata + AppIcon Dark
- [ ] Block AK — Build Release 0 warn
- [ ] Block AL — Simulator + Git cleanup
- [ ] Block AM — Tag v1.0.0-final-v21

## Blockers / decisions

- **MLXHuggingFaceMacros macro:** требует manual Xcode UI Trust&Enable. Document как ADR-V21-MLX-MACRO post-build verify. Не блокирует build если macro используется только для editor functionality (что подтверждается ошибкой "must be enabled before it can be used in support of editor functionality").

## Метрики (по состоянию начала v21)

| Метрика | Baseline | Target |
|---|---|---|
| *View.swift | 104 | 110+ |
| Эмодзи в DesignSystem | 11 | 0 |
| 3D Lyalya screens | 2/104 (1.9%) | 30+/104 |
| Light/Dark @Environment | 5/104 | 104/104 |
| iPhone SE 3 overflow risk | 25 files | 0 |
| Tests coverage | unknown | 90%+ measured |
| Resources size | 1.5 GB | ≤1.5 GB |
| Hex colors hardcoded | 27 places | 0 |
| HSMascotView animations | 3 hooks | 0 unconditional |
| Build status | mixed | 0 warn + 0 err |
