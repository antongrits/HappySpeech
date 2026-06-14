import SwiftUI

// MARK: - SpeechHomeworkPlannerView

struct SpeechHomeworkPlannerView: View {

    @State private var interactor = SpeechHomeworkPlannerInteractor()
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                // Parent-контур: спокойный однотонный холст #F0EFF6 (light) /
                // #181820 (dark). Без кремового mesh-оверлея — статичный фон.
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "homeworkPlanner.nav.title")))
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
            VStack(spacing: SpacingTokens.sp3) {
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
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(String(localized: "homeworkPlanner.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(String(localized: "homeworkPlanner.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                HStack(spacing: SpacingTokens.sp2) {
                    HSProgressBar(value: interactor.progress, style: .parent)
                        .frame(height: 6)
                    Text("\(interactor.doneCount) / \(interactor.items.count)")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .monospacedDigit()
                }
                .padding(.top, 2)
            }
        }
    }

    private var list: some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(interactor.items.enumerated()), id: \.element.id) { index, item in
                row(item)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96)
                    }
                    .hsParallaxTile(factor: 0.15)
                    .zIndex(Double(interactor.items.count - index))
            }
        }
    }

    private func row(_ item: SpeechHomeworkPlannerModels.Item) -> some View {
        Button {
            hapticService.impact(.light)
            interactor.toggle(item.id)
        } label: {
            // Done-состояние карточки — тёплая коралловая подложка (не зелёный
            // Semantic.successBg: зелёная заливка off-palette на крупной карточке).
            // Само «галочка» остаётся мелким семантическим success-акцентом.
            HSCard(style: item.isDone ? .tinted(ColorTokens.Brand.primaryLo.opacity(0.45)) : .flat) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(item.dayOfWeek)
                        .font(TypographyTokens.caption(12).weight(.bold))
                        .foregroundStyle(ColorTokens.Parent.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(ColorTokens.Parent.accent.opacity(0.12))
                        )
                    Text(item.title)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(item.isDone
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Parent.inkSoft)
                        .hsSymbolEffect(.bounce, value: item.isDone)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.dayOfWeek). \(item.title)"))
        .accessibilityValue(Text(item.isDone
            ? String(localized: "homeworkPlanner.a11y.done")
            : String(localized: "homeworkPlanner.a11y.notDone")))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "homeworkPlanner.cta.confirm"),
            style: .primary,
            size: .large,
            icon: "checkmark.circle.fill"
        ) {
            hapticService.notification(.success)
            exitToParentHome()
        }
    }
}

// MARK: - Preview

#Preview("HomeworkPlanner — Light") {
    SpeechHomeworkPlannerView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("HomeworkPlanner — Dark") {
    SpeechHomeworkPlannerView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
