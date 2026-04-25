import SwiftUI
import OSLog

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
                    zonesGrid
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
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                ColorTokens.Kid.bg,
                ColorTokens.Brand.lilac.opacity(0.18),
                ColorTokens.Kid.bg
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Mascot header

    private var mascotHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(verbatim: "🦋")
                .font(.system(size: 86))
                .scaleEffect(appeared && !reduceMotion ? 1.06 : 1.0)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: appeared
                )
                .accessibilityHidden(true)

            Text(String(localized: "worldMap.mascot.greeting"))
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
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
                        .font(.system(size: 14, weight: .semibold))
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
            }

            Spacer(minLength: 0)

            if display.hasStreak {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .font(.system(size: 14, weight: .semibold))
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
        // Если зона открыта — навигация
        if let card = display.zones.first(where: { $0.id == id }), !card.isLocked {
            container.soundService.playUISound(.tap)
            router?.routeOpenZone(zoneId: id)
        } else {
            container.hapticService.notification(.warning)
        }
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
            highlightedSound: targetSound.isEmpty ? nil : targetSound
        ))
    }
}

// MARK: - WorldZoneTile

/// Карточка одной зоны на карте. Размер 140×160pt по дизайн-спеке.
/// При `isWide=true` растягивается на полную ширину (для 5-й зоны).
private struct WorldZoneTile: View {

    let card: WorldZoneCard
    let cardWidth: CGFloat?
    let appeared: Bool
    let index: Int
    let reduceMotion: Bool
    var isWide: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            tileContent
                .frame(maxWidth: isWide ? .infinity : cardWidth)
                .frame(minHeight: 160)
                .background(background)
                .overlay(highlightOverlay)
                .overlay(lockOverlay)
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
                .shadow(
                    color: card.backgroundColor.opacity(0.32),
                    radius: 12, x: 0, y: 6
                )
                .scaleEffect(scaleValue)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.55, dampingFraction: 0.78)
                            .delay(Double(index) * 0.08),
                    value: appeared
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                    value: isPressed
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(card.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Subviews

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            HStack(alignment: .top) {
                Text(card.icon)
                    .font(.system(size: isWide ? 44 : 36))
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if !card.isLocked {
                    Text(card.progressLabel)
                        .font(TypographyTokens.mono(11).weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(card.foregroundColor.opacity(0.18))
                        )
                        .foregroundStyle(card.foregroundColor)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(card.name)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(card.foregroundColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(card.soundsLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(card.foregroundColor.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HSProgressBar(
                value: card.progress,
                style: .parent,
                tint: card.foregroundColor
            )
            .frame(height: 4)

            Text(card.lessonsLabel)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(card.foregroundColor.opacity(0.7))
        }
        .padding(SpacingTokens.regular)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        card.backgroundColor,
                        card.backgroundColor.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        if card.isHighlighted {
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 3)
                .shadow(color: .white.opacity(0.4), radius: 8)
        }
    }

    @ViewBuilder
    private var lockOverlay: some View {
        if card.isLocked {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(.black.opacity(0.35))
                Image(systemName: "lock.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var scaleValue: CGFloat {
        if card.isLocked { return 1.0 }
        return isPressed && !reduceMotion ? 0.96 : 1.0
    }
}

// MARK: - Preview

#Preview("WorldMap") {
    NavigationStack {
        WorldMapView(childId: "preview-child", targetSound: "С")
    }
    .environment(AppContainer.preview())
    .environment(\.circuitContext, .kid)
}
