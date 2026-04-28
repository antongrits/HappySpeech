import ARKit
import SwiftUI

// MARK: - ARZoneView (Clean Swift: View)

struct ARZoneView: View {

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    @State private var interactor: ARZoneInteractor?
    @State private var presenter: ARZonePresenter?
    @State private var router: ARZoneRouter?
    @State private var viewModelHolder = ARZoneDisplay()

    /// Компактные устройства (iPhone SE, iPhone mini): < 375pt.
    /// На них 3D-вид не грузим — слишком дорого и тесно, показываем 2D-эмодзи-фоллбэк.
    private var isCompactDevice: Bool {
        UIScreen.main.bounds.width < 375
    }

    var body: some View {
        NavigationStack(path: $viewModelHolder.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    heroBanner
                    quickTipsCarousel
                    plannerBannerSection
                    instructionsSection
                    recommendedSection
                    activitiesHeader
                    difficultyFilterChips
                    activitiesContent
                    unsupportedNotice
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.medium)
                .padding(.bottom, SpacingTokens.xxxLarge)
            }
            .navigationTitle(Text("ar.zone.title"))
            .navigationBarTitleDisplayMode(.large)
            .background(ColorTokens.Kid.bg.ignoresSafeArea())
            .navigationDestination(for: ARGameDestination.self) { destination in
                ARZoneView.destinationView(for: destination)
            }
        }
        .sheet(item: $viewModelHolder.pendingTutorial) { request in
            ARZoneTutorialSheetView(
                tutorial: request.tutorial,
                onStart: {
                    interactor?.dismissTutorial(
                        .init(destination: request.destination, action: .start)
                    )
                },
                onSkip: {
                    interactor?.dismissTutorial(
                        .init(destination: request.destination, action: .skip)
                    )
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(RadiusTokens.sheet)
        }
        .onAppear { bootstrap() }
        .task {
            // Показываем placeholder первые ~300 мс — USDZ успевает подгрузиться,
            // затем interactor пересчитает phase в .ready / .unsupported.
            try? await Task.sleep(for: .milliseconds(300))
            interactor?.loadGames(.init(childId: container.currentChildId))
        }
    }

    // MARK: - Hero banner (sky→lilac gradient + decorative pulse rings + 3D Lyalya)

    private var heroBanner: some View {
        ARHeroBanner(
            isCompactDevice: isCompactDevice,
            mascotState: viewModelHolder.mascotState,
            phase: viewModelHolder.phase
        )
    }

    // MARK: - Quick tips carousel

    @ViewBuilder
    private var quickTipsCarousel: some View {
        if !viewModelHolder.tips.isEmpty {
            ARQuickTipsCarousel(tips: viewModelHolder.tips)
        }
    }

    // MARK: - Planner Banner (AdaptivePlannerService recommendation)

    @ViewBuilder
    private var plannerBannerSection: some View {
        if let banner = viewModelHolder.plannerBanner {
            ARPlannerBannerView(banner: banner)
        }
    }

    // MARK: - Instructions section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text("ar.zone.instructions.title")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.tiny)

            VStack(spacing: SpacingTokens.small) {
                ForEach(viewModelHolder.instructionSteps) { step in
                    InstructionStepCard(step: step)
                }
            }
        }
    }

    // MARK: - Recommended CTA

    @ViewBuilder
    private var recommendedSection: some View {
        if let recommended = viewModelHolder.recommendedCard,
           viewModelHolder.phase == .ready {
            ARStartRecommendedButton(card: recommended) { [weak interactor] in
                interactor?.selectGame(.init(
                    gameId: recommended.id,
                    skipTutorial: recommended.hasBeenPlayedBefore
                ))
            }
        }
    }

    // MARK: - Activities section

    private var activitiesHeader: some View {
        Text("ar.zone.activitiesSection")
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .padding(.top, SpacingTokens.small)
    }

    @ViewBuilder
    private var difficultyFilterChips: some View {
        if !viewModelHolder.cards.isEmpty {
            ARDifficultyFilterChips(selected: $viewModelHolder.activeFilter)
        }
    }

    @ViewBuilder
    private var activitiesContent: some View {
        if !viewModelHolder.cards.isEmpty {
            gamesGrid
        } else if viewModelHolder.phase == .loading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, SpacingTokens.xxLarge)
        } else {
            // phase = .unsupported: подсказка рендерится в unsupportedNotice ниже
            EmptyView()
        }
    }

    private var filteredCards: [ARGameCard] {
        viewModelHolder.cards.filter { viewModelHolder.activeFilter.matches($0) }
    }

    @ViewBuilder
    private var gamesGrid: some View {
        if filteredCards.isEmpty {
            ARFilterEmptyState(filter: viewModelHolder.activeFilter)
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: SpacingTokens.small),
                    GridItem(.flexible(), spacing: SpacingTokens.small)
                ],
                spacing: SpacingTokens.small
            ) {
                ForEach(filteredCards) { card in
                    Button {
                        interactor?.selectGame(.init(
                            gameId: card.id,
                            skipTutorial: card.hasBeenPlayedBefore
                        ))
                    } label: {
                        ARGameCardView(card: card)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(arCardAccessibilityLabel(card: card))
                    )
                    .accessibilityHint(Text(card.subtitle))
                    .accessibilityAddTraits(card.badge == .recommendedByLyalya ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private var unsupportedNotice: some View {
        if !viewModelHolder.isARSupported {
            ARFallbackBannerView { [weak interactor] in
                interactor?.selectFallback(.init())
            }
        }
    }

    // MARK: - Accessibility helper

    private func arCardAccessibilityLabel(card: ARGameCard) -> String {
        var label = "AR игра: \(card.title), \(card.estimatedMinutes) мин"
        switch card.badge {
        case .recommendedByLyalya:
            label += ", рекомендовано Лялей"
        case .newGame:
            label += ", новая игра"
        case .completed:
            label += ", пройдено сегодня"
        case .none:
            break
        }
        switch card.difficulty {
        case 1: label += ", лёгкий уровень"
        case 2: label += ", средний уровень"
        case 3: label += ", сложный уровень"
        default: break
        }
        return label
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard interactor == nil else { return }
        let interactor = ARZoneInteractor()
        let presenter = ARZonePresenter()
        let router = ARZoneRouter()

        // Инжектируем AdaptivePlannerService из AppContainer
        interactor.plannerService = container.adaptivePlannerService
        interactor.presenter = presenter

        presenter.viewModel = viewModelHolder
        router.coordinator = coordinator
        router.onNavigateLocal = { [weak viewModelHolder] destination in
            viewModelHolder?.path.append(destination)
        }
        viewModelHolder.router = router

        self.interactor = interactor
        self.presenter = presenter
        self.router = router
    }

    // MARK: - Destination factory

    @ViewBuilder
    static func destinationView(for destination: ARGameDestination) -> some View {
        switch destination {
        case .arMirror:        ARMirrorView()
        case .butterflyCatch:  ButterflyCatchView()
        case .holdThePose:     HoldThePoseView()
        case .mimicLyalya:     MimicLyalyaView()
        case .breathingGame:   BreathingARView()
        case .soundAndFace:    SoundAndFaceView()
        case .poseSequence:    PoseSequenceView()
        case .arStoryQuest:    ARStoryQuestView()
        }
    }
}

// MARK: - ARZoneDisplay (Observable view-state)

@Observable
@MainActor
final class ARZoneDisplay: ARZoneDisplayLogic {

    // MARK: - TutorialRequest (Identifiable для sheet(item:))

    struct TutorialRequest: Identifiable {
        let id: String          // == tutorial.id
        let tutorial: ARTutorial
        let destination: ARGameDestination
    }

    // MARK: - Published state

    var cards: [ARGameCard] = []
    var instructionSteps: [InstructionStep] = []
    var tips: [ARQuickTip] = []
    var recommendedCard: ARGameCard?
    var mascotState: LyalyaAnimation = .idle
    var phase: ARZonePhase = .loading
    var isARSupported: Bool = true
    var path: [ARGameDestination] = []
    /// Пользовательский UI-state — какой фильтр сложности активен сейчас.
    var activeFilter: ARDifficultyFilter = .all
    /// Баннер рекомендации AdaptivePlannerService (nil = не показывать).
    var plannerBanner: ARPlannerBanner?
    /// Pending tutorial request — .sheet(item:) реагирует на non-nil.
    var pendingTutorial: TutorialRequest?
    /// Слабая ссылка на router нужна, чтобы Display мог триггернуть routeToFallback,
    /// не утаскивая координатор из View. Router владеется через @State в ARZoneView.
    weak var router: ARZoneRouter?

    // MARK: - DisplayLogic

    func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel) {
        self.cards = viewModel.cards
        self.instructionSteps = viewModel.instructionSteps
        self.tips = viewModel.tips
        self.recommendedCard = viewModel.recommendedCard
        self.mascotState = viewModel.mascotState
        self.phase = viewModel.phase
        self.isARSupported = viewModel.isARSupported
        self.plannerBanner = viewModel.plannerBanner
    }

    func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel) {
        // tutorial == nil → сразу переходим к игре
        path.append(viewModel.destination)
    }

    func displayShowTutorial(_ viewModel: ARZoneModels.SelectGame.ViewModel) {
        guard let tutorial = viewModel.tutorial else {
            // Нет инструкции — сразу к игре
            path.append(viewModel.destination)
            return
        }
        // Сигнализируем View через Observable-поле — sheet(item:) подхватит
        pendingTutorial = TutorialRequest(
            id: tutorial.id,
            tutorial: tutorial,
            destination: viewModel.destination
        )
    }

    func displayDismissTutorial(_ viewModel: ARZoneModels.DismissTutorial.ViewModel) {
        pendingTutorial = nil
        path.append(viewModel.destination)
    }

    func displaySelectFallback(_ viewModel: ARZoneModels.SelectFallback.ViewModel) {
        router?.routeToFallback()
    }

    func displayRefreshPlannerAdvice(_ viewModel: ARZoneModels.RefreshPlannerAdvice.ViewModel) {
        self.plannerBanner = viewModel.banner
    }
}

