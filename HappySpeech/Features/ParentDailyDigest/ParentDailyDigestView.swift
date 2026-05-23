import SwiftUI

// MARK: - ParentDailyDigestView

struct ParentDailyDigestView: View {

    @State private var interactor = ParentDailyDigestInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "parentDigest.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Parent.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: SpacingTokens.sp4) {
                hero
                kpiGrid(state: interactor.state)
                momentCard(state: interactor.state)
                tipCard(state: interactor.state)
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var hero: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "parentDigest.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "parentDigest.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func kpiGrid(state: ParentDailyDigestModels.ViewState) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(state.kpis) { kpi in
                kpiTile(kpi)
            }
        }
    }

    private func kpiTile(_ kpi: ParentDailyDigestModels.KPI) -> some View {
        HSCard(style: .flat) {
            VStack(spacing: 6) {
                Image(systemName: kpi.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                Text(kpi.value)
                    .font(TypographyTokens.title(18))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(kpi.label)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(kpi.label): \(kpi.value)"))
    }

    private func momentCard(state: ParentDailyDigestModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Parent.accent.opacity(0.10))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Text(state.photoMomentEmoji)
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Момент дня")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Text(state.photoMomentCaption)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
        }
    }

    private func tipCard(state: ParentDailyDigestModels.ViewState) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Text("Совет дня")
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.accent)
                }
                Text(state.tip.text)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.leading)
                Text("— \(state.tip.author)")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "parentDigest.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("ParentDailyDigest — Light") {
    ParentDailyDigestView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ParentDailyDigest — Dark") {
    ParentDailyDigestView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
