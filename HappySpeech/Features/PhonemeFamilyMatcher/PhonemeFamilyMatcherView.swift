import SwiftUI

// MARK: - PhonemeFamilyMatcherView

struct PhonemeFamilyMatcherView: View {

    let childId: String

    @State private var interactor: PhonemeFamilyMatcherInteractor?
    @State private var selectedFamily: PhonemeFamilyMatcherModels.Family = .whistling
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidCool mesh палитра (phonemic).
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "phonemeFamily.nav.title")))
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
                    interactor = PhonemeFamilyMatcherInteractor(childId: childId)
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
                    hero(state: interactor.state)
                    familyPicker
                    wordsGrid(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: PhonemeFamilyMatcherModels.ViewState) -> some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "phonemeFamily.hero.title"))
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "phonemeFamily.hero.subtitle"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Text("Правильно: \(state.matchedCount) из \(state.words.count)")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.top, 4)
            }
        }
    }

    private var familyPicker: some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(PhonemeFamilyMatcherModels.Family.allCases) { family in
                Button {
                    hapticService.impact(.light)
                    selectedFamily = family
                } label: {
                    Text(family.title)
                        .font(TypographyTokens.caption(11))
                        .foregroundStyle(selectedFamily == family ? .white : ColorTokens.Kid.ink)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selectedFamily == family
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.surface
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedFamily == family ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func wordsGrid(interactor: PhonemeFamilyMatcherInteractor) -> some View {
        LazyVGrid(columns: columns, spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.words) { word in
                wordChip(word) {
                    hapticService.impact(.light)
                    interactor.assign(word.id, to: selectedFamily)
                    if word.family == selectedFamily {
                        hapticService.notification(.success)
                    }
                }
                // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                .scrollTransition(.animated.threshold(.visible(0.3))) { content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                }
                // Step 10 Batch G — Pattern 4: parallax drift на word chips.
                .hsParallaxTile(factor: 0.2)
            }
        }
    }

    private func wordChip(
        _ word: PhonemeFamilyMatcherModels.Word,
        action: @escaping () -> Void
    ) -> some View {
        let isCorrect = word.assignedFamily == word.family
        let isAssigned = word.assignedFamily != nil
        return Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Text(word.text)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isAssigned
                                    ? (isCorrect
                                        ? ColorTokens.Semantic.successBg
                                        : ColorTokens.Kid.surfaceAlt)
                                    : ColorTokens.Kid.surface
                            )
                    )
                if isAssigned && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Semantic.success)
                        // Step 10 Batch G — Pattern 5: bounce on correct assignment.
                        .hsSymbolEffect(.bounce, value: isCorrect)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Слово \(word.text)"))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(interactor: PhonemeFamilyMatcherInteractor) -> some View {
        HSButton(
            String(localized: "phonemeFamily.cta.action"),
            style: .primary,
            size: .large,
            icon: "arrow.counterclockwise"
        ) {
            hapticService.impact(.light)
            interactor.reset()
        }
    }
}

// MARK: - Preview

#Preview("PhonemeFamilyMatcher — Light") {
    PhonemeFamilyMatcherView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PhonemeFamilyMatcher — Dark") {
    PhonemeFamilyMatcherView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
