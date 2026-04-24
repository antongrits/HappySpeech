import SwiftUI
import OSLog
import UniformTypeIdentifiers

// MARK: - DragAndMatchView
//
// «Перетащи и совмести» — ребёнок перетаскивает слова (карточки emoji + текст)
// в правильную корзину-категорию. Используется SwiftUI API `draggable` +
// `dropDestination` (iOS 16+).
//
// Состояния:
//   1. loading    — прогресс
//   2. playing    — grid слов вверху + корзины внизу, drag-and-drop
//   3. completed  — звёзды + счёт + CTA «Завершить»
//
// Слова с правильным размещением получают зелёный outline, с ошибочным — красный.
// Автозавершение — когда все слова размещены.

struct DragAndMatchView: View {

    // MARK: Inputs

    let soundGroup: String
    let childName: String
    let onComplete: (Float) -> Void

    // MARK: Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: State

    @State private var display: DragAndMatchDisplay
    @State private var interactor: DragAndMatchInteractor
    @State private var presenter: DragAndMatchPresenter
    @State private var draggingWordId: String?
    @State private var hoveringBucketId: String?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DragAndMatchView")

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
        let interactor = DragAndMatchInteractor(hapticService: haptic)
        let presenter = DragAndMatchPresenter()
        interactor.presenter = presenter
        _interactor = State(initialValue: interactor)
        _presenter = State(initialValue: presenter)
        _display = State(initialValue: DragAndMatchDisplay())
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
        }
        .task {
            presenter.viewModel = display
            await interactor.loadSession(.init(
                soundGroup: soundGroup,
                childName: childName
            ))
        }
        .onChange(of: display.pendingFinalScore) { _, newValue in
            if let score = newValue {
                logger.info("onComplete score=\(score, privacy: .public)")
                onComplete(score)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String(localized: "Перетащи слова в правильные корзины")
        )
    }

    @ViewBuilder
    private var content: some View {
        switch display.phase {
        case .loading:    loadingView
        case .playing:    playingView
        case .completed:  completedView
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

    // MARK: Playing

    private var playingView: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            wordsPool
            Spacer(minLength: 0)
            bucketsRow
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.large)
        .padding(.bottom, SpacingTokens.large)
        .animation(
            reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85),
            value: display.placedWords
        )
    }

    private var header: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(display.greeting.isEmpty
                 ? String(localized: "Разложи слова по корзинам")
                 : display.greeting)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(progressLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Words pool

    private var wordsPool: some View {
        let unplaced = display.words.filter { display.placedWords[$0.id] == nil }
        let columns = [
            GridItem(.adaptive(minimum: 108), spacing: SpacingTokens.small)
        ]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
            ForEach(unplaced) { word in
                wordChip(word)
            }
        }
        .frame(minHeight: 140)
        .accessibilityLabel(String(localized: "Слова для сортировки"))
    }

    private func wordChip(_ word: DragWord) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(word.emoji)
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text(word.word)
                .font(TypographyTokens.headline(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .frame(width: 110, height: 88)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .strokeBorder(
                    draggingWordId == word.id
                        ? ColorTokens.Brand.primary
                        : .clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(draggingWordId == word.id ? 0.95 : 1.0)
        .opacity(draggingWordId == word.id ? 0.7 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
            value: draggingWordId
        )
        .draggable(word) {
            // Preview, который показывается при drag (iOS берёт его как glass
            // card под пальцем).
            wordDragPreview(word)
        }
        .onTapGesture {
            // Tap-to-speak — мелкий UX-бонус для любопытных детей.
            container.soundService.playUISound(.tap)
        }
        .accessibilityLabel(word.word)
        .accessibilityHint(String(localized: "Перетащи в правильную корзину"))
    }

    private func wordDragPreview(_ word: DragWord) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(word.emoji).font(.system(size: 44))
            Text(word.word)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .padding(SpacingTokens.small)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    // MARK: Buckets

    private var bucketsRow: some View {
        HStack(alignment: .top, spacing: SpacingTokens.medium) {
            ForEach(display.buckets) { bucket in
                bucketCard(bucket)
            }
        }
    }

    private func bucketCard(_ bucket: DragBucket) -> some View {
        let contents = display.words.filter { display.placedWords[$0.id] == bucket.id }
        let isHovering = (hoveringBucketId == bucket.id)

        return VStack(spacing: SpacingTokens.small) {
            HStack(spacing: SpacingTokens.tiny) {
                Text(bucket.emoji).font(.system(size: 22))
                Text(bucket.title)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                spacing: 6
            ) {
                ForEach(contents) { word in
                    placedChip(word, bucket: bucket)
                }
            }
            .frame(minHeight: 72)
        }
        .padding(SpacingTokens.small)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(bucketBackground(for: bucket.color))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(
                    isHovering
                        ? ColorTokens.Brand.primary
                        : bucketBorder(for: bucket.color),
                    style: StrokeStyle(
                        lineWidth: isHovering ? 3 : 2,
                        dash: isHovering ? [] : [6]
                    )
                )
        )
        .dropDestination(for: DragWord.self) { items, _ in
            guard let word = items.first else { return false }
            draggingWordId = nil
            hoveringBucketId = nil
            display.placedWords[word.id] = bucket.id
            container.soundService.playUISound(.dragDrop)
            Task {
                await interactor.dropWord(.init(
                    wordId: word.id,
                    bucketId: bucket.id
                ))
            }
            return true
        } isTargeted: { hovering in
            hoveringBucketId = hovering ? bucket.id : nil
            if hovering {
                draggingWordId = nil
            }
        }
        .accessibilityLabel(bucket.title)
        .accessibilityHint(String(localized: "Корзина для слов"))
    }

    private func placedChip(_ word: DragWord, bucket: DragBucket) -> some View {
        let isCorrect = display.correctWords.contains(word.id)
        let isIncorrect = display.incorrectWords.contains(word.id)
        let borderColor: Color = isCorrect
            ? ColorTokens.Feedback.correct
            : isIncorrect
              ? ColorTokens.Feedback.incorrect
              : ColorTokens.Kid.line

        return HStack(spacing: SpacingTokens.micro) {
            Text(word.emoji).font(.system(size: 18))
            Text(word.word)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(ColorTokens.Kid.surface)
        )
        .overlay(
            Capsule().strokeBorder(borderColor, lineWidth: 2)
        )
        .accessibilityLabel(word.word)
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

    // MARK: - Helpers

    private var progressLabel: String {
        "\(display.placedWords.count) / \(display.words.count)"
    }

    private func bucketBackground(for color: String) -> Color {
        switch color.lowercased() {
        case "mint":   return ColorTokens.Brand.mint.opacity(0.12)
        case "lilac":  return ColorTokens.Brand.lilac.opacity(0.12)
        case "butter": return ColorTokens.Brand.butter.opacity(0.18)
        case "sky":    return ColorTokens.Brand.sky.opacity(0.12)
        case "rose":   return ColorTokens.Brand.rose.opacity(0.18)
        default:       return ColorTokens.Kid.surface
        }
    }

    private func bucketBorder(for color: String) -> Color {
        switch color.lowercased() {
        case "mint":   return ColorTokens.Brand.mint.opacity(0.6)
        case "lilac":  return ColorTokens.Brand.lilac.opacity(0.6)
        case "butter": return ColorTokens.Brand.butter.opacity(0.7)
        case "sky":    return ColorTokens.Brand.sky.opacity(0.6)
        case "rose":   return ColorTokens.Brand.rose.opacity(0.7)
        default:       return ColorTokens.Kid.line
        }
    }

    private func finalize() {
        guard display.pendingFinalScore == nil else { return }
        let total = Float(max(display.words.count, 1))
        let correct = Float(display.correctWords.count)
        let score = correct / total
        container.soundService.playUISound(.complete)
        display.pendingFinalScore = score
    }

    // MARK: - Group key inference

    /// Преобразует `soundTarget` из SessionActivity в ключ для `DragWord.set`.
    private static func groupKey(for sound: String) -> String {
        switch sound.uppercased() {
        case "С", "З", "Ц":       return "whistling"
        case "Ш", "Ж", "Ч", "Щ":  return "hissing"
        case "Р", "Л":             return "sonorant"
        default:                    return "whistling"
        }
    }
}

// MARK: - Display: DisplayLogic adapter

extension DragAndMatchDisplay: DragAndMatchDisplayLogic {

    func displayLoadSession(_ viewModel: DragAndMatchModels.LoadSession.ViewModel) {
        words = viewModel.words
        buckets = viewModel.buckets
        greeting = viewModel.greeting
        placedWords = [:]
        correctWords = []
        incorrectWords = []
        feedbackText = ""
        phase = .playing
    }

    func displayDropWord(_ viewModel: DragAndMatchModels.DropWord.ViewModel) {
        // `placedWords` уже обновлён в View до вызова Interactor, здесь мы
        // только маркируем слово как correct/incorrect для бордера.
        if viewModel.correct {
            correctWords.insert(viewModel.wordId)
            incorrectWords.remove(viewModel.wordId)
        } else {
            incorrectWords.insert(viewModel.wordId)
            correctWords.remove(viewModel.wordId)
        }
        feedbackText = viewModel.feedbackText
    }

    func displayCompleteSession(_ viewModel: DragAndMatchModels.CompleteSession.ViewModel) {
        starsEarned = viewModel.starsEarned
        scoreLabel = viewModel.scoreLabel
        completionMessage = viewModel.message
        phase = .completed
    }
}

// MARK: - Preview

#Preview("Playing") {
    DragAndMatchView(
        soundGroup: "whistling",
        childName: "Саша",
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
