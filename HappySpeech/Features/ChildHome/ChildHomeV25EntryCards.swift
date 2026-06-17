import SwiftUI

// MARK: - ChildHomeV25EntryCard
//
// v25 6.2 — full-width карточка-вход для новых детских фич
// (F-302 ArticulationGym, F-303 WordBank).
//
// Вынесена из `ChildHomeView` отдельным компонентом, чтобы не раздувать
// body основного экрана (SwiftLint `type_body_length`).

struct ChildHomeV25EntryCard: View {

    /// Резолвленный заголовок (из ключа каталога или явной локализованной строки).
    private let title: Text
    private let hint: Text
    /// Текстовая метка для VoiceOver (явная строка либо ключ).
    private let accessibilityTitle: Text
    private let accessibilityHint: Text
    let iconName: String
    let accent: Color
    let action: () -> Void

    /// Ключевой инициализатор (строки берутся из String Catalog по ключу).
    init(titleKey: String, hintKey: String, iconName: String, accent: Color, action: @escaping () -> Void) {
        self.title = Text(LocalizedStringKey(titleKey))
        self.hint = Text(LocalizedStringKey(hintKey))
        self.accessibilityTitle = Text(LocalizedStringKey(titleKey))
        self.accessibilityHint = Text(LocalizedStringKey(hintKey))
        self.iconName = iconName
        self.accent = accent
        self.action = action
    }

    /// Явный инициализатор: заголовок/подсказка переданы готовыми
    /// локализованными строками (для фич без ключей в каталоге).
    init(title: String, hint: String, iconName: String, accent: Color, action: @escaping () -> Void) {
        self.title = Text(title)
        self.hint = Text(hint)
        self.accessibilityTitle = Text(title)
        self.accessibilityHint = Text(hint)
        self.iconName = iconName
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: iconName)
                    .font(TypographyTokens.headline(22))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(accent.opacity(0.9)))
                    .accessibilityHidden(true)

                title
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
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint(accessibilityHint)
    }
}
