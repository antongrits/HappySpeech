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
        Text(syllable.text)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(syllable.state.color)
            .padding(.horizontal, SpacingTokens.sp3)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(syllable.state.color.opacity(0.12))
            )
            .scaleEffect(isActive && !reduceMotion ? 1.12 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.65),
                value: isActive
            )
            .accessibilityHidden(true)
    }
}

// TODO defer to Block Q (test coverage): snapshot tests for all states.
