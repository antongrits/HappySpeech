# Firebase Config v22 — Registry

**Plan:** v22 Phase 3
**Date:** 2026-05-13
**Author:** antongrits

## Block 3.1 — Dynamic Links (Family Invite)

**Status:** Active service implemented, FDL deprecated upstream.

### Current state
- `HappySpeech/Services/DynamicLinksService.swift` — Live + Mock impl
- Используется в Family Invite (parent → secondary parent / observer)
- Payload: `linkType`, `familyId`, `role` (primary/secondary/observer), `inviterUid`, `expiresAt`, `extraParams`
- Errors: `invalidConfiguration`, `linkCreationFailed`, `linkResolutionFailed`, `expiredLink`, `invalidPayload`

### Upstream deprecation
Google announced Firebase Dynamic Links sunset: **August 25, 2025**. Service продолжает работать до этой даты, но не принимает новых customers и не получает feature updates.

### v22 decision
**Defer migration к Universal Links + AssociatedDomains** на v23 (см. ADR-V22-FDL-DEPRECATED). Текущая реализация работоспособна для diploma defense.

### Metric tracking placeholder
Внутренние events (через локальную `AnalyticsService` шину без external SDK):
- `family_invite_created` — payload: `{ role, expiresInDays }`
- `family_invite_opened` — payload: `{ linkType, success }`
- `family_invite_expired` — payload: `{ role }`

---

## Block 3.2 — Remote Config A/B (Whisper variants)

**Status:** Parameter documented; deploy через user-side Firebase Console.

### Existing Remote Config parameters (HappySpeech/Services/RemoteConfigService.swift)
- 8 feature flags (`feature_*_enabled`)
- 4 content config (`lyalya_voice_default`, `daily_reminder_time`, `weekly_summary_day`, `parent_summary_day`)
- 3 onboarding/session (`onboarding_skip_allowed`, `demo_mode_steps`, `max_session_duration_min`)
- 2 UI flags (`home_show_streak_celebration`, `parent_dashboard_show_ml_insights`)
- 2 version management (`min_app_version`, `force_update_min_version`)
- 1 A/B test (`tutorial_variant` — A/B)

### NEW parameter: whisper_model_override

| Property | Value |
|---|---|
| Key | `whisper_model_override` |
| Type | string |
| Default value | `auto` |
| Allowed values | `auto`, `always_small`, `always_base` |
| Description | Override Block 1.2 device-tier logic для A/B Whisper model selection |
| Conditions | Initial: 100% audience, equal split between variants |
| Activation | App launch (after `fetch() + activate()`) |
| Success metric | `speech_accuracy_score` (internal AnalyticsService event) |
| Min sample size | 100 sessions per variant (estimated 2 weeks с дефолтным trafic) |

### Variants

| Variant | Model | Hypothesis |
|---|---|---|
| Control (`auto`) | Device-tier auto select (Block 1.2 logic) | Baseline — adaptive selection works |
| Variant A (`always_small`) | `whisper-small.en` (~244M params) | Higher accuracy, более slow на low-tier |
| Variant B (`always_base`) | `whisper-base.en` (~74M params) | Lower latency, sufficient accuracy |

### Deploy steps (user-side via Firebase Console)
1. Firebase Console → Project `happyspeech-prod` → Remote Config
2. Add parameter `whisper_model_override`, default `auto`
3. Add condition `whisper_ab_test_small` — 33% random audience → `always_small`
4. Add condition `whisper_ab_test_base` — 33% random audience → `always_base`
5. Publish changes
6. iOS side: Block 1.2 logic уже проверяет `whisper_model_override`, при значении ≠`auto` использует override

### Integration in iOS
В `RemoteConfigService.swift` потребуется добавить:
```swift
public protocol RemoteConfigService {
    // ...
    var whisperModelOverride: String { get }  // "auto" | "always_small" | "always_base"
}
```
И ключ `whisper_model_override` в `RCKey` enum. **Эта интеграция — задача v23 (defer вместе с deploy)**.

---

## Block 3.3 — Blender 3D Lyalya

**Status:** Final defer (ADR-V22-BLENDER-FINAL-DEFER).

Не относится к Firebase Config. См. decisions.md.

---

## Block 3.4 — AppIcon variants

**Status:** ALREADY COMPLETED in earlier sprint (v21).

`HappySpeech/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` уже регистрирует:
- `AppIcon-Any-1024.png` (Light/default)
- `AppIcon-Dark-1024.png` (luminosity: dark)
- `AppIcon-Tinted-1024.png` (luminosity: tinted, iOS 18+)

iOS automatic selection по system appearance работает out-of-the-box.

**Note (v21 audit):** Dark variant procedural quality flagged как "ugly" в v21 ADR-V21-AJ-DARKICON-DEFER. Visual polishing — defer на v23 (manual Figma/Sketch redesign).
