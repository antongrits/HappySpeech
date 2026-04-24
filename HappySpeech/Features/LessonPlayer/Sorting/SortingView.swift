import SwiftUI
import OSLog

// MARK: - SortingView
//
// «Сортировка по категориям» — по центру слово (emoji + подпись), снизу две
// кнопки-корзины (например, «Живое» / «Неживое»). Tap по кнопке классифицирует
// слово, на экран на 0.7 с выходит мягкий цветной overlay (зелёный / коралловый),
// затем индекс сдвигается на следующее слово. После 8 слов — экран результатов
// со звёздами и CTA «Завершить». В шапке — таймер (90 с) и индикатор серии
// правильных ответов.

struct SortingView: View {

    // MARK: Inputs

    let soundGroup: String
    let childName: String
    let onComplete: (Float) -> Void

    // MARK: Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    @State private var display: SortingDisplay
    @State private var interactor: SortingInteractor
    @State private var presenter: SortingPresenter

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SortingView")

    // MARK: - Init

    @MainActor
    init(
        soundGroup: String,
        childName: String,
        onComplete: @escaping (Float) -> Void
    ) {
        self.soundGroup = soundGroup
        self.childName = childName
        self.onComplete = onComplete

        let haptic: any HapticService = LiveHapticService()
        let interactor = SortingInteractor(hapticService: haptic)
        let presenter = SortingPresenter()
        interactor.presenter = presenter
        _interactor = State(initialValue: interactor)
        _presenter = State(initialValue: presenter)
        _display = State(initialValue: SortingDisplay())
    }

    @MainActor
    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.init(
            soundGroup: Self.groupKey(for: activity.soundTarget),
            childName: "",
            onComplete: onComplete
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            content
            feedbackOverlay
        }
        .task {
            presenter.viewModel = display
            await interactor.loadSession(.init(
                soundGroup: soundGroup,
                childName: childName
            ))
        }
        .onDisappear {
            interactor.cancel()
        }
        .onChange(of: display.pendingFinalScore) { _, newValue in
            if let score = newValue {
                logger.info("onComplete score=\(score, privacy: .public)")
                onComplete(score)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Разложи слова по категориям"))
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:
            loadingView
        case .classifying, .feedback:
            classifyingView
        case .completed:
            completedView
        }
    }