// MARK: - ARMascot2DFallback (iPhone SE и ошибки 3D-загрузки)

/// 2D эмодзи-фоллбэк маскота Ляли.
/// Используется на компактных устройствах (iPhone SE) и как визуальный placeholder.
private struct ARMascot2DFallback: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.sky],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .shadow(color: ColorTokens.Brand.lilac.opacity(0.3), radius: 14, x: 0, y: 6)
            Text("🦋")
                .font(.system(size: size * 0.5))
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
        .offset(y: bob)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.idlePulse) {
                bob = -6
            }
        }
        .accessibilityLabel(Text("ar.zone.mascot.accessibility"))
    }
}

// MARK: - ARMascotLoadingPlaceholder

/// Пульсирующий круг — placeholder поверх 3D-вида пока USDZ загружается (~300 мс).
/// Автоматически скрывается через ARZonePhase == .ready.
private struct ARMascotLoadingPlaceholder: View {
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 0.9
    @State private var opacity: Double = 0.6

    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        ColorTokens.Brand.lilac.opacity(0.4),
                        ColorTokens.Brand.sky.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size * 0.85, height: size * 0.85)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    scale = 1.05
                    opacity = 0.35
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - ARHeroBanner

/// Hero-баннер на входе в AR-зону.
/// Содержит 3D Лялю (или 2D-фоллбэк), декоративные пульсирующие кольца и
/// gradient-фон sky → lilac (через `ColorTokens.Brand`).
/// Reduced Motion отключает кольца и тени.
private struct ARHeroBanner: View {
    let isCompactDevice: Bool
    let mascotState: LyalyaAnimation
    let phase: ARZonePhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringScale: CGFloat = 0.9
    @State private var ringOpacity: Double = 0.55

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            ZStack {
                heroBackground
                pulseRings
                heroMascot
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
            .shadow(
                color: ColorTokens.Brand.sky.opacity(reduceMotion ? 0.0 : 0.25),
                radius: 16, x: 0, y: 8
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("ar.zone.mascot.accessibility"))

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                Text("ar.zone.greeting")
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text("ar.zone.subtitle")
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, SpacingTokens.tiny)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                ringScale = 1.08
                ringOpacity = 0.25
            }
        }
    }

    private var heroBackground: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.sky,
                ColorTokens.Brand.lilac
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var pulseRings: some View {
        if !reduceMotion {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .scaleEffect(ringScale * 1.05)
                    .opacity(ringOpacity * 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var heroMascot: some View {
        ZStack {
            if isCompactDevice {
                ARMascot2DFallback(size: 160)
            } else {
                LyalyaRealityView(animation: mascotState, size: 220)
                if phase == .loading {
                    ARMascotLoadingPlaceholder(size: 220)
                        .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - ARQuickTipsCarousel

/// Карусель «быстрых советов» — ротация раз в 4.5 сек.
/// При Reduced Motion смены не анимируются (резкая замена).
private struct ARQuickTipsCarousel: View {
    let tips: [ARQuickTip]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var index: Int = 0
    @State private var task: Task<Void, Never>?

    var body: some View {
        let tip = tips[safe: index] ?? tips[0]
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Brand.sky.opacity(0.18)),
            padding: SpacingTokens.regular
        ) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: tip.icon)
                    .font(TypographyTokens.headline(20).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                Text(tip.text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                tipDots
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(
                    colorScheme == .light
                        ? ColorTokens.Brand.sky.opacity(0.40)
                        : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(tip.text))
        .id(tip.id)
        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.97)))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
        .onAppear { startRotation() }
        .onDisappear { stopRotation() }
    }

    private var tipDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<tips.count, id: \.self) { i in
                Circle()
                    .fill(i == index
                          ? ColorTokens.Brand.primary
                          : ColorTokens.Brand.primary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private func startRotation() {
        guard tips.count > 1 else { return }
        stopRotation()
        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(4500))
                if Task.isCancelled { return }
                index = (index + 1) % tips.count
            }
        }
    }

    private func stopRotation() {
        task?.cancel()
        task = nil
    }
}

// MARK: - ARStartRecommendedButton

/// CTA «Начать AR-сессию» — стартует первую рекомендованную лёгкую игру.
/// Показывается только при `phase == .ready`.
private struct ARStartRecommendedButton: View {
    let card: ARGameCard
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 48, height: 48)
                    Image(systemName: "play.fill")
                        .font(TypographyTokens.headline(20).weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .scaleEffect(pulse)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ar.zone.recommended.cta")
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(card.title)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(RadiusTokens.lg)
            .shadow(
                color: ColorTokens.Brand.primary.opacity(reduceMotion ? 0.0 : 0.32),
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ar.zone.recommended.cta"))
        .accessibilityHint(Text(card.title))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = 1.07
            }
        }
    }
}

