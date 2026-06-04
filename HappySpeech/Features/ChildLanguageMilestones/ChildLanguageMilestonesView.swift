import SwiftUI

// MARK: - ChildLanguageMilestonesView

struct ChildLanguageMilestonesView: View {

    @State private var interactor = ChildLanguageMilestonesInteractor()
    @State private var didBindChild = false
    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "languageMilestones.nav.title")))
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
        .onAppear {
            // Привязываем интерактор к реальному ребёнку, чтобы отметки
            // персистились per-child. Один раз за жизненный цикл view.
            guard !didBindChild else { return }
            didBindChild = true
            if !container.currentChildId.isEmpty {
                interactor = ChildLanguageMilestonesInteractor(childId: container.currentChildId)
            }
        }
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
        HSLiquidGlassCard(style: .elevated) {
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
            ForEach(Array(ChildLanguageMilestonesModels.Section.allCases.enumerated()), id: \.element.id) { index, section in
                sectionCard(section)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .hsParallaxTile(factor: 0.25)
                    .zIndex(Double(ChildLanguageMilestonesModels.Section.allCases.count - index))
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
                    .hsSymbolEffect(.bounce, value: item.isAchieved)
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
            exitToParentHome()
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
