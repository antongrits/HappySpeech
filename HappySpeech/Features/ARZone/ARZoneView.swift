import ARKit
import SwiftUI

// MARK: - ARZoneView (Clean Swift: View)
//
// Компоненты вынесены в `ARZoneViewComponents.swift`.
// Карточки и фильтры — в `ARZoneViewCards.swift`.

struct ARZoneView: View {

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var interactor: ARZoneInteractor?
    @State private var presenter: ARZonePresenter?
    @State private var router: ARZoneRouter?
    @State private var viewModelHolder = ARZoneDisplay()

    // S.4 v16 — AR Face Filter Mode (fun mode).
    @State private var showFaceFilterSheet: Bool = false

    /// Компактные устройства (iPhone SE, iPhone mini) — compact horizontal size class.
    /// На них 3D-вид не грузим — слишком дорого и тесно, показываем 2D-эмодзи-фоллбэк.
    /// На iPad (regular) — всегда показываем 3D.
    private var isCompactDevice: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack(path: $viewModelHolder.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    heroBanner
                    faceFilterEntryButton
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
        .fullScreenCover(isPresented: $showFaceFilterSheet) {
            ARFaceFilterView()
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

    // MARK: - Face filter entry (S.4 v16)

    private var faceFilterEntryButton: some View {
        Button {
            showFaceFilterSheet = true
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "theatermasks.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ar.zone.faceFilter.title")
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(.white)
                    Text("ar.zone.faceFilter.subtitle")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [ColorTokens.Brand.lilac, ColorTokens.Brand.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ar.zone.faceFilter.title"))
        .accessibilityHint(Text("ar.zone.faceFilter.hint"))
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

// MARK: - Preview

#Preview {
    ARZoneView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
