import OSLog
import SwiftUI

// MARK: - WorldMapView
//
// Kid-контур. «Карта звуков»: 5 цветных зон, маскот сверху, sticky bottom-панель
// с общим прогрессом и стриком. Прогресс приходит из Realm (на текущем спринте —
// in-memory seed в Interactor'е). Сигнатура `init(childId:targetSound:)`
// сохранена — вью подключён в AppCoordinator.
//
// VIP: View → Interactor → Presenter → Display.

struct WorldMapView: View {

    // MARK: - Inputs

    let childId: String
    let targetSound: String

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - VIP State

    @State private var display = WorldMapDisplay()
    @State private var interactor: WorldMapInteractor?
    @State private var presenter: WorldMapPresenter?
    @State private var router: WorldMapRouter?
    @State private var bootstrapped = false
    @State private var appeared = false

    // MARK: - Optional callbacks

    private let onDismiss: (() -> Void)?
    private let onOpenZone: ((String) -> Void)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "WorldMapView")

    // MARK: - Init

    init(
        childId: String,
        targetSound: String,
        onDismiss: (() -> Void)? = nil,
        onOpenZone: ((String) -> Void)? = nil
    ) {
        self.childId = childId
        self.targetSound = targetSound
        self.onDismiss = onDismiss
        self.onOpenZone = onOpenZone
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundLayer

            ScrollView {
                VStack(spacing: SpacingTokens.large) {
                    mascotHeader
                    streakBadge
                    if useGridFallback {
                        zonesGrid
                    } else {
                        islandsCanvas
                    }
                    Spacer(minLength: 96)
                }
                .padding(.top, SpacingTokens.medium)
                .padding(.bottom, SpacingTokens.xxLarge)
            }

            stickyBottomPanel

            if let toast = display.toastMessage {
                HSToast(toast, type: .info)
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.0))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            display.clearToast()
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "worldMap.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
        .sheet(isPresented: Binding(
            get: { display.isZoneDetailSheetPresented },
            set: { if !$0 { display.dismissZoneDetailSheet() } }
        )) {
            if let detail = display.zoneDetailViewModel {
                WorldZoneDetailSheet(
                    viewModel: detail,
                    reduceMotion: reduceMotion,
                    onStart: { handleStartZone(detail.zoneId) },
                    onDismiss: { display.dismissZoneDetailSheet() }
                )
                .presentationDetents([.large, .fraction(0.72)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(RadiusTokens.xl)
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        // F.tier1 v21: lilac accent в gradient мягче в dark, чтобы карта не «фонила» фиолетом.
        LinearGradient(
            colors: [
                ColorTokens.Kid.bg,
                ColorTokens.Brand.lilac.opacity(colorScheme == .dark ? 0.10 : 0.18),
                ColorTokens.Kid.bg
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Mascot header

    private var mascotHeader: some View {
        HStack(spacing: SpacingTokens.regular) {
            // F.tier1 v21: mascot мягче в dark.
            // E v21: 3D Ляля в header WorldMap (требование пользователя).
            LyalyaHeroView(state: .pointing, mood: 0.7, size: 96)
                .opacity(colorScheme == .dark ? 0.92 : 1.0)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text(String(localized: "worldmap.title"))
                    .font(TypographyTokens.title(22).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(String(localized: "worldMap.mascot.greeting"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Streak badge

    @ViewBuilder
    private var streakBadge: some View {
        let streakText = display.hasStreak
            ? display.streakLabel
            : String(localized: "worldmap.streak.start")
        HSLiquidGlassCard(
            style: .tinted(
                display.hasStreak
                    ? ColorTokens.Brand.primary
                    : ColorTokens.Brand.sky
            ),
            padding: SpacingTokens.small
        ) {
            HStack(spacing: SpacingTokens.tiny) {
                Image(systemName: display.hasStreak ? "flame.fill" : "sparkles")
                    .font(TypographyTokens.body(16).weight(.semibold))
                    .foregroundStyle(
                        display.hasStreak
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Brand.sky
                    )
                    .accessibilityHidden(true)
                Text(streakText)
                    .font(TypographyTokens.headline(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(streakText)
    }

    // MARK: - Islands canvas

    private var islandsCanvas: some View {
        WorldMapIslandsCanvas(
            cards: display.zones,
            appeared: appeared,
            reduceMotion: reduceMotion,
            onTapZone: { handleZoneTap($0) }
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    /// Использовать сеточный fallback вместо канваса:
    /// — на iPad/regular size class (там много места — карточки выглядят лучше);
    /// — на больших Dynamic Type, где плашки на канвасе перестают помещаться.
    private var useGridFallback: Bool {
        if hSizeClass == .regular { return true }
        return dynamicTypeSize >= .accessibility1
    }

    // MARK: - Zones grid

    private var zonesGrid: some View {
        let isCompact = hSizeClass == .compact
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: SpacingTokens.regular),
            GridItem(.flexible(), spacing: SpacingTokens.regular)
        ]

        return VStack(spacing: SpacingTokens.regular) {
            // Первые 4 зоны — грид 2×2
            LazyVGrid(columns: columns, spacing: SpacingTokens.regular) {
                ForEach(Array(display.zones.prefix(4).enumerated()), id: \.element.id) { index, card in
                    WorldZoneTile(
                        card: card,
                        cardWidth: isCompact ? nil : 220,
                        appeared: appeared,
                        index: index,
                        reduceMotion: reduceMotion
                    ) {
                        handleZoneTap(card.id)
                    }
                    // Block J v18 — kavsoft-style tilt carousel scroll transition.
                    .hsScrollEffect(.tiltCarousel)
                }
            }

            // 5-я зона — отдельной полной шириной
            if let last = display.zones.dropFirst(4).first {
                WorldZoneTile(
                    card: last,
                    cardWidth: nil,
                    appeared: appeared,
                    index: 4,
                    reduceMotion: reduceMotion,
                    isWide: true
                ) {
                    handleZoneTap(last.id)
                }
                // Block J v18 — kavsoft-style tilt carousel scroll transition.
                .hsScrollEffect(.tiltCarousel)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Sticky bottom panel

    private var stickyBottomPanel: some View {
        HStack(spacing: SpacingTokens.regular) {
            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                HStack(spacing: SpacingTokens.tiny) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .font(TypographyTokens.caption(14).weight(.semibold))
                        .accessibilityHidden(true)
                    Text(display.totalStarsLabel)
                        .font(TypographyTokens.mono(13))
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                HSProgressBar(
                    value: display.totalProgressFraction,
                    style: .parent,
                    tint: ColorTokens.Brand.mint
                )
                .frame(height: 6)
                .frame(maxWidth: 180)
                .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            if display.hasStreak {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .font(TypographyTokens.caption(14).weight(.semibold))
                        .accessibilityHidden(true)
                    Text(display.streakLabel)
                        .font(TypographyTokens.mono(13).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(ColorTokens.Brand.primary.opacity(0.12))
                )
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.regular)
        .background(
            ColorTokens.Kid.surface
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.summaryAccessibilityLabel)
    }

    // MARK: - Actions

    private func handleZoneTap(_ id: String) {
        container.hapticService.impact(.medium)
        interactor?.selectZone(.init(zoneId: id))
        // Всегда открываем detail sheet — для locked зон там информация о блокировке
        interactor?.loadZoneDetail(.init(zoneId: id))
        if let card = display.zones.first(where: { $0.id == id }), card.isLocked {
            container.hapticService.notification(.warning)
        } else {
            container.soundService.playUISound(.tap)
        }
    }

    private func handleStartZone(_ id: String) {
        display.dismissZoneDetailSheet()
        router?.routeOpenZone(zoneId: id)
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = WorldMapInteractor()
        let presenter = WorldMapPresenter()
        let router = WorldMapRouter()

        interactor.presenter = presenter
        presenter.display = display
        router.onDismiss = onDismiss
        router.onOpenZone = onOpenZone

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        interactor.loadMap(.init(
            childId: childId,
            highlightedSound: targetSound.isEmpty ? nil : targetSound,
            childAge: nil
        ))
    }
}
