import SwiftUI

// MARK: - HSAccessibleTextStyle

public enum HSAccessibleTextStyle: Sendable, Equatable {
    case title
    case headline
    case body
    case caption
    case label
}

// MARK: - HSAccessibleText

/// Dynamic Type-friendly text wrapper. Picks a font from `TypographyTokens`
/// based on `style`, but allows callers to override the size. Always ships
/// with `lineLimit(nil)` and `minimumScaleFactor(0.75)` so long Russian
/// strings reflow gracefully under accessibility text sizes.
public struct HSAccessibleText: View {

    private let text: String
    private let style: HSAccessibleTextStyle
    private let size: CGFloat
    private let muted: Bool
    private let align: TextAlignment
    private let emphasis: Bool

    public init(
        _ text: String,
        style: HSAccessibleTextStyle = .body,
        size: CGFloat = 16,
        muted: Bool = false,
        align: TextAlignment = .leading,
        emphasis: Bool = false
    ) {
        self.text = text
        self.style = style
        self.size = size
        self.muted = muted
        self.align = align
        self.emphasis = emphasis
    }

    public var body: some View {
        Text(text)
            .font(font)
            .fontWeight(emphasis ? .semibold : nil)
            .foregroundStyle(foreground)
            .multilineTextAlignment(align)
            .lineLimit(nil)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(isHeader ? .isHeader : [])
    }

    // MARK: - Style mapping

    private var font: Font {
        switch style {
        case .title:    return TypographyTokens.title(size)
        case .headline: return TypographyTokens.headline(size)
        case .body:     return TypographyTokens.body(size)
        case .caption:  return TypographyTokens.caption(size)
        case .label:    return TypographyTokens.caption(size)
        }
    }

    private var foreground: Color {
        muted ? ColorTokens.Kid.inkMuted : ColorTokens.Kid.ink
    }

    private var isHeader: Bool {
        style == .title || style == .headline
    }
}

// MARK: - Preview

#Preview("HSAccessibleText") {
    VStack(alignment: .leading, spacing: SpacingTokens.regular) {
        HSAccessibleText("Привет, малыш!", style: .title, size: 28)
        HSAccessibleText("Сегодня учим звук С", style: .headline, size: 20, emphasis: true)
        HSAccessibleText(
            "Сядь поудобнее, расправь плечи и улыбнись зеркалу. Сейчас мы будем петь песенку про насос.",
            style: .body,
            size: 16
        )
        HSAccessibleText("Подсказка для родителей", style: .caption, size: 13, muted: true)
        HSAccessibleText("ПРОГРЕСС", style: .label, size: 12, muted: true, emphasis: true)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}
