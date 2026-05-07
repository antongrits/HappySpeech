import SwiftUI

// MARK: - HSContentSymbol
//
// Block D v16: универсальный helper для рендеринга строкового идентификатора,
// который может быть либо SF Symbol name (содержит точку или одно из known
// keyword'ов), либо Asset name (Illustration из Assets.xcassets).
//
// Это введено после массовой замены эмодзи на SF Symbol / Illustration в
// LessonPlayer моделях. Поле `emoji: String` в Models теперь хранит либо
// "word_apple" (Asset), либо "checkmark.circle.fill" (SF Symbol). HSContentSymbol
// делает правильный выбор автоматически.

public struct HSContentSymbol: View {
    /// Имя SF Symbol или Asset.
    public let name: String
    /// Размер (для SF Symbol — pointSize, для Asset — фрейм W=H).
    public let size: CGFloat
    /// Tint только для SF Symbol (Asset рендерится без tint).
    public let tint: Color

    public init(
        _ name: String,
        size: CGFloat = 32,
        tint: Color = ColorTokens.Brand.primary
    ) {
        self.name = name
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        if isSFSymbol(name) {
            Image(systemName: name)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: size + 4, height: size + 4)
                .accessibilityHidden(true)
        } else {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size + 8, height: size + 8)
                .accessibilityHidden(true)
        }
    }

    /// Эвристика: SF Symbol либо содержит точку (multi-word), либо это известное
    /// одно слово (sparkles, calendar, magnifyingglass и т.д.) из mapping table.
    private func isSFSymbol(_ s: String) -> Bool {
        if s.contains(".") { return true }
        return Self.knownSingleWordSymbols.contains(s)
    }

    /// SF Symbols без точек, использовавшиеся в Block D mapping.
    private static let knownSingleWordSymbols: Set<String> = [
        "sparkles", "sparkle", "questionmark", "calendar", "magnifyingglass",
        "target", "ribbon", "soccerball", "iphone", "stethoscope",
        "globe", "snowflake"
    ]
}

#if DEBUG
#Preview("HSContentSymbol — SF Symbol") {
    HSContentSymbol("party.popper.fill", size: 48, tint: ColorTokens.Brand.gold)
}

#Preview("HSContentSymbol — Asset") {
    HSContentSymbol("word_apple", size: 48)
}
#endif
