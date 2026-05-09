# Block H.verify v18 — 3D Heroes Coverage Audit

## Date: 2026-05-09

---

## Coverage statistics

### Project-wide
- LyalyaRealityKitView usage: **8 файлов**
- LyalyaMascotView usage: **83 файла**
- Total Lyalya references: **154 файла**

### Цепочка рендера (подтверждена)
```
LyalyaMascotView → HSMascotView → ZStack:
  Layer 2: Image PNG (2D fallback, всегда видна)
  Layer 3: LyalyaRealityKitView (3D USDZ, прозрачный фон)
```
- `LyalyaHeroView` — обёртка над `LyalyaMascotView`, добавляет frame и параметры mood/viseme.
- `LyalyaRealityKitView`: `cameraMode = .nonAR`, `backgroundColor = .clear`, `environment.background = .color(.clear)`, `isOpaque = false`. **Прозрачность подтверждена.**
- Pink background anti-pattern: **не обнаружен** (последний fix — F.1 v15, визуальный аудит K v17 94 файла, 0 артефактов).

---

## R-screens (post-tag) — детальная таблица

| Экран | Lyalya в loading | Компонент | Размер | Lyalya в hero-секции | Проблема |
|---|---|---|---|---|---|
| DialectAdaptation | да | `LyalyaMascotView` | 80pt | **НЕТ** — используется SF Symbol `waveform.and.mic` | P1 |
| LogopedistChat | да | `LyalyaMascotView` | 80pt | **НЕТ** — hero-секции нет вообще | P1 |
| WeeklyChallenge | да | `LyalyaMascotView` | 80pt | **НЕТ** — используется SF Symbol (symbolName из ViewModel) | P1 |
| FamilyAchievements | да | `LyalyaMascotView` | 80pt | **НЕТ** — используется SF Symbol `flame.fill`/`person.3` | P1 |
| CulturalContent | да | `LyalyaMascotView` | 80pt | **НЕТ** — используется SF Symbol `books.vertical.fill` | P1 |

**Итог по R-screens:** Ляля присутствует **только в loading-состоянии** (size: 80pt, только спиннер). В hero-секциях загруженного контента — SF Symbols без маскота. Это прямое нарушение требования Plan v18: «На экранах нет 3d героев... очень много свободного места».

---

## Onboarding (Block I requirement)

**Требование Plan v18:** LyalyaRealityKitView 200–300pt × 10 шагов онбординга.

| Шаг | Компонент | Размер | Соответствие |
|---|---|---|---|
| welcome | `LyalyaHeroView` | 240pt | OK — в диапазоне |
| role | `LyalyaHeroView` | 200pt | OK — граница диапазона |
| childName | `LyalyaHeroView` | 180pt | ⚠ ниже 200pt |
| childAge | `LyalyaHeroView` | 180pt | ⚠ ниже 200pt |
| goals | `LyalyaHeroView` | 180pt | ⚠ ниже 200pt |
| sounds | `LyalyaHeroView` | 160pt | ⚠ ниже 200pt |
| schedule | `LyalyaHeroView` | 200pt | OK |
| permissions | `LyalyaHeroView` | 180pt | ⚠ ниже 200pt |
| modelDownload | `LyalyaHeroView` | 220pt | OK |
| completion | `LyalyaHeroView` | 220pt | OK |

Фактически: **10 из 10 шагов** имеют `LyalyaHeroView` (через `LyalyaMascotView` → `HSMascotView` → `LyalyaRealityKitView`). Однако 5 шагов (childName, childAge, goals, sounds, permissions) имеют size < 200pt, что ниже нижней границы требования Plan v18.

---

## DesignSystem J B.10 + Group C — совместимость

| Компонент | Lyalya | Контекст |
|---|---|---|
| `HSEmptyStateView` | `LyalyaMascotView` size: 96pt | Присутствует, **но внутри Circle background** (ColorTokens.Brand.primary.opacity(0.15), 120pt) — фон под маскотом. Технически не розовый Rectangle, это design-системный элемент. |
| `HSTimelineView` | нет | не требуется |
| `HSStarRatingView` | нет | не требуется |
| `HSPaywallTeaser` | нет | не требуется |

`HSEmptyStateView` — Circle под маскотом — это **intentional design** (аура-фон), не артефакт. Проверено: `ColorTokens.Brand.primary.opacity(0.15)`, не hardcoded hex.

---

## Issues found

### P1 — 5 issues (критические, блокируют план v18)
1. **DialectAdaptation** — hero-секция без Lyalya (SF Symbol вместо маскота)
2. **LogopedistChat** — нет hero-секции с Lyalya вообще (только loading)
3. **WeeklyChallenge** — hero-секция без Lyalya (SF Symbol вместо маскота)
4. **FamilyAchievements** — hero-секция без Lyalya (streak section — только иконка пламени)
5. **CulturalContent** — hero-секция без Lyalya (SF Symbol вместо маскота)

### P2 — 5 issues (некритические)
6. **Onboarding.childName** — LyalyaHeroView size 180pt < 200pt (требование: 200–300pt)
7. **Onboarding.childAge** — LyalyaHeroView size 180pt < 200pt
8. **Onboarding.goals** — LyalyaHeroView size 180pt < 200pt
9. **Onboarding.sounds** — LyalyaHeroView size 160pt < 200pt (критически мало)
10. **Onboarding.permissions** — LyalyaHeroView size 180pt < 200pt

### P0 — 0 issues
- Прозрачный фон LyalyaRealityKitView: подтверждён, розовый Rectangle не воспроизводится.

**Итого:** P0=0, P1=5, P2=5

---

## Recommended fixes (для следующего исполнителя)

### R-screens — добавить LyalyaHeroView в hero-секции (P1)
Для каждого из 5 R-screens вверху основного контента (после loading) добавить:
```swift
LyalyaHeroView(state: .explaining, mood: 0.7, size: 180)
    .accessibilityHidden(true)
```
Размер 180pt допустим для parent-контура (меньше экранного пространства, чем на детских экранах).

### Onboarding — поднять размеры до 200pt (P2)
- childName, childAge, goals, permissions: `size: 200`
- sounds: `size: 200` (был 160pt — наибольшее отклонение)

---

## Verdict

**⚠ Improvements needed (P1 блокеры)**

3D Lyalya hero полностью присутствует и корректно работает в:
- Онбординге (10/10 шагов, LyalyaHeroView через LyalyaMascotView → HSMascotView → LyalyaRealityKitView)
- Ключевых экранах (ChildHome size 140pt, SessionComplete size 140pt, Rewards size 56pt)
- Loading-состояниях всех 5 R-screens (size 80pt)
- DesignSystem HSEmptyStateView (size 96pt)

**Не покрыты Lyalya-героем:** hero-секции 5 R-screens (DialectAdaptation, LogopedistChat, WeeklyChallenge, FamilyAchievements, CulturalContent) — вместо маскота используются SF Symbols. Это основная причина «много свободного места» по Plan v18.
