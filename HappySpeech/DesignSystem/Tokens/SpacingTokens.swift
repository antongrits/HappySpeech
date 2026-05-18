import SwiftUI

// MARK: - SpacingTokens

/// Система отступов на базе 4pt-сетки.
///
/// `SpacingTokens` предоставляет именованные константы для всех отступов,
/// выровненных на 4pt-сетку. Переведены из дизайн-прототипа `tokens.jsx`.
///
/// Используй **семантические алиасы** вместо числовых (`sp1`–`sp16`) —
/// они явно выражают назначение:
///
/// | Алиас | Значение | Назначение |
/// |-------|---------|-----------|
/// | `micro` | 4pt | Иконка + текст |
/// | `tiny` | 8pt | Внутри компонента |
/// | `small` | 12pt | Между элементами списка |
/// | `regular` | 16pt | Стандартный отступ |
/// | `screenEdge` | 24pt | Горизонтальные поля экрана |
/// | `cardPad` | 20pt | Внутренние отступы карточки |
/// | `sectionGap` | 32pt | Между секциями |
///
/// ## Пример
/// ```swift
/// VStack(spacing: SpacingTokens.listGap) {
///     ForEach(items) { item in
///         HSCard { ... }
///     }
/// }
/// .padding(.horizontal, SpacingTokens.screenEdge)
/// .padding(.top, SpacingTokens.pageTop)
/// ```
///
/// ## See Also
/// - ``ColorTokens``
/// - ``RadiusTokens``
public enum SpacingTokens {
    public static let sp1: CGFloat = 4
    public static let sp2: CGFloat = 8
    public static let sp3: CGFloat = 12
    public static let sp4: CGFloat = 16
    public static let sp5: CGFloat = 20
    public static let sp6: CGFloat = 24
    public static let sp8: CGFloat = 32
    public static let sp10: CGFloat = 40
    public static let sp12: CGFloat = 48
    public static let sp16: CGFloat = 64

    // Semantic aliases
    public static let micro: CGFloat = sp1     // 4
    public static let tiny: CGFloat = sp2     // 8
    public static let small: CGFloat = sp3     // 12
    public static let regular: CGFloat = sp4     // 16
    public static let medium: CGFloat = sp5     // 20
    public static let large: CGFloat = sp6     // 24
    public static let xLarge: CGFloat = sp8     // 32
    public static let xxLarge: CGFloat = sp10    // 40
    public static let xxxLarge: CGFloat = sp12    // 48
    public static let screenEdge: CGFloat = sp6     // 24 — standard horizontal screen padding
    public static let cardPad: CGFloat = sp5     // 20 — inside card padding
    public static let listGap: CGFloat = sp3     // 12 — gap between list rows
    public static let sectionGap: CGFloat = sp8     // 32 — gap between sections
    public static let pageTop: CGFloat = sp10    // 40 — page top inset
}

// MARK: - RadiusTokens
// Translated from tokens.jsx r: { xs:8, sm:12, md:18, lg:24, xl:32, full:9999 }

public enum RadiusTokens {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 18
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let full: CGFloat = 9999

    // Semantic aliases
    public static let chip: CGFloat = xs    // 8
    public static let card: CGFloat = lg    // 24
    public static let button: CGFloat = xl    // 32
    public static let sheet: CGFloat = xl    // 32
    public static let avatar: CGFloat = full

    // MARK: - Concentric Radii (v29)
    //
    // For nested geometry (icon inside tile inside card) the inner radius
    // must equal the outer radius minus the inset, so the corner curves
    // stay parallel — Apple's iOS 26 hardware-aligned geometry. Mismatched
    // radii are a subtle "amateur" tell.

    /// Inner radius concentric with an outer corner, given the inset between them.
    /// Never goes below `xs / 1.5` so very small nested elements stay rounded.
    public static func concentric(outer: CGFloat, inset: CGFloat) -> CGFloat {
        max(outer - inset, xs / 1.5)
    }

    /// Radius for an element inset inside a standard card by `inset` points.
    public static func insideCard(inset: CGFloat = SpacingTokens.cardPad) -> CGFloat {
        concentric(outer: card, inset: inset)
    }
}
