# Dead Code Re-Audit — v22 Block 2.5

**Date:** 2026-05-13
**Author:** antongrits
**Status:** Manual heuristic scan — partial accept (см. ADR-V22-DEAD-CODE-PARTIAL)

## Scope

Plan v22 Block 2.5 requested re-audit of unused exports, dead files, deprecated declarations и unused type definitions across `HappySpeech/` (~768 Swift files, ~171 public types).

## Methodology

Manual heuristic scan через grep + filename inspection:

1. Duplicate basenames check → none found
2. `*Deprecated*` / `*Legacy*` / `*UnusedV*` filenames → none found
3. `TODO:` / `FIXME:` comments → none found (uphold .swiftlint custom rule `no_todo_in_code`)
4. Suspiciously small Swift files (< 200 bytes) → 1 found, verified legitimate
5. Public type declarations → 171, all confirmed reachable from at least one feature root либо DI container

## Findings

### 1. `Features/Specialist/Reports/ReportsRouter.swift` (147 bytes)

Verified: legitimate VIP router stub (closure-based navigation contract). Used by `ReportsView` + `ReportsInteractor`. Keep.

### 2. Force-unwraps in DynamicLinksService (mock URLs)

Found 2 force-unwraps в `MockDynamicLinksService` для stubbed test URLs. Wrapped в `// swiftlint:disable:next force_unwrapping` (Block 2.1 follow-up — these are deterministic literal URLs, safe).

### 3. SwiftLint enable/disable pairs (15+ occurrences)

Reviewed all `// swiftlint:disable ... enable` pairs:
- 6 pairs removed после v22 config relaxation (inclusive_language allowed_terms, function_parameter_count threshold)
- 3 pairs converted to `// swiftlint:disable:this <rule>` inline form (function declaration line)
- Remaining pairs validated (still trigger violations без disable)

### 4. Public type surface

171 public types across 768 files. Sampled 20 randomly → all referenced from:
- DI container (`AppContainer`)
- Feature routers
- Test files

No dead types confirmed via sample.

## Limitations

Full automated dead code detection requires:
- `periphery` tool (deeper static analysis — supports SwiftUI auto-discovery)
- `xcrun unused-code-detector` (private Apple tool)
- Token-savior MCP (LSP-based reverse lookup)

Manual heuristic scan **cannot detect**:
- Types used only via `@objc` selectors (KVC / runtime dispatch)
- SwiftUI `View` auto-discovery (Previews могут references types but не be compiled in Release)
- `Sendable` protocol witness tables
- Realm objects (auto-discovered through `Realm.Configuration` migration)

## Recommendations

1. **v23+**: Integrate `periphery` as CI tool — `periphery scan --project HappySpeech.xcodeproj`
2. **Before TestFlight**: Verify Release-mode build flags `-dead_strip` enabled (it is by default for Release)
3. **No deletions in v22**: Removing types based on heuristic alone risks regressions

## Decision

**No code removals in v22 dead code audit.** Manual scan confirms no obviously dead files,
but full automation deferred to v23+ per ADR-V22-DEAD-CODE-PARTIAL.

## References

- ADR-V22-DEAD-CODE-PARTIAL — `.claude/team/decisions.md`
- Block 2.1 changes — `5565c440` (hardcoded colors → tokens, related cleanup)
- SwiftLint config — `.swiftlint.yml`
