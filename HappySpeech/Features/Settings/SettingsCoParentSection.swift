import SwiftUI

// MARK: - FamilyInviteEntryAction

/// Какую поверхность открыть после прохождения ParentalGate.
enum FamilyInviteEntryAction: String, Identifiable {
    case create
    case redeem

    var id: String { rawValue }
}

// MARK: - SettingsView Co-Parent Section
//
// Точка входа со-родительства (FamilyInvite) в родительском контуре Settings.
// Две CTA: «Пригласить близкого» (создание кода) и «У меня есть код» (принятие).
// Каждая открывается через ParentalGate (см. SettingsView sheets).

extension SettingsView {

    var coParentSection: some View {
        Section {
            coParentRow(
                title: String(localized: "settings.coParent.invite"),
                subtitle: String(localized: "settings.coParent.invite.subtitle"),
                icon: "person.crop.circle.badge.plus",
                tint: ColorTokens.Brand.primary,
                hint: String(localized: "settings.coParent.invite.hint")
            ) {
                pendingFamilyInviteAction = .create
            }

            coParentRow(
                title: String(localized: "settings.coParent.haveCode"),
                subtitle: String(localized: "settings.coParent.haveCode.subtitle"),
                icon: "qrcode.viewfinder",
                tint: ColorTokens.Brand.lilac,
                hint: String(localized: "settings.coParent.haveCode.hint")
            ) {
                pendingFamilyInviteAction = .redeem
            }
        } header: {
            Text(String(localized: "settings.section.coParent"))
                .font(TypographyTokens.caption(12).weight(.semibold))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .textCase(.uppercase)
        } footer: {
            Text(String(localized: "settings.coParent.footer"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func coParentRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SpacingTokens.sp3) {
                coParentIcon(icon, tint: tint)
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(title)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(TypographyTokens.caption(13))
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
    }

    private func coParentIcon(_ systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.xs, style: .continuous)
                .fill(tint.opacity(0.15))
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}
