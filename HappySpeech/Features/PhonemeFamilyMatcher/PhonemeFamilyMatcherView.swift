import SwiftUI

// MARK: - PhonemeFamilyMatcherView

struct PhonemeFamilyMatcherView: View {

    let childId: String

    @State private var interactor: PhonemeFamilyMatcherInteractor?
    @State private var selectedFamily: PhonemeFamilyMatcherModels.Family = .whistling
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    private let columns = [
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2),
        GridItem(.flexible(), spacing: SpacingTokens.sp2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationBarHidden(true)
            .task {
                if interactor == nil {
                    let game = PhonemeFamilyMatcherInteractor(
                        childId: childId,
                        worker: PhonemeFamilyMatcherWorker(),
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = game
                    await game.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if !interactor.state.isLoaded {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if interactor.state.isEmpty {
                emptyState
            } else {
                let state = interactor.state
                KidGameTapScaffold(
                    stepLabel: String(
                        format: String(localized: "phonemeFamily.progress %lld %lld"),
                        state.matchedCount, state.words.count
                    ),
                    progress: state.words.isEmpty ? nil
                        : Double(state.matchedCount) / Double(state.words.count),
                    promptText: String(localized: "phonemeFamily.hero.subtitle"),
                    mascotState: .pointing,
                    primary: KidGamePrimaryAction(
                        title: String(localized: "phonemeFamily.cta.action"),
                        icon: "arrow.counterclockwise"
                    ) {
                        hapticService.impact(.light)
                        interactor.reset()
                    },
                    onClose: { exitGame() }
                ) {
                    familyPicker
                    wordsGrid(interactor: interactor)
                }
            }
        } else {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(String(localized: "phonemeFamily.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(SpacingTokens.screenEdge)
    }

    private var familyPicker: some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(PhonemeFamilyMatcherModels.Family.allCases) { family in
                Button {
                    hapticService.impact(.light)
                    selectedFamily = family
                } label: {
                    Text(family.title)
                        .font(TypographyTokens.labelRounded(12, weight: .semibold))
                        .foregroundStyle(selectedFamily == family ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SpacingTokens.small)
                        .background(
                            Capsule().fill(
                                selectedFamily == family
                                    ? ColorTokens.Brand.primary
                                    : ColorTokens.Kid.surface
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    selectedFamily == family ? Color.clear : ColorTokens.Kid.line,
                                    lineWidth: 1
                                )
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
                    .font(TypographyTokens.kidCardTitle(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SpacingTokens.small)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(
                                isAssigned
                                    ? (isCorrect
                                        ? ColorTokens.Brand.mint.opacity(0.16)
                                        : ColorTokens.Kid.surfaceAlt)
                                    : ColorTokens.Kid.surface
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                    .strokeBorder(
                                        isAssigned && isCorrect
                                            ? ColorTokens.Semantic.success
                                            : ColorTokens.Kid.line,
                                        lineWidth: isAssigned && isCorrect ? 2 : 1
                                    )
                            )
                    )
                if isAssigned && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(ColorTokens.Semantic.success)
                        .hsSymbolEffect(.bounce, value: isCorrect)
                        .padding(SpacingTokens.micro)
                }
            }
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(format: String(localized: "phonemeFamily.word.a11y %@"), word.text)))
        .accessibilityAddTraits(.isButton)
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
