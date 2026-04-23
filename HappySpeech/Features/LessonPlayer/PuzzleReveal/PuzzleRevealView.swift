import SwiftUI
import OSLog

// MARK: - PuzzleRevealView
//
// "Сложи пазл": за каждое правильно произнесённое слово открывается кусочек
// пазла. Визуальная награда за серию правильных ответов. 6 кусочков = 6
// слов, score = revealed_pieces / total.

struct PuzzleRevealView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var words: [String] = []
    @State private var currentIndex: Int = 0
    @State private var revealed: Set<Int> = []

    private let logger = Logger(subsystem: "ru.happyspeech", category: "PuzzleReveal")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "puzzle.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            puzzleGrid
            currentWord
            buttonsRow
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { words = Self.words(for: activity.soundTarget) }
    }

    private var puzzleGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
            spacing: 2
        ) {
            ForEach(0..<6, id: \.self) { index in
                ZStack {
                    Rectangle()
                        .fill(revealed.contains(index)
                              ? Color.white
                              : ColorTokens.Brand.primary.opacity(0.8))
                    if revealed.contains(index) {
                        Image(systemName: pieceSymbol(for: index))
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    } else {
                        Image(systemName: "questionmark")
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: 320)
    }

    @ViewBuilder
    private var currentWord: some View {
        if currentIndex < words.count {
            Text(words[currentIndex])
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(SpacingTokens.medium)
                .background(Capsule().fill(ColorTokens.Kid.surface))
        } else {
            Text(String(localized: "puzzle.complete"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Brand.primary)
        }
    }

    private var buttonsRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            HSButton(String(localized: "puzzle.say_it"), style: .primary) {
                mark(correct: true)
            }
            .disabled(currentIndex >= words.count)
            HSButton(String(localized: "puzzle.skip"), style: .secondary) {
                mark(correct: false)
            }
            .disabled(currentIndex >= words.count)
        }
    }

    private func mark(correct: Bool) {
        if correct {
            revealed.insert(currentIndex)
            container.soundService.playUISound(.correct)
        } else {
            container.soundService.playUISound(.incorrect)
        }
        currentIndex += 1
        if currentIndex >= words.count {
            let score = Float(revealed.count) / Float(words.count)
            logger.info("puzzle score=\(score, privacy: .public)")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                onComplete(score)
            }
        }
    }

    private func pieceSymbol(for index: Int) -> String {
        ["star.fill","heart.fill","leaf.fill","sun.max.fill","moon.fill","cloud.fill"][index]
    }

    static func words(for sound: String) -> [String] {
        switch sound {
        case "Р": return ["рыба","рука","рот","крот","ворона","корабль"]
        case "Ш": return ["шапка","шарик","кошка","мышка","шуба","камыш"]
        default:  return ["сад","сумка","сон","нос","коса","слон"]
        }
    }
}

#Preview {
    PuzzleRevealView(
        activity: SessionActivity(
            id: "preview", gameType: .puzzleReveal, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
