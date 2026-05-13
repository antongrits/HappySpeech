---
name: recursive-audit-loop-skill
description: Workflow для recursive audit→fix→audit loop без верхней границы. Документирует pattern для HappySpeech Plan v23 Phase 6 — cto Opus audit → spawn fix block → re-audit → loop до 0 findings. Used в HappySpeech Plan v23.
tools: Read, Write, Bash
---

# Recursive Audit Loop — без верхней границы

## Когда использовать

Пользователь явно сказал: «делать loops audit→fix→audit→fix пока всё не идеально». Это финальный этап перед сдачей проекта.

## Pattern

```
1. cto Opus xhigh — full project audit (read проекта + cross-check всех планов)
2. code-reviewer Opus xhigh — INDEPENDENT review (не видит cto report)
3. Main loop: merge findings → categorize P0/P1/P2
4. Spawn fix Block per P0 finding (sequential — может parallel ≤3 если non-conflicting)
5. Verify each fix done → commit
6. После closing P0 → re-run steps 1-2 (audit again)
7. If findings remain (any P0/P1) → loop continue
8. If 0 findings P0+P1 → proceed Phase 7 (final tag)
```

## Iteration template

Iteration N (N=1,2,...):
- `.claude/team/v23-audit-iteration-N.md` — findings file
- Spawn fix block: `Agent(ios-developer Opus, "Fix finding #X from v23-audit-iteration-N.md")`
- Commit: `fix(audit): 6.N v23 iteration <N> — closed P0 finding #X`
- Re-audit → next iteration

## NO upper bound

Loop continues пока:
- cto находит ≥1 finding P0/P1 → spawn fix → next iter
- OR пользователь явно говорит «всё, хватит» → переход к Phase 7

## Audit criteria template

cto agent должен check:

### Code health
- 0 TODO/FIXME/HACK/XXX
- 0 print() statements
- 0 force unwraps в production (Features/Services/Workers)
- 0 Color.white/.black hardcoded
- 0 XCTSkip активных
- 0 SwiftLint --strict errors
- 0 build warnings

### UI quality
- Каждый *View.swift имеет 3D Lyalya либо professional 2D illustration
- Light/Dark adaptive (@Environment(\.colorScheme) where needed)
- Touch targets ≥56pt kids / ≥44pt adults
- VoiceOver labels 100% interactive
- Dynamic Type Small→AccessibilityLarge OK
- No content overflow iPhone SE 3 (320pt)
- No эмодзи в UI strings
- No EN-keys leak (все String(localized) имеют ru entry)

### Localization
- 0 en keys in Localizable.xcstrings
- Plain Russian language (no technical jargon в kid UI)

### Tests
- Coverage ≥85%
- 0 meaningless XCTAssertTrue(true) tests
- 0 XCTSkip
- UI tests cover ≥100 screens

### Architecture
- Clean Swift VIP compliance per Feature
- AppContainer DI без singletons
- Services через protocols only
- Realm migrations не destructive

### Assets
- AppIcon Single Size 3 PNG (Any/Dark/Tinted)
- Lottie meta.generator = Bodymovin/After Effects (real)
- 3D Lyalya USDZ real (≥100 KB)
- Wav2Vec2 real ≥300 MB (not stub)

### Firebase
- Auth + Firestore + FCM + Storage + RemoteConfig + AppCheck + CloudFunctions активны
- App Check enforced production
- Security rules deployed

### Project hygiene
- No *.bak files в repo
- _workshop/screenshots/ ≤50 MB
- DerivedData old (>3 days) auto-cleaned via Stop hook
- 0 Co-Authored-By: Claude в v23 коммитах
- Git author = antongrits

## Exit criteria

`Phase 6 closed = 0 findings P0/P1` в одной итерации (cto+code-reviewer оба возвращают clean report).

## Verification per iteration

```bash
echo "=== Iteration <N> audit results ==="
echo "P0: $(grep -c '^### P0' .claude/team/v23-audit-iteration-${N}.md)"
echo "P1: $(grep -c '^### P1' .claude/team/v23-audit-iteration-${N}.md)"
echo "P2: $(grep -c '^### P2' .claude/team/v23-audit-iteration-${N}.md)"
```

When P0 + P1 == 0 → proceed Phase 7 (final tag).
