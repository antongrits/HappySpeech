import SwiftUI

// MARK: - SoundExplorerMapView

struct SoundExplorerMapView: View {

    let childId: String

    @State private var interactor: SoundExplorerMapInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 5)

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidCool палитра для
                // «карты звуков» (прохладный exploration feel).
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidCool, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "soundMap.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = SoundExplorerMapInteractor(
                        childId: childId,
                        childRepository: container.childRepository,
                        sessionRepository: container.sessionRepository,
                        variationGenerator: container.contentEngine.variationGenerator
                    )
                    interactor = new
                    new.refresh()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            VStack(spacing: 0) {
                MapJourneyHeader(
                    title: String(localized: "soundMap.hero.title"),
                    subtitle: String(localized: "soundMap.hero.subtitle"),
                    starsCollected: "\(knownCount(interactor))",
                    starsTotal: String(
                        format: String(localized: "soundMap.known.of", defaultValue: "из %d"),
                        interactor.sounds.count
                    ),
                    progress: masteryProgress(interactor),
                    leadingIcon: "map.fill",
                    reduceMotion: reduceMotion
                )
                .padding(.top, SpacingTokens.tiny)

                ScrollView {
                    VStack(spacing: SpacingTokens.sp3) {
                        heroGreeting
                        filterBar(interactor: interactor)
                        grid(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp16)
                }
            }
            // Стеклянный футер CTA по эталону — карточка «текущий уровень».
            .safeAreaInset(edge: .bottom) {
                MapLevelCTACard(
                    badgeText: "",
                    badgeSystemImage: "play.fill",
                    kicker: String(localized: "soundMap.cta.kicker", defaultValue: "Тренировка"),
                    levelTitle: String(localized: "soundMap.cta.level", defaultValue: "Гимнастика звуков"),
                    actionTitle: String(localized: "action.play", defaultValue: "Играть"),
                    reduceMotion: reduceMotion,
                    onTap: {
                        hapticService.notification(.success)
                        coordinator.navigate(to: .articulationGym(soundGroup: featuredArticulationGroup(interactor)))
                    }
                )
                .padding(.bottom, SpacingTokens.tiny)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    /// Маппинг звуковой ячейки карты в нужную группу артикуляционной
    /// гимнастики. Раньше КАЖДАЯ ячейка жёстко роутила в `.sibilant` —
    /// ребёнок, тапнув Р/Л/Ш/К, попадал в гимнастику ЧУЖОГО (свистящего)
    /// звука. Теперь сопоставляем по конкретному звуку (точнее группы:
    /// различает Сь/Зь, Рь/Ль) с фоллбэком на группу ячейки.
    ///
    /// `ArticulationSoundGroup` покрывает 3 группы (свистящие/шипящие/соноры).
    /// Заднеязычные/гласные/губные своей гимнастики не имеют — ведём в
    /// `.sonor` (содержит универсальную разминку языка + позы, ближайшие к
    /// задним укладам), чтобы не уводить ребёнка в свистящие.
    static func articulationGroup(for cell: SoundExplorerMapModels.SoundCell) -> ArticulationSoundGroup {
        let sound = cell.id.trimmingCharacters(in: .whitespaces).uppercased()
        let base = String(sound.prefix(1))
        switch base {
        case "С", "З", "Ц":           return .sibilant
        case "Ш", "Ж", "Ч", "Щ":      return .hissing
        case "Р", "Л":                return .sonor
        default:
            // По русскому имени группы ячейки.
            switch cell.group {
            case "Свистящие":   return .sibilant
            case "Шипящие":     return .hissing
            case "Соноры":      return .sonor
            default:            return .sonor
            }
        }
    }

    /// Группа для футер-CTA «Играть»: ведёт в звук, который ребёнок сейчас
    /// активно учит (первый `.learning`), иначе — в первый неосвоенный, иначе
    /// в первую группу инвентаря с гимнастикой. Никогда не жёсткий `.sibilant`.
    private func featuredArticulationGroup(_ interactor: SoundExplorerMapInteractor) -> ArticulationSoundGroup {
        let pool = interactor.sounds
        if let learning = pool.first(where: { $0.mastery == .learning }) {
            return Self.articulationGroup(for: learning)
        }
        if let untried = pool.first(where: { $0.mastery == .untried }) {
            return Self.articulationGroup(for: untried)
        }
        if let any = pool.first {
            return Self.articulationGroup(for: any)
        }
        return .sibilant
    }

    /// Число освоенных звуков (для пилюли в шапке).
    private func knownCount(_ interactor: SoundExplorerMapInteractor) -> Int {
        interactor.sounds.filter { $0.mastery == .known }.count
    }

    /// Доля освоения карты звуков (освоенные + половина «учу») 0…1.
    private func masteryProgress(_ interactor: SoundExplorerMapInteractor) -> Double {
        let total = interactor.sounds.count
        guard total > 0 else { return 0 }
        let known = Double(interactor.sounds.filter { $0.mastery == .known }.count)
        let learning = Double(interactor.sounds.filter { $0.mastery == .learning }.count)
        return (known + learning * 0.5) / Double(total)
    }

    /// Компактная карточка-приветствие Ляли под шапкой — тёплый «воздух»
    /// и контекст, без дублирования заголовка.
    private var heroGreeting: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 56)
                    .accessibilityHidden(true)
                Text(String(localized: "soundMap.hero.greeting", defaultValue: "Нажми на звук, чтобы потренировать его с Лялей."))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
        }
    }

    private func filterBar(interactor: SoundExplorerMapInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(SoundExplorerMapModels.MasteryFilter.allCases) { f in
                    chip(f, interactor: interactor)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(
        _ f: SoundExplorerMapModels.MasteryFilter,
        interactor: SoundExplorerMapInteractor
    ) -> some View {
        let selected = interactor.filter == f
        return Button {
            hapticService.impact(.light)
            interactor.setFilter(f)
        } label: {
            Text(f.title)
                .font(TypographyTokens.body(13))
                .foregroundStyle(selected
                                 ? ColorTokens.Overlay.onAccent
                                 : ColorTokens.Kid.ink)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(selected
                                   ? ColorTokens.Brand.primary
                                   : ColorTokens.Kid.bgSoft)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(f.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func grid(interactor: SoundExplorerMapInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.visible) { cell in
                soundCell(cell)
                    // Step 10 Batch E — Pattern 3: scrollTransition stagger
                    // fade+scale на sound-map cells.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.92))
                    }
                    // Step 10 Batch E — Pattern 4: parallax drift на map cells.
                    .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func soundCell(_ cell: SoundExplorerMapModels.SoundCell) -> some View {
        // P0.2 v32: каждый чип — 72pt квадрат с gradient fill, radius md=18,
        // badge состояния цветной (gold/primary/soft). ShadowTokens.Kid.tile.
        let (bgFrom, bgTo, textColor): (Color, Color, Color) = {
            switch cell.mastery {
            case .known:
                return (
                    ColorTokens.Brand.primaryLo.opacity(0.30),
                    ColorTokens.Brand.primary.opacity(0.10),
                    ColorTokens.Brand.primary
                )
            case .learning:
                return (
                    ColorTokens.Brand.butter.opacity(0.35),
                    ColorTokens.Brand.gold.opacity(0.12),
                    ColorTokens.Brand.gold
                )
            case .untried:
                return (
                    ColorTokens.Kid.bgSoft.opacity(0.90),
                    ColorTokens.Kid.surface.opacity(0.60),
                    ColorTokens.Kid.ink
                )
            }
        }()

        return Button {
            hapticService.impact(.light)
            coordinator.navigate(to: .articulationGym(soundGroup: Self.articulationGroup(for: cell)))
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Text(cell.id)
                        .font(TypographyTokens.title(22).weight(.black))
                        .foregroundStyle(textColor)
                    Text(cell.group)
                        .font(TypographyTokens.caption(8))
                        .foregroundStyle(textColor.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.7)
                    if cell.activityCount > 0 {
                        // Число реально-наполняемых игр-вариаций для звука
                        // (из ContentVariationGenerator) — делает контент видимым.
                        Text(String(localized: "soundMap.cell.games", defaultValue: "\(cell.activityCount) игр"))
                            .font(TypographyTokens.caption(8).weight(.semibold))
                            .foregroundStyle(textColor.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 72)
                .padding(.vertical, SpacingTokens.sp2)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [bgFrom, bgTo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(colorScheme == .dark ? 0.10 : 0.50),
                            lineWidth: 0.5
                        )
                )

                // Значок состояния (P0.2: цветные badge вместо серого замка)
                masteryBadge(for: cell.mastery)
                    .padding(SpacingTokens.micro)
            }
            .depthShadow(ShadowTokens.kidDepth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(cell.id), группа \(cell.group), \(masteryAccessibilityLabel(cell.mastery))"))
    }

    @ViewBuilder
    private func masteryBadge(for mastery: SoundExplorerMapModels.Mastery) -> some View {
        switch mastery {
        case .known:
            Image(systemName: "checkmark.circle.fill")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
        case .learning:
            Image(systemName: "star.fill")
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Brand.gold)
        case .untried:
            EmptyView()
        }
    }

    private func masteryAccessibilityLabel(_ mastery: SoundExplorerMapModels.Mastery) -> String {
        switch mastery {
        case .known:    return String(localized: "soundMap.mastery.known", defaultValue: "освоен")
        case .learning: return String(localized: "soundMap.mastery.learning", defaultValue: "учу")
        case .untried:  return String(localized: "soundMap.mastery.untried", defaultValue: "ещё не пробовал")
        }
    }
}

// MARK: - Preview

#Preview("SoundExplorerMap — Light") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundExplorerMap — Dark") {
    SoundExplorerMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
