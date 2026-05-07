import OSLog
import SwiftUI

// MARK: - DemoAccentColor + Resolved Colors

/// Маппинг семантического акцента шага → конкретные `Color` из ColorTokens.
/// Хранится в слое View, чтобы Models / Presenter оставались UIKit-free.
private extension DemoAccentColor {

    /// Базовый цвет акцента (используется на иконках, кнопках, маскоте).
    var resolvedColor: Color {
        switch self {
        case .primary: return ColorTokens.Brand.primary
        case .purple:  return ColorTokens.Brand.lilac
        case .orange:  return ColorTokens.Brand.primaryHi
        case .teal:    return ColorTokens.Brand.sky
        case .green:   return ColorTokens.Brand.mint
        case .sky:     return ColorTokens.Brand.sky
        case .mint:    return ColorTokens.Brand.mint
        case .lilac:   return ColorTokens.Brand.lilac
        case .butter:  return ColorTokens.Brand.butter
        case .gold:    return ColorTokens.Brand.gold
        case .rose:    return ColorTokens.Brand.rose
        case .parent:  return ColorTokens.Parent.accent
        case .spec:    return ColorTokens.Spec.accent
        }
    }

    /// Вторая точка градиента (отличается оттенком, чтобы дать «глубину»).
    var resolvedSecondary: Color {
        switch self {
        case .primary: return ColorTokens.Brand.lilac
        case .purple:  return ColorTokens.Brand.primary
        case .orange:  return ColorTokens.Brand.butter
        case .teal:    return ColorTokens.Brand.lilac
        case .green:   return ColorTokens.Brand.sky
        case .sky:     return ColorTokens.Brand.mint
        case .mint:    return ColorTokens.Brand.sky
        case .lilac:   return ColorTokens.Brand.sky
        case .butter:  return ColorTokens.Brand.gold
        case .gold:    return ColorTokens.Brand.butter
        case .rose:    return ColorTokens.Brand.primary
        case .parent:  return ColorTokens.Brand.sky
        case .spec:    return ColorTokens.Brand.lilac
        }
    }
}

// MARK: - DemoModeView
//
// Полноэкранный 15-шаговый walkthrough.
//
// Каждый шаг — слайд с:
//   • динамическим линейным градиентом (accent → secondary);
//   • декоративными плавающими «парус»-кругами поверх фона;
//   • большой круглой illustration (SF Symbol) с тенью;
//   • заголовком (Display), подзаголовком (Caption), описанием (Body);
//   • маскотом Лялей в нужном состоянии (waving / explaining / pointing / …);
//   • опциональной кнопкой «Попробовать!» (для интерактивных шагов 4 и 5);
//   • прогресс-баром «Шаг N из 15» в шапке;
//   • кнопками «Назад» / «Далее» (или «Начать!» на последнем);
//   • кнопкой «Пропустить» в toolbar.
//
// Свайп TabView .page переключает шаги (Reduced Motion → без animation).
// Все интерактивные элементы имеют `accessibilityLabel` / `accessibilityHint`.

struct DemoModeView: View {

    // MARK: - Environment

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    // MARK: - VIP State

    @State private var display = DemoDisplay()
    @State private var interactor: DemoInteractor?
    @State private var presenter: DemoPresenter?
    @State private var router: DemoRouter?
    @State private var bootstrapped = false

    // MARK: - Local UI State

    /// Показывать ли Overview Sheet со списком всех 15 шагов.
    @State private var showOverview = false
    /// Локальный обратный отсчёт авто-перехода (5→0).
    @State private var countdownSeconds: Int = 5
    /// Timer для отображения обратного отсчёта (отдельно от autoAdvanceTask в Interactor).
    @State private var countdownTimer: Timer?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DemoModeView")

    // MARK: - Init

