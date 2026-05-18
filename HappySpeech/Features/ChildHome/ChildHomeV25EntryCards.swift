import SwiftUI

// MARK: - ChildHomeV25EntryCard
//
// v25 6.2 — full-width карточка-вход для новых детских фич
// (F-302 ArticulationGym, F-303 WordBank).
//
// Вынесена из `ChildHomeView` отдельным компонентом, чтобы не раздувать
// body основного экрана (SwiftLint `type_body_length`).

struct ChildHomeV25EntryCard: View {

    let titleKey: String
    let hintKey: String
    let iconName: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: iconName)
                    .font(TypographyTokens.headline(22))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(0.9)))
                    .accessibilityHidden(true)

                Text(LocalizedStringKey(titleKey))
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, SpacingTokens.sp4)
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .tapFeedback()
        .accessibilityLabel(Text(LocalizedStringKey(titleKey)))
        .accessibilityHint(Text(LocalizedStringKey(hintKey)))
    }
}
