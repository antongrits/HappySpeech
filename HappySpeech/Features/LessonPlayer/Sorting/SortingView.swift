import SwiftUI
import OSLog

// MARK: - SortingView
//
// "Сортировка": 6 слов раскладываются по двум колонкам — левая "с моим звуком",
// правая "без моего звука". Tap по слову в центре меняет его колонку.

struct SortingView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var items: [Item] = []
    @State private var placement: [String: Column] = [:]
    @State private var score: Float?

    enum Column: String, Sendable { case left, right }

    struct Item: Identifiable, Equatable, Hashable {
        let id: String
        let word: String
        let symbol: String
        let correctColumn: Column
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Sorting")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            HStack(alignment: .top, spacing: SpacingTokens.small) {
                column(.left, title: String(localized: "sorting.left.\(activity.soundTarget)"))
                column(.right, title: String(localized: "sorting.right"))
            }
            Spacer()
            HSButton(String(localized: "sorting.check"), style: .primary, action: check)
                .disabled(placement.count < items.count || score != nil)
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { setup() }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "sorting.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "sorting.tap_to_move"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private func column(_ side: Column, title: String) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(title)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            VStack(spacing: SpacingTokens.tiny) {
                ForEach(items.filter { placement[$0.id] == side }) { item in
                    chip(for: item, current: side)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .top)
            .padding(SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
        }
    }

    private func chip(for item: Item, current: Column) -> some View {
        Button {
            placement[item.id] = current == .left ? .right : .left
            container.soundService.playUISound(.dragPick)
        } label: {
            HStack {
                Image(systemName: item.symbol)
                Text(item.word)
            }
            .font(TypographyTokens.body(14))
            .padding(SpacingTokens.small)
            .background(Capsule().fill(ColorTokens.Brand.primary.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.word)
    }

    // MARK: - Actions

    private func setup() {
        items = Self.items(for: activity.soundTarget).shuffled()
        // Initially all start in .left — user has to rearrange.
        placement = Dictionary(uniqueKeysWithValues: items.map { ($0.id, Column.left) })
        score = nil
    }

    private func check() {
        let correct = items.filter { placement[$0.id] == $0.correctColumn }.count
        let s = Float(correct) / Float(items.count)
        score = s
        logger.info("sorting score=\(s, privacy: .public)")
        container.soundService.playUISound(s >= 0.67 ? .correct : .incorrect)
        container.hapticService.notification(s >= 0.67 ? .success : .warning)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            onComplete(s)
        }
    }

    // MARK: - Content

    static func items(for sound: String) -> [Item] {
        switch sound {
        case "Р":
            return [
                Item(id: "a", word: "рыба",  symbol: "fish.fill",     correctColumn: .left),
                Item(id: "b", word: "корова",symbol: "hare.fill",     correctColumn: .left),
                Item(id: "c", word: "торт",  symbol: "birthday.cake.fill", correctColumn: .left),
                Item(id: "d", word: "дом",   symbol: "house.fill",    correctColumn: .right),
                Item(id: "e", word: "луна",  symbol: "moon.fill",     correctColumn: .right),
                Item(id: "f", word: "кот",   symbol: "pawprint.fill", correctColumn: .right),
            ]
        case "Ш":
            return [
                Item(id: "a", word: "шапка", symbol: "laurel.leading", correctColumn: .left),
                Item(id: "b", word: "кошка", symbol: "pawprint",       correctColumn: .left),
                Item(id: "c", word: "машина",symbol: "car.fill",       correctColumn: .left),
                Item(id: "d", word: "дом",   symbol: "house.fill",     correctColumn: .right),
                Item(id: "e", word: "луна",  symbol: "moon.fill",      correctColumn: .right),
                Item(id: "f", word: "рыба",  symbol: "fish.fill",      correctColumn: .right),
            ]
        default:
            return [
                Item(id: "a", word: "сад",   symbol: "tree.fill",      correctColumn: .left),
                Item(id: "b", word: "сумка", symbol: "bag.fill",       correctColumn: .left),
                Item(id: "c", word: "слон",  symbol: "hare.fill",      correctColumn: .left),
                Item(id: "d", word: "мяч",   symbol: "soccerball",     correctColumn: .right),
                Item(id: "e", word: "дом",   symbol: "house.fill",     correctColumn: .right),
                Item(id: "f", word: "кот",   symbol: "pawprint.fill",  correctColumn: .right),
            ]
        }
    }
}

#Preview {
    SortingView(
        activity: SessionActivity(
            id: "preview", gameType: .sorting, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
