import SwiftUI
import OSLog

// MARK: - SoundHunterView
//
// «Охота на звук» — ребёнок видит 6 картинок и должен отметить те, в
// названии которых есть target sound. Развивает фонематический слух и
// слоговой анализ.
//
// Прод UX:
//   • 3×2 grid больших tap-tiles, каждый с символом SF Symbol + подпись.
//   • Tap включает "отмечено" состояние; повторный tap снимает.
//   • Кнопка «Проверить» — доступна только когда выбрано ≥1.
//   • Score: (правильных_отмеченных − ошибочных_отмеченных) / количество_целевых.
//   • Accessibility: VoiceOver labels на каждом тайле.

struct SoundHunterView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var items: [Item] = []
    @State private var selectedIds: Set<String> = []
    @State private var phase: Phase = .selecting
    @State private var score: Float?

    enum Phase: Sendable { case selecting, scoring, feedback }

    struct Item: Identifiable, Equatable, Hashable {
        let id: String
        let word: String
        let symbol: String
        let containsTarget: Bool
    }

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundHunter")

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            header
            grid
            Spacer()
            actionRow
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { items = Self.items(for: activity.soundTarget) }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: SpacingTokens.tiny) {
            Text(String(localized: "sound_hunter.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "sound_hunter.find_sound.\(activity.soundTarget)"))
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 2),
            spacing: SpacingTokens.small
        ) {
            ForEach(items) { item in
                Button {
                    toggle(item)
                } label: {
                    tile(for: item)
                }
                .buttonStyle(.plain)
                .disabled(phase != .selecting)
                .accessibilityLabel(item.word)
                .accessibilityHint(String(localized: "sound_hunter.tap_to_toggle"))
            }
        }
    }

    private func tile(for item: Item) -> some View {
        let selected = selectedIds.contains(item.id)
        let isRevealed = phase == .feedback
        let correctState = isRevealed && item.containsTarget
        let wrongState = isRevealed && selected && !item.containsTarget
        return VStack(spacing: SpacingTokens.small) {
            Image(systemName: item.symbol)
                .font(.system(size: 40, weight: .medium))
            Text(item.word)
                .font(TypographyTokens.body(15))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(background(
                    selected: selected,
                    correct: correctState, wrong: wrongState
                ))
        )
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(SpacingTokens.small)
            }
        }
    }

    private func background(selected: Bool, correct: Bool, wrong: Bool) -> Color {
        if correct { return Color.green.opacity(0.18) }
        if wrong   { return Color.orange.opacity(0.25) }
        return selected ? ColorTokens.Brand.primary.opacity(0.18) : ColorTokens.Kid.surface
    }

    private var actionRow: some View {
        HSButton(
            String(localized: phase == .feedback ? "sound_hunter.continue" : "sound_hunter.check"),
            style: .primary,
            action: checkOrContinue
        )
        .disabled(phase == .selecting && selectedIds.isEmpty)
    }

    // MARK: - Actions

    private func toggle(_ item: Item) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
        container.soundService.playUISound(.tap)
    }

    private func checkOrContinue() {
        switch phase {
        case .selecting: check()
        case .feedback:
            if let score { onComplete(score) }
        case .scoring: break
        }
    }

    private func check() {
        phase = .scoring
        let targets = items.filter(\.containsTarget)
        guard !targets.isEmpty else { return onComplete(0.5) }
        let correctHits = selectedIds.filter { id in
            items.first { $0.id == id }?.containsTarget ?? false
        }.count
        let wrongHits = selectedIds.count - correctHits
        let raw = Float(correctHits - wrongHits) / Float(targets.count)
        let clamped = max(0, min(1, raw))
        score = clamped
        logger.info("score=\(clamped, privacy: .public)")
        container.hapticService.notification(clamped >= 0.5 ? .success : .warning)
        phase = .feedback
    }

    // MARK: - Content

    /// Returns 6 items for the given target sound, 3 of which contain it.
    static func items(for sound: String) -> [Item] {
        switch sound {
        case "Р":
            return [
                Item(id: "r1", word: "рыба",   symbol: "fish.fill",     containsTarget: true),
                Item(id: "r2", word: "дом",    symbol: "house.fill",    containsTarget: false),
                Item(id: "r3", word: "крыша",  symbol: "tent.fill",     containsTarget: true),
                Item(id: "r4", word: "кот",    symbol: "pawprint.fill", containsTarget: false),
                Item(id: "r5", word: "корова", symbol: "hare.fill",     containsTarget: true),
                Item(id: "r6", word: "луна",   symbol: "moon.fill",     containsTarget: false),
            ]
        case "Ш":
            return [
                Item(id: "sh1", word: "шапка",  symbol: "laurel.leading", containsTarget: true),
                Item(id: "sh2", word: "луна",   symbol: "moon.fill",      containsTarget: false),
                Item(id: "sh3", word: "кошка",  symbol: "pawprint",       containsTarget: true),
                Item(id: "sh4", word: "дом",    symbol: "house.fill",     containsTarget: false),
                Item(id: "sh5", word: "шарик",  symbol: "balloon.fill",   containsTarget: true),
                Item(id: "sh6", word: "машина", symbol: "car.fill",       containsTarget: true),
            ]
        case "С":
            return [
                Item(id: "s1", word: "сад",   symbol: "tree.fill",     containsTarget: true),
                Item(id: "s2", word: "рыба",  symbol: "fish.fill",     containsTarget: false),
                Item(id: "s3", word: "сумка", symbol: "bag.fill",      containsTarget: true),
                Item(id: "s4", word: "мяч",   symbol: "soccerball",    containsTarget: false),
                Item(id: "s5", word: "слон",  symbol: "hare.fill",     containsTarget: true),
                Item(id: "s6", word: "кот",   symbol: "pawprint.fill", containsTarget: false),
            ]
        default:
            return items(for: "С")
        }
    }
}

#Preview {
    SoundHunterView(
        activity: SessionActivity(
            id: "preview", gameType: .soundHunter, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
