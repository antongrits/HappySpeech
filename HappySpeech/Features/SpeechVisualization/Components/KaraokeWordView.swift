import SwiftUI

// MARK: - KaraokeWordView
//
// Block S.3 v16 — UI компонент: строка слогов с анимацией подсветки.
// Каждый слог — pill с цветом в зависимости от state (idle/active/correct/...).
//
// Reduced Motion: убираем scale-анимацию, оставляем только цвет.

struct KaraokeWordView: View {

    let syllables: [SpeechVisualizationModels.Load.SyllableViewModel]
    let activeSyllableID: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SpacingTokens.sp1) {
            ForEach(syllables) { syllable in
                pill(syllable: syllable, isActive: syllable.id == activeSyllableID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(combinedAccessibilityLabel))
    }

    private var combinedAccessibilityLabel: String {
        syllables.map(\.accessibilityLabel).joined(separator: ", ")
    }

    @ViewBuilder
    private func pill(
        syllable: SpeechVisualizationModels.Load.SyllableViewModel,
        isActive: Bool
    ) -> some View {
        // Активный слог — сплошная тёплая butter-заливка с тёмным текстом
        // и подъёмом (эталон караоке-дорожки); неактивный — мягкая подложка.
        Text(syllable.text)
            .font(TypographyTokens.titleLarge(32))
            .foregroundStyle(isActive ? ColorTokens.Kid.ink : syllable.state.color)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isActive
                          ? ColorTokens.Brand.butter
                          : syllable.state.color.opacity(0.12))
                    .shadow(
                        color: isActive
                            ? ColorTokens.Brand.butter.opacity(0.45)
                            : .clear,
                        radius: isActive ? 10 : 0,
                        y: isActive ? 3 : 0
                    )
            )
            .scaleEffect(isActive && !reduceMotion ? 1.12 : 1.0)
            .offset(y: isActive && !reduceMotion ? -2 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.65),
                value: isActive
            )
            .accessibilityHidden(true)
    }
}

// NOTE deferred to Block Q (test coverage): snapshot tests for all states.
