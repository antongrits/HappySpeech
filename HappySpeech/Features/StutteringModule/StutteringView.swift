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
        ZStack {
            // Спокойный ОДНОТОННЫЙ тёплый фон (cream), статичный.
            HSMeshGradientBackground(palette: .calm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            scrollContent
        }
        // open-design: inline title — крупный заголовок встроен в scroll-контент.
        .navigationTitle(String(localized: "stuttering.entry.title"))
        .navigationBarTitleDisplayMode(.inline)
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
            VStack(spacing: 0) {
                // open-design: большой заголовок + subtitle внутри scroll (не navigationTitle large).
                hubHeader
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp2)
                    .padding(.bottom, SpacingTokens.sp4)

                // Ляля + speech bubble (open-design: mascot row immediately under heading)
                mascotBubbleRow
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp4)

                // Adaptive recommendation strip (optional)
                if scene.display.recommendedMode != nil {
                    adaptiveRecommendationHighlight
                        .padding(.horizontal, SpacingTokens.screenEdge)
                        .padding(.bottom, SpacingTokens.sp3)
                }

                // Voice prompt (optional)
                if !scene.display.voicePromptText.isEmpty {
                    voicePromptBanner
                        .padding(.horizontal, SpacingTokens.screenEdge)
                        .padding(.bottom, SpacingTokens.sp3)
                }

                // Section header "Инструменты · выбери своё"
                toolsSectionHeader
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp3)

                // 2×2 grid + full-width diary card (open-design layout)
                exerciseGrid
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp5)

                // Educational info tiles
                educationalSection
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.bottom, SpacingTokens.sp5)
            }
        }
    }

    // MARK: - Hub Header (large title in scroll, open-design)

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(String(localized: "stuttering.hub.title", defaultValue: "Плавная речь"))
                .font(TypographyTokens.kidHero(32).weight(.heavy))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "stuttering.hub.subtitle", defaultValue: "Спокойные инструменты для ритма, дыхания и мягкого начала."))
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Mascot Bubble Row (open-design: Ляля left + speech bubble right)

    private var mascotBubbleRow: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 66)
                .accessibilityHidden(true)

            // Speech bubble with left-tail (open-design style)
            ZStack(alignment: .leading) {
                // tail (rotated square)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .frame(width: 14, height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: -7)

                Text(String(localized: "stuttering.hub.bubble",
                            defaultValue: "Дыши спокойно. Будем говорить плавно, не спеша."))
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, SpacingTokens.sp3)
                    .padding(.horizontal, SpacingTokens.sp3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                    .padding(.leading, SpacingTokens.sp2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "stuttering.mascot.accessibility",
                   defaultValue: "Ляля говорит: Дыши спокойно. Будем говорить плавно, не спеша.")
        )
    }

    // MARK: - Voice Prompt Banner

    @ViewBuilder
    private var voicePromptBanner: some View {
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
        .background(ColorTokens.Brand.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: RadiusTokens.md))
        .accessibilityLabel(scene.display.voicePromptText)
        .accessibilityAddTraits(.isStaticText)
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

    // MARK: - Tools Section Header (open-design: "Инструменты" + "выбери своё")

    private var toolsSectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "stuttering.section.tools.title", defaultValue: "Инструменты"))
                .font(TypographyTokens.headline(17).weight(.heavy))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: SpacingTokens.sp2)
            Text(String(localized: "stuttering.section.tools.hint", defaultValue: "выбери своё"))
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Exercise Grid (open-design: 2-col grid + full-width diary card)
    //
    // Layout: 4 tool cards in 2×2 grid, then diary card full-width at bottom.
    // ExerciseCard uses opaque surface fill (not glass) matching open-design .tool style.

    private var exerciseGrid: some View {
        let nonDiaryCards = scene.display.cards.filter { $0.mode != .diary }
        let diaryCard = scene.display.cards.first(where: { $0.mode == .diary })
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: SpacingTokens.sp3),
            GridItem(.flexible(), spacing: SpacingTokens.sp3)
        ]

        return VStack(spacing: SpacingTokens.sp3) {
            LazyVGrid(columns: columns, spacing: SpacingTokens.sp3) {
                ForEach(Array(nonDiaryCards.enumerated()), id: \.element.id) { idx, card in
                    ExerciseCard(
                        card: card,
                        isWide: false,
                        isRecommended: card.mode == scene.display.recommendedMode
                    )
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0.15)
                            : MotionTokens.spring.delay(Double(idx) * 0.08),
                        value: nonDiaryCards.count
                    )
                    .onTapGesture { navigateTo = card.mode }
                }
            }

            // Full-width diary card (open-design: diary-card spanning both columns)
            if let diary = diaryCard {
                DiaryCard(card: diary,
                          isRecommended: diary.mode == scene.display.recommendedMode) {
                    navigateTo = diary.mode
                }
            }
        }
    }

    // MARK: - Educational Section

    private var educationalSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            Text(String(localized: "stuttering.section.education.title"))
                .font(TypographyTokens.headline(16).weight(.heavy))
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
                        .fixedSize(horizontal: false, vertical: true)
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
                // Fix v33 P1 — иконка укрупнена и обведена tinted-кругом,
                // чтобы стопка из 3 InfoTile считывалась как «3 разных карточки»,
                // а не как «бледная мутная стопка» поверх mesh-фона .calm.
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .font(TypographyTokens.headline(20))
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.14), in: Circle())
                Text(String(localized: String.LocalizationValue(titleKey)))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .font(TypographyTokens.caption(13))
            }
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(color.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: String.LocalizationValue(titleKey)))
        .accessibilityAddTraits(.isButton)
        .frame(minHeight: 60)
    }
}

