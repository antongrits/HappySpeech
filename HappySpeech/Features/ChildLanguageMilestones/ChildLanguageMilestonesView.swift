import SwiftUI

// MARK: - ChildLanguageMilestonesView

struct ChildLanguageMilestonesView: View {

    @State private var interactor = ChildLanguageMilestonesInteractor()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "languageMilestones.nav.title")))
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
                sectionsList
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
                Text(interactor.state.ageBand)
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Parent.accent)
                Text(String(localized: "languageMilestones.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "languageMilestones.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HSProgressBar(value: interactor.state.overallProgress, style: .parent, tint: ColorTokens.Parent.accent)
                    .frame(height: 6)
                    .padding(.top, 6)
            }
        }
    }

    private var sectionsList: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ForEach(ChildLanguageMilestonesModels.Section.allCases) { section in
                sectionCard(section)
            }
        }
    }

    private func sectionCard(_ section: ChildLanguageMilestonesModels.Section) -> some View {
        let items = interactor.state.items(in: section)
        let done = items.filter(\.isAchieved).count
        return HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: section.iconSystemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ColorTokens.Parent.accent)
                    Text(section.title)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Spacer()
                    Text("\(done)/\(items.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                ForEach(items) { item in
                    checkRow(item)
                }
            }
        }
    }

    private func checkRow(_ item: ChildLanguageMilestonesModels.Item) -> some View {
        Button {
            hapticService.impact(.light)
            interactor.toggle(item.id)
        } label: {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: item.isAchieved ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(
                        item.isAchieved ? ColorTokens.Semantic.success : ColorTokens.Parent.inkSoft
                    )
                Text(item.title)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.isAchieved ? "Достигнуто" : "Не достигнуто"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "languageMilestones.cta.action"),
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

#Preview("ChildLanguageMilestones — Light") {
    ChildLanguageMilestonesView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ChildLanguageMilestones — Dark") {
    ChildLanguageMilestonesView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
