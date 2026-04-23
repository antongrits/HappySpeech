import SwiftUI
import OSLog

// MARK: - MinimalPairsView
//
// "Минимальные пары" — один из самых важных логопедических шаблонов для
// дифференциации похожих звуков (С/Ш, Р/Л, К/Г, Ц/Ч …). Ребёнок слышит
// целевое слово, видит пару картинок и выбирает нужную.
//
// Производственный UX:
//   1. Карточки picture-tile 2×1 — большие tap-targets.
//   2. Play-эталон автоматически на появлении + кнопка "послушать ещё раз".
//   3. После правильного ответа — feedback 0.7 сек → onComplete(score).
//   4. Три попытки на пару, каждый промах снижает итоговый score на 0.25.
//   5. Accessibility: VoiceOver-метки + Reduced Motion.

struct MinimalPairsView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pair: Pair = Self.defaultPair(for: "С")
    @State private var roundIndex: Int = 0
    @State private var attemptsUsed: Int = 0
    @State private var selectedIndex: Int?
    @State private var isCorrectSelection: Bool?

    private let totalRounds = 4
    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairs")

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            listenButton
            optionRow
            feedbackView
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear {
            pair = Self.defaultPair(for: activity.soundTarget)
            playReference()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: SpacingTokens.small) {
            Text(String(localized: "minimal_pairs.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("\(roundIndex + 1) / \(totalRounds)")
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var listenButton: some View {
        HSButton(
            String(localized: "minimal_pairs.listen_again"),
            style: .secondary,
            action: playReference
        )
        .frame(maxWidth: 260)
    }

    private var optionRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            optionCard(index: 0, word: pair.left, symbol: pair.leftSymbol)
            optionCard(index: 1, word: pair.right, symbol: pair.rightSymbol)
        }
    }

    private func optionCard(index: Int, word: String, symbol: String) -> some View {
        Button(action: { choose(index: index) }) {
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: symbol)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(word)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(cardFill(for: index))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCorrectSelection != nil)
        .accessibilityLabel(word)
    }

    @ViewBuilder
    private var feedbackView: some View {
        if let isCorrect = isCorrectSelection {
            Text(isCorrect
                 ? String(localized: "minimal_pairs.correct")
                 : String(localized: "minimal_pairs.try_again"))
                .font(TypographyTokens.headline(17))
                .foregroundStyle(isCorrect ? .green : .orange)
                .transition(.opacity)
        }
    }

    // MARK: - Styling

    private func cardFill(for index: Int) -> Color {
        guard let selected = selectedIndex, selected == index,
              let correct = isCorrectSelection else {
            return ColorTokens.Kid.surface
        }
        return correct ? Color.green.opacity(0.18) : Color.orange.opacity(0.18)
    }

    // MARK: - Actions

    private func playReference() {
        container.soundService.playUISound(.tap)
    }

    private func choose(index: Int) {
        guard isCorrectSelection == nil else { return }
        attemptsUsed += 1
        selectedIndex = index
        let correct = index == pair.correctIndex
        isCorrectSelection = correct

        container.soundService.playUISound(correct ? .correct : .incorrect)
        container.hapticService.notification(correct ? .success : .warning)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 800))
            if correct || attemptsUsed >= 3 {
                advanceRound(correctOnThisPair: correct)
            } else {
                isCorrectSelection = nil
                selectedIndex = nil
            }
        }
    }

    private func advanceRound(correctOnThisPair: Bool) {
        roundIndex += 1
        attemptsUsed = 0
        isCorrectSelection = nil
        selectedIndex = nil

        if roundIndex >= totalRounds {
            // Aggregate across rounds: correct on first attempt = 1.0,
            // any retry docks 0.25.
            let attemptsPenalty = Float(attemptsUsed) * 0.25
            let score: Float = correctOnThisPair
                ? max(0.25, 1.0 - attemptsPenalty)
                : 0.25
            logger.info("finished score=\(score, privacy: .public)")
            onComplete(score)
        } else {
            pair = Self.pair(for: activity.soundTarget, round: roundIndex)
            playReference()
        }
    }

    // MARK: - Pair catalogue

    struct Pair: Equatable, Hashable {
        let left: String
        let leftSymbol: String
        let right: String
        let rightSymbol: String
        let correctIndex: Int
    }

    static func defaultPair(for sound: String) -> Pair {
        pair(for: sound, round: 0)
    }

    /// Canonical word pairs (source: Коноваленко "Дифференциация звуков").
    /// Each target "sound" describes the pair discrimination ("С/Ш", "Р/Л", etc).
    static func pair(for sound: String, round: Int) -> Pair {
        switch sound {
        case "С/Ш", "С":
            let pairs: [Pair] = [
                Pair(left: "миска", leftSymbol: "fork.knife",
                     right: "мишка", rightSymbol: "pawprint.fill",
                     correctIndex: 0),
                Pair(left: "усы",   leftSymbol: "mustache",
                     right: "уши",  rightSymbol: "ear.fill",
                     correctIndex: 0),
                Pair(left: "кассы",  leftSymbol: "cart.fill",
                     right: "каши",  rightSymbol: "bowl.fill",
                     correctIndex: 1),
                Pair(left: "сутки", leftSymbol: "clock.fill",
                     right: "шутки",rightSymbol: "face.smiling",
                     correctIndex: 0),
            ]
            return pairs[round % pairs.count]
        case "Р/Л", "Р":
            let pairs: [Pair] = [
                Pair(left: "рак",   leftSymbol: "tortoise.fill",
                     right: "лак",  rightSymbol: "paintbrush.pointed.fill",
                     correctIndex: 0),
                Pair(left: "рама",  leftSymbol: "square.fill",
                     right: "лама", rightSymbol: "hare.fill",
                     correctIndex: 1),
                Pair(left: "рожки", leftSymbol: "triangle.fill",
                     right: "ложки",rightSymbol: "fork.knife",
                     correctIndex: 0),
                Pair(left: "играй", leftSymbol: "gamecontroller.fill",
                     right: "иглай",rightSymbol: "needle",
                     correctIndex: 0),
            ]
            return pairs[round % pairs.count]
        case "К/Г", "К":
            let pairs: [Pair] = [
                Pair(left: "кот",   leftSymbol: "pawprint",
                     right: "год",  rightSymbol: "calendar",
                     correctIndex: 0),
                Pair(left: "кол",   leftSymbol: "line.diagonal",
                     right: "гол",  rightSymbol: "soccerball.inverse",
                     correctIndex: 1),
                Pair(left: "купи",  leftSymbol: "cart",
                     right: "губи", rightSymbol: "mouth.fill",
                     correctIndex: 0),
                Pair(left: "коза",  leftSymbol: "hare.fill",
                     right: "коса", rightSymbol: "scissors",
                     correctIndex: 1),
            ]
            return pairs[round % pairs.count]
        default:
            // Fallback — C/Ш pair as safe default.
            return pair(for: "С/Ш", round: round)
        }
    }
}

#Preview {
    MinimalPairsView(
        activity: SessionActivity(
            id: "preview", gameType: .minimalPairs, lessonId: "l1",
            soundTarget: "С/Ш", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
