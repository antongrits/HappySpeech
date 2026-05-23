import SwiftUI

// MARK: - LyalyaPersonalCoachView

struct LyalyaPersonalCoachView: View {

    let childId: String

    @State private var interactor: LyalyaPersonalCoachInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
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
                    interactor = LyalyaPersonalCoachInteractor(childId: childId)
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
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(interactor: LyalyaPersonalCoachInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.lilac.opacity(0.18))) {
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
                    Text("Раунд \(min(interactor.currentIndex + 1, interactor.rounds.count)) из \(interactor.rounds.count)")
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
                Text("Точно! Молодец!")
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .font(TypographyTokens.body(15))
            }
        case .tryAgain:
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .foregroundStyle(ColorTokens.Semantic.warning)
                Text("Попробуем ещё разок")
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
                Text("Готово! Правильных ответов: \(interactor.correctCount) из \(interactor.rounds.count)")
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
                String(localized: "coach.cta.start"),
                style: .secondary,
                size: .large,
                icon: "arrow.clockwise"
            ) {
                hapticService.notification(.success)
                dismiss()
            }
        } else if interactor.reaction != .none {
            HSButton(
                "Дальше",
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
