import SwiftUI
import OSLog

// MARK: - ListenAndChooseView

/// Production "Listen and Choose" game.
///
/// Contract with `SessionShell`: the parent provides a `SessionActivity` and an
/// `onComplete` closure that receives the final score [0.0 – 1.0]. The game
/// auto-loads a round on appear, handles up to 3 attempts per round, and then
/// calls `onComplete` once the round is finished.
struct ListenAndChooseView: View {

    // MARK: Input

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    // MARK: VIP

    @State private var interactor: (any ListenAndChooseBusinessLogic)?
    @State private var presenter: ListenAndChoosePresenter?
    @State private var router: ListenAndChooseRouter?
    @Environment(AppContainer.self) private var container

    // MARK: State

    @State private var vm: ListenAndChooseModels.LoadRound.ViewModel?
    @State private var attemptsUsed: Int = 0
    @State private var selectedIndex: Int?
    @State private var feedbackText: String?
    @State private var feedbackIsCorrect: Bool?
    @State private var revealAnswer: Bool = false
    @State private var isPlayingSample: Bool = false
    @State private var shakeIndex: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Body

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            if let vm {
                instructionSection(vm)
                optionsGrid(vm)
            } else {
                ProgressView().progressViewStyle(.circular)
            }
            if let text = feedbackText {
                feedbackBanner(text, isCorrect: feedbackIsCorrect ?? false)
            }
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
        .task { await bootstrap() }
    }

    // MARK: Instruction

    private func instructionSection(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            Text(vm.instructionText)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)

            Button {
                playSample(targetWord: vm.targetWord)
            } label: {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: isPlayingSample ? "speaker.wave.3.fill" : "play.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                    Text(String(localized: "Прослушать"))
                        .font(TypographyTokens.body(17))
                }
                .foregroundStyle(.white)
                .padding(.vertical, SpacingTokens.small)
                .padding(.horizontal, SpacingTokens.large)
                .background(
                    Capsule().fill(ColorTokens.Brand.primary)
                )
            }
            .accessibilityLabel(String(localized: "Прослушать слово \(vm.targetWord)"))
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: Options grid

    private func optionsGrid(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> some View {
        let columns = [GridItem(.flexible(), spacing: SpacingTokens.regular),
                       GridItem(.flexible(), spacing: SpacingTokens.regular)]
        return LazyVGrid(columns: columns, spacing: SpacingTokens.regular) {
            ForEach(Array(vm.options.enumerated()), id: \.element.id) { idx, option in
                optionCard(option, index: idx, vm: vm)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func optionCard(
        _ option: ListenAndChooseModels.LoadRound.OptionViewModel,
        index: Int,
        vm: ListenAndChooseModels.LoadRound.ViewModel
    ) -> some View {
        let isSelected = selectedIndex == index
        let isCorrect = index == vm.correctIndex
        let shouldHighlightCorrect = revealAnswer && isCorrect
        let isWrongSelection = isSelected && feedbackIsCorrect == false && !revealAnswer
        let shakeOffset: CGFloat = shakeIndex == index && !reduceMotion ? 8 : 0

        return Button {
            selectOption(index: index, vm: vm)
        } label: {
            VStack(spacing: SpacingTokens.small) {
                Image(systemName: option.imageSystemName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(option.word)
                    .font(TypographyTokens.body(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 140)
            .padding(SpacingTokens.regular)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(cardBackground(isCorrect: shouldHighlightCorrect, isWrong: isWrongSelection))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(cardBorder(isCorrect: shouldHighlightCorrect, isWrong: isWrongSelection), lineWidth: 2)
            )
            .scaleEffect(isSelected && !reduceMotion ? 0.97 : 1.0)
            .offset(x: shakeOffset)
        }
        .buttonStyle(.plain)
        .disabled(feedbackIsCorrect == true || revealAnswer)
        .accessibilityLabel(String(localized: "Вариант: \(option.word)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(
            shouldHighlightCorrect
                ? String(localized: "Правильный ответ")
                : (isWrongSelection ? String(localized: "Неверно") : "")
        )
    }

    private func cardBackground(isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect { return ColorTokens.Semantic.successBg }
        if isWrong   { return ColorTokens.Semantic.errorBg }
        return ColorTokens.Kid.surface
    }

    private func cardBorder(isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect { return ColorTokens.Semantic.success }
        if isWrong   { return ColorTokens.Semantic.error }
        return ColorTokens.Kid.line
    }

    // MARK: Feedback banner

    private func feedbackBanner(_ text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? ColorTokens.Semantic.success : ColorTokens.Semantic.error)
            Text(text)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.ink)
        }
        .padding(.vertical, SpacingTokens.small)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            Capsule().fill(isCorrect ? ColorTokens.Semantic.successBg : ColorTokens.Semantic.errorBg)
        )
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: Actions

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = ListenAndChoosePresenter()
        let routerInstance = ListenAndChooseRouter()
        routerInstance.onFinish = { score in onComplete(score) }
        let interactorInstance = ListenAndChooseInteractor(
            contentService: container.contentService
        )
        interactorInstance.presenter = presenterInstance
        // Use a class-bound bridge because SwiftUI struct can't conform to
        // AnyObject protocols. The bridge forwards display callbacks into
        // `@State` via closures.
        let bridge = ListenAndChooseDisplayBridge(
            onLoad: { new in vm = new },
            onAttempt: { result in
                feedbackText = result.feedbackText
                feedbackIsCorrect = result.isCorrect
                revealAnswer = result.shouldRevealAnswer
                if let finalScore = result.finalScore {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(800))
                        onComplete(finalScore)
                    }
                }
            }
        )
        presenterInstance.display = bridge

        presenter = presenterInstance
        router = routerInstance
        interactor = interactorInstance

        await interactorInstance.loadRound(
            ListenAndChooseModels.LoadRound.Request(
                soundTarget: activity.soundTarget,
                difficulty: activity.difficulty
            )
        )
    }

    private func playSample(targetWord: String) {
        guard !isPlayingSample else { return }
        isPlayingSample = true
        container.hapticService.selection()
        // Production audio playback happens through AudioService.playAudio(url:);
        // a real asset URL is resolved from the ContentPack. Here we simulate timing.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            isPlayingSample = false
        }
    }

    private func selectOption(index: Int, vm: ListenAndChooseModels.LoadRound.ViewModel) {
        guard feedbackIsCorrect != true, !revealAnswer else { return }
        selectedIndex = index
        attemptsUsed += 1
        container.hapticService.selection()

        interactor?.submitAttempt(
            ListenAndChooseModels.SubmitAttempt.Request(
                selectedIndex: index,
                correctIndex: vm.correctIndex,
                attemptsUsed: attemptsUsed
            )
        )
    }

}

// MARK: - Bridge

/// Class-bound bridge that mirrors display callbacks into SwiftUI `@State` via a closure.
@MainActor
final class ListenAndChooseDisplayBridge: ListenAndChooseDisplayLogic {
    let onLoad: (ListenAndChooseModels.LoadRound.ViewModel) -> Void
    let onAttempt: (ListenAndChooseModels.SubmitAttempt.ViewModel) -> Void

    init(
        onLoad: @escaping (ListenAndChooseModels.LoadRound.ViewModel) -> Void,
        onAttempt: @escaping (ListenAndChooseModels.SubmitAttempt.ViewModel) -> Void
    ) {
        self.onLoad = onLoad
        self.onAttempt = onAttempt
    }

    func displayLoadRound(_ viewModel: ListenAndChooseModels.LoadRound.ViewModel) {
        onLoad(viewModel)
    }

    func displaySubmitAttempt(_ viewModel: ListenAndChooseModels.SubmitAttempt.ViewModel) {
        onAttempt(viewModel)
    }
}
