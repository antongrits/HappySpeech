import OSLog
import SwiftUI

// MARK: - SoundHunterView
//
// «Охота на звук» — экран-игра для ребёнка. Показывает 3×3 сетку предметов и
// hint-баннер «Найди слова со звуком «С»». Правильное нажатие даёт зелёную
// подсветку и галочку; неправильное — красную тряску (предмет возвращается
// в idle через 0.5с). После сбора всех целевых на сцене — переход к следующей
// (автоматически через 0.8с), после 3-й — итог со звёздами.
//
// Интеграция с SessionShell: `SoundHunterView(activity:, onComplete:)`.

struct SoundHunterView: View {

    // MARK: - Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.exitGame) private var exitGame

    // MARK: - VIP

    @State private var interactor: SoundHunterInteractor?
    @State private var presenter: SoundHunterPresenter?
    @State private var router: SoundHunterRouter?
    @State private var display = SoundHunterDisplay()
    @State private var bootstrapped = false

    // MARK: - Shake phase toggle for animation

    @State private var shakePhase: Bool = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunterView")

    // MARK: - Body

    var body: some View {
        ZStack {
            KidGameCanvasBackground(palette: .kidWarm)

            switch display.phase {
            case .loading:
                loadingView
            case .hunting:
                huntingView
            case .sceneComplete:
                sceneCompleteView
            case .completed:
                completedView
            }
        }
        .task { await bootstrap() }
        .onChange(of: display.shakeItemId) { _, newValue in
            guard newValue != nil else { return }
            // Тумблер для HStack-shake — анимация внутри tile.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) {
                shakePhase.toggle()
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(ColorTokens.Brand.primary)
                .scaleEffect(1.4)
            Text(String(localized: "Готовим охоту…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityLabel(String(localized: "Загрузка"))
    }

    // MARK: - Hunting

    private var huntingView: some View {
        KidGameCanvasScaffold(
            title: Text(display.hintText),
            subtitle: String(localized: "Сцена \(display.sceneIndex + 1) из \(display.totalScenes)"),
            progress: display.progressFraction,
            palette: .kidWarm,
            onExit: { exitGame() }
        ) {
            huntCanvasContent
        } toolbar: {
            huntScoreBar
        }
    }

    /// SoundHunter не имеет ручного CTA — предметы нажимаются прямо на холсте,
    /// сцена авто-переходит. Нижняя панель показывает живой счёт «найдено».
    private var huntScoreBar: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            Text(String(localized: "Найдено: \(display.correctCount) из \(display.totalCorrectNeeded)"))
                .font(TypographyTokens.kidCardTitle(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .padding(.horizontal, SpacingTokens.regular)
        .background {
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
        }
        .accessibilityElement(children: .combine)
    }

    private var huntCanvasContent: some View {
        VStack(spacing: SpacingTokens.small) {
            grid

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                KidGameMascotBubble(message: display.hintText, state: .explaining, size: 48)
                Spacer(minLength: 0)
            }
        }
        .padding(SpacingTokens.small)
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: SpacingTokens.small),
                count: 3
            ),
            spacing: SpacingTokens.small
        ) {
            ForEach(display.items) { item in
                HuntItemTile(
                    item: item,
                    isShaking: display.shakeItemId == item.id,
                    shakePhase: shakePhase,
                    reduceMotion: reduceMotion
                ) {
                    interactor?.tapItem(.init(itemId: item.id))
                }
            }
        }
    }

    // MARK: - Scene complete (intermediate)

    private var sceneCompleteView: some View {
        VStack(spacing: SpacingTokens.medium) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(TypographyTokens.kidDisplay(72))
                .foregroundStyle(ColorTokens.Brand.mint)
                .accessibilityHidden(true)
            Text(String(localized: "Отлично! Ты нашёл все слова."))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(String(localized: "Следующая сцена…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Сцена пройдена. Следующая сцена."))
    }

    // MARK: - Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: SpacingTokens.medium)

            starsRow
                .accessibilityLabel(
                    String(localized: "Получено звёзд: \(display.starsEarned) из 3")
                )

