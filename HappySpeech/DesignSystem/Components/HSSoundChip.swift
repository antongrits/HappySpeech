import SwiftUI

// MARK: - HSSoundChip

/// Small pill showing a phoneme with optional selection state.
public struct HSSoundChip: View {
    let sound: String
    let isSelected: Bool
    let onTap: () -> Void

    public init(sound: String, isSelected: Bool = false, onTap: @escaping () -> Void = {}) {
        self.sound = sound
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(sound)
                .font(TypographyTokens.headline())
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(isSelected ? ColorTokens.Brand.primary : Color(.secondarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : Color(.systemFill),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Звук \(sound)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
