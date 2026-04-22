import SwiftUI

// MARK: - SpacingTokens
// 4pt base grid. Translated from tokens.jsx sp: { 1:4, 2:8, 3:12, 4:16, 5:20, 6:24, 8:32, 10:40, 12:48, 16:64 }

public enum SpacingTokens {
    public static let sp1:  CGFloat = 4
    public static let sp2:  CGFloat = 8
    public static let sp3:  CGFloat = 12
    public static let sp4:  CGFloat = 16
    public static let sp5:  CGFloat = 20
    public static let sp6:  CGFloat = 24
    public static let sp8:  CGFloat = 32
    public static let sp10: CGFloat = 40
    public static let sp12: CGFloat = 48
    public static let sp16: CGFloat = 64

    // Semantic aliases
    public static let micro:      CGFloat = sp1     // 4
    public static let tiny:       CGFloat = sp2     // 8
    public static let small:      CGFloat = sp3     // 12
    public static let regular:    CGFloat = sp4     // 16
    public static let medium:     CGFloat = sp5     // 20
    public static let large:      CGFloat = sp6     // 24
    public static let xLarge:     CGFloat = sp8     // 32
    public static let xxLarge:    CGFloat = sp10    // 40
    public static let xxxLarge:   CGFloat = sp12    // 48
    public static let screenEdge: CGFloat = sp6     // 24 — standard horizontal screen padding
    public static let cardPad:    CGFloat = sp5     // 20 — inside card padding
    public static let listGap:    CGFloat = sp3     // 12 — gap between list rows
    public static let sectionGap: CGFloat = sp8     // 32 — gap between sections
    public static let pageTop:    CGFloat = sp10    // 40 — page top inset
}

// MARK: - RadiusTokens
// Translated from tokens.jsx r: { xs:8, sm:12, md:18, lg:24, xl:32, full:9999 }

public enum RadiusTokens {
    public static let xs:   CGFloat = 8
    public static let sm:   CGFloat = 12
    public static let md:   CGFloat = 18
    public static let lg:   CGFloat = 24
    public static let xl:   CGFloat = 32
    public static let full: CGFloat = 9999

    // Semantic aliases
    public static let chip:    CGFloat = xs    // 8
    public static let card:    CGFloat = lg    // 24
    public static let button:  CGFloat = xl    // 32
    public static let sheet:   CGFloat = xl    // 32
    public static let avatar:  CGFloat = full
}
