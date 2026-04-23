import SwiftUI

// MARK: - GuidedTourTipView

/// Coach-mark bubble shown next to the spotlighted element during the guided tour.
/// Renders the current step's title/body, a progress indicator "1/11", a primary
/// "Next" action and an optional "Skip" secondary action.
///
/// The bubble auto-positions above or below the spotlight rect depending on which
/// half of the screen the rect sits in, so the tip never overlaps the highlighted
/// element.
struct GuidedTourTipView: View {

    let step: TourStep
    let stepNumber: Int
    let totalSteps: Int
    let spotlightRect: CGRect?
    let screenSize: CGSize
    let isLastStep: Bool

    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            headerRow
            Text(step.title)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(step.body)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            actionRow
        }
        .padding(SpacingTokens.sp5)
        .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.lg))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg)
                .stroke(ColorTokens.Brand.primary.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .frame(maxWidth: 340)
        .padding(.horizontal, SpacingTokens.sp5)
        .position(
            x: screenSize.width / 2,
            y: verticalAnchor
        )
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .animation(
            reduceMotion ? .linear(duration: 0.15) : MotionTokens.spring,
            value: step.id
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(step.title). \(step.body)")
        .accessibilityHint(String(localized: "tour.a11y.hint"))
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Text("\(stepNumber) / \(totalSteps)")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .padding(.horizontal, SpacingTokens.sp2)
                .padding(.vertical, SpacingTokens.sp1)
                .background(ColorTokens.Brand.primary.opacity(0.12), in: Capsule())

            Spacer()

            if step.allowSkip && !isLastStep {
                Button(action: onSkip) {
                    Text(String(localized: "tour.skip"))
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .accessibilityLabel(String(localized: "tour.skip"))
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button(action: onNext) {
                HStack(spacing: SpacingTokens.sp2) {
                    Text(isLastStep
                         ? String(localized: "tour.done")
                         : String(localized: "tour.next"))
                    if !isLastStep {
                        Image(systemName: "arrow.right")
                    }
                }
                .font(TypographyTokens.cta())
                .foregroundStyle(Color.white)
                .padding(.horizontal, SpacingTokens.sp5)
                .padding(.vertical, SpacingTokens.sp3)
                .background(ColorTokens.Brand.primary, in: Capsule())
            }
            .accessibilityLabel(isLastStep
                                ? String(localized: "tour.done")
                                : String(localized: "tour.next"))
        }
    }

    // MARK: - Positioning

    /// Places the tip in the opposite half of the screen from the spotlight rect.
    /// When the spotlight is in the top half → tip sits in the bottom 40 %.
    /// When the spotlight is in the bottom half → tip sits in the top 40 %.
    /// When rect is unknown → centered on screen.
    private var verticalAnchor: CGFloat {
        guard let rect = spotlightRect, rect != .zero else {
            return screenSize.height / 2
        }
        let midY = rect.midY
        let topHalf = midY < screenSize.height / 2
        return topHalf ? screenSize.height * 0.72 : screenSize.height * 0.28
    }
}

// MARK: - Preview

#Preview("Tip") {
    ZStack {
        ColorTokens.Kid.bg.ignoresSafeArea()
        GuidedTourTipView(
            step: TourSteps.all[0],
            stepNumber: 1,
            totalSteps: 11,
            spotlightRect: CGRect(x: 40, y: 120, width: 320, height: 80),
            screenSize: CGSize(width: 393, height: 852),
            isLastStep: false,
            onNext: {},
            onSkip: {}
        )
    }
}
