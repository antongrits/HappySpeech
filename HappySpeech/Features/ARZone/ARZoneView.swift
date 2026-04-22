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

    var body: some View {
        NavigationStack(path: $viewModelHolder.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: SpacingTokens.large) {
                    header
                    if !viewModelHolder.cards.isEmpty {
                        gamesGrid
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, SpacingTokens.xxLarge)
                    }
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
            interactor?.loadGames(.init())
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text("ar.zone.greeting")
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("ar.zone.subtitle")
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
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
    var isARSupported: Bool = true
    var path: [ARGameDestination] = []

    func displayLoadGames(_ viewModel: ARZoneModels.LoadGames.ViewModel) {
        self.cards = viewModel.cards
        self.isARSupported = viewModel.isARSupported
    }

    func displaySelectGame(_ viewModel: ARZoneModels.SelectGame.ViewModel) {
        path.append(viewModel.destination)
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
