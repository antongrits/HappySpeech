import SwiftUI
import UIKit

// MARK: - HSStarRatingView

/// Звёздный рейтинг 1–5 — для финального экрана урока и истории сессий.
///
/// Поддерживает два режима: `.display` (read-only — для отображения предыдущих
/// результатов) и `.interactive` (пользователь оценивает урок). В интерактивном
/// режиме каждая звезда — отдельная tap-target шириной 44pt × 44pt (соответствие HIG).
/// При нажатии воспроизводится тактильный отклик через `UIImpactFeedbackGenerator`.
///
/// Цвет заполненной звезды — `ColorTokens.Brand.gold` (gold), пустой — `secondary`.
/// VoiceOver: «Оценка X из 5», в interactive-режиме каждая звезда озвучивается
/// как «Поставить N звёзд».
///
/// ## Пример
/// ```swift
/// // Display
/// HSStarRatingView(rating: 4)
///
/// // Interactive
/// @State var rating: Int = 0
/// HSStarRatingView(rating: $rating, mode: .interactive)
/// ```
///
/// ## See Also
/// - ``ColorTokens``
/// - ``HSButton``
@available(iOS 17.0, *)
public struct HSStarRatingView: View {

    // MARK: - Mode

    public enum Mode: Sendable {
        case display
        case interactive
    }

    // MARK: - Public API

    private let maxStars: Int
    private let mode: Mode
    private let starSize: CGFloat

    @Binding private var rating: Int
    private let displayRating: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Inits

    /// Display-режим — фиксированный rating, без `Binding`.
    public init(rating: Int, maxStars: Int = 5, starSize: CGFloat = 28) {
        self._rating = .constant(rating)
        self.displayRating = rating
        self.maxStars = maxStars
        self.mode = .display
        self.starSize = starSize
    }

    /// Interactive-режим — двусторонняя привязка к `Binding<Int>`.
    public init(
        rating: Binding<Int>,
        mode: Mode = .interactive,
        maxStars: Int = 5,
        starSize: CGFloat = 32
    ) {
        self._rating = rating
        self.displayRating = rating.wrappedValue
        self.maxStars = maxStars
        self.mode = mode
        self.starSize = starSize
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: SpacingTokens.tiny) {
            ForEach(1...maxStars, id: \.self) { index in
                star(at: index)
            }
        }
        .accessibilityElement(children: mode == .interactive ? .contain : .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    // MARK: - Star

    @ViewBuilder
    private func star(at index: Int) -> some View {
        let effectiveRating = mode == .interactive ? rating : displayRating
        let isFilled = index <= effectiveRating

        Group {
            switch mode {
            case .display:
                starImage(isFilled: isFilled)
            case .interactive:
                Button {
                    handleTap(newRating: index)
                } label: {
                    starImage(isFilled: isFilled)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(localized: "starRating.set", defaultValue: "Поставить")
                    + " \(index) "
                    + String(localized: "starRating.outOf", defaultValue: "из")
                    + " \(maxStars)"
                )
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    private func starImage(isFilled: Bool) -> some View {
        let icon = Image(systemName: isFilled ? "star.fill" : "star")
            .font(.system(size: starSize, weight: .semibold))
            .foregroundStyle(isFilled ? ColorTokens.Brand.gold : Color.secondary)
            // v29 — star/star.fill swap is a native symbol replace.
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isFilled && !reduceMotion ? 1.1 : 1.0)
            .animation(
                MotionTokens.reward(reduceMotion: reduceMotion),
                value: isFilled
            )
        if reduceMotion {
            icon
        } else {
            // Reward bounce when the star fills.
            icon.symbolEffect(.bounce, value: isFilled)
        }
    }

    // MARK: - Tap

    private func handleTap(newRating: Int) {
        rating = newRating
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        let value = mode == .interactive ? rating : displayRating
        return String(localized: "starRating.label.prefix", defaultValue: "Оценка")
            + " \(value) "
            + String(localized: "starRating.outOf", defaultValue: "из")
            + " \(maxStars)"
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("HSStarRatingView — Display") {
    VStack(spacing: SpacingTokens.large) {
        HSStarRatingView(rating: 5)
        HSStarRatingView(rating: 3)
        HSStarRatingView(rating: 1)
        HSStarRatingView(rating: 0)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}

@available(iOS 17.0, *)
#Preview("HSStarRatingView — Interactive Light") {
    @Previewable @State var rating: Int = 3
    return VStack(spacing: SpacingTokens.large) {
        HSStarRatingView(rating: $rating, mode: .interactive)
        Text("Текущая оценка: \(rating)")
            .font(TypographyTokens.body())
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}

@available(iOS 17.0, *)
#Preview("HSStarRatingView — Interactive Dark") {
    @Previewable @State var rating: Int = 4
    return VStack(spacing: SpacingTokens.large) {
        HSStarRatingView(rating: $rating, mode: .interactive)
        Text("Текущая оценка: \(rating)")
            .font(TypographyTokens.body())
    }
    .padding()
    .background(ColorTokens.Kid.bg)
    .preferredColorScheme(.dark)
}
#endif
