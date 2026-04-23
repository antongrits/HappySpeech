import SwiftUI
import OSLog

// MARK: - BingoView
//
// "Бинго со звуком": 3×3 сетка картинок. Ребёнок отмечает те, что содержат
// целевой звук. Неверное отмечание = -20% к итогу. Score = correct/total
// minus wrong penalty.

struct BingoView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var grid: [Cell] = []
    @State private var markedIndices: Set<Int> = []
    @State private var wrongMarks: Int = 0
    @State private var score: Float?

    struct Cell: Identifiable, Equatable, Hashable {
        let id: Int
        let word: String
        let symbol: String
        let containsTarget: Bool
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Bingo")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "bingo.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 3),
                spacing: SpacingTokens.small
            ) {
                ForEach(grid) { cell in
                    cellTile(cell)
                }
            }
            Spacer()
            HSButton(String(localized: "bingo.finish"), style: .primary, action: finish)
                .disabled(score != nil)
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { grid = Self.grid(for: activity.soundTarget) }
    }

    private func cellTile(_ cell: Cell) -> some View {
        let isMarked = markedIndices.contains(cell.id)
        return Button {
            toggle(cell)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cell.symbol)
                    .font(.system(size: 28))
                Text(cell.word).font(TypographyTokens.body(13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(isMarked ? Color.green.opacity(0.2) : ColorTokens.Kid.surface)
            )
        }
        .buttonStyle(.plain)
        .disabled(score != nil)
        .accessibilityLabel(cell.word)
    }

    // MARK: - Actions

    private func toggle(_ cell: Cell) {
        if markedIndices.contains(cell.id) {
            markedIndices.remove(cell.id)
        } else {
            markedIndices.insert(cell.id)
            if !cell.containsTarget { wrongMarks += 1 }
        }
        container.soundService.playUISound(.tap)
    }

    private func finish() {
        let correctMarks = grid.filter { markedIndices.contains($0.id) && $0.containsTarget }.count
        let totalTargets = max(1, grid.filter(\.containsTarget).count)
        let base = Float(correctMarks) / Float(totalTargets)
        let penalty = Float(wrongMarks) * 0.2
        let s = max(0, min(1, base - penalty))
        score = s
        logger.info("bingo score=\(s, privacy: .public)")
        container.soundService.playUISound(s >= 0.6 ? .correct : .incorrect)
        container.hapticService.notification(s >= 0.6 ? .success : .warning)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            onComplete(s)
        }
    }

    // MARK: - Content

    static func grid(for sound: String) -> [Cell] {
        let data: [(String, String, Bool)] = {
            switch sound {
            case "Р": return [
                ("рыба","fish.fill",true),       ("дом","house.fill",false),        ("корова","hare.fill",true),
                ("кот","pawprint.fill",false),   ("крыша","tent.fill",true),         ("луна","moon.fill",false),
                ("торт","birthday.cake.fill",true),("мяч","soccerball",false),       ("шарик","balloon.fill",true),
            ]
            case "Ш": return [
                ("шапка","laurel.leading",true), ("дом","house.fill",false),        ("кошка","pawprint",true),
                ("машина","car.fill",true),      ("луна","moon.fill",false),        ("мышка","scribble.variable",true),
                ("шарик","balloon.fill",true),   ("мяч","soccerball",false),        ("кот","pawprint.fill",false),
            ]
            default: return [
                ("сад","tree.fill",true),        ("дом","house.fill",false),        ("слон","hare.fill",true),
                ("рыба","fish.fill",false),      ("сумка","bag.fill",true),         ("мяч","soccerball",false),
                ("нос","nose",true),             ("кот","pawprint.fill",false),     ("сон","bed.double.fill",true),
            ]
            }
        }()
        return data.enumerated().map { idx, tuple in
            Cell(id: idx, word: tuple.0, symbol: tuple.1, containsTarget: tuple.2)
        }
    }
}

#Preview {
    BingoView(
        activity: SessionActivity(
            id: "preview", gameType: .bingo, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