    init() {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                animatedBackground
                contentLayer
                if let toast = display.toastMessage {
                    toastOverlay(toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
                // AutoAdvance countdown overlay (правый нижний угол над carousel)
                if display.autoAdvanceEnabled {
                    autoAdvanceCountdownOverlay
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(3)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    overviewButton
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    replayButton
                    autoAdvanceToggleButton
                    skipButton
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showOverview) {
                DemoOverviewSheet(
                    steps: display.steps,
                    currentIndex: display.currentIndex
                ) { index in
                    interactor?.jumpTo(.init(index: index))
                }
            }
        }
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.pendingSkip) { _, value in
            guard value else { return }
            display.consumeSkip()
            stopCountdown()
            coordinator.navigate(to: .auth)
        }
        .onChange(of: display.pendingCompleted) { _, value in
            guard value else { return }
            display.consumeCompleted()
            stopCountdown()
            coordinator.navigate(to: .auth)
        }
        .onChange(of: display.toastMessage) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_400_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .linear(duration: 0.01) : MotionTokens.spring) {
                    display.consumeToast()
                }
            }
        }
        .onChange(of: display.autoAdvanceEnabled) { _, enabled in
            if enabled {
                startCountdown()
            } else {
                stopCountdown()
            }
        }
        .onChange(of: display.currentIndex) { _, _ in
            // При переходе на новый шаг — сбрасываем отсчёт.
            if display.autoAdvanceEnabled {
                startCountdown()
            }
        }
    }

    // MARK: - Animated background

    /// Динамический градиент: accent → secondary текущего шага. При свайпе
    /// между шагами SwiftUI плавно интерполирует градиент.
    private var animatedBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    display.accent.resolvedColor,
                    display.accent.resolvedSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(ColorTokens.Overlay.glass)
                    .frame(width: 320)
                    .offset(x: -120, y: -260)
                Circle()
                    .fill(ColorTokens.Overlay.glass)
                    .frame(width: 220)
                    .offset(x: 140, y: 80)
                Circle()
                    .fill(ColorTokens.Overlay.glass)
                    .frame(width: 160)
                    .offset(x: -80, y: 240)
            }
            .accessibilityHidden(true)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: display.accent)
    }

    // MARK: - Content layer

    private var contentLayer: some View {
        VStack(spacing: 0) {
            progressHeader
            Spacer(minLength: SpacingTokens.medium)
            stepCarousel
            Spacer(minLength: SpacingTokens.medium)
            mascotBubble
            Spacer(minLength: SpacingTokens.medium)
            actionRow
        }
        .padding(.bottom, SpacingTokens.large)
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack {
                Text(display.progressLabel)
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityIdentifier("demo.progress.label")
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            ProgressView(value: display.progress)
                .progressViewStyle(.linear)
                .tint(.white)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .accessibilityHidden(true)

            // DotNavigator под прогресс-баром
            if !display.steps.isEmpty {
                DemoDotNavigator(
                    totalSteps: display.steps.count,
                    currentIndex: display.currentIndex,
                    accent: display.accent.resolvedColor
                ) { index in
                    interactor?.jumpTo(.init(index: index))
                }
            }
        }
        .padding(.top, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.progressLabel)
    }

    // MARK: - Toolbar buttons

    private var skipButton: some View {
        Button {
            interactor?.skipDemo(.init())
        } label: {
            Text(String(localized: "demo.cta.skip"))
                .font(TypographyTokens.body(14).weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .frame(minWidth: 44, minHeight: 44)
                .background(Color.black.opacity(0.001))
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "demo.a11y.skip"))
        .accessibilityHint(String(localized: "demo.a11y.skip.hint"))
        .accessibilityIdentifier("demo.skip")
    }

    private var replayButton: some View {
        Button {
            interactor?.replayStep(.init())
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(TypographyTokens.body(16))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "demo.replay.button"))
        .accessibilityHint(String(localized: "demo.replay.hint"))
        .accessibilityIdentifier("demo.replay")
    }

    private var autoAdvanceToggleButton: some View {
        Button {
            interactor?.toggleAutoAdvance(.init())
        } label: {
            Image(systemName: display.autoAdvanceEnabled ? "play.circle.fill" : "play.circle")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(display.autoAdvanceEnabled ? .white : .white.opacity(0.7))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(display.autoAdvanceEnabled
            ? String(localized: "demo.autoadvance.toggle.on")
            : String(localized: "demo.autoadvance.toggle.off")
        )
        .accessibilityIdentifier("demo.autoadvance.toggle")
    }

    private var overviewButton: some View {
        Button {
            showOverview = true
        } label: {
            Image(systemName: "list.bullet.rectangle")
                .font(TypographyTokens.body(16))
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "demo.overview.label"))
        .accessibilityIdentifier("demo.overview")
    }

    // MARK: - AutoAdvance countdown overlay

    private var autoAdvanceCountdownOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                DemoAutoAdvanceCountdownView(
                    secondsLeft: countdownSeconds,
                    accent: display.accent.resolvedColor
                )
                .padding(.trailing, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.xLarge + SpacingTokens.xLarge)
            }
        }
    }

    // MARK: - Countdown helpers

    private func startCountdown() {
        countdownSeconds = 5
        stopCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.countdownSeconds > 0 {
                    self.countdownSeconds -= 1
                } else {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = 5
    }

    // MARK: - Step carousel

    /// TabView с .page стилем: пользователь может свайпать между шагами,
    /// или нажимать «Назад / Далее». Reduced Motion: TabView сам не делает
    /// тяжёлых анимаций, но мы убираем дополнительный transition вокруг card.
    @ViewBuilder
    private var stepCarousel: some View {
        if display.steps.isEmpty {
            HSCard(style: .elevated, padding: SpacingTokens.xLarge) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.screenEdge)
        } else {
            TabView(selection: pageBinding) {
                ForEach(Array(display.steps.enumerated()), id: \.offset) { index, step in
                    stepCard(for: step)
                        .tag(index)
                        .padding(.horizontal, SpacingTokens.screenEdge)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 420)
            .accessibilityIdentifier("demo.carousel")
        }
    }

    /// Биндинг для TabView selection. Чтение → текущий index из display,
    /// запись → отправляет JumpTo в Interactor.
    private var pageBinding: Binding<Int> {
        Binding(
            get: { display.currentIndex },
            set: { newValue in
                interactor?.jumpTo(.init(index: newValue))
            }
        )
    }

    // MARK: - Step card

    private func stepCard(for step: DemoStep) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.large) {
            VStack(spacing: SpacingTokens.medium) {
                illustrationView(for: step)
                VStack(spacing: SpacingTokens.tiny) {
                    if !step.subtitle.isEmpty {
                        Text(step.subtitle.uppercased())
                            .font(TypographyTokens.mono(11))
                            .foregroundStyle(step.accent.resolvedColor.opacity(0.9))
                            .tracking(1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Text(step.title)
                        .font(TypographyTokens.title(24))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .accessibilityIdentifier("demo.step.title")
                    Text(step.description)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, SpacingTokens.tiny)
                }

                if step.hasInteractive, let actionTitle = step.actionTitle {
                    Button {
                        interactor?.tapInteractive(.init())
                    } label: {
                        Label(actionTitle, systemImage: "play.circle.fill")
                            .font(TypographyTokens.cta())
                            .foregroundStyle(.white)
                            .padding(.horizontal, SpacingTokens.medium)
                            .padding(.vertical, SpacingTokens.small)
                            .background(
                                Capsule()
                                    .fill(step.accent.resolvedColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(actionTitle)
                    .accessibilityHint(String(localized: "demo.try.hint"))
                    .accessibilityIdentifier("demo.try.button")
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(combinedAccessibilityLabel(for: step))
    }

    // MARK: - Illustration

    /// Большой круглый «постер» шага: SF Symbol по центру + emoji-fallback
    /// + тень. Если у шага задан `illustrationSymbol` — рендерим Image,
    /// иначе используем `screenSymbol` как Text.
    @ViewBuilder
    private func illustrationView(for step: DemoStep) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            step.accent.resolvedColor.opacity(0.85),
                            step.accent.resolvedSecondary.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .shadow(color: step.accent.resolvedColor.opacity(0.35), radius: 20, y: 8)

            if !step.illustrationSymbol.isEmpty {
                Image(systemName: step.illustrationSymbol)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: step.screenSymbol)
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
        }
        .padding(.top, SpacingTokens.small)
    }

    // MARK: - Mascot bubble

    private var mascotBubble: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            LyalyaMascotView(state: display.lyalyaState, size: 72)
                .accessibilityHidden(true)

            HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
                Text(display.mascotText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "demo.a11y.mascot"), display.mascotText)
        )
        .accessibilityIdentifier("demo.mascot.bubble")
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: SpacingTokens.small) {
            HSButton(
                display.backTitle,
                style: .secondary,
                size: .medium,
                icon: "chevron.left"
            ) {
                interactor?.goBack(.init())
            }
            .disabled(display.isFirst)
            .opacity(display.isFirst ? 0.5 : 1.0)
            .accessibilityHint(String(localized: "demo.a11y.back.hint"))
            .accessibilityIdentifier("demo.back.button")

            if display.isLast {
                HSButton(
                    display.nextTitle,
                    style: .primary,
                    icon: "checkmark"
                ) {
                    interactor?.completeDemo(.init())
                }
                .accessibilityHint(String(localized: "demo.a11y.finish.hint"))
                .accessibilityIdentifier("demo.finish.button")
            } else {
                HSButton(
                    display.nextTitle,
                    style: .primary,
                    icon: "chevron.right"
                ) {
                    interactor?.advanceStep(.init())
                }
                .accessibilityHint(String(localized: "demo.a11y.next.hint"))
                .accessibilityIdentifier("demo.next.button")
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    // MARK: - Toast overlay

    private func toastOverlay(_ message: String) -> some View {
        VStack {
            HStack(spacing: SpacingTokens.small) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.white)
                Text(message)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, SpacingTokens.medium)
            .padding(.vertical, SpacingTokens.small)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.75))
            )
            .padding(.top, SpacingTokens.xLarge)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Helpers

    private func combinedAccessibilityLabel(for step: DemoStep) -> String {
        let subtitle = step.subtitle.isEmpty ? "" : "\(step.subtitle). "
        return "\(subtitle)\(step.title). \(step.description)"
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let presenter = DemoPresenter()
        presenter.display = display
        let interactor = DemoInteractor()
        interactor.presenter = presenter
        let router = DemoRouter()
        let coord = coordinator
        router.onSkipped = { coord.navigate(to: .auth) }
        router.onCompleted = { coord.navigate(to: .auth) }
        router.onRouteToHome = { coord.navigate(to: .auth) }

        self.presenter = presenter
        self.interactor = interactor
        self.router = router

        interactor.loadDemo(.init())
    }
}

// MARK: - Preview

#Preview("DemoMode") {
    DemoModeView()
        .environment(AppCoordinator())
}
