import SwiftUI

// MARK: - ConversationStartersParentView

struct ConversationStartersParentView: View {

    @State private var interactor = ConversationStartersParentInteractor()
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "conversationStarters.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitToParentHome()
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
                list
                cta
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "conversationStarters.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "conversationStarters.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.state.questions.enumerated()), id: \.element.id) { index, question in
                row(question)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .zIndex(Double(interactor.state.questions.count - index))
            }
        }
    }

    private func row(_ question: ConversationStartersParentModels.Question) -> some View {
        HSCard(style: question.isFavorite ? .tinted(ColorTokens.Parent.accent.opacity(0.10)) : .flat) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                            .fill(ColorTokens.Brand.lilac.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(question.text)
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    Text(question.category.title)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(ColorTokens.Parent.bgDeep)
                        )
                }
                Spacer()
                Button {
                    hapticService.impact(.light)
                    interactor.toggleFavorite(question.id)
                } label: {
                    Image(systemName: question.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            question.isFavorite ? ColorTokens.Brand.primary : ColorTokens.Parent.inkSoft
                        )
                        .hsSymbolEffect(.bounce, value: question.isFavorite)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(question.isFavorite
                    ? String(localized: "conversationStarters.a11y.unfavorite")
                    : String(localized: "conversationStarters.a11y.favorite")))
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "conversationStarters.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            exitToParentHome()
        }
    }
}

// MARK: - Preview

#Preview("ConversationStartersParent — Light") {
    ConversationStartersParentView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ConversationStartersParent — Dark") {
    ConversationStartersParentView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
