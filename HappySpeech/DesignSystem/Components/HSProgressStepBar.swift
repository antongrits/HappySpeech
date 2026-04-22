import SwiftUI

// MARK: - HSProgressStepBar

/// Step-based progress indicator for SessionShell.
/// Shows N circles connected by lines:
///   - completed steps: filled solid
///   - current step: pulsing ring
///   - future steps: muted grey
public struct HSProgressStepBar: View {

    private let totalSteps: Int
    private let currentStep: Int   // 1-based
    private let accentColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Layout constants

    private let dotSize:     CGFloat = 18
    private let activeDotSize: CGFloat = 22
    private let lineHeight:  CGFloat = 3
    private let ringWidth:   CGFloat = 3

    // MARK: - Init

    public init(
        totalSteps: Int,
        currentStep: Int,
        accentColor: Color = ColorTokens.Session.progressBar
    ) {
        self.totalSteps = max(1, totalSteps)
        self.currentStep = max(1, min(currentStep, totalSteps))
        self.accentColor = accentColor
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(1...totalSteps, id: \.self) { step in
                stepDot(for: step)

                if step < totalSteps {
                    connectorLine(upTo: step)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: activeDotSize)
        .onAppear { startPulse() }
        .onChange(of: currentStep) { _, _ in startPulse() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "Шаг \(currentStep) из \(totalSteps)")
        )
        .accessibilityValue(
            String(localized: "\(Int(Double(currentStep - 1) / Double(max(1, totalSteps - 1)) * 100)) процентов")
        )
    }

    // MARK: - Step Dot

    @ViewBuilder
    private func stepDot(for step: Int) -> some View {
        let state = dotState(for: step)

        ZStack {
            // Outer pulse ring — only for current step
            if state == .current {
                Circle()
                    .strokeBorder(accentColor.opacity(0.35), lineWidth: ringWidth)
                    .frame(width: activeDotSize + 6, height: activeDotSize + 6)
                    .scaleEffect(pulseScale)
            }

            // Dot fill
            Circle()
                .fill(dotFillColor(for: state))
                .frame(width: state == .current ? activeDotSize : dotSize,
                       height: state == .current ? activeDotSize : dotSize)

            // Checkmark for completed
            if state == .completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: activeDotSize + 6, height: activeDotSize + 6)
        .animation(reduceMotion ? nil : MotionTokens.spring, value: state)
    }

    // MARK: - Connector Line

    private func connectorLine(upTo step: Int) -> some View {
        let filled = step < currentStep
        return RoundedRectangle(cornerRadius: lineHeight / 2, style: .continuous)
            .fill(filled ? accentColor : ColorTokens.Session.progressBackground)
            .frame(height: lineHeight)
    }

    // MARK: - Helpers

    private enum DotState: Equatable {
        case completed, current, future
    }

    private func dotState(for step: Int) -> DotState {
        if step < currentStep  { return .completed }
        if step == currentStep { return .current }
        return .future
    }

    private func dotFillColor(for state: DotState) -> Color {
        switch state {
        case .completed: return accentColor
        case .current:   return accentColor
        case .future:    return ColorTokens.Session.progressBackground
        }
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        pulseScale = 1.0
        withAnimation(
            .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.22
        }
    }
}

// MARK: - Preview

#Preview("HSProgressStepBar") {
    VStack(spacing: SpacingTokens.sp8) {
        Text("Шаг 1 из 5").font(TypographyTokens.caption())
        HSProgressStepBar(totalSteps: 5, currentStep: 1, accentColor: ColorTokens.Brand.primary)
            .padding(.horizontal)

        Text("Шаг 3 из 5").font(TypographyTokens.caption())
        HSProgressStepBar(totalSteps: 5, currentStep: 3, accentColor: ColorTokens.Brand.mint)
            .padding(.horizontal)

        Text("Шаг 5 из 5").font(TypographyTokens.caption())
        HSProgressStepBar(totalSteps: 5, currentStep: 5, accentColor: ColorTokens.Brand.gold)
            .padding(.horizontal)
    }
    .padding(SpacingTokens.sp6)
    .background(ColorTokens.Kid.bg)
}
