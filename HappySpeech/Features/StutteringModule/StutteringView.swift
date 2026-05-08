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

    // LoadScreen
    var cards: [ExerciseCardViewModel] = []
    var showWelcomeSheet: Bool = false
    var selectedMode: StutteringMode?

    // Progress
    var featureRows: [FeatureProgressViewModel] = []
    var totalSessionsLabel: String = ""
    var fluencyLabel: String = ""
    var showProgressPanel: Bool = false

    // Adaptive recommendation
    var recommendedMode: StutteringMode?
    var voicePromptText: String = ""
    var showGlowAnimation: Bool = false

    // MARK: - DisplayLogic

    func displayLoadScreen(_ viewModel: StutteringModels.LoadScreen.ViewModel) {
        cards = viewModel.cards
        showWelcomeSheet = viewModel.showWelcomeSheet
    }

    func displaySelectMode(_ viewModel: StutteringModels.SelectMode.ViewModel) {
        selectedMode = viewModel.mode
    }

    func displayLoadProgress(_ viewModel: StutteringModels.LoadProgress.ViewModel) {
        featureRows = viewModel.featureRows
        totalSessionsLabel = viewModel.totalSessionsLabel
        fluencyLabel = viewModel.fluencyLabel
        showProgressPanel = !viewModel.featureRows.isEmpty
    }

    func displayAdaptiveRecommendation(_ viewModel: StutteringModels.LoadAdaptiveRecommendation.ViewModel) {
        recommendedMode = viewModel.recommendedMode
        voicePromptText = viewModel.voicePromptText
        showGlowAnimation = viewModel.showGlowAnimation
    }
}

// MARK: - StutteringView

struct StutteringView: View {

    @State private var scene = StutteringScene()
    @State private var navigateTo: StutteringMode?
    @State private var showInfoType: InfoCardType?
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    progressToolbarButton
                }
            }
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
            .sheet(item: $showInfoType) { type in
                StutteringStaticInfoSheet(type: type) {
                    showInfoType = nil
                }
            }
            .navigationDestination(item: $navigateTo) { mode in
                StutteringRouter().destinationView(for: mode)
            }
        }
        .environment(\.circuitContext, .kid)
        .task {
            scene.interactor.loadScreen(.init())
            scene.interactor.loadProgress(.init())
            scene.interactor.loadAdaptiveRecommendation(.init())
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp5) {
                mascotHeader
                voicePromptBanner
                adaptiveRecommendationHighlight
                exerciseGrid
                educationalSection
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp2)
            .padding(.bottom, SpacingTokens.sp5)
        }
    }

    // MARK: - Mascot Header

    private var mascotHeader: some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSMascotView(mood: .encouraging, size: 140)
                .accessibilityLabel(String(localized: "stuttering.mascot.accessibility"))
                .accessibilityHidden(true)

            Text(String(localized: "stuttering.entry.subtitle"))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.sp4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Voice Prompt Banner

    @ViewBuilder
    private var voicePromptBanner: some View {
        if !scene.display.voicePromptText.isEmpty {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .font(TypographyTokens.body(16))
                Text(scene.display.voicePromptText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.sp3)
            .background(ColorTokens.Brand.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: RadiusTokens.md))
            .accessibilityLabel(scene.display.voicePromptText)
            .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Adaptive Recommendation Highlight

    @ViewBuilder
    private var adaptiveRecommendationHighlight: some View {
        if let recommended = scene.display.recommendedMode {
            AdaptiveRecommendationCard(
                mode: recommended,
                showGlow: scene.display.showGlowAnimation,
                reduceMotion: reduceMotion
            ) {
                navigateTo = recommended
            }
        }
    }

    // MARK: - Exercise Grid

    private var exerciseGrid: some View {
        GeometryReader { geo in
            let useTwoColumns = geo.size.width >= 375
            let columns = useTwoColumns
                ? [GridItem(.flexible(), spacing: SpacingTokens.sp3),
                   GridItem(.flexible(), spacing: SpacingTokens.sp3)]
                : [GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
                ForEach(Array(scene.display.cards.enumerated()), id: \.element.id) { idx, card in
                    ExerciseCard(
                        card: card,
                        isWide: !useTwoColumns,
                        isRecommended: card.mode == scene.display.recommendedMode
                    )
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
                : (scene.display.cards.count > 2 ? 420 : 140)
        )
    }

    // MARK: - Educational Section

    private var educationalSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "stuttering.section.education.title"))
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)

            InfoTile(
                titleKey: "stuttering.info.what.title",
                symbol: "questionmark.circle.fill",
                color: ColorTokens.Brand.sky
            ) {
                showInfoType = .whatIsStuttering
            }

            InfoTile(
                titleKey: "stuttering.info.how.title",
                symbol: "heart.fill",
                color: ColorTokens.Brand.mint
            ) {
                showInfoType = .howAppHelps
            }

            InfoTile(
                titleKey: "stuttering.info.techniques.title",
                symbol: "list.bullet.clipboard.fill",
                color: ColorTokens.Brand.butter
            ) {
                showInfoType = .techniques
            }
        }
        .padding(.top, SpacingTokens.sp2)
    }

    // MARK: - Progress Toolbar Button

    private var progressToolbarButton: some View {
        Button {
            scene.interactor.loadProgress(.init())
        } label: {
            Image(systemName: "chart.bar.fill")
                .foregroundStyle(ColorTokens.Brand.primary)
        }
        .accessibilityLabel(String(localized: "stuttering.toolbar.progress.accessibility"))
    }
}

