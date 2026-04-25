import SwiftUI
import OSLog

// MARK: - DemoModeView
//
// 15-шаговый walkthrough. Каждый шаг показывает:
//   – заголовок и описание раздела;
//   – большой emoji-постер «экрана» (или Spotlight-вырез поверх затемнения);
//   – маскот Ляля с подсказкой в облачке;
//   – прогресс «Шаг N из 15» + LinearProgressView;
//   – кнопки Назад / Далее (или «Завершить» на 15-м шаге);
//   – кнопку Skip в toolbar.
//
// Сигнатура `init()` сохранена для AppCoordinator.

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

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DemoModeView")

    // MARK: - Init

    init() {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    progressHeader
                    Spacer(minLength: SpacingTokens.large)
                    spotlightCanvas
                    Spacer(minLength: SpacingTokens.large)
                    mascotBubble
                    Spacer(minLength: SpacingTokens.large)
                    actionRow
                }
                .padding(.bottom, SpacingTokens.large)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        interactor?.skipDemo(.init())
                    } label: {
                        Text(String(localized: "demo.cta.skip"))
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel(String(localized: "demo.a11y.skip"))
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.circuitContext, .kid)
        .task { await bootstrap() }
        .onChange(of: display.pendingSkip) { _, value in
            guard value else { return }
            display.consumeSkip()
            coordinator.navigate(to: .auth)
        }
        .onChange(of: display.pendingCompleted) { _, value in
            guard value else { return }
            display.consumeCompleted()
            coordinator.navigate(to: .auth)
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                ColorTokens.Brand.primary.opacity(0.95),
                ColorTokens.Brand.lilac.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // Decorative parallax circles
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                    .frame(width: 280)
                    .offset(x: -100, y: -200)
                Circle().fill(Color.white.opacity(0.04))
                    .frame(width: 200)
                    .offset(x: 130, y: 60)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Progress header

    private var progressHeader: some View {
        VStack(spacing: SpacingTokens.tiny) {
            HStack {
                Text(display.progressLabel)
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            ProgressView(value: display.progress)
                .progressViewStyle(.linear)
                .tint(.white)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .accessibilityHidden(true)
        }
        .padding(.top, SpacingTokens.tiny)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.progressLabel)
    }

    // MARK: - Spotlight canvas

    /// Имитирует «вырез» в затемнённом overlay'е поверх предполагаемого
    /// «экрана»-карточки. Использует Canvas + .blendMode(.destinationOut),
    /// чтобы получить дырку круглой формы.
    private var spotlightCanvas: some View {
        ZStack {
            // Фейковый «экран» приложения за overlay'ем.
            HSCard(style: .elevated, padding: SpacingTokens.xLarge) {
                VStack(spacing: SpacingTokens.medium) {
                    Text(display.screenEmoji)
                        .font(.system(size: 88))
                        .accessibilityHidden(true)
                    Text(display.stepTitle)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                    Text(display.stepDescription)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, SpacingTokens.tiny)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
            .id(display.currentIndex)   // re-render with transition on step change
        }
        .animation(reduceMotion ? nil : MotionTokens.page, value: display.currentIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(display.stepTitle). \(display.stepDescription)")
    }

    // MARK: - Mascot bubble

    private var mascotBubble: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            HSMascotView(mood: .explaining, size: 64)
                .accessibilityHidden(true)

            HSCard(style: .tinted(Color.white.opacity(0.95)), padding: SpacingTokens.medium) {
                Text(display.mascotText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.mascotText)
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

            if display.isLast {
                HSButton(
                    display.nextTitle,
                    style: .primary,
                    icon: "checkmark"
                ) {
                    interactor?.completeDemo(.init())
                }
            } else {
                HSButton(
                    display.nextTitle,
                    style: .primary,
                    icon: "chevron.right"
                ) {
                    interactor?.advanceStep(.init())
                }
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
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
