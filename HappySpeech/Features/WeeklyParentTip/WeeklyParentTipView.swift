import SwiftUI

// MARK: - WeeklyParentTipView

struct WeeklyParentTipView: View {

    @State private var interactor = WeeklyParentTipInteractor()
    @State private var isShareSheetPresented: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "weeklyTip.nav.title")))
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
                bodyCard
                bulletsCard
                authorCard
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(interactor.state.tip.weekLabel)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                Text(String(localized: "weeklyTip.hero.title"))
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "weeklyTip.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text(interactor.state.tip.title)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .padding(.top, 8)
            }
        }
    }

    private var bodyCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                ForEach(Array(interactor.state.tip.bodyParagraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var bulletsCard: some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("3 простых упражнения на эту неделю")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .padding(.bottom, 2)
                ForEach(Array(interactor.state.tip.bulletPoints.enumerated()), id: \.offset) { idx, bullet in
                    HStack(alignment: .top, spacing: SpacingTokens.sp2) {
                        Text("\(idx + 1).")
                            .font(TypographyTokens.body(14).weight(.semibold))
                            .foregroundStyle(ColorTokens.Parent.accent)
                            .frame(width: 22, alignment: .leading)
                        Text(bullet)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Parent.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                }
            }
        }
    }

    private var authorCard: some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Parent.accent)
                    .hsSymbolEffect(.pulse, value: interactor.state.tip.authorName)
                VStack(alignment: .leading, spacing: 2) {
                    Text(interactor.state.tip.authorName)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Text(interactor.state.tip.authorRole)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                Spacer()
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "weeklyTip.cta.action"),
            style: .primary,
            size: .large,
            icon: "square.and.arrow.up"
        ) {
            hapticService.notification(.success)
            interactor.recordShare()
            isShareSheetPresented = true
        }
        .sheet(isPresented: $isShareSheetPresented) {
            WeeklyParentTipShareSheet(items: [interactor.shareText])
                .ignoresSafeArea()
        }
    }
}

// MARK: - Share sheet

/// Системный share-лист (`UIActivityViewController`) для совета недели.
/// SwiftUI `ShareLink` не покрывает кейс «поделиться по нажатию HSButton»,
/// поэтому используем тонкую UIKit-обёртку (как в `WeeklyRecapView`).
private struct WeeklyParentTipShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview("WeeklyParentTip — Light") {
    WeeklyParentTipView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("WeeklyParentTip — Dark") {
    WeeklyParentTipView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