            Text(display.scoreLabel)
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            Text(display.completionMessage)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)

            Spacer(minLength: SpacingTokens.medium)

            HSButton(
                String(localized: "Завершить"),
                style: .primary,
                icon: "checkmark.circle.fill"
            ) {
                onComplete(display.lastScore)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
            .accessibilityIdentifier("gameNextButton")
            .accessibilityHint(String(localized: "Вернуться к занятию"))
        }
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.kidDisplay(44))
                    .foregroundStyle(
                        index < display.starsEarned
                            ? ColorTokens.Brand.gold
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(index < display.starsEarned ? 1.0 : 0.88)
                    .animation(
                        reduceMotion
                            ? nil
                            : .spring(response: 0.4, dampingFraction: 0.6)
                                .delay(Double(index) * 0.1),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityElement(children: .ignore)
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = SoundHunterInteractor(
            targetSound: activity.soundTarget,
            hapticService: container.hapticService,
            soundService: container.soundService
        )
        let presenter = SoundHunterPresenter()
        let router = SoundHunterRouter()

        interactor.presenter = presenter
        interactor.router = router
        presenter.viewModel = display
        router.onDismiss = { [weak display] in
            guard let display else { return }
            onComplete(display.lastScore)
        }

        self.interactor = interactor
        self.presenter = presenter
        self.router = router

        logger.info("Bootstrap sound=\(activity.soundTarget, privacy: .public)")
        interactor.loadScene(.init(sceneIndex: 0))
    }
}

// MARK: - HuntItemTile

/// Отдельная карточка в сетке. Цвет, галочка/крестик и тряска зависят от
/// `item.tapState`. Tile сохраняет фиксированную высоту, чтобы сетка была
/// предсказуемой и удобной для маленьких пальцев.
private struct HuntItemTile: View {

    let item: HuntItem
    let isShaking: Bool
    let shakePhase: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                iconView
                wordView
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 104)
            .padding(.vertical, SpacingTokens.small)
            .padding(.horizontal, SpacingTokens.tiny)
            .background(backgroundShape)
            .overlay(alignment: .topTrailing) { stateBadge }
            .overlay(borderShape)
            .contentShape(Rectangle())
            .scaleEffect(scaleForState)
            .offset(x: shakeOffset)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65),
                value: item.tapState
            )
        }
        .buttonStyle(.plain)
        .disabled(item.tapState != .idle)
        .accessibilityLabel(item.word)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Subviews

    private var iconView: some View {
        Image(systemName: item.icon)
            .font(TypographyTokens.display(36))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .frame(height: 40)
            .accessibilityHidden(true)
    }

    private var wordView: some View {
        Text(item.word)
            .font(TypographyTokens.body(14))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .strikethrough(item.tapState == .correct, pattern: .solid, color: foregroundColor)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch item.tapState {
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Feedback.correct)
                .padding(SpacingTokens.tiny)
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Feedback.incorrect)
                .padding(SpacingTokens.tiny)
        case .revealed:
            Image(systemName: "star.fill")
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Brand.gold)
                .padding(SpacingTokens.tiny)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            .fill(backgroundColor)
    }

    @ViewBuilder
    private var borderShape: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            .stroke(borderColor, lineWidth: 1.5)
    }

    // MARK: Styling by state

    private var backgroundColor: Color {
        switch item.tapState {
        case .idle:     return ColorTokens.Kid.surface
        case .correct:  return ColorTokens.Feedback.correct.opacity(0.18)
        case .wrong:    return ColorTokens.Feedback.incorrect.opacity(0.20)
        case .revealed: return ColorTokens.Brand.gold.opacity(0.18)
        }
    }

    private var borderColor: Color {
        switch item.tapState {
        case .idle:     return ColorTokens.Kid.line
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return ColorTokens.Feedback.incorrect
        case .revealed: return ColorTokens.Brand.gold
        }
    }

    private var foregroundColor: Color {
        switch item.tapState {
        case .idle:     return ColorTokens.Kid.ink
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return ColorTokens.Feedback.incorrect
        case .revealed: return ColorTokens.Brand.gold
        }
    }

    /// Цвет иконки предмета. В состоянии покоя — брендовый тон вместо чёрного
    /// силуэта, чтобы карточки оставались в общей цветной палитре приложения.
    private var iconColor: Color {
        switch item.tapState {
        case .idle:     return ColorTokens.Brand.primary
        case .correct:  return ColorTokens.Feedback.correct
        case .wrong:    return ColorTokens.Feedback.incorrect
        case .revealed: return ColorTokens.Brand.gold
        }
    }

    private var scaleForState: CGFloat {
        guard !reduceMotion else { return 1 }
        switch item.tapState {
        case .correct: return 1.06
        case .wrong:   return 0.97
        default:       return 1
        }
    }

    private var shakeOffset: CGFloat {
        guard isShaking, !reduceMotion else { return 0 }
        return shakePhase ? 6 : -6
    }

    private var accessibilityHint: String {
        switch item.tapState {
        case .idle:     return String(localized: "Нажми, если в слове есть целевой звук")
        case .correct:  return String(localized: "Правильно")
        case .wrong:    return String(localized: "Неверно")
        case .revealed: return String(localized: "Правильный ответ")
        }
    }
}

// MARK: - Preview

#Preview("Hunting") {
    SoundHunterView(
        activity: SessionActivity(
            id: "preview",
            gameType: .soundHunter,
            lessonId: "l1",
            soundTarget: "С",
            difficulty: 2,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
