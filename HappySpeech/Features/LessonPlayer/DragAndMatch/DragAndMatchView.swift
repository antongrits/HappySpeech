import SwiftUI
import OSLog

// MARK: - DragAndMatchView
//
// "Перетащи и найди пару" — 3 слова (карточки) нужно перетащить в 3 правильные
// корзины (позиции звука: начало / середина / конец). Через .draggable +
// .dropDestination. На симуляторе без мыши — fallback long-press + tap-to-move.

struct DragAndMatchView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var unplaced: [Word] = []
    @State private var inSlot: [Position: Word?] = [.initial: nil, .medial: nil, .final: nil]
    @State private var selectedWordId: String?
    @State private var score: Float?

    enum Position: String, Sendable, CaseIterable {
        case initial, medial, final
        var title: String {
            switch self {
            case .initial: return String(localized: "drag.position.initial")
            case .medial:  return String(localized: "drag.position.medial")
            case .final:   return String(localized: "drag.position.final")
            }
        }
    }

    struct Word: Identifiable, Equatable, Hashable {
        let id: String
        let text: String
        let correctPosition: Position
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "DragAndMatch")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            slotsRow
            unplacedRow
            Spacer()
            HSButton(
                String(localized: "drag.check"),
                style: .primary,
                action: check
            )
            .disabled(unplaced.isEmpty == false || score != nil)
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { setup() }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "drag.title.\(activity.soundTarget)"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "drag.subtitle"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var slotsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(Position.allCases, id: \.rawValue) { pos in
                slot(for: pos)
            }
        }
    }

    private func slot(for position: Position) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(position.title)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(
                        ColorTokens.Brand.primary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                if let word = inSlot[position] ?? nil {
                    Text(word.text)
                        .font(TypographyTokens.body(15))
                        .padding(SpacingTokens.small)
                        .background(ColorTokens.Kid.surface, in: Capsule())
                        .onTapGesture { removeFromSlot(at: position) }
                }
            }
            .frame(height: 80)
        }
        .onTapGesture { placeSelectedInSlot(position) }
    }

    private var unplacedRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(unplaced) { word in
                Text(word.text)
                    .font(TypographyTokens.body(16))
                    .padding(SpacingTokens.small)
                    .background(
                        Capsule().fill(
                            selectedWordId == word.id
                                ? ColorTokens.Brand.primary.opacity(0.3)
                                : ColorTokens.Kid.surface
                        )
                    )
                    .onTapGesture { selectedWordId = word.id }
                    .accessibilityLabel(word.text)
            }
        }
        .frame(minHeight: 60)
    }

    // MARK: - Actions

    private func setup() {
        unplaced = Self.words(for: activity.soundTarget).shuffled()
        inSlot = [.initial: nil, .medial: nil, .final: nil]
        selectedWordId = nil
        score = nil
    }

    private func placeSelectedInSlot(_ position: Position) {
        guard let id = selectedWordId,
              let word = unplaced.first(where: { $0.id == id })
        else { return }
        // If slot occupied, return that word to unplaced first.
        if let occupant = inSlot[position] ?? nil {
            unplaced.append(occupant)
        }
        inSlot[position] = word
        unplaced.removeAll { $0.id == id }
        selectedWordId = nil
        container.soundService.playUISound(.dragDrop)
    }

    private func removeFromSlot(at position: Position) {
        guard let word = inSlot[position] ?? nil else { return }
        unplaced.append(word)
        inSlot[position] = nil
    }

    private func check() {
        var correct = 0
        for (pos, word) in inSlot {
            if let word, word.correctPosition == pos { correct += 1 }
        }
        let s = Float(correct) / 3.0
        score = s
        logger.info("drag score=\(s, privacy: .public)")
        container.soundService.playUISound(s >= 0.67 ? .correct : .incorrect)
        container.hapticService.notification(s >= 0.67 ? .success : .warning)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            onComplete(s)
        }
    }

    // MARK: - Content

    static func words(for sound: String) -> [Word] {
        switch sound {
        case "Р":
            return [
                Word(id: "w1", text: "рыба",    correctPosition: .initial),
                Word(id: "w2", text: "корова",  correctPosition: .medial),
                Word(id: "w3", text: "комар",   correctPosition: .final),
            ]
        case "Ш":
            return [
                Word(id: "w1", text: "шапка",   correctPosition: .initial),
                Word(id: "w2", text: "кошка",   correctPosition: .medial),
                Word(id: "w3", text: "малыш",   correctPosition: .final),
            ]
        default:
            return [
                Word(id: "w1", text: "сад",     correctPosition: .initial),
                Word(id: "w2", text: "косы",    correctPosition: .medial),
                Word(id: "w3", text: "нос",     correctPosition: .final),
            ]
        }
    }
}

#Preview {
    DragAndMatchView(
        activity: SessionActivity(
            id: "preview", gameType: .dragAndMatch, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
