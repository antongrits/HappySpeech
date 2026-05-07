import SwiftUI

// MARK: - HSSwipeCardStack
//
// Block O v16 — Tinder-style стек карточек.
//
// Стек карточек, где верхняя реагирует на DragGesture: смещается, поворачивается
// пропорционально offset'у. При выходе за threshold (±150pt) карточка улетает,
// карточка ниже масштабируется до 1.0 и становится верхней. Идеальная база
// для упражнений `minimal-pairs` и `sorting`.
//
// Generic-контейнер по `Identifiable` элементам. Колбэк `onSwipe` сообщает
// направление (left/right) — фича сама решает, что значит «верно/неверно».
//
// Usage:
// ```swift
// HSSwipeCardStack(items: pairs) { pair, direction in
//     interactor.handle(pair: pair, direction: direction)
// } card: { pair in
//     VStack { Text(pair.word) ... }
// }
// ```
//
// References:
// - kavsoft.dev (Tinder Card Stack)
// - github.com/dadalar/SwiftUI-CardStackView (MIT)
// - Hacking with Swift — DragGesture rotationEffect

@available(iOS 17.0, *)
public struct HSSwipeCardStack<Item: Identifiable, Card: View>: View {

    public enum SwipeDirection {
        case left, right
    }

    // MARK: - Public API

    public let items: [Item]
    public let onSwipe: (Item, SwipeDirection) -> Void
    public let card: (Item) -> Card

    /// Максимум видимых карточек в стеке (по дефолту 3).
    public var maxVisible: Int = 3

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.hapticService) private var hapticService

    // MARK: - State

    @State private var offset: CGSize = .zero
    @State private var topIndex: Int = 0

    public init(
        items: [Item],
        maxVisible: Int = 3,
        onSwipe: @escaping (Item, SwipeDirection) -> Void,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.items = items
        self.maxVisible = maxVisible
        self.onSwipe = onSwipe
        self.card = card
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            ForEach(visibleSlice.reversed(), id: \.element.id) { entry in
                cardView(for: entry.element, depth: entry.offset)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(for item: Item, depth: Int) -> some View {
        let isTop = depth == 0
        let scale = 1.0 - CGFloat(depth) * 0.05
        let yOffset = CGFloat(depth) * 12.0

        card(item)
            .scaleEffect(scale)
            .offset(x: isTop ? offset.width : 0, y: yOffset + (isTop ? offset.height : 0))
            .rotationEffect(.degrees(isTop ? Double(offset.width) / 20 : 0))
            .opacity(isTop ? topOpacity : 1.0)
            .gesture(isTop ? dragGesture(for: item) : nil)
            .animation(
                reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.78),
                value: topIndex
            )
            .accessibilityAddTraits(isTop ? [.isButton] : [])
    }

    private var topOpacity: Double {
        let progress = min(abs(offset.width) / 200, 1.0)
        return 1.0 - progress * 0.5
    }

    // MARK: - Drag Gesture

    private func dragGesture(for item: Item) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if reduceMotion {
                    offset = .zero
                } else {
                    offset = value.translation
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 150
                if value.translation.width > threshold {
                    swipe(item: item, direction: .right, distance: 600)
                } else if value.translation.width < -threshold {
                    swipe(item: item, direction: .left, distance: -600)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        offset = .zero
                    }
                }
            }
    }

    private func swipe(item: Item, direction: SwipeDirection, distance: CGFloat) {
        hapticService.impact(.light)
        if reduceMotion {
            offset = .zero
            advance(item: item, direction: direction)
        } else {
            withAnimation(.easeOut(duration: 0.28)) {
                offset = CGSize(width: distance, height: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                advance(item: item, direction: direction)
            }
        }
    }

    private func advance(item: Item, direction: SwipeDirection) {
        onSwipe(item, direction)
        offset = .zero
        if topIndex < items.count {
            topIndex += 1
        }
    }

    // MARK: - Slice

    private var visibleSlice: [(offset: Int, element: Item)] {
        guard topIndex < items.count else { return [] }
        let endIndex = min(topIndex + maxVisible, items.count)
        return zip(0..<maxVisible, items[topIndex..<endIndex]).map { (offset: $0, element: $1) }
    }
}

// MARK: - Preview

#Preview("HSSwipeCardStack") {
    SwipePreview()
        .padding()
        .background(ColorTokens.Kid.bg)
}

@available(iOS 17.0, *)
private struct SwipePreview: View {
    struct DemoCard: Identifiable {
        let id = UUID()
        let title: String
        let color: Color
    }

    @State private var items = [
        DemoCard(title: "Сова", color: ColorTokens.Brand.primary),
        DemoCard(title: "Собака", color: ColorTokens.Brand.mint),
        DemoCard(title: "Сапог", color: ColorTokens.Brand.lilac),
        DemoCard(title: "Сок", color: ColorTokens.Brand.butter)
    ]

    @State private var lastDirection: String = ""

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Text("Последний свайп: \(lastDirection)")
                .font(TypographyTokens.body())

            HSSwipeCardStack(
                items: items,
                maxVisible: 3,
                onSwipe: { _, dir in
                    lastDirection = dir == .right ? "вправо" : "влево"
                },
                card: { card in
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .fill(card.color.opacity(0.85))
                        .frame(height: 280)
                        .overlay(
                            Text(card.title)
                                .font(TypographyTokens.titleLarge())
                                .foregroundStyle(.white)
                        )
                        .shadow(color: ColorTokens.Overlay.shadow, radius: 14, x: 0, y: 8)
                }
            )
            .frame(height: 320)
        }
    }
}
