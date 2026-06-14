import SwiftUI

// MARK: - ParentMoodCheckInView

struct ParentMoodCheckInView: View {

    @State private var interactor = ParentMoodCheckInInteractor()
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)

    var body: some View {
        NavigationStack {
            ZStack {
                // Parent-контур: спокойный прохладный холст #F0EFF6 (light) /
                // #181820 (dark) из эталона. Статичный, без тёплого Kid-mesh —
                // как HomeTasks / SpeechHomeworkPlanner / FamilyCalendar.
                ColorTokens.Parent.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "parentMood.nav.title")))
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
                grid
                noteField
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
                Text(String(localized: "parentMood.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "parentMood.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(Array(ParentMoodCheckInModels.Mood.allCases.enumerated()), id: \.element) { index, mood in
                moodTile(mood)
                    .hsParallaxTile(factor: 0.3)
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                    }
                    .zIndex(Double(ParentMoodCheckInModels.Mood.allCases.count - index))
            }
        }
    }

    private func moodTile(_ mood: ParentMoodCheckInModels.Mood) -> some View {
        let selected = interactor.entry.mood == mood
        return Button {
            hapticService.impact(.light)
            interactor.entry.mood = mood
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji).font(.system(size: 40))
                Text(mood.label)
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Parent.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selected
                          ? ColorTokens.Parent.accent.opacity(0.15)
                          : ColorTokens.Parent.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected
                            ? ColorTokens.Parent.accent
                            : ColorTokens.Parent.line,
                            lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mood.label))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var noteField: some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text(String(localized: "parentMood.note.label"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                TextField(String(localized: "parentMood.note.placeholder"), text: Binding(
                    get: { interactor.entry.note },
                    set: { interactor.entry.note = $0 }
                ), axis: .vertical)
                    .lineLimit(2...5)
                    .padding(SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTokens.Parent.bg)
                    )
            }
        }
    }

    private var cta: some View {
        HSButton(
            String(localized: "parentMood.cta.save"),
            style: .primary,
            size: .large,
            icon: "heart.fill"
        ) {
            hapticService.notification(.success)
            interactor.save()
            exitToParentHome()
        }
        .disabled(interactor.entry.mood == nil)
        .opacity(interactor.entry.mood == nil ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview("ParentMoodCheckIn — Light") {
    ParentMoodCheckInView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("ParentMoodCheckIn — Dark") {
    ParentMoodCheckInView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
