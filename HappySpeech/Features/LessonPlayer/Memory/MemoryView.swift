import SwiftUI
import OSLog

// MARK: - MemoryView
//
// Карточная игра "Память": 8 карточек (4 пары) лежат рубашкой вверх,
// каждая пара — слово с целевым звуком + картинка. Ребёнок переворачивает
// по две, при совпадении — оставляем открытыми, при несовпадении — прячем.

struct MemoryView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var cards: [Card] = []
    @State private var flippedIndices: [Int] = []
    @State private var matchedIds: Set<String> = []
    @State private var turnCount: Int = 0
    @State private var isResolving: Bool = false

    struct Card: Identifiable, Equatable, Hashable {
        let id: Int
        let pairId: String
        let word: String
        let symbol: String
        let isWord: Bool
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Memory")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            grid
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { cards = Self.deck(for: activity.soundTarget).shuffled() }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "memory.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "memory.turns.\(turnCount)"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 4),
            spacing: SpacingTokens.small
        ) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                Button { flip(at: index) } label: {
                    cardTile(card: card, index: index)
                }
                .buttonStyle(.plain)
                .disabled(
                    matchedIds.contains(card.pairId) ||
                    flippedIndices.contains(index) ||
                    isResolving
                )
            }
        }
    }

    private func cardTile(card: Card, index: Int) -> some View {
        let isFaceUp = flippedIndices.contains(index) || matchedIds.contains(card.pairId)
        return ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isFaceUp ? ColorTokens.Kid.surface : ColorTokens.Brand.primary.opacity(0.85))
            if isFaceUp {
                VStack(spacing: 4) {
                    if card.isWord {
                        Text(card.word)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    } else {
                        Image(systemName: card.symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                }
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(height: 80)
        .accessibilityLabel(isFaceUp ? card.word : String(localized: "memory.card_back"))
    }

    // MARK: - Flip logic

    private func flip(at index: Int) {
        guard !isResolving else { return }
        flippedIndices.append(index)
        container.soundService.playUISound(.tap)
        if flippedIndices.count == 2 {
            resolvePair()
        }
    }

    private func resolvePair() {
        isResolving = true
        turnCount += 1
        let first  = cards[flippedIndices[0]]
        let second = cards[flippedIndices[1]]

        if first.pairId == second.pairId && first.id != second.id {
            matchedIds.insert(first.pairId)
            container.soundService.playUISound(.correct)
            container.hapticService.notification(.success)
            flippedIndices.removeAll()
            isResolving = false
            if matchedIds.count == cards.count / 2 { finish() }
        } else {
            container.soundService.playUISound(.incorrect)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(700))
                flippedIndices.removeAll()
                isResolving = false
            }
        }
    }

    private func finish() {
        let pairs = cards.count / 2
        let optimalTurns = pairs
        let extra = max(0, turnCount - optimalTurns)
        let score = max(0.3, 1.0 - 0.05 * Float(extra))
        logger.info("memory finished turns=\(self.turnCount, privacy: .public)")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            onComplete(score)
        }
    }

    // MARK: - Deck

    static func deck(for sound: String) -> [Card] {
        let items: [(String, String)] = {
            switch sound {
            case "Р": return [("рыба","fish.fill"),("корова","hare.fill"),("крыша","tent.fill"),("торт","birthday.cake.fill")]
            case "Ш": return [("шапка","laurel.leading"),("кошка","pawprint"),("шарик","balloon.fill"),("мышка","scribble.variable")]
            default:  return [("сом","fish.fill"),("слон","hare.fill"),("сумка","bag.fill"),("сад","tree.fill")]
            }
        }()

        var cards: [Card] = []
        for (i, item) in items.enumerated() {
            let pairId = "p\(i)"
            cards.append(Card(id: i * 2, pairId: pairId, word: item.0, symbol: item.1, isWord: true))
            cards.append(Card(id: i * 2 + 1, pairId: pairId, word: item.0, symbol: item.1, isWord: false))
        }
        return cards
    }
}

#Preview {
    MemoryView(
        activity: SessionActivity(
            id: "preview", gameType: .memory, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
