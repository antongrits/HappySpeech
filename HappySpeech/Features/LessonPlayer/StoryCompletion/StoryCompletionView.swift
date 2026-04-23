import SwiftUI
import OSLog

// MARK: - StoryCompletionView
//
// "Заверши историю": Ляля читает короткую историю с пропусками. Ребёнок
// выбирает пропущенное слово из 3 вариантов. 4 пропуска = 4 раунда.

struct StoryCompletionView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var rounds: [Round] = []
    @State private var currentIndex: Int = 0
    @State private var correct: Int = 0
    @State private var showFeedback: Bool = false
    @State private var lastCorrect: Bool = false

    struct Round: Equatable, Hashable {
        let sentence: String   // "Рыбка плавает в ___"
        let options: [String]  // ["море","доме","небе"]
        let correctIndex: Int
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryCompletion")

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            if currentIndex < rounds.count {
                Text(rounds[currentIndex].sentence)
                    .font(TypographyTokens.title(20))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(SpacingTokens.medium)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Kid.surface)
                    )
                optionsRow
            }
            if showFeedback {
                Text(lastCorrect
                     ? String(localized: "story.correct")
                     : String(localized: "story.wrong"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(lastCorrect ? .green : .orange)
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { rounds = Self.rounds(for: activity.soundTarget) }
    }

    private var header: some View {
        Text(String(localized: "story.title"))
            .font(TypographyTokens.title(22))
            .foregroundStyle(ColorTokens.Kid.ink)
    }

    private var optionsRow: some View {
        VStack(spacing: SpacingTokens.small) {
            ForEach(0..<rounds[currentIndex].options.count, id: \.self) { idx in
                HSButton(rounds[currentIndex].options[idx], style: .secondary) {
                    choose(idx)
                }
            }
        }
    }

    private func choose(_ index: Int) {
        let round = rounds[currentIndex]
        let isCorrect = index == round.correctIndex
        lastCorrect = isCorrect
        showFeedback = true
        if isCorrect { correct += 1 }
        container.soundService.playUISound(isCorrect ? .correct : .incorrect)
        container.hapticService.notification(isCorrect ? .success : .warning)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            showFeedback = false
            currentIndex += 1
            if currentIndex >= rounds.count {
                let s = Float(correct) / Float(rounds.count)
                logger.info("story score=\(s, privacy: .public)")
                onComplete(s)
            }
        }
    }

    // MARK: - Content

    static func rounds(for sound: String) -> [Round] {
        switch sound {
        case "Р":
            return [
                Round(sentence: "Рыбка плавает в ___.",  options: ["море","доме","небе"], correctIndex: 0),
                Round(sentence: "___ красит забор.",       options: ["Марина","Кошка","Ваза"], correctIndex: 0),
                Round(sentence: "Корова даёт ___.",        options: ["молоко","яблоко","стекло"], correctIndex: 0),
                Round(sentence: "Ворона сидит на ___.",    options: ["крыше","столе","полу"], correctIndex: 0),
            ]
        case "Ш":
            return [
                Round(sentence: "Кошка ест ___.",          options: ["кашу","мясо","суп"], correctIndex: 0),
                Round(sentence: "Мышка спряталась в ___.", options: ["шкафу","саду","парке"], correctIndex: 0),
                Round(sentence: "Ребёнок в ___ идёт.",     options: ["шапке","руке","лапке"], correctIndex: 0),
                Round(sentence: "Машина едет по ___.",     options: ["шоссе","реке","лесу"], correctIndex: 0),
            ]
        default:
            return [
                Round(sentence: "Солнце светит в ___.",    options: ["саду","море","доме"], correctIndex: 0),
                Round(sentence: "Слон ходит по ___.",      options: ["саванне","крыше","реке"], correctIndex: 0),
                Round(sentence: "Сом плывёт в ___.",       options: ["реке","небе","доме"], correctIndex: 0),
                Round(sentence: "Сумка на ___.",           options: ["столе","яблоке","полке"], correctIndex: 0),
            ]
        }
    }
}

#Preview {
    StoryCompletionView(
        activity: SessionActivity(
            id: "preview", gameType: .storyCompletion, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
