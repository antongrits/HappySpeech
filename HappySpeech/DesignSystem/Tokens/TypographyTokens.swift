import SwiftUI

// MARK: - TypographyTokens
// SF Pro Rounded for kid circuit; SF Pro Text for parent/specialist.

public enum TypographyTokens {

    // MARK: - Font Styles

    /// Display — big hero text (kid contour), 32–40pt
    public static func display(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Title — section headers, 22–28pt
    public static func title(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Headline — card titles, 17–20pt
    public static func headline(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Body — main reading text, 15–16pt
    public static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Caption — labels, hints, 12–13pt
    public static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Mono — scores, technical data, 12–14pt
    public static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// CTA — call-to-action buttons, 17pt
    public static func cta() -> Font {
        .system(size: 17, weight: .bold, design: .rounded)
    }

    /// KidDisplay — extra-large rounded for child contour, 40pt+
    public static func kidDisplay(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    // MARK: - Dynamic Type Scaled Variants

    /// Body scaled to Dynamic Type.
    public static var bodyScaled: Font { .body }

    /// Headline scaled to Dynamic Type.
    public static var headlineScaled: Font { .headline }

    /// Caption scaled to Dynamic Type.
    public static var captionScaled: Font { .caption }

    // MARK: - Line Spacing

    public enum LineSpacing {
        public static let tight:   CGFloat = 1.1
        public static let normal:  CGFloat = 1.35
        public static let relaxed: CGFloat = 1.5
        public static let loose:   CGFloat = 1.7
    }

    // MARK: - Letter Spacing

    public enum LetterSpacing {
        public static let tight:   CGFloat = -0.5
        public static let normal:  CGFloat = 0
        public static let wide:    CGFloat = 0.5
        public static let widest:  CGFloat = 2.0
    }
}
