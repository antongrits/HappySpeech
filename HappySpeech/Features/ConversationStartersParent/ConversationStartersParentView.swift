import SwiftUI

// MARK: - ConversationStartersParentView

struct ConversationStartersParentView: View {

    @State private var interactor = ConversationStartersParentInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "conversationStarters.nav.title")))
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
                list
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
                Text(String(localized: "conversationStarters.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
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
            ForEach(interactor.state.questions) { question in
                row(question)
            }
        }
    }

    private func row(_ question: ConversationStartersParentModels.Question) -> some View {
        HSCard(style: question.isFavorite ? .tinted(ColorTokens.Parent.accent.opacity(0.10)) : .flat) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(TypographyTokens.body(15))
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
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(question.isFavorite ? "Убрать из избранного" : "В избранное"))
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
            dismiss()
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
