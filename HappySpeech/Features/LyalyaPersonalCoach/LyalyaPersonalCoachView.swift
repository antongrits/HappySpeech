import SwiftUI

// MARK: - LyalyaPersonalCoachView

struct LyalyaPersonalCoachView: View {

    let childId: String

    @State private var interactor: LyalyaPersonalCoachInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "coach.nav.title")))
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
                    let coach = LyalyaPersonalCoachInteractor(
                        childId: childId,
                        worker: LyalyaPersonalCoachWorker(childRepository: container.childRepository),
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = coach
                    await coach.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if !interactor.isLoaded {
                ProgressView().controlSize(.large)
            } else if interactor.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero(interactor: interactor)
                        if let round = interactor.current {
                            questionCard(round, interactor: interactor)
                            optionsGrid(round: round, interactor: interactor)
                            reactionView(interactor: interactor)
                        } else {
                            summary(interactor: interactor)
                        }
                        cta(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(String(localized: "coach.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.screenEdge)
    }

    private func hero(interactor: LyalyaPersonalCoachInteractor) -> some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .explaining, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "coach.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "coach.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text(String(
                        format: String(localized: "coach.round %lld %lld"),
                        min(interactor.currentIndex + 1, interactor.rounds.count),
                        interactor.rounds.count
                    ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func questionCard(
        _ round: LyalyaPersonalCoachModels.Round,
        interactor: LyalyaPersonalCoachInteractor
    ) -> some View {
        HSCard(style: .elevated) {
            Text(round.question)
                .font(TypographyTokens.title(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp2)
        }
    }

    private func optionsGrid(
        round: LyalyaPersonalCoachModels.Round,
        interactor: LyalyaPersonalCoachInteractor
    ) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.sp2), count: 2)
        return LazyVGrid(columns: cols, spacing: SpacingTokens.sp2) {
            ForEach(Array(round.options.enumerated()), id: \.offset) { idx, opt in
                Button {
                    hapticService.impact(.light)
                    interactor.answer(idx)
                } label: {
                    Text(opt)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ColorTokens.Kid.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(ColorTokens.Kid.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(interactor.reaction != .none)
                .accessibilityLabel(Text(opt))
                .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0)
                        .scaleEffect(phase.isIdentity ? 1 : 0.92)
                }
                .hsParallaxTile(factor: 0.20)
                .zIndex(Double(round.options.count - idx))
            }
        }
    }

    @ViewBuilder
    private func reactionView(interactor: LyalyaPersonalCoachInteractor) -> some View {
        switch interactor.reaction {
        case .correct:
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.success)
                    .hsSymbolEffect(.bounce, value: interactor.correctCount)
                Text(String(localized: "coach.reaction.correct"))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .font(TypographyTokens.body(15))
            }
        case .tryAgain:
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .hsSymbolEffect(.pulse, value: interactor.currentIndex)
                Text(String(localized: "coach.reaction.tryAgain"))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .font(TypographyTokens.body(15))
            }
        case .none:
            EmptyView()
        }
    }

    private func summary(interactor: LyalyaPersonalCoachInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            VStack(spacing: SpacingTokens.sp2) {
                LyalyaMascotView(state: .celebrating, size: 80)
                    .accessibilityHidden(true)
                Text(String(
                    format: String(localized: "coach.summary %lld %lld"),
                    interactor.correctCount, interactor.rounds.count
                ))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
        }
    }

    @ViewBuilder
    private func cta(interactor: LyalyaPersonalCoachInteractor) -> some View {
        if interactor.isFinished {
            HSButton(
                String(localized: "coach.cta.again"),
                style: .secondary,
                size: .large,
                icon: "arrow.clockwise"
            ) {
                hapticService.notification(.success)
                Task { await interactor.restart() }
            }
        } else if interactor.reaction != .none {
            HSButton(
                String(localized: "coach.cta.next"),
                style: .primary,
                size: .large,
                icon: "arrow.right"
            ) {
                hapticService.impact(.light)
                interactor.next()
            }
        }
    }
}

// MARK: - Preview

#Preview("LyalyaPersonalCoach — Light") {
    LyalyaPersonalCoachView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("LyalyaPersonalCoach — Dark") {
    LyalyaPersonalCoachView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}
