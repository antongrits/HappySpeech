import SwiftUI

// MARK: - HSSymbolEffectStyle

/// Semantic mapping over the iOS 17+ `SymbolEffect` API.
///
/// Use through `View.hsSymbolEffect(_:value:)` so the feature layer never
/// has to gate on `#available` — the modifier provides a no-op fallback for
/// pre-iOS-17 builds.
public enum HSSymbolEffectStyle: Sendable {
    /// Native `.bounce` — single bouncy pop.
    case bounce
    /// Native `.pulse` — gentle, periodic emphasis.
    case pulse
    /// Native `.variableColor` — fill levels animate one at a time.
    case variableColor
    /// Native `.scale.up` then `.scale.default` — emphatic resize.
    case scale
}

// MARK: - HSSymbolEffect ViewModifier

/// View modifier that wraps Apple's `.symbolEffect(_:options:value:)` API
/// with `HappySpeech` semantics and a safe fallback on older OS versions.
///
/// On iOS 17+ the modifier installs the requested effect with `.repeating`
/// behaviour; on iOS 16 it returns the view unchanged so existing call
/// sites stay source-compatible.
public struct HSSymbolEffect<Value: Equatable>: ViewModifier {

    public let style: HSSymbolEffectStyle
    public let value: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(style: HSSymbolEffectStyle, value: Value) {
        self.style = style
        self.value = value
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            applied(to: content)
        } else {
            content
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func applied(to content: Content) -> some View {
        // Under Reduce Motion we keep the icon static but still observe
        // the value so SwiftUI redraws if the upstream state changes.
        if reduceMotion {
            content
        } else {
            switch style {
            case .bounce:
                content.symbolEffect(.bounce, options: .default, value: value)
            case .pulse:
                content.symbolEffect(.pulse, options: .default, value: value)
            case .variableColor:
                // `.repeating` (no arg) is iOS 17+; `.repeat(.continuous)`
                // requires iOS 18, so we stay on the iOS 17 baseline.
                content.symbolEffect(
                    .variableColor.iterative.reversing,
                    options: .repeating,
                    value: value
                )
            case .scale:
                content.symbolEffect(.bounce.up, options: .default, value: value)
            }
        }
    }
}

// MARK: - View extension

public extension View {

    /// Applies a HappySpeech-branded SF Symbol effect keyed by `value`.
    ///
    /// - Parameters:
    ///   - style: Which native effect to apply.
    ///   - value: Any `Equatable` change-driver — the effect fires whenever
    ///     `value` mutates.
    ///
    /// ## Example
    /// ```swift
    /// Image(systemName: "heart.fill")
    ///     .hsSymbolEffect(.bounce, value: tapCount)
    /// ```
    func hsSymbolEffect<Value: Equatable>(
        _ style: HSSymbolEffectStyle,
        value: Value
    ) -> some View {
        modifier(HSSymbolEffect(style: style, value: value))
    }
}

// MARK: - Preview

#Preview("HSSymbolEffect — heart pulse") {
    struct PreviewHost: View {
        @State private var tapCount = 0
        var body: some View {
            VStack(spacing: SpacingTokens.large) {
                Button {
                    tapCount += 1
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .hsSymbolEffect(.bounce, value: tapCount)
                }
                .buttonStyle(.plain)

                Text("Tapped \(tapCount) times")
                    .font(TypographyTokens.body())

                Image(systemName: "wifi")
                    .font(.system(size: 64))
                    .foregroundStyle(ColorTokens.Brand.sky)
                    .hsSymbolEffect(.variableColor, value: tapCount)
            }
            .padding(SpacingTokens.large)
        }
    }
    return PreviewHost()
}
