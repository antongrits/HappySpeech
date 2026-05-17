import OSLog
import SwiftUI

// MARK: - SortingView
//
// «Сортировка по категориям» — по центру слово (emoji + подпись), снизу кнопки-
// корзины (2–4 категории). Tap по кнопке классифицирует слово, на экран на 0.7 с
// выходит мягкий цветной overlay (зелёный / коралловый), затем индекс сдвигается
// на следующее слово. После всех слов — экран результатов со звёздами и
// per-category breakdown. В шапке — таймер (90 с) и серия правильных ответов.
// Кнопка «Подсказка» даёт 3 уровня помощи.

struct SortingView: View {

    // MARK: - Inputs

    let soundGroup: String
    let childName: String
    let onComplete: (Float) -> Void

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

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
            hintOverlay
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
        .accessibilityLabel(String(localized: "sorting.greeting.default"))
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

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.medium) {
            LyalyaMascotView(state: .thinking, size: 120)
                .accessibilityHidden(true)
            ProgressView()
                .scaleEffect(1.4)
                .tint(ColorTokens.Brand.primary)
            Text(String(localized: "sorting.status.preparing"))
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Classifying

    private var classifyingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer(minLength: 0)
            wordCard
            Spacer(minLength: 0)
            categoryButtons
            hintButton
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
                 ? String(localized: "sorting.greeting.default")
                 : display.greeting)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
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
            String(
                format: NSLocalizedString("sorting.progress.word_position %lld %lld", comment: ""),
                display.currentWordIndex + 1,
                display.words.count
            )
        )
    }

    private var timerLabel: some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: "timer")
                .font(TypographyTokens.caption(13))
            Text(display.timerLabel)
                .font(TypographyTokens.mono(14))
                .monospacedDigit()
        }
        .foregroundStyle(timerColor(for: display.timerColor))
        .accessibilityLabel(
            String(
                format: NSLocalizedString("sorting.accessibility.time_remaining %@", comment: ""),
                display.timerLabel
            )
        )
    }

    private var streakBadge: some View {
        HStack(spacing: SpacingTokens.micro) {
            Image(systemName: "flame.fill")
                .font(TypographyTokens.caption(12))
            Text(
                String(
                    format: NSLocalizedString("sorting.streak.label %lld", comment: ""),
                    display.currentStreak
                )
            )
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
                HSContentSymbol(word.emoji, size: 120)
                Text(word.word)
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if display.autoPlacedWords.contains(word.id) {
                    Label(String(localized: "sorting.action.auto"), systemImage: "wand.and.stars")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
            }
            .padding(SpacingTokens.large)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
            )
            .shadow(color: ColorTokens.Overlay.shadow, radius: 12, y: 4)
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
            .accessibilityLabel(
                String(
                    format: NSLocalizedString("sorting.accessibility.drag_to_bin %@", comment: ""),
                    word.word
                )
            )
        }
    }

    private var categoryButtons: some View {
        let columns = display.categories.count <= 2
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.medium) {
            ForEach(Array(display.categories.enumerated()), id: \.element.id) { index, category in
                categoryButton(category)
                    .accessibilityIdentifier("sortingCategory_\(index)")
            }
        }
    }

    private func categoryButton(_ category: SortingCategory) -> some View {
        let isHighlighted = display.highlightedCategoryId == category.id
        return Button {
            handleClassify(categoryId: category.id)
        } label: {
            VStack(spacing: SpacingTokens.small) {
                HSContentSymbol(category.emoji, size: 44)
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
                    .fill(isHighlighted
                          ? AnyShapeStyle(ColorTokens.Brand.primary.opacity(0.18))
                          : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? ColorTokens.Brand.primary : ColorTokens.Overlay.highlight,
                        lineWidth: isHighlighted ? 3 : 1
                    )
            )
            .shadow(color: isHighlighted
                    ? ColorTokens.Brand.primary.opacity(0.2)
                    : ColorTokens.Overlay.shadow,
                    radius: isHighlighted ? 10 : 4, y: 2)
            .scaleEffect(isHighlighted ? 1.03 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                value: isHighlighted
            )
        }
        .buttonStyle(.plain)
        .disabled(display.phase != .classifying)
        .accessibilityLabel(category.title)
        .accessibilityHint(String(localized: "sorting.accessibility.bin_hint"))
    }

    private var hintButton: some View {
        Button {
            requestHint()
        } label: {
            Label(String(localized: "sorting.action.hint"), systemImage: "lightbulb.fill")
                .font(TypographyTokens.caption(14))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(
                    Capsule(style: .continuous)
                        .fill(ColorTokens.Brand.primary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(display.phase != .classifying)
        .accessibilityLabel(String(localized: "sorting.accessibility.hint_label"))
        .accessibilityHint(String(localized: "sorting.accessibility.hint_levels"))
    }

    // MARK: - Feedback overlay

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
                    .font(TypographyTokens.kidDisplay(96))
                    .foregroundStyle(color)
                Text(display.feedbackText)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                if display.streakBadgeVisible {
                    HStack(spacing: SpacingTokens.tiny) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(ColorTokens.Brand.butter)
                        Text(
                            String(
                                format: NSLocalizedString("sorting.streak.title %lld", comment: ""),
                                display.currentStreak
                            )
                        )
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
            }
            .padding(SpacingTokens.xLarge)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 16, y: 4)
            )
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.feedbackText)
        }
    }

    // MARK: - Hint overlay

    @ViewBuilder
    private var hintOverlay: some View {
        if display.hintVisible {
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: "lightbulb.fill")
                    .font(TypographyTokens.kidDisplay(32))
                    .foregroundStyle(ColorTokens.Brand.butter)
                Text(display.hintText)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.large)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .shadow(color: ColorTokens.Overlay.shadowMedium, radius: 12, y: 3)
            )
            .padding(.horizontal, SpacingTokens.xLarge)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(
                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                value: display.hintVisible
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.hintText)
        }
    }

    // MARK: - Completed

    private var completedView: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.large) {
                Spacer(minLength: SpacingTokens.large)
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

                if !display.categoryBreakdown.isEmpty {
                    categoryBreakdownView
                }

                if display.autoPlacedCount > 0 {
                    Text(
                        String(
                            format: NSLocalizedString("sorting.summary.auto_placed", comment: ""),
                            display.autoPlacedCount
                        )
                    )
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: SpacingTokens.large)
                HSButton(
                    String(localized: "sorting.action.finish"),
                    style: .primary,
                    icon: "checkmark.circle.fill"
                ) { finalize() }
                .frame(maxWidth: 320)
                .padding(.bottom, SpacingTokens.large)
                .accessibilityIdentifier("gameNextButton")
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "sorting.accessibility.game_over"))
    }

    private var starsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(0..<3, id: \.self) { idx in
                Image(systemName: idx < display.starsEarned ? "star.fill" : "star")
                    .font(TypographyTokens.kidDisplay(44))
                    .foregroundStyle(
                        idx < display.starsEarned
                            ? ColorTokens.Brand.butter
                            : ColorTokens.Kid.line
                    )
                    .scaleEffect(idx < display.starsEarned ? 1.0 : 0.85)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.65)
                            .delay(Double(idx) * 0.12),
                        value: display.starsEarned
                    )
            }
        }
        .accessibilityLabel(
            String(
                format: NSLocalizedString("sorting.summary.stars_earned %lld", comment: ""),
                display.starsEarned
            )
        )
    }

    private var categoryBreakdownView: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "sorting.section.by_category"))
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            ForEach(display.categoryBreakdown, id: \.categoryId) { stat in
                HStack {
                    Text(stat.title)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Text("\(stat.correct)/\(stat.total)")
                        .font(TypographyTokens.mono(14))
                        .foregroundStyle(
                            stat.accuracy >= 0.7 ? ColorTokens.Feedback.correct : ColorTokens.Feedback.incorrect
                        )
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(
                        format: NSLocalizedString("sorting.accessibility.category_stat %@ %lld %lld", comment: ""),
                        stat.title,
                        stat.correct,
                        stat.total
                    )
                )
            }
            if let best = display.bestCategoryTitle {
                Label(
                    String(
                        format: NSLocalizedString("sorting.summary.best %@", comment: ""),
                        best
                    ),
                    systemImage: "crown.fill"
                )
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.butter)
            }
        }
        .padding(SpacingTokens.medium)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
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

    private func requestHint() {
        guard display.phase == .classifying else { return }
        guard let word = currentWord else { return }
        Task {
            await interactor.requestHint(.init(wordId: word.id))
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