// MARK: - ARDifficultyFilterChips

/// Набор chips для фильтра по сложности (Все / Легко / Средне / Сложно).
private struct ARDifficultyFilterChips: View {
    @Binding var selected: ARDifficultyFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(ARDifficultyFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selected = filter
                        }
                    } label: {
                        chip(for: filter, isActive: selected == filter)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringResource(stringLiteral: filter.titleKey)))
                    .accessibilityAddTraits(selected == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    private func chip(for filter: ARDifficultyFilter, isActive: Bool) -> some View {
        Text(LocalizedStringResource(stringLiteral: filter.titleKey))
            .font(TypographyTokens.body(13).weight(.semibold))
            .foregroundStyle(isActive ? Color.white : ColorTokens.Kid.ink)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.vertical, SpacingTokens.tiny)
            .background(
                Capsule().fill(
                    isActive
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(ColorTokens.Kid.surfaceAlt)
                )
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? Color.clear : ColorTokens.Kid.ink.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - ARFilterEmptyState

/// «Под этот фильтр игр нет» — мягкий empty-state.
private struct ARFilterEmptyState: View {
    let filter: ARDifficultyFilter

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.title(28).weight(.regular))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)
            Text("ar.zone.filter.empty")
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.xLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ar.zone.filter.empty"))
    }
}