    // MARK: Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(ColorTokens.Brand.primary)
            Text(String(localized: "Готовим игру…"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: Classifying

    private var classifyingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            wordCard
            Spacer(minLength: 0)
            categoryButtons
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.large)
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(display.setTitle)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                timerLabel
            }
            Text(display.greeting.isEmpty
                 ? String(localized: "Разложи слова по категориям")
                 : display.greeting)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            HSProgressBar(value: progressValue)
                .frame(height: 8)
            HStack {
                Text(progressLabel)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .monospacedDigit()
                Spacer()
                if display.currentStreak >= 2 {
                    streakBadge
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "Слово \(display.currentWordIndex + 1) из \(display.words.count)")
        )
    }

    private var timerLabel: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
            Text(display.timerLabel)
                .font(TypographyTokens.mono(14))
                .monospacedDigit()
        }
        .foregroundStyle(timerColor(for: display.timerColor))
        .accessibilityLabel(String(localized: "Осталось времени: \(display.timerLabel)"))
    }

    private var streakBadge: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
            Text(String(localized: "серия ×\(display.currentStreak)"))
                .font(TypographyTokens.caption(12))
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Brand.butter.opacity(0.25))
        )
        .foregroundStyle(ColorTokens.Kid.ink)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var wordCard: some View {
        if let word = currentWord {
            VStack(spacing: SpacingTokens.medium) {
                Text(word.emoji)
                    .font(.system(size: 120))
                    .accessibilityHidden(true)
                Text(word.word)
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(SpacingTokens.large)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
            .id(word.id)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .opacity
            ))
            .animation(
                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75),
                value: word.id
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(word.word)
        }
    }

    private var categoryButtons: some View {
        HStack(spacing: SpacingTokens.medium) {
            ForEach(display.categories) { category in
                categoryButton(category)
            }
        }
    }

    private func categoryButton(_ category: SortingCategory) -> some View {
        Button {
            handleClassify(categoryId: category.id)
        } label: {
            VStack(spacing: SpacingTokens.small) {
                Text(category.emoji)
                    .font(.system(size: 44))
                    .accessibilityHidden(true)
                Text(category.title)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(.vertical, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(display.phase != .classifying)
        .accessibilityLabel(category.title)
        .accessibilityHint(String(localized: "Положить слово сюда"))
    }

    // MARK: Feedback overlay

    @ViewBuilder
    private var feedbackOverlay: some View {
        if display.phase == .feedback,
           let correct = display.lastClassificationCorrect {
            let color = correct
                ? ColorTokens.Feedback.correct
                : ColorTokens.Feedback.incorrect
            let iconName = correct ? "checkmark.circle.fill" : "xmark.circle.fill"
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: iconName)
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(color)
                Text(display.feedbackText)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                if display.streakBadgeVisible {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(ColorTokens.Brand.butter)
                        Text(String(localized: "Серия ×\(display.currentStreak)"))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
            }
            .padding(SpacingTokens.xLarge)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: .black.opacity(0.18), radius: 16, y: 4)
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.feedbackText)
        }
    }

    // MARK: Completed

    private var completedView: some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer()
            starsRow
            Text(display.scoreLabel)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
                .monospacedDigit()
            Text(display.completionMessage)
                .font(TypographyTokens.body(17))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, SpacingTokens.xLarge)
            Spacer()
            HSButton(
                String(localized: "Завершить"),
                style: .primary
            ) { finalize() }
            .frame(maxWidth: 320)
            .padding(.bottom, SpacingTokens.large)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Игра завершена"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(
                        idx < display.starsEarned
                            ? ColorTokens.Brand.butter
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(idx < display.starsEarned ? 1.0 : 0.85)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65).delay(Double(idx) * 0.12),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityLabel(
            String(localized: "Получено звёзд: \(display.starsEarned) из 3")
        )
    }

    // MARK: - Actions

    private func handleClassify(categoryId: String) {
        guard display.phase == .classifying else { return }
        guard let word = currentWord else { return }
        container.soundService.playUISound(.tap)
        Task {
            await interactor.classifyWord(.init(
                wordId: word.id,
                categoryId: categoryId
            ))
        }
    }

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        container.soundService.playUISound(.complete)
        display.pendingFinalScore = display.finalScore
    }

    // MARK: - Helpers

    private var currentWord: SortingWord? {
        guard !display.words.isEmpty,
              display.currentWordIndex < display.words.count
        else { return nil }
        return display.words[display.currentWordIndex]
    }

    private var progressValue: Double {
        let total = max(display.words.count, 1)
        return Double(display.currentWordIndex) / Double(total)
    }

    private var progressLabel: String {
        "\(min(display.currentWordIndex + 1, display.words.count)) / \(display.words.count)"
    }

    private func timerColor(for name: String) -> Color {
        switch name {
        case "red":    return ColorTokens.Feedback.incorrect
        case "orange": return ColorTokens.Brand.butter
        default:       return ColorTokens.Brand.mint
        }
    }

    // MARK: - Group key inference

    /// Преобразует `soundTarget` из SessionActivity в ключ для `SortingSet.set`.
    private static func groupKey(for sound: String) -> String {
        switch sound.uppercased() {
        case "С", "З", "Ц":       return "whistling"
        case "Ш", "Ж", "Ч", "Щ":  return "hissing"
        case "Р", "Л":             return "sonorant"
        case "К", "Г", "Х":        return "velar"
        default:                   return "any"
        }
    }
}

// MARK: - Display: DisplayLogic adapter

extension SortingDisplay: SortingDisplayLogic {

    func displayLoadSession(_ viewModel: SortingModels.LoadSession.ViewModel) {
        setTitle = viewModel.setTitle
        words = viewModel.words
        categories = viewModel.categories
        greeting = viewModel.greeting
        timeLimit = viewModel.timeLimit
        classifiedWords = [:]
        correctWords = []
        incorrectWords = []
        currentWordIndex = 0
        currentStreak = 0
        streakBadgeVisible = false
        feedbackText = ""
        lastClassificationCorrect = nil
        phase = .classifying
    }

    func displayClassifyWord(_ viewModel: SortingModels.ClassifyWord.ViewModel) {
        if viewModel.correct {
            correctWords.insert(viewModel.wordId)
            incorrectWords.remove(viewModel.wordId)
            currentStreak += 1
        } else {
            incorrectWords.insert(viewModel.wordId)
            correctWords.remove(viewModel.wordId)
            currentStreak = 0
        }
        feedbackText = viewModel.feedbackText
        lastClassificationCorrect = viewModel.correct
        streakBadgeVisible = viewModel.streakBadgeVisible
        classifiedWords[viewModel.wordId] = viewModel.correct ? "correct" : "incorrect"
        phase = .feedback

        // После 0.7 с — следующее слово. Если это было последнее (всё
        // классифицировано), то Interactor уже вызвал completeSession и
        // Presenter пришёл со starsEarned — мы просто не будем листать дальше.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self else { return }
            // Если пришёл completed — completeSession переключит phase.
            if phase == .feedback {
                if currentWordIndex < words.count - 1 {
                    currentWordIndex += 1
                }
                phase = .classifying
                lastClassificationCorrect = nil
                streakBadgeVisible = false
            }
        }
    }

    func displayTimerTick(_ viewModel: SortingModels.TimerTick.ViewModel) {
        timerLabel = viewModel.timerLabel
        timerColor = viewModel.timerColor
    }

    func displayCompleteSession(_ viewModel: SortingModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        finalScore = viewModel.finalScore
        phase = .completed
    }
}

// MARK: - Preview

#Preview("Playing") {
    SortingView(
        soundGroup: "whistling",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