// MARK: - ExerciseCard
//
// open-design .tool: opaque surface background, 1pt line border, border-radius 22px.
// Tinted icon circle (background = accent @ 16% opacity), bold title, muted duration.
// Height fixed at 130pt — matches 2-column grid proportions on 375pt.

private struct ExerciseCard: View {

    let card: ExerciseCardViewModel
    let isWide: Bool
    let isRecommended: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            // Tinted icon container (open-design: .ticon width=44 border-radius=14)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(symbolColor.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: card.symbol)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(symbolColor)
            }

            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                HStack(alignment: .top) {
                    Text(card.title)
                        .font(TypographyTokens.headline(16).weight(.heavy))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                        .lineLimit(2)
                    if card.completedToday {
                        Spacer(minLength: 2)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.Brand.mint)
                            .font(TypographyTokens.body(14))
                            .hsSymbolEffect(.bounce, value: card.completedToday)
                            .accessibilityLabel(
                                String(localized: "stuttering.card.completed.accessibility")
                            )
                    }
                }
                Text(card.duration)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                if card.streak > 0 {
                    Label("\(card.streak)", systemImage: "flame.fill")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Brand.rose)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(SpacingTokens.sp4)
        .background(ColorTokens.Kid.surface)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(
                    isRecommended
                        ? ColorTokens.Brand.primary.opacity(0.45)
                        : ColorTokens.Kid.line,
                    lineWidth: isRecommended ? 2 : 1
                )
        )
        .shadow(color: ColorTokens.Overlay.shadow, radius: 8, y: 4)
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

// MARK: - DiaryCard
//
// open-design .diary-card: full-width, horizontal layout — icon · text body · chevron.
// Accent color = Brand.gold (diary icon), subtitle = "last entry" row with mint dot.

private struct DiaryCard: View {

    let card: ExerciseCardViewModel
    let isRecommended: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SpacingTokens.sp3) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ColorTokens.Brand.gold.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: card.symbol)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Brand.gold)
                }

                // Text body
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(card.title)
                        .font(TypographyTokens.headline(16).weight(.heavy))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: SpacingTokens.sp1) {
                        Circle()
                            .fill(card.completedToday
                                  ? ColorTokens.Brand.mint
                                  : ColorTokens.Kid.inkSoft)
                            .frame(width: 8, height: 8)
                        Text(card.completedToday
                             ? String(localized: "stuttering.diary.today_done",
                                     defaultValue: "Сегодня · запись сделана")
                             : String(localized: "stuttering.diary.today_pending",
                                     defaultValue: "Сегодня · добавь запись"))
                            .font(TypographyTokens.caption(12).weight(.semibold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .padding(SpacingTokens.sp4)
            .background(ColorTokens.Kid.surface)
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(
                        isRecommended
                            ? ColorTokens.Brand.primary.opacity(0.45)
                            : ColorTokens.Kid.line,
                        lineWidth: isRecommended ? 2 : 1
                    )
            )
            .shadow(color: ColorTokens.Overlay.shadow, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1.0)
        .animation(MotionTokens.spring, value: isPressed)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - StutteringWelcomeSheet

struct StutteringWelcomeSheet: View {

    let onStart: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.sp6) {
            Spacer(minLength: 0)

            // Fix #12 — welcome sheet stuttering модуля использует
            // канонического маскота LyalyaMascotView в waving (как AR-зона),
            // а не «.idle» HSMascotView — единый бренд во всём приложении.
            LyalyaMascotView(state: .waving, size: 120)

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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SpacingTokens.sp5)

            Spacer(minLength: 0)

            HSButton(
                String(localized: "stuttering.welcome.cta"),
                style: .primary,
                action: onStart
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .frame(height: 56)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, SpacingTokens.sp8)
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .environment(\.circuitContext, .kid)
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
    NavigationStack {
        StutteringView()
    }
    .environment(\.circuitContext, .kid)
}
