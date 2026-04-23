import SwiftUI
import OSLog

// MARK: - ScreeningView
//
// Full-screen prompt-by-prompt screening flow. Each prompt renders a card
// with an illustration, stimulus text ("рыба"), a play-reference button, and
// a 0–3 scoring row the child taps for self-rating. The interactor converts
// the tap to a 0.0/0.33/0.67/1.0 score and moves to the next prompt.
//
// UX choices:
//   • One prompt visible at a time (no scrollable list) — reduces cognitive load.
//   • Mandatory progress bar (n/20) + block title banner.
//   • Block transitions show a short "well done" breather screen.
//   • Final summary reuses `HSPictTile`/`HSBadge` style from DesignSystem.

struct ScreeningView: View {

    let childId: String
    let childAge: Int
    let onFinish: (ScreeningOutcome) -> Void
    let onCancel: () -> Void

    @State private var interactor: ScreeningInteractor?
    @State private var presenter: ScreeningPresenter?
    @State private var router: ScreeningRouter?
    @State private var state = ScreeningViewState()

    @Environment(AppContainer.self) private var container

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.large) {
                header
                if state.isFinished, let outcome = state.outcome {
                    SummaryView(vm: outcome, onDone: { onFinish(outcome.outcome) })
                } else if state.showBlockTransition, let blockTitle = state.blockTitle {
                    BlockTransitionView(title: blockTitle) {
                        state.showBlockTransition = false
                    }
                } else if let prompt = state.currentPrompt {
                    PromptCard(
                        prompt: prompt,
                        onScore: { score in submit(score: score) },
                        onPlay: { container.soundService.playUISound(.tap) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    ProgressView().progressViewStyle(.circular)
                }
                Spacer(minLength: 0)
            }
            .padding(SpacingTokens.screenEdge)
        }
        .task { await bootstrap() }
        .environment(\.circuitContext, .parent)   // screening is a parent-supervised flow
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            Spacer()
            if let progress = state.progressText {
                Text(progress)
                    .font(TypographyTokens.caption(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    // MARK: - Wiring

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = ScreeningPresenter()
        let interactorInstance = ScreeningInteractor()
        let routerInstance = ScreeningRouter()

        interactorInstance.presenter = presenterInstance
        presenterInstance.display = ScreeningDisplayBridge(state: state) { self.state = $0 }
        routerInstance.onComplete = { outcome in onFinish(outcome) }
        routerInstance.onCancel = onCancel

        self.interactor = interactorInstance
        self.presenter = presenterInstance
        self.router = routerInstance

        await interactorInstance.startScreening(.init(childId: childId, childAge: childAge))
    }

    private func submit(score: Float) {
        guard let prompt = state.currentPrompt else { return }
        container.hapticService.selection()
        Task {
            await interactor?.submitAnswer(.init(
                promptId: prompt.id, score: score, attemptCount: 1
            ))
            if state.isLastPrompt {
                await interactor?.finishScreening(.init(childId: childId))
            }
        }
    }
}

// MARK: - ScreeningViewState

struct ScreeningViewState: Equatable {
    var prompts: [ScreeningPrompt] = []
    var currentIndex: Int = 0
    var progressText: String?
    var blockTitle: String?
    var showBlockTransition: Bool = false
    var isFinished: Bool = false
    var outcome: ScreeningSummaryViewModel?

    var currentPrompt: ScreeningPrompt? {
        guard prompts.indices.contains(currentIndex) else { return nil }
        return prompts[currentIndex]
    }

    var isLastPrompt: Bool {
        !prompts.isEmpty && currentIndex == prompts.count - 1
    }
}

struct ScreeningSummaryViewModel: Equatable {
    let outcome: ScreeningOutcome
    let rows: [SoundVerdictViewModel]
    let recommendedSessionMinutes: Int
    let summaryText: String
}

// MARK: - Display bridge

@MainActor
private final class ScreeningDisplayBridge: ScreeningDisplayLogic {
    private var state: ScreeningViewState
    private let commit: (ScreeningViewState) -> Void

    init(state: ScreeningViewState, commit: @escaping (ScreeningViewState) -> Void) {
        self.state = state
        self.commit = commit
    }

    func displayStartScreening(_ vm: ScreeningModels.StartScreening.ViewModel) {
        state.prompts = vm.prompts
        state.currentIndex = 0
        state.progressText = "1 / \(vm.prompts.count)"
        state.blockTitle = vm.prompts.first?.block.title
        commit(state)
    }

    func displaySubmitAnswer(_ vm: ScreeningModels.SubmitAnswer.ViewModel) {
        if let next = vm.nextPromptIndex {
            state.currentIndex = next
            state.progressText = "\(next + 1) / \(state.prompts.count)"
            if vm.shouldShowBlockTransition {
                state.blockTitle = state.prompts[next].block.title
                state.showBlockTransition = true
            }
        }
        commit(state)
    }

    func displayFinishScreening(_ vm: ScreeningModels.FinishScreening.ViewModel) {
        // Re-hydrate outcome from the interactor-passed ViewModel — we lack the
        // full `ScreeningOutcome` here, so reconstruct a minimal container. In
        // real flow we'd use the Response outcome directly; bridge is a UI
        // projection only.
        state.isFinished = true
        commit(state)
    }
}

// MARK: - PromptCard

private struct PromptCard: View {
    let prompt: ScreeningPrompt
    let onScore: (Float) -> Void
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(prompt.stimulus)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            HSButton(String(localized: "screening.prompt.listen"), style: .secondary, action: onPlay)
                .frame(maxWidth: 260)

            HStack(spacing: SpacingTokens.small) {
                scoreButton(0.0, label: String(localized: "screening.score.wrong"),   color: .red)
                scoreButton(0.33, label: String(localized: "screening.score.partial"), color: .orange)
                scoreButton(0.67, label: String(localized: "screening.score.good"),    color: .yellow)
                scoreButton(1.0, label: String(localized: "screening.score.perfect"), color: .green)
            }
        }
        .padding(SpacingTokens.large)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }

    private func scoreButton(_ score: Float, label: String, color: Color) -> some View {
        Button(action: { onScore(score) }) {
            VStack(spacing: SpacingTokens.tiny) {
                Circle().fill(color.opacity(0.3)).frame(width: 44, height: 44)
                Text(label).font(TypographyTokens.caption(11))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Block transition + Summary

private struct BlockTransitionView: View {
    let title: String
    let onContinue: () -> Void
    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text("🎉")
                .font(.system(size: 56))
            Text(String(localized: "screening.block.next"))
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(title)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            HSButton(String(localized: "screening.continue"), style: .primary, action: onContinue)
                .frame(maxWidth: 240)
        }
    }
}

private struct SummaryView: View {
    let vm: ScreeningSummaryViewModel
    let onDone: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            Text(String(localized: "screening.summary.title"))
                .font(TypographyTokens.title())
            Text(vm.summaryText)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            HSProgressBar(value: 1.0)
            HSButton(String(localized: "screening.summary.done"), style: .primary, action: onDone)
                .frame(maxWidth: .infinity)
        }
        .padding(SpacingTokens.large)
    }
}
