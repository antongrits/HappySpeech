import SwiftUI

// MARK: - StutteringScene (VIP scene holder)

@MainActor
final class StutteringScene {
    let interactor: StutteringInteractor
    let presenter: StutteringPresenter
    let display: StutteringDisplay

    init() {
        let interactor = StutteringInteractor()
        let presenter = StutteringPresenter()
        let display = StutteringDisplay()
        presenter.view = display
        interactor.presenter = presenter
        self.interactor = interactor
        self.presenter = presenter
        self.display = display
    }
}

// MARK: - StutteringDisplay (@Observable)

@Observable
@MainActor
final class StutteringDisplay: StutteringDisplayLogic {
    var cards: [ExerciseCardViewModel] = []
    var showWelcomeSheet: Bool = false
    var selectedMode: StutteringMode?

    func displayLoadScreen(_ viewModel: StutteringModels.LoadScreen.ViewModel) {
        cards = viewModel.cards
        showWelcomeSheet = viewModel.showWelcomeSheet
    }

    func displaySelectMode(_ viewModel: StutteringModels.SelectMode.ViewModel) {
        selectedMode = viewModel.mode
    }
}

// MARK: - StutteringView

struct StutteringView: View {

    @State private var scene = StutteringScene()
    @State private var navigateTo: StutteringMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("stuttering_welcome_shown") private var welcomeShown: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                scrollContent
            }
            .navigationTitle(String(localized: "stuttering.entry.title"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: Binding(
                get: { scene.display.showWelcomeSheet },
                set: { _ in }
            )) {
                StutteringWelcomeSheet {
                    welcomeShown = true
                    scene.interactor.markWelcomeSeen()
                    scene.display.showWelcomeSheet = false
                }
            }
            .navigationDestination(item: $navigateTo) { mode in
                destinationView(for: mode)
            }
        }
        .environment(\.circuitContext, .kid)
        .task {
            scene.interactor.loadScreen(.init())
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp5) {
                mascotHeader
                exerciseGrid
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)
        }
    }

    private var mascotHeader: some View {
        HSMascotView(mood: .idle)
            .frame(width: 100, height: 100)
            .frame(maxWidth: .infinity)
    }

    private var exerciseGrid: some View {
        GeometryReader { geo in
            let useTwoColumns = geo.size.width >= 375
            let columns = useTwoColumns
                ? [GridItem(.flexible(), spacing: SpacingTokens.sp3),
                   GridItem(.flexible(), spacing: SpacingTokens.sp3)]
                : [GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
                ForEach(Array(scene.display.cards.enumerated()), id: \.element.id) { idx, card in
                    ExerciseCard(card: card, isWide: !useTwoColumns)
                        .opacity(1)
                        .scaleEffect(1)
                        .animation(
                            reduceMotion
                                ? .linear(duration: 0.15)
                                : MotionTokens.spring.delay(Double(idx) * 0.08),
                            value: scene.display.cards.count
                        )
                        .onTapGesture {
                            navigateTo = card.mode
                        }
                }
            }
        }
        .frame(
            minHeight: scene.display.cards.isEmpty
                ? 0
                : (scene.display.cards.count > 2 ? 280 : 140)
        )
    }

    @ViewBuilder
    private func destinationView(for mode: StutteringMode) -> some View {
        switch mode {
        case .metronome:
            MetronomeView()
        case .breathing:
            BreathingTreeView()
        case .softOnset:
            SoftOnsetView()
        case .diary:
            FluencyDiaryView()
        }
    }
}

// MARK: - ExerciseCard

private struct ExerciseCard: View {

    let card: ExerciseCardViewModel
    let isWide: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Image(systemName: card.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .frame(width: 40, height: 40)

                Text(card.title)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(card.duration)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: isWide ? 100 : 130)
        }
        .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
        .animation(MotionTokens.spring, value: isPressed)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var symbolColor: Color {
        switch card.symbolColor {
        case .primary: return ColorTokens.Brand.primary
        case .mint:    return ColorTokens.Brand.mint
        case .butter:  return ColorTokens.Brand.butter
        case .sky:     return ColorTokens.Brand.sky
        }
    }
}

// MARK: - StutteringWelcomeSheet

struct StutteringWelcomeSheet: View {

    let onStart: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.sp6) {
            HSMascotView(mood: .idle)
                .frame(width: 120, height: 120)

            VStack(spacing: SpacingTokens.sp3) {
                Text(String(localized: "stuttering.welcome.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)

                Text(String(localized: "stuttering.welcome.disclaimer"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, SpacingTokens.sp5)

            HSButton(
                String(localized: "stuttering.welcome.cta"),
                style: .primary,
                action: onStart
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .frame(height: 56)
        }
        .padding(.vertical, SpacingTokens.sp8)
        .environment(\.circuitContext, .parent)
    }
}

// MARK: - Preview

#Preview("StutteringView") {
    StutteringView()
        .environment(\.circuitContext, .kid)
}
