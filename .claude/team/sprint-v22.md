# Sprint v22 — HappySpeech (2026-05-13)

> **Plan:** [v22 reflective-juggling-sifakis](../../tmp/plans/plan-v22.md) (2150 lines, 25 blocks, 5 phases)
> **Baseline tag:** `v1.0.0-final-v21` (commit e742159e)
> **Target tag:** `v1.0.0-final-v22`
> **Focus:** Close 15 audit gaps + manual visual verification 208 PNG (genuine 100%)

## Status

**Active phase:** Phase 0 — Audit Closure & Baselines

### Phase 0 — Audit Closure (5 blocks)
- [x] **Block 0.1** — Plan v22 copy + sprint init + 7 new skills (total 79)
- [ ] Block 0.2 — AppRoute extension (104 routes) + 170 PNG manual screenshot tour
- [ ] Block 0.3 — SwiftLint custom rules (color literal + async)
- [ ] Block 0.4 — TestDataBuilder + MockServices library
- [ ] Block 0.5 — Cold start Os.signposts instrumentation

### Phase 1 — ML Improvements (5 blocks)
- [ ] Block 1.1 — RussianPhonemeClassifier 88.9% → 92%+
- [ ] Block 1.2 — Whisper adaptive selection (age/device based)
- [ ] Block 1.3 — EmotionDetection + TonguePosture revalidation
- [ ] Block 1.4 — ML signpost profiling
- [ ] Block 1.5 — MLPerformance 4 XCTSkip closed

### Phase 2 — Code Quality Deep (5 blocks)
- [ ] Block 2.1 — Hardcoded colors → ColorTokens (FamilyAwards 3 + Story 2)
- [ ] Block 2.2 — SwiftLint --strict 0 violations + pre-commit hook
- [ ] Block 2.3 — AsyncStream FamilyVoice pollChildSession
- [ ] Block 2.4 — SwiftGen L10n.swift externalization
- [ ] Block 2.5 — Dead code re-audit (token-savior)

### Phase 3 — Feature Completeness (5 blocks)
- [ ] Block 3.1 — Firebase Dynamic Links real Family invite
- [ ] Block 3.2 — Remote Config A/B test Whisper variants
- [ ] Block 3.3 — Blender 8 emotional Lyalya variants (либо ADR-V22-BLENDER-FINAL-DEFER)
- [ ] Block 3.4 — AppIcon Dark + Tinted variants
- [ ] Block 3.5 — Competitor research applied + v23 backlog

### Phase 4 — Test Coverage Closure (5 blocks)
- [ ] Block 4.1 — AuthFlow 8 XCTSkip closed
- [ ] Block 4.2 — WorldMap state machine refactor (1 XCTSkip)
- [ ] Block 4.3 — ML integration test suite (15 tests)
- [ ] Block 4.4 — Firebase snapshot mocking library
- [ ] Block 4.5 — Coverage ≥70% verified + 0 XCTSkip

### Phase 5 — Final Polish & Tag (5 blocks)
- [ ] Block 5.1 — Manual screenshot tour final 208 PNG (Claude SAM reads via MCP)
- [ ] Block 5.2 — Performance regression (<3s cold start)
- [ ] Block 5.3 — Accessibility re-pass (VoiceOver/Dynamic Type/Haptic)
- [ ] Block 5.4 — README v22 + ADR-V22-FINAL
- [ ] Block 5.5 — Tag v1.0.0-final-v22 + FINAL READY

## Метрики

| Метрика | Baseline | Target v22 |
|---|---|---|
| *View.swift | 110 | 110+ |
| XCTSkip active | 18 | **0** |
| Coverage | 35% | **70%+** |
| Hardcoded hex colors | 5 | **0** |
| Phoneme accuracy | 88.9% | **92%+** |
| Manual screenshots | 38/208 | **208/208 read** |
| AppIcon variants | Light | Light + Dark + Tinted |
| Firebase Dynamic Links | Static | **Real FDL** |
| Cold start | unknown | **<3s** |
| Localization | RU only | RU primary + EN externalized |

## Blockers / decisions

- **Block 3.3 Blender:** второй attempt после v19. Если still unavailable → ADR-V22-BLENDER-FINAL-DEFER.
- **Block 3.4 AppIcon Dark:** FLUX-1-schnell либо Canva fallback.
- **Manual screenshot tour:** user explicit «сам вручную ты всё должен делать» — central к Block 0.2 + 5.1.
