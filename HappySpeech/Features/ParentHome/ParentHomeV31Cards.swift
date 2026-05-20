import SwiftUI

// MARK: - ParentHomeV31Cards
//
// v31 Волна A — извлечённые из ParentHomeView entry-карточки для функций v31,
// чтобы не превышать порог Type Body Length (SwiftLint 800 строк) в основном
// view. Каждая карточка — самостоятельный View-компонент.

struct DailyRitualsLyalyaEntryCard: View {

    let onTap: (RitualKind) -> Void

    var body: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                header
                tilesRow
            }
            .padding(SpacingTokens.sp4)
        }
        .accessibilityElement(children: .contain)
        .environment(\.circuitContext, .parent)
    }

    private var header: some View {
        HStack(spacing: SpacingTokens.sp3) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "dailyRituals.entry.title"))
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "dailyRituals.entry.subtitle"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: SpacingTokens.sp1)
        }
    }

    private var iconBadge: some View {
        Image(systemName: "clock.badge.checkmark.fill")
            .font(.title3)
            .foregroundStyle(ColorTokens.Brand.mint)
            .frame(width: 40, height: 40)
            .background(Circle().fill(ColorTokens.Brand.mint.opacity(0.15)))
            .accessibilityHidden(true)
    }

    private var tilesRow: some View {
        HStack(spacing: SpacingTokens.sp2) {
            tile(
                kind: .morning,
                labelKey: "dailyRituals.kind.morning",
                symbol: "sun.max.fill",
                tint: ColorTokens.Brand.butter
            )
            tile(
                kind: .evening,
                labelKey: "dailyRituals.kind.evening",
                symbol: "moon.stars.fill",
                tint: ColorTokens.Brand.lilac
            )
        }
    }

    private func tile(
        kind: RitualKind,
        labelKey: String.LocalizationValue,
        symbol: String,
        tint: Color
    ) -> some View {
        Button {
            onTap(kind)
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(String(localized: labelKey))
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm)
                    .fill(tint.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: labelKey)))
        .accessibilityAddTraits(.isButton)
    }
}
