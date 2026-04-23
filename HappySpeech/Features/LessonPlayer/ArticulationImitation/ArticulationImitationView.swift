import SwiftUI
import OSLog

// MARK: - ArticulationImitationView
//
// "Повтори артикуляцию": серия из 4 артикуляционных упражнений (лопатка,
// чашечка, грибок, лошадка). Ляля показывает, ребёнок повторяет перед
// камерой. Настоящий tracking живёт в AR/ArticulationService; здесь —
// self-scored "Получилось/Не получилось" UX на 4 раунда.

struct ArticulationImitationView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var index: Int = 0
    @State private var scoredCorrect: Int = 0

    struct Exercise: Equatable, Hashable {
        let title: String
        let description: String
        let symbol: String
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ArticulationImitation")

    private let exercises: [Exercise] = [
        Exercise(title: "Лопатка",
                 description: "Приоткрой рот, положи широкий язык на нижнюю губу",
                 symbol: "mouth"),
        Exercise(title: "Чашечка",
                 description: "Подними язык к нёбу, края — вверх",
                 symbol: "cup.and.saucer"),
        Exercise(title: "Грибок",
                 description: "Присоси язык к нёбу, как грибок",
                 symbol: "theatermasks"),
        Exercise(title: "Лошадка",
                 description: "Щёлкай языком, как скачет лошадка",
                 symbol: "pawprint"),
    ]

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            if index < exercises.count {
                exerciseCard(exercises[index])
                buttonsRow
            } else {
                Text(String(localized: "articulation.finished"))
                    .font(TypographyTokens.title(22))
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "articulation.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("\(index + 1) / \(exercises.count)")
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private func exerciseCard(_ ex: Exercise) -> some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: ex.symbol)
                .font(.system(size: 64))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text(ex.title)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(ex.description)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private var buttonsRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            HSButton(String(localized: "articulation.got_it"), style: .primary) {
                advance(correct: true)
            }
            HSButton(String(localized: "articulation.try_later"), style: .secondary) {
                advance(correct: false)
            }
        }
    }

    private func advance(correct: Bool) {
        if correct { scoredCorrect += 1 }
        container.soundService.playUISound(correct ? .correct : .tap)
        index += 1
        if index >= exercises.count {
            let s = Float(scoredCorrect) / Float(exercises.count)
            logger.info("articulation score=\(s, privacy: .public)")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                onComplete(s)
            }
        }
    }
}

#Preview {
    ArticulationImitationView(
        activity: SessionActivity(
            id: "preview", gameType: .articulationImitation, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
