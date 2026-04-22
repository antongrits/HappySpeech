import SwiftUI

// MARK: - HSPictTile

/// Picture tile used in ListenAndChoose, Memory, SoundHunter and similar games.
/// Displays an image (SF Symbol or asset) with a label and animated state feedback.
/// Touch target is 88×88pt minimum for the kid circuit (5–8 years).
public struct HSPictTile: View {

    // MARK: - Tile State

    public enum TileState: Equatable {
        case neutral
        case selected
        case correct
        case incorrect

        var borderColor: Color {
            switch self {
            case .neutral:   return .clear
            case .selected:  return ColorTokens.Games.listenAndChoose
            case .correct:   return ColorTokens.Feedback.correct
            case .incorrect: return ColorTokens.Feedback.incorrect
            }
        }

        var backgroundColor: Color {
            switch self {
            case .neutral:   return ColorTokens.Kid.surface
            case .selected:  return ColorTokens.Games.listenAndChoose.opacity(0.12)
            case .correct:   return ColorTokens.Feedback.correct.opacity(0.12)
            case .incorrect: return ColorTokens.Feedback.incorrect.opacity(0.10)
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .neutral:  return 0
            default:        return 3
            }
        }

        var accessibilitySuffix: String {
            switch self {
            case .neutral:   return ""
            case .selected:  return String(localized: ", выбрано")
            case .correct:   return String(localized: ", правильно")
            case .incorrect: return String(localized: ", неправильно")
            }
        }
    }

    // MARK: - Image Source

    public enum ImageSource {
        case symbol(String)          // SF Symbol name
        case asset(String)           // xcassets image name
    }

    // MARK: - Properties

    private let imageSource: ImageSource
    private let label: String
    private let state: TileState
    private let size: CGFloat
    private let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scaleEffect: CGFloat = 1.0

    // MARK: - Init

    public init(
        image: ImageSource,
        label: String,
        state: TileState = .neutral,
        size: CGFloat = 140,
        onTap: @escaping () -> Void
    ) {
        self.imageSource = image
        self.label = label
        self.state = state
        self.size = size
        self.onTap = onTap
    }

    /// Convenience init with SF Symbol name.
    public init(
        symbol: String,
        label: String,
        state: TileState = .neutral,
        size: CGFloat = 140,
        onTap: @escaping () -> Void
    ) {
        self.init(image: .symbol(symbol), label: label, state: state, size: size, onTap: onTap)
    }

    // MARK: - Body

    public var body: some View {
        Button(action: handleTap) {
            VStack(spacing: SpacingTokens.sp2) {
                imageView
                    .frame(width: imageSize, height: imageSize)

                Text(label)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(SpacingTokens.sp3)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(state.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .strokeBorder(state.borderColor, lineWidth: state.borderWidth)
            )
            .scaleEffect(scaleEffect)
        }
        .buttonStyle(.plain)
        // Ensure minimum 88x88pt touch target in kid circuit
        .frame(minWidth: 88, minHeight: 88)
        .contentShape(Rectangle())
        .onChange(of: state) { _, newState in
            guard !reduceMotion else { return }
            if newState == .correct || newState == .incorrect {
                withAnimation(MotionTokens.bounce) {
                    scaleEffect = newState == .correct ? 1.08 : 0.95
                }
                withAnimation(MotionTokens.bounce.delay(0.18)) {
                    scaleEffect = 1.0
                }
            }
        }
        .accessibilityLabel(label + state.accessibilitySuffix)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "Нажмите, чтобы выбрать этот ответ"))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var imageView: some View {
        switch imageSource {
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(imageColor)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        }
    }

    // MARK: - Helpers

    private var imageSize: CGFloat { size * 0.52 }

    private var imageColor: Color {
        switch state {
        case .neutral, .selected: return ColorTokens.Brand.primary
        case .correct:            return ColorTokens.Feedback.correct
        case .incorrect:          return ColorTokens.Feedback.incorrect
        }
    }

    private func handleTap() {
        guard state == .neutral || state == .selected else { return }
        if !reduceMotion {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                scaleEffect = 0.94
            }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6).delay(0.10)) {
                scaleEffect = 1.0
            }
        }
        onTap()
    }
}

// MARK: - Preview

#Preview("HSPictTile States") {
    VStack(spacing: SpacingTokens.sp5) {
        HStack(spacing: SpacingTokens.sp4) {
            HSPictTile(symbol: "tortoise.fill", label: "Черепаха", state: .neutral) {}
            HSPictTile(symbol: "hare.fill", label: "Заяц", state: .selected) {}
        }
        HStack(spacing: SpacingTokens.sp4) {
            HSPictTile(symbol: "bird.fill", label: "Птица", state: .correct) {}
            HSPictTile(symbol: "fish.fill", label: "Рыба", state: .incorrect) {}
        }
    }
    .padding()
    .background(ColorTokens.Kid.bg)
    .environment(\.circuitContext, .kid)
}
