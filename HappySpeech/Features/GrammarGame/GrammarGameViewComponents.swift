import SwiftUI

// MARK: - GrammarGameViewComponents
//
// Подкомпоненты `GrammarGameView`. Все структуры — `internal`.

// MARK: - PluralPreviewGrid

/// Сетка из 5 копий иконки предмета (анимация «много»).
struct PluralPreviewGrid: View {
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 8
        ) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "circle.fill")
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Brand.primary.opacity(0.7))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Brand.primary.opacity(0.08))
        )
    }
}

// MARK: - DativeDropTargetView

struct DativeDropTargetView: View {
    let character: DativeCharacter
    let isHighlighted: Bool
    var isSmall: Bool = false

    private let frameWidth: CGFloat
    private let frameHeight: CGFloat

    init(character: DativeCharacter, isHighlighted: Bool, isSmall: Bool = false) {
        self.character = character
        self.isHighlighted = isHighlighted
        self.isSmall = isSmall
        self.frameWidth  = isSmall ? 80 : 100
        self.frameHeight = isSmall ? 100 : 120
    }

    var body: some View {
        VStack(spacing: SpacingTokens.small) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(isHighlighted
                          ? ColorTokens.Brand.primary.opacity(0.15)
                          : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(
                                isHighlighted ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                lineWidth: isHighlighted ? 3 : 1.5
                            )
                    )
                    .frame(width: frameWidth, height: frameHeight)

                Image(systemName: "person.circle.fill")
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }

            Text(character.dativeName)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel("\(character.dativeName), поле для перетаскивания")
        .accessibilityHint(String(localized: "grammar.game.accessibility.drop_here", bundle: .main))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - GenitiveSceneView

struct GenitiveSceneView: View {
    let containers: [GenitiveContainer]
    let selectedContainerId: String?
    let correctContainerId: String?

    var body: some View {
        ZStack {
            // Фон сцены (заглушка)
            Color.clear

            // Ляля держит предмет в верхней части
            Image(systemName: "person.fill")
                .font(TypographyTokens.kidDisplay(40))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)

            // Контейнеры в нижней части
            HStack(spacing: SpacingTokens.large) {
                ForEach(containers) { container in
                    ContainerTapTargetView(
                        container: container,
                        isSelected: selectedContainerId == container.id,
                        isCorrect: correctContainerId == container.id
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SpacingTokens.xLarge)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, SpacingTokens.xLarge)
        }
    }
}

// MARK: - ContainerTapTargetView

struct ContainerTapTargetView: View {
    let container: GenitiveContainer
    let isSelected: Bool
    let isCorrect: Bool

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .strokeBorder(borderColor, lineWidth: borderWidth)
                    )
                Image(systemName: "cube.box.fill")
                    .font(TypographyTokens.kidDisplay(32))
                    .foregroundStyle(ColorTokens.Brand.primary)
            }
            .frame(width: 80, height: 88)

            Text(container.genitiveName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel("\(container.genitiveName), нажмите чтобы выбрать")
        .accessibilityAddTraits(.isButton)
    }

    private var backgroundColor: Color {
        if isCorrect { return ColorTokens.Semantic.successBg }
        if isSelected { return ColorTokens.Semantic.errorBg }
        return ColorTokens.Kid.surface
    }

    private var borderColor: Color {
        if isCorrect { return ColorTokens.Semantic.success }
        if isSelected { return ColorTokens.Semantic.error }
        return ColorTokens.Kid.line
    }

    private var borderWidth: CGFloat { isSelected || isCorrect ? 3 : 1.5 }
}

// MARK: - PartyGuestsGrid

struct PartyGuestsGrid: View {
    let confirmedCount: Int
    let totalGuests: Int

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.regular), count: 3),
            spacing: SpacingTokens.regular
        ) {
            ForEach(0..<totalGuests, id: \.self) { idx in
                if idx < confirmedCount {
                    // Прибывший гость
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(TypographyTokens.title(28))
                                .foregroundStyle(ColorTokens.Brand.primary)
                        )
                        .transition(.scale.animation(.spring(response: 0.5).delay(Double(idx) * 0.1)))
                } else {
                    // Пустое место
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        .foregroundStyle(ColorTokens.Kid.line)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: "person.badge.plus")
                                .font(TypographyTokens.headline(22))
                                .foregroundStyle(ColorTokens.Kid.inkSoft)
                        )
                }
            }
        }
    }
}
