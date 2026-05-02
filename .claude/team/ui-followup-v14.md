# UI Follow-up Issues v14 — Block M.fix

**Дата:** 2026-05-02  
**Статус:** отложены для Block N (требуют арт-ассетов или рефакторинга)

## Отложенные visual issues (Priority 2)

### BUG-008: ChildHomeView — Ляля отсутствует в hero-зоне
- **Причина:** LyalyaRealityKitView рендерится, но RealityKit-файл маскота требует
  финального art asset. Только код, без ассета — пустой кадр.
- **Fix:** добавить финальный `.reality` / `.usdc` файл Ляли в Resources.
- **Трудозатраты:** M (нужен art-ассет от designer-visual)

### BUG-009: ChildHome — чат-пузырь без аватара Ляли
- **Причина:** компонент `HSMascotView` не добавлен к bubble в ChildHomeView.
- **Fix:** добавить `LyalyaMascotView(state: .explaining, size: 40)` + speech-cloud
  декоратор к chat bubble.
- **Трудозатраты:** S

### BUG-010: WorldMapView — без иллюстрированных зон
- **Причина:** MVP-заглушки (circles/nodes). Требует custom illustrations.
- **Fix:** добавить illustrated backgrounds из DesignSystem или asset catalog.
- **Трудозатраты:** L (art)

### BUG-011: StutteringHomeView — пустое пространство сверху (~40%)
- **Fix:** убрать Spacer() или уменьшить top padding.
- **Трудозатраты:** XS

### BUG-012: FluencyDiaryView — системный SF Symbol в empty state
- **Fix:** заменить на LyalyaMascotView + custom encouraging string.
- **Трудозатраты:** XS

### BUG-013: LessonPlayerView — SF Symbol placeholders вместо illustrations
- **Причина:** content pack `sound_s_pack.json` не содержит imageAsset для карточек.
- **Fix:** добавить illustration assets в content packs.
- **Трудозатраты:** L (art + content)

### BUG-014: ARZoneView — прямоугольная обрезка иллюстрации бабочки
- **Fix:** добавить `.clipShape(Circle())` или `.clipShape(RoundedRectangle(cornerRadius:))`.
- **Трудозатраты:** XS

### BUG-015: SessionCompleteView — пустой score-circle без анимации
- **Причина:** display.scoreInt = 0 пока фаза .scoreReveal не активирована.
  bootstrap() запускает runStageSchedule() с задержкой 0.5s — на скриншоте виден
  начальный пустой круг. В реальном usage работает корректно.
- **Статус:** FALSE POSITIVE (работает в runtime, только статический screenshot пустой)

### BUG-016: ChildHomeView SE3 — обрезка текста "Запомни" в горизонтальном скролле
- **Fix:** `lineLimit(2)` → `lineLimit(nil)` + `minimumScaleFactor(0.8)` на card title.
- **Трудозатраты:** XS

### BUG-017: ParentHome SE3 — tab bar label overlap
- **Причина:** системный TabView. Нет кастомного решения без UIKit workaround.
- **Статус:** SYSTEM BEHAVIOR — принято как есть.

### BUG-018: OnboardingView — Ляля как прямоугольный thumbnail
- **Причина:** `LyalyaRealityKitView` рендерится как RealityKit viewport (прямоугольник).
  Нужен `.clipShape` или fallback image.
- **Fix:** добавить `.clipShape(Circle())` к LyalyaRealityKitView или fallback изображение.
- **Трудозатраты:** S

### BUG-019: SiblingMultiplayer — имя симулятора в UI
- **Статус:** COSMETIC / FALSE POSITIVE в симуляторе. Не воспроизводится на реальном устройстве.

---

## Закрытые в Block M.fix

- BUG-001: OnboardingFlowView — кнопка «Далее» за экраном SE3 → FIXED (safeAreaInset)
- BUG-002: AuthSignInView — footer-кнопки за экраном SE3 → FIXED (compact padding)
- BUG-003: sessionComplete.score.label → ADDED to Localizable.xcstrings
- BUG-004: parent.home.greeting.night → ADDED
- BUG-005: parent.home.date.today → ADDED
- BUG-006: settings.header.greeting / settings.header.subtitle → ADDED
- BUG-007: customization.skin.classic / customization.color.warm → EXISTED (false alarm)
