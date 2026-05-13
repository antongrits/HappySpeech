# Backlog v23+ (candidate features post-v22)

**Created:** 2026-05-13
**Source:** v22 Plan Phase 3 closure + v19/v21 carry-forward gaps + competitor research

## P0 Critical (gaps from v22 deferrals)

- **Real Russian phonetic corpus retrain** → close Block 1.1 synthetic ceiling (ADR-V22-R-PHONEME-SYNTHETIC-CEILING)
  - Common Voice RU phonetic subset (CC0) + OpenSLR SLR96 (Apache 2.0)
  - Forced alignment (montreal-forced-aligner либо wav2vec2 CTC) → frame-level labels
  - Target: ≥92% real-audio accuracy
  - Estimated: 2-3 дня work + GPU training

- **Blender 3D Lyalya emotional variants** (8 blendshapes) → close ADR-V22-BLENDER-FINAL-DEFER
  - Install Blender 4.x + rig Lyalya base mesh
  - Commission Russian-native artist для professional rig (если бюджет позволит)
  - Variants: happy, sad, surprised, thinking, listening, encouraging, celebrating, sleepy
  - Export USDZ через Blender → RealityKit

- **AppIcon Dark + Tinted manual redesign** → close ADR-V22-APPICON-DARK-FINAL-DEFER + ADR-V21-AJ-DARKICON-DEFER
  - Manual Figma/Sketch design (procedural noise unacceptable)
  - Export 1024x1024 PNG per variant
  - Update `AppIcon.appiconset/Contents.json` (already accepts 3 variants)

- **Apple Developer enrollment** ($99/yr) → unlock:
  - TestFlight beta distribution
  - App Store Connect submission
  - APNs remote push (parental reminders)
  - Sign in with Apple production capability

## P1 Feature expansion (post-Plan v22)

- **EN localization активный variant** (current: stub `L10n.swift`)
  - Полный translation pass через String Catalog
  - QA на VoiceOver English
- **Watch companion** (parent reminders — daily streak push)
- **iPad UI variants** (currently iPhone-only layout)
- **Voice clone real** (XTTS-v2 child voice samples — 5 секунд reference → clone Lyalya voice)
- **ARKit Scene Reconstruction** для playroom mapping (AR exercises интегрированы в reality)

## P1 Firebase migration

- **Universal Links migration** (FDL deprecated Aug 2025) → закрыть ADR-V22-FDL-DEPRECATED
  - AssociatedDomains capability в entitlements
  - apple-app-site-association на happyspeech.app
  - DeepLinkRouter parse paths /invite/family/{id}, /share/content/{id}
  - Migrate existing FDL payload structure к URL path/query schema
- **Whisper A/B Remote Config deploy** (Block 3.2 defer) — Firebase Console + iOS protocol extension `whisperModelOverride`

## P2 Tooling & QA improvements

- **SwiftGen build phase integration** (v22 Block 2.4 stub)
  - Заменить manual `L10n.swift` на generated файл
  - Pre-build phase в project.yml
- **Periphery dead code analyzer** (v22 Block 2.5 manual heuristic)
  - Brew install + config + integrate в CI
- **Speech-to-Text для длительной записи** (story telling mode — 60s+ samples)
- **Multi-language UI** (English + Spanish + другие славянские для CIS market)
- **Snapshot tests coverage 80%+** (current ~60%)
- **UI tests на key flows** (Onboarding, Daily session, Parent dashboard)

## Competitor gaps (carried forward от v21 AD)

- **Логопотам:** leaderboard system (weekly streak among friends)
- **Буковки:** letter tracing с Apple Pencil (iPad-specific)
- **Логомаг:** video lessons library (curated YouTube subset для родителей)
- **Speech Blubs:** AR character-based exercises (наша AR пока минимальна)
- **DragonBox Speech:** narrative-driven episodic content (story arcs across weeks)

## P3 Research & future

- **Clinical pilot** с логопедами-партнёрами (3-6 месяцев observation study)
- **IRB review** для child voice data collection (если решим собирать real dataset)
- **Subscription tiers** (Family / Specialist / Clinic) — post-MVP monetization
- **Backend scale-out** (Firestore → Cloud SQL для analytics queries при >10K users)
- **Privacy audit** (independent review перед public launch)

---

## Plan v22 closure summary

Plan v22 closed with following defer surface (all P0/P1 above):
- 1 ML synthetic ceiling (real-corpus retrain)
- 1 Blender 3D rig
- 1 AppIcon manual redesign
- 1 Firebase Universal Links migration
- 1 RemoteConfig Whisper A/B deploy
- 1 Apple Developer enrollment ($99/yr)

Дипломная защита возможна с текущим состоянием. Production launch требует закрытия P0.