// MARK: - AdaptiveRecommendationCard

private struct AdaptiveRecommendationCard: View {

    let mode: StutteringMode
    let showGlow: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var glowPulse: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "star.fill")
                    .foregroundStyle(ColorTokens.Brand.butter)
                    .font(TypographyTokens.headline(20))
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(String(localized: "stuttering.recommendation.title"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                    Text(localizedTitle)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .font(TypographyTokens.caption(14))
            }
            .padding(SpacingTokens.sp4)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.Brand.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.lg)
                            .stroke(ColorTokens.Brand.primary.opacity(glowPulse ? 0.5 : 0.2), lineWidth: 2)
                    )
                    .shadow(
                        color: ColorTokens.Brand.primary.opacity(glowPulse ? 0.3 : 0.0),
                        radius: glowPulse ? 12 : 0
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(String(localized: "stuttering.recommendation.title")), \(localizedTitle)")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            guard showGlow && !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var localizedTitle: String {
        switch mode {
        case .metronome:       return String(localized: "stuttering.exercise.metronome.title")
        case .breathing:       return String(localized: "stuttering.exercise.breathing.title")
        case .softOnset:       return String(localized: "stuttering.exercise.soft_start.title")
        case .diary:           return String(localized: "stuttering.exercise.diary.title")
        case .pacing:          return String(localized: "stuttering.exercise.pacing.title")
        case .metronomeRhythm: return String(localized: "stuttering.exercise.metronome_rhythm.title")
        case .easySpeech:      return String(localized: "stuttering.exercise.easy_speech.title")
        }
    }
}

// MARK: - InfoTile

private struct InfoTile: View {

    let titleKey: String
    let symbol: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .font(TypographyTokens.headline(18))
                    .frame(width: 32, height: 32)
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .font(TypographyTokens.caption(13))
            }
            .padding(SpacingTokens.sp3)
            .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: String.LocalizationValue(titleKey)))
        .accessibilityAddTraits(.isButton)
        .frame(minHeight: 56)
    }
}

// MARK: - ExerciseCard

private struct ExerciseCard: View {

    let card: ExerciseCardViewModel
    let isWide: Bool
    let isRecommended: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack {
                    Image(systemName: card.symbol)
                        .font(TypographyTokens.title(28))
                        .foregroundStyle(symbolColor)
                        .frame(width: 40, height: 40)
                    Spacer()
                    if card.completedToday {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.mint)
                            .font(TypographyTokens.body(16))
                            .accessibilityLabel(String(localized: "stuttering.card.completed.accessibility"))
                    }
                }
                Text(card.title)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(card.duration)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                if card.streak > 0 {
                    Label("\(card.streak)", systemImage: "flame.fill")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.rose)
                }
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
        case .rose:    return ColorTokens.Brand.rose
        case .lilac:   return ColorTokens.Brand.lilac
        case .gold:    return ColorTokens.Brand.gold
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

// MARK: - StutteringStaticInfoSheet

struct StutteringStaticInfoSheet: View {

    let type: InfoCardType
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Image(systemName: iconSymbol)
                .font(TypographyTokens.kidDisplay(48))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.sp3) {
                Text(title)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)

                Text(infoBody)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, SpacingTokens.sp5)

            HSButton(
                String(localized: "stuttering.info.close"),
                style: .secondary,
                action: onDismiss
            )
            .frame(height: 56)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(.vertical, SpacingTokens.sp8)
        .environment(\.circuitContext, .kid)
    }

    private var title: String {
        switch type {
        case .whatIsStuttering: return String(localized: "stuttering.info.what.title")
        case .howAppHelps:      return String(localized: "stuttering.info.how.title")
        case .techniques:       return String(localized: "stuttering.info.techniques.title")
        }
    }

    private var infoBody: String {
        switch type {
        case .whatIsStuttering: return String(localized: "stuttering.info.what.body")
        case .howAppHelps:      return String(localized: "stuttering.info.how.body")
        case .techniques:       return String(localized: "stuttering.info.techniques.body")
        }
    }

    private var iconSymbol: String {
        switch type {
        case .whatIsStuttering: return "questionmark.circle.fill"
        case .howAppHelps:      return "heart.fill"
        case .techniques:       return "list.bullet.clipboard.fill"
        }
    }

    private var iconColor: Color {
        switch type {
        case .whatIsStuttering: return ColorTokens.Brand.sky
        case .howAppHelps:      return ColorTokens.Brand.mint
        case .techniques:       return ColorTokens.Brand.butter
        }
    }
}

// MARK: - InfoCardType + Identifiable

extension InfoCardType: Identifiable {
    var id: String {
        switch self {
        case .whatIsStuttering: return "whatIsStuttering"
        case .howAppHelps:      return "howAppHelps"
        case .techniques:       return "techniques"
        }
    }
}

// MARK: - Preview

#Preview("StutteringView") {
    StutteringView()
        .environment(\.circuitContext, .kid)
}