// MARK: - ARFallbackBannerView

/// Полноценный fallback-баннер для устройств без TrueDepth-камеры.
/// Содержит иконку, заголовок, объяснение и CTA «Открыть 2D-альтернативу».
private struct ARFallbackBannerView: View {
    let onSelectFallback: () -> Void

    var body: some View {
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Semantic.warningBg),
            padding: SpacingTokens.large
        ) {
            VStack(spacing: SpacingTokens.regular) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.Semantic.warning.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "iphone.gen3.slash")
                        .font(TypographyTokens.title(28).weight(.medium))
                        .foregroundStyle(ColorTokens.Semantic.warning)
                        .accessibilityHidden(true)
                }
                Text("ar.zone.unsupportedTitle")
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Text("ar.zone.unsupportedBody")
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onSelectFallback) {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "play.fill")
                            .accessibilityHidden(true)
                        Text("ar.zone.fallbackCTA")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SpacingTokens.large)
                    .padding(.vertical, SpacingTokens.small)
                    .background(
                        Capsule().fill(ColorTokens.Semantic.warning)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("ar.zone.fallbackCTA"))
                .padding(.top, SpacingTokens.tiny)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - InstructionStepCard

/// Карточка с одним шагом инструкции: номер + иконка + заголовок + текст.
/// Цветной индикатор слева — по `ARCardPalette` через `tintIndex`.
private struct InstructionStepCard: View {
    let step: InstructionStep

