import SwiftUI

// MARK: - ParentHomeV31WaveBCards
//
// v31 Волна B — извлечённые из ParentHomeView entry-карточки для новых
// функций Wave B (Parent voice notes / «Мамин голос»). Поддерживает
// требование SwiftLint к Type Body Length основного экрана.

struct ParentVoiceNoteEntryCard: View {

    let onTap: () -> Void

    var body: some View {
        HSCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                iconBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "voice.entry.title"))
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "voice.entry.subtitle"))
                        .font(TypographyTokens.body())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: SpacingTokens.sp1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .accessibilityHidden(true)
            }
            .padding(SpacingTokens.sp4)
        }
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "voice.entry.title") + ". " +
            String(localized: "voice.entry.subtitle")
        )
        .accessibilityAddTraits(.isButton)
        .environment(\.circuitContext, .parent)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.rose.opacity(0.14))
                .frame(width: 44, height: 44)
            Image(systemName: "waveform.and.mic")
                .font(TypographyTokens.subtitle(20))
                .foregroundStyle(ColorTokens.Brand.rose)
        }
        .accessibilityHidden(true)
    }
}
