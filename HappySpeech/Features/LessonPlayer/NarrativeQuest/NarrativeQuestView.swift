import SwiftUI
import OSLog

// MARK: - NarrativeQuestView
//
// "Квест с Лялей": Ляля ведёт ребёнка через мини-историю с 4 развилками.
// На каждой развилке ребёнок выбирает, куда идти дальше, и произносит
// слово с целевым звуком (моделируется Say/Skip). Score = произнесённых / 4.

struct NarrativeQuestView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var steps: [Step] = []
    @State private var index: Int = 0
    @State private var spoken: Int = 0

    struct Step: Equatable, Hashable {
        let narration: String
        let word: String
        let illustration: String
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "NarrativeQuest")

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            if index < steps.count {
                Image(systemName: steps[index].illustration)
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(steps[index].narration)
                    .font(TypographyTokens.body(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(steps[index].word)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(SpacingTokens.medium)
                    .background(Capsule().fill(ColorTokens.Kid.surface))
                buttonRow
            } else {
                Text(String(localized: "quest.end"))
                    .font(TypographyTokens.title(22))
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { steps = Self.steps(for: activity.soundTarget) }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "quest.title"))
                .font(TypographyTokens.title(22))
            Text("\(index + 1) / \(steps.count)")
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var buttonRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            HSButton(String(localized: "quest.said_it"), style: .primary) {
                advance(spoken: true)
            }
            HSButton(String(localized: "quest.skip"), style: .secondary) {
                advance(spoken: false)
            }
        }
    }

    private func advance(spoken: Bool) {
        if spoken {
            self.spoken += 1
            container.soundService.playUISound(.correct)
        } else {
            container.soundService.playUISound(.tap)
        }
        index += 1
        if index >= steps.count {
            let s = Float(self.spoken) / Float(max(1, steps.count))
            logger.info("quest score=\(s, privacy: .public)")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onComplete(s)
            }
        }
    }

    // MARK: - Content

    static func steps(for sound: String) -> [Step] {
        switch sound {
        case "Р":
            return [
                Step(narration: "Жила-была Рыбка в реке. Она плавала и пела песенку.", word: "рыба",    illustration: "fish.fill"),
                Step(narration: "Вдруг Рыбка встретила Крота. Они поздоровались.",     word: "крот",    illustration: "hare.fill"),
                Step(narration: "Вместе они пошли к старой Вороне.",                    word: "ворона",  illustration: "leaf.fill"),
                Step(narration: "Ворона дала им подарок — кусочек торта!",              word: "торт",    illustration: "birthday.cake.fill"),
            ]
        case "Ш":
            return [
                Step(narration: "Кошка надела шапку и пошла гулять.",                   word: "шапка",   illustration: "laurel.leading"),
                Step(narration: "На дороге она встретила Мышку в клетчатой шубе.",      word: "мышка",   illustration: "scribble.variable"),
                Step(narration: "Вместе они поехали на машине в магазин.",              word: "машина",  illustration: "car.fill"),
                Step(narration: "И купили себе вкусный шоколадный шарик.",              word: "шарик",   illustration: "balloon.fill"),
            ]
        default:
            return [
                Step(narration: "В саду росли красивые цветы.",                          word: "сад",     illustration: "tree.fill"),
                Step(narration: "К саду пришёл огромный Слон.",                         word: "слон",    illustration: "hare.fill"),
                Step(narration: "Он принёс сумку с сыром.",                              word: "сумка",   illustration: "bag.fill"),
                Step(narration: "Солнце грело их, и всем было хорошо.",                 word: "солнце",  illustration: "sun.max.fill"),
            ]
        }
    }
}

#Preview {
    NarrativeQuestView(
        activity: SessionActivity(
            id: "preview", gameType: .narrativeQuest, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
