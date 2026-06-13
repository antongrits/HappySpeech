import SwiftUI

// MARK: - HSPrivacyPill
//
// Маленькая «успокаивающая» плашка для голосовых экранов родителя:
// «Приватно · на устройстве». Соответствует эталону parent-voice
// (lockpill в правом верхнем углу): иконка замка + текст на surface-капсуле.
//
// Семантически зелёная success-иконка замка — допустимый МЕЛКИЙ акцент
// (символ «защищено»), фон капсулы — нейтральный Parent.surface.

/// Компактная плашка-капсула «Приватно · на устройстве» для приватных
/// голосовых фич родителя.
public struct HSPrivacyPill: View {

    private let text: String

    public init(text: String? = nil) {
        self.text = text ?? String(localized: "voice.privacy.onDevice")
    }

    public var body: some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ColorTokens.Semantic.success)
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule()
                .fill(ColorTokens.Parent.surface)
                .overlay(
                    Capsule()
                        .strokeBorder(ColorTokens.Parent.line, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("HSPrivacyPill") {
    VStack(spacing: 20) {
        HSPrivacyPill()
        HSPrivacyPill()
            .environment(\.colorScheme, .dark)
    }
    .padding()
    .background(ColorTokens.Parent.bg)
}
#endif