    var body: some View {
        let palette = ARCardPalette.gradient(for: step.tintIndex)
        HSCard(style: .elevated) {
            HStack(alignment: .top, spacing: SpacingTokens.regular) {
                // Круглый бейдж с номером и иконкой
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: palette,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: step.icon)
                        .font(TypographyTokens.title(22).weight(.semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .topTrailing) {
                    Text("\(step.number)")
                        .font(TypographyTokens.body(11).weight(.bold))
                        .foregroundStyle(palette.first ?? ColorTokens.Brand.primary)
                        .padding(4)
                        .background(Circle().fill(Color.white))
                        .offset(x: 6, y: -6)
                }

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(step.title)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    Text(step.body)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(step.number). \(step.title). \(step.body)"))
    }
}

// MARK: - ARPlannerBannerView

/// Баннер рекомендации/предупреждения от AdaptivePlannerService.
/// Три варианта: recommended (звезда), fatigueWarning (zzz), fatigueLight (листик).
private struct ARPlannerBannerView: View {
    let banner: ARPlannerBanner

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconBounce: Int = 0

    private var bannerStyle: HSLiquidGlassStyle {
        switch banner.variant {
        case .recommended:    return .tinted(ColorTokens.Brand.butter.opacity(0.22))
        case .fatigueWarning: return .tinted(ColorTokens.Semantic.warningBg)
        case .fatigueLight:   return .tinted(ColorTokens.Brand.mint.opacity(0.2))
        }
    }

    private var iconColor: Color {
        switch banner.variant {
        case .recommended:    return ColorTokens.Brand.gold
        case .fatigueWarning: return ColorTokens.Semantic.warning
        case .fatigueLight:   return ColorTokens.Brand.mint
        }
    }

    var body: some View {
        HSLiquidGlassCard(style: bannerStyle, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: banner.icon)
                    .font(TypographyTokens.title(24).weight(.semibold))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.bounce.down, value: iconBounce)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(String(localized: String.LocalizationValue(banner.titleKey)))
                        .font(TypographyTokens.headline(14).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(String(localized: String.LocalizationValue(banner.bodyKey)))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                "\(String(localized: String.LocalizationValue(banner.titleKey))). " +
                "\(String(localized: String.LocalizationValue(banner.bodyKey)))"
            )
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(MotionTokens.bounce.delay(0.4)) {
                iconBounce += 1
            }
        }
    }
}

// MARK: - ARGameCardView

private struct ARGameCardView: View {
    let card: ARGameCard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = ARCardPalette.gradient(for: card.accentColorIndex)
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                HStack {
                    Image(systemName: card.iconName)
                        .font(TypographyTokens.title(30).weight(.medium))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Spacer()
                    difficultyDots
                }
                Spacer(minLength: SpacingTokens.tiny)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text(card.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: SpacingTokens.micro) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text("\(card.estimatedMinutes) мин")
                            .font(TypographyTokens.body(12))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(SpacingTokens.regular)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(RadiusTokens.lg)
            .shadow(
                color: colors.first?.opacity(0.3) ?? .black.opacity(0.15),
                radius: reduceMotion ? 0 : 8,
                x: 0, y: 4
            )

            // Бейдж от AdaptivePlannerService
            ARGameBadgeOverlay(badge: card.badge)
                .padding(.top, SpacingTokens.small)
                .padding(.trailing, SpacingTokens.small)
        }
    }

    private var difficultyDots: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < card.difficulty ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - ARGameBadgeOverlay

/// Маленький бейдж в углу карточки AR-игры.
private struct ARGameBadgeOverlay: View {
    let badge: ARGameBadge

    var body: some View {
        switch badge {
        case .recommendedByLyalya:
            badgeView(icon: "star.fill", color: ColorTokens.Brand.gold,
                      labelKey: "ar.zone.badge.recommended")
        case .newGame:
            badgeView(icon: "sparkles", color: ColorTokens.Brand.sky,
                      labelKey: "ar.zone.badge.new")
        case .completed:
            badgeView(icon: "checkmark.circle.fill", color: ColorTokens.Brand.mint,
                      labelKey: "ar.zone.badge.completed")
        case .none:
            EmptyView()
        }
    }

    private func badgeView(icon: String, color: Color, labelKey: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .accessibilityHidden(true)
            Text(String(localized: String.LocalizationValue(labelKey)))
                .font(TypographyTokens.body(9).weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(color)
        )
        .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Array safe subscript (локальный helper для карусели)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    ARZoneView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
