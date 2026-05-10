# Plan v19 Block I — Unified 3D/2D Lyalya Hero

## Audit Results

### 2D PNG Assets (10 imagesets)
| Asset | Art Style | Status |
|---|---|---|
| mascot_lyalya_happy | Чёткий контур, жёлтая корона, перики | OK — baseline |
| mascot_lyalya_celebrate | Мягкий размытый стиль | OK — допустимо |
| mascot_lyalya_wave | Пушистый, розовые крылья | OK — допустимо |
| mascot_lyalya_sad | Пушистый с точками на крыльях | OK — допустимо |
| mascot_lyalya_think | Розовый мягкий стиль | OK — допустимо |
| mascot_lyalya_sleep | Leaning anime style | OK — допустимо |
| mascot_lyalya_sing | Простой округлый | OK — допустимо |
| mascot_lyalya_read | Округлый, чтение книги | OK — допустимо |
| mascot_lyalya_listen | OUTLIER: медведеобразный, голубые глаза, нет антенн | FIXED — убран из маппинга |
| mascot_lyalya_star | Розово-пушистый | не используется в маппинге |
| seasonal_newyear_lyalya | OUTLIER: другой персонаж (вертикальный, желтоватый) | не в маппинге — OK |

### 3D Assets
| Asset | Status |
|---|---|
| lyalya3d_v2.usdz | PRIMARY — используется в LyalyaRealityKitView |
| lyalya3d.usdz | Legacy, не используется |

### Usage Count
- 3D RealityKit: 1 компонент (LyalyaRealityKitView) → используется через HSMascotView → LyalyaMascotView → 80+ экранов
- 2D PNG: только как fallback Layer 2 внутри HSMascotView, пока 3D не загрузился

## Fixes Applied (Block I v19)

### 1. 2D Анимации убраны (требование пользователя)
- `LyalyaMascotView.swift`: убран `breathingScale` + `MotionTokens.idlePulse` repeatForever — 2D PNG больше не дышит
- `OnboardingFlowViewComponents.swift`: убраны `scaleEffect` с LyalyaHeroView на 4 шагах (welcome, role, goals, sounds)
- `OnboardingFlowViewComponents2.swift`: убраны `scaleEffect` с LyalyaHeroView на 4 шагах (schedule, permissions, modelDownload, screeningIntro)
- `SessionCompleteView.swift`: убран `scaleEffect(visible ? 1 : 0.2)` → заменён на только opacity fade
- `CelebrationOverlayView.swift`: убран `scaleEffect(mascotVisible ? 1 : 0.6)` → только opacity
- `PermissionFlowView.swift`: убран `repeatForever scaleEffect(celebrationActive ? 1.05 : 1.0)` целиком

### 2. Inconsistent 2D Art — исправлен маппинг
- `HSMascotView.swift` illustrationName: `.explaining` больше не маппируется на `mascot_lyalya_listen` (медведеобразный outlier) → теперь `mascot_lyalya_happy`

### 3. 3D Transparent Background — VERIFIED
- `LyalyaRealityKitView.makeUIView`: `arView.backgroundColor = .clear` ✅
- `arView.environment.background = .color(.clear)` ✅
- `arView.isOpaque = false` ✅
- `cameraMode: .nonAR` ✅
- Bundle resource path `ARAssets/lyalya3d_v2.usdz` confirmed in project.yml ✅

## Cross-Cutting Principle (Block I v19)
- 3D Ляля: анимируется только внутри RealityKit (3D blendshapes, named entity transforms) — никакого SwiftUI `scaleEffect`/`rotationEffect`/`idlePulse` поверх неё
- 2D Ляля (fallback PNG): только `.opacity()` entrance fade — никаких `scaleEffect`, `rotationEffect`, `repeatForever`
- Heroine consistency: все 2D иллюстрации — бабочка/мотылёк с антеннами персикового цвета; outlier `mascot_lyalya_listen` убран из маппинга
