import SwiftUI

// MARK: - StoryRetellingProView

struct StoryRetellingProView: View {

    let childId: String

    @State private var interactor: StoryRetellingProInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidCool палитра для
                // фокус-режима «пересказ» (прохладный воздух, мыслительный).
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidCool, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "storyRetelling.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = StoryRetellingProInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    list(interactor: interactor)
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        // Step 10 Batch E — Pattern 2: hero на HSLiquidGlassCard(.elevated).
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "storyRetelling.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "storyRetelling.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func list(interactor: StoryRetellingProInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.stories) { story in
                row(story: story, isSelected: story.id == interactor.state.selectedStoryId) {
                    hapticService.impact(.light)
                    interactor.select(story.id)
                }
                // Step 10 Batch E — Pattern 3: scrollTransition stagger
                // fade+scale на story rows.
                .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
                // Step 10 Batch E — Pattern 4: parallax drift на story tiles.
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func row(
        story: StoryRetellingProModels.Story,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: isSelected ? .tinted(ColorTokens.Brand.mint.opacity(0.20)) : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: story.isCompleted ? "checkmark.seal.fill" : "book.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            story.isCompleted ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft
                        )
                        // Step 10 Batch E — Pattern 5: checkmark bounce при
                        // переключении completed.
                        .hsSymbolEffect(.bounce, value: story.isCompleted)
                        .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.title)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                        Text(story.summary)
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(story.keyFactsCount) фактов")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                        Text("\(story.durationSeconds / 60):\(String(format: "%02d", story.durationSeconds % 60))")
                            .font(TypographyTokens.caption(11))
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(story.title), \(story.keyFactsCount) ключевых фактов"))
        .accessibilityAddTraits(.isButton)
    }

    private var cta: some View {
        HSButton(
            String(localized: "storyRetelling.cta.action"),
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            hapticService.notification(.success)
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("StoryRetellingPro — Light") {
    StoryRetellingProView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("StoryRetellingPro — Dark") {
    StoryRetellingProView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
