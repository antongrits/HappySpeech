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
                    heroSection
                    instructionsSection
                    activitiesHeader
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
        .onAppear { bootstrap() }
        .task {
            // Показываем placeholder первые ~300 мс — USDZ успевает подгрузиться,
            // затем interactor пересчитает phase в .ready / .unsupported.
            try? await Task.sleep(for: .milliseconds(300))
            interactor?.loadGames(.init())
        }
    }

    // MARK: - Hero section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            heroMascot
            Text("ar.zone.greeting")
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("ar.zone.subtitle")
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    /// Hero-маскот 240pt с placeholder-пульсацией первые ~300 мс загрузки.
    /// На iPhone SE — 2D эмодзи-фоллбэк 🦋 (ARMascot2DFallback).
    @ViewBuilder
    private var heroMascot: some View {
        ZStack {
            if isCompactDevice {
                ARMascot2DFallback(size: 160)
            } else {
                LyalyaRealityView(
                    animation: viewModelHolder.mascotState,
                    size: 240
                )
                .accessibilityLabel(Text("ar.zone.mascot.accessibility"))
                // Placeholder — пульсирующий круг поверх 3D пока phase = .loading
                if viewModelHolder.phase == .loading {
                    ARMascotLoadingPlaceholder(size: 240)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, SpacingTokens.tiny)
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

    // MARK: - Activities section

    private var activitiesHeader: some View {
        Text("ar.zone.activitiesSection")
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .padding(.top, SpacingTokens.small)
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

    private var gamesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: SpacingTokens.small),
                GridItem(.flexible(), spacing: SpacingTokens.small)
            ],
            spacing: SpacingTokens.small
        ) {
            ForEach(viewModelHolder.cards) { card in
                Button {
                    interactor?.selectGame(.init(gameId: card.id))
                } label: {
                    ARGameCardView(card: card)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(card.title))
                .accessibilityHint(Text(card.subtitle))
            }
        }
    }

    @ViewBuilder
    private var unsupportedNotice: some View {
        if !viewModelHolder.isARSupported {
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Semantic.warning)
                VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                    Text("ar.zone.unsupportedTitle")
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text("ar.zone.unsupportedBody")
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
            }
            .padding(SpacingTokens.regular)
            .background(ColorTokens.Semantic.warningBg)
            .cornerRadius(RadiusTokens.md)
        }
    }

    // MARK: - Wiring

    private func bootstrap() {
        guard interactor == nil else { return }
        let interactor = ARZoneInteractor()
        let presenter = ARZonePresenter()
        let router = ARZoneRouter()

        interactor.presenter = presenter
        presenter.viewModel = viewModelHolder
        router.coordinator = coordinator
        router.onNavigateLocal = { [weak viewModelHolder] destination in
            viewModelHolder?.path.append(destination)
        }

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
    var cards: [ARGameCard] = []
    var instructionSteps: [InstructionStep] = []
    var mascotState: LyalyaAnimation = .idle
    var phase: ARZonePhase = .loading
    var isARSupported: Bool = true
    var path: [ARGameDestination] = []

    func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel) {
        self.cards = viewModel.cards
        self.instructionSteps = viewModel.instructionSteps
        self.mascotState = viewModel.mascotState
        self.phase = viewModel.phase
        self.isARSupported = viewModel.isARSupported
    }

    func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel) {
        path.append(viewModel.destination)
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
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
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

// MARK: - ARGameCardView

private struct ARGameCardView: View {
    let card: ARGameCard
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = ARCardPalette.gradient(for: card.accentColorIndex)
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            HStack {
                Image(systemName: card.iconName)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
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

// MARK: - Preview

#Preview {
    ARZoneView()
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
