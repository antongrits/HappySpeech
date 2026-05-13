# Plan v21 Block Y — Remote Config + A/B Testing

**Дата:** 2026-05-13
**Статус:** VERIFY-ONLY (no code changes)
**Контекст:** Block W audit baseline, ADR-V18-U (Dynamic Links replacement)

---

## Current state

### Remote Config

- **Service:** active — `HappySpeech/Services/RemoteConfigService.swift`
  - Protocol: `RemoteConfigService` (Sendable, @Observable LiveRemoteConfigService)
  - Mock: `MockRemoteConfigService`
  - Bootstrap в `HappySpeechApp.swift:165` — `fetch + activate + startRealtimeUpdates`
  - DI: `AppContainer.remoteConfigService` (lazy live + preview-mock)
- **SDK linked:** `FirebaseRemoteConfig` через SPM (`project.yml:204`)
- **Min fetch interval:** 3600 s (production); 0 s в Mock
- **Realtime updates:** через `addOnConfigUpdateListener`, активация автоматическая

#### Templates defined (21 ключ)

**Feature flags (8):**
- `feature_seasonal_events_enabled` (default true)
- `feature_voice_clone_enabled` (default false)
- `feature_body_tracking_enabled` (default true)
- `feature_realtime_lipsync_enabled` (default false)
- `feature_spectrogram_enabled` (default true)
- `feature_emotion_detection_enabled` (default true)
- `feature_speaker_verification_enabled` (default true)
- `feature_qwen_kid_circuit` (default false)

**Content config (4):**
- `lyalya_voice_default` ("pro")
- `daily_reminder_time` ("17:00")
- `weekly_summary_day` ("sunday")
- `parent_summary_day` ("sunday")

**Onboarding & session (3):**
- `onboarding_skip_allowed` (true)
- `demo_mode_steps` (15)
- `max_session_duration_min` (25)

**UI flags (2):**
- `home_show_streak_celebration` (true)
- `parent_dashboard_show_ml_insights` (true)

**Version management (2):**
- `min_app_version` ("1.0.0")
- `force_update_min_version` ("1.0.0")

**A/B Testing (1):**
- `tutorial_variant` (default "A") — Block U.5 v18, activation event `app_first_open`

#### Usage в app (consumers)

- `FCMService` — gating push reminders по `daily_reminder_time`
- `ContentPackDownloadService` — sezonal events flag
- `CloudFunctionsService` — feature gates для серверных функций
- Home/Parent screens — `home_show_streak_celebration`, `parent_dashboard_show_ml_insights`
- Onboarding — `tutorial_variant` (A/B), `onboarding_skip_allowed`, `demo_mode_steps`

### A/B Testing

- **ABTesting SDK linked:** **NO** — `FirebaseABTesting` отсутствует в `project.yml`
- **Active experiments:** none (production)
- **Tutorial A/B (Block U.5 v18):** реализован через Remote Config `tutorial_variant`
  — Firebase A/B Testing console может управлять распределением без отдельного SDK
  (через server-side targeting на параметре Remote Config)

### Installations

- **Service:** active — `HappySpeech/Services/InstallationsService.swift`
  - Protocol: `InstallationsServiceProtocol` (Sendable)
  - Live: `LiveInstallationsService` (через `Installations.installations()`)
  - Mock: `MockInstallationsService`
  - DI: `AppContainer.installationsService`
- **SDK linked:** `FirebaseInstallations` через SPM (`project.yml:212`)
- **Anonymous → upgrade flow:** запись `installationID` в Firestore-профиль при первом запуске; flow подтверждён в Block W audit (verified)

### Dynamic Links replacement (ADR-V18-U)

- **createFamilyInviteToken Cloud Function:** verified в Block W (active в backend)
- **Token-based flow vs Dynamic Link:**
  - Старый: `FirebaseDynamicLinks` (deprecated Aug 2025 by Google)
  - Новый: server-issued JWT-like token → child-side claim через onCall function
  - Преимущество: работает без Dynamic Links инфраструктуры, проще QR-флоу
- **Note:** `FirebaseDynamicLinks` product ещё linked в `project.yml:214` (legacy compat для существующих ссылок). Defer удаление до v22 (deprecation grace period).

---

## Recommendations for v22+

1. **A/B Test для Onboarding variants**
   — Classic (current 5-step) vs Parallax (scrolling story) vs Video intro
   — Метрика: `onboarding_completion_rate` × `day1_retention`
   — Ключ: `onboarding_variant` (A/B/C)

2. **Feature flags для seasonal events**
   — Уже есть `feature_seasonal_events_enabled` (general toggle)
   — Добавить granular: `seasonal_halloween_enabled`, `seasonal_newyear_enabled`, `seasonal_summer_enabled`
   — Server-side scheduling без релиза

3. **Voice variant A/B**
   — `lyalya_voice_variant` (tuned vs base)
   — Метрика: `voice_satisfaction_rate` (через явный rating prompt после 5 сессий)
   — Уже есть `lyalya_voice_default` — расширить до polychoice + experiment

4. **Lesson difficulty curve A/B**
   — `lesson_difficulty_curve` (linear / adaptive / mastery-gated)
   — Метрика: `session_dropout_rate` × `correct_attempts_rate`
   — Требует ML-метрик из Block X

5. **Force update threshold A/B**
   — Тестировать UX мягкого vs жёсткого force-update prompt
   — Ключ: `force_update_style` (soft / hard)

---

## Block Y scope decision

**VERIFY-ONLY** (no new SDK additions).

### Decision matrix

| Component | Linked | Active | Action v21 |
|---|---|---|---|
| FirebaseRemoteConfig | yes | yes | keep (no change) |
| FirebaseInstallations | yes | yes | keep (no change) |
| FirebaseABTesting (separate SDK) | no | no | **DEFER** |
| FirebaseDynamicLinks | yes (legacy) | replaced (ADR-V18-U) | defer removal v22 |

### Rationale для ADR-V21-Y-AB-TESTING-DEFER

- **No Apple Developer Account** в текущем scope (Plan v21 baseline) — нет production-распространения, поэтому нет реальной аудитории для A/B экспериментов.
- **Firebase A/B Testing console** работает поверх Remote Config параметров — отдельный SDK `FirebaseABTesting` нужен только для analytics-linked экспериментов (требует Firebase Analytics, который **запрещён** в Kids Category — см. CLAUDE.md §11).
- **Текущий tutorial A/B** работает через простой `tutorial_variant` параметр Remote Config — этого достаточно для дипломной демонстрации.
- **Alternative:** при необходимости production A/B можно использовать собственный server-side allocator через Cloud Function без Firebase ABTesting SDK.

### Status

**Remote Config + Installations** — already active, properly integrated, tested. No changes needed.

**A/B Testing** — deferred до v22 + появления Apple Developer Account + переоценка Kids Category ограничений.

**Dynamic Links** — удаление product из SPM defer до v22 (grace period после ADR-V18-U).
