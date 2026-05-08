import OSLog
import SwiftUI

// MARK: - ListenAndChoosePhase

/// 4-фазный state machine для одного раунда «Слушай и выбирай»:
///
///   listening   — Ляля проигрывает целевое слово; кнопки выбора отключены
///   choosing    — карточки активны, ребёнок может ткнуть; stagger-anim
///   revealing   — показываем правильный ответ + флаш; кнопки disabled
///   nextItem    — короткая пауза перед загрузкой следующего раунда
enum ListenAndChoosePhase: Sendable, Equatable {
    case listening
    case choosing
    case revealing
    case nextItem
}

// MARK: - ListenAndChooseView

/// Production "Listen and Choose" game.
///
/// Contract with `SessionShell`: the parent provides a `SessionActivity` and an
/// `onComplete` closure that receives the final score [0.0 – 1.0]. The game
/// auto-loads a round on appear, handles up to 3 attempts per round, and then
/// calls `onComplete` once the round is finished.
///
/// UI:
///   • AudioPlayButton — 88×88pt circle с 3-х концентрическими ripple-волнами;
///   • LazyVGrid 2×2 — карточки HSLiquidGlassCard, появляются stagger
///     (delay 0.1 × n) при каждом новом задании;
///   • Shake-анимация на неправильно выбранной карточке.
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
    @State private var phase: ListenAndChoosePhase = .listening
    @State private var attemptsUsed: Int = 0
    @State private var selectedIndex: Int?
    @State private var feedbackText: String?
    @State private var feedbackIsCorrect: Bool?
    @State private var revealAnswer: Bool = false
    @State private var isPlayingSample: Bool = false
    @State private var shakeIndex: Int?
    @State private var visibleCardCount: Int = 0
    @State private var staggerTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Body

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            if let vm {
                instructionSection(vm)
                audioPlayerRow(vm)
                phaseLabel
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
        .onDisappear {
            staggerTask?.cancel()
            staggerTask = nil
        }
    }

    // MARK: Phase label (под кнопкой проигрывания)

    @ViewBuilder
    private var phaseLabel: some View {
        switch phase {
        case .listening:
            phaseRow(icon: "ear", text: String(localized: "listen.phase.listening"),
                     tint: ColorTokens.Brand.primary)
        case .choosing:
            phaseRow(icon: "hand.tap", text: String(localized: "listen.phase.choosing"),
                     tint: ColorTokens.Kid.inkSoft)
        case .revealing:
            phaseRow(icon: "checkmark.seal.fill", text: String(localized: "listen.phase.revealing"),
                     tint: ColorTokens.Semantic.success)
        case .nextItem:
            phaseRow(icon: "arrow.right.circle", text: String(localized: "listen.phase.next_item"),
                     tint: ColorTokens.Kid.inkSoft)
        }
    }

    private func phaseRow(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: icon)
                .font(TypographyTokens.caption(14).weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.body(14))
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: Instruction

    private func instructionSection(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.small) {
            LyalyaMascotView(
                state: phase == .listening ? .singing : .pointing,
                size: 80
            )
            .accessibilityHidden(true)

            Text(vm.instructionText)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)

            if let progress = vm.progressText {
                Text(progress)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }

            if let hint = vm.hintText {
                Text(hint)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.regular)
            }
        }
    }

    // MARK: Audio player row (главная кнопка прослушивания + Replay)

    private func audioPlayerRow(_ vm: ListenAndChooseModels.LoadRound.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.large) {
            AudioPlayButton(
                isPlaying: isPlayingSample,
                reduceMotion: reduceMotion,
                onTap: { playSample(targetWord: vm.targetWord) }
            )
            .accessibilityLabel(String(localized: "Прослушать слово \(vm.targetWord)"))
            .accessibilityHint(String(localized: "listen.audio.button.hint"))

            Button {
                interactor?.replayCurrentWord(ListenAndChooseModels.ReplayWord.Request())
                container.hapticService.selection()
            } label: {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(TypographyTokens.body(18).weight(.semibold))
                        .accessibilityHidden(true)
                    Text(String(localized: "Повтори"))
                        .font(TypographyTokens.body(14))
                }
                .foregroundStyle(ColorTokens.Kid.inkSoft)
                .padding(.vertical, SpacingTokens.small)
                .padding(.horizontal, SpacingTokens.regular)
                .overlay(
                    Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
            }
            .accessibilityLabel(String(localized: "Повторить слово ещё раз"))
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
                    .opacity(reduceMotion || idx < visibleCardCount ? 1 : 0)
                    .offset(y: reduceMotion || idx < visibleCardCount ? 0 : 12)
                    .animation(reduceMotion ? nil : .spring(duration: 0.45), value: visibleCardCount)
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
            HSLiquidGlassCard(style: cardGlassStyle(isCorrect: shouldHighlightCorrect, isWrong: isWrongSelection),
                              padding: SpacingTokens.regular) {
                VStack(spacing: SpacingTokens.small) {
                    Image(systemName: option.imageSystemName)
                        .font(TypographyTokens.display(48).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text(option.word)
                        .font(TypographyTokens.body(17))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 110)
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(cardBorder(isCorrect: shouldHighlightCorrect, isWrong: isWrongSelection), lineWidth: 2)
            )
            .scaleEffect(isSelected && !reduceMotion ? 0.97 : 1.0)
            .offset(x: shakeOffset)
            .animation(reduceMotion ? nil : .spring(duration: 0.25), value: shakeIndex)
        }
        .buttonStyle(.plain)
        .disabled(phase != .choosing || feedbackIsCorrect == true || revealAnswer)
        .accessibilityLabel(String(localized: "Вариант: \(option.word)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(
            shouldHighlightCorrect
                ? String(localized: "Правильный ответ")
                : (isWrongSelection ? String(localized: "Неверно") : "")
        )
    }

    private func cardGlassStyle(isCorrect: Bool, isWrong: Bool) -> HSLiquidGlassStyle {
        if isCorrect { return .tinted(ColorTokens.Semantic.success) }
        if isWrong { return .tinted(ColorTokens.Semantic.error) }
        return .primary
    }

    private func cardBorder(isCorrect: Bool, isWrong: Bool) -> Color {
        if isCorrect { return ColorTokens.Semantic.success }
        if isWrong { return ColorTokens.Semantic.error }
        return ColorTokens.Kid.line
    }

    // MARK: Feedback banner

    private func feedbackBanner(_ text: String, isCorrect: Bool) -> some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? ColorTokens.Semantic.success : ColorTokens.Semantic.error)
                .accessibilityHidden(true)
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
            onLoad: { new in
                vm = new
                onNewRoundLoaded(optionsCount: new.options.count)
            },
            onAttempt: { result in
                feedbackText = result.feedbackText
                feedbackIsCorrect = result.isCorrect
                revealAnswer = result.shouldRevealAnswer
                if result.shouldRevealAnswer || result.isCorrect {
                    phase = .revealing
                }
                if !result.isCorrect && !result.shouldRevealAnswer {
                    triggerShake(at: selectedIndex)
                }
                if let finalScore = result.finalScore {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(800))
                        phase = .nextItem
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
        phase = .listening
        container.hapticService.selection()
        // Production audio playback happens through AudioService.playAudio(url:);
        // a real asset URL is resolved from the ContentPack. Here we simulate timing.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            isPlayingSample = false
            phase = .choosing
        }
    }

    private func selectOption(index: Int, vm: ListenAndChooseModels.LoadRound.ViewModel) {
        guard phase == .choosing, feedbackIsCorrect != true, !revealAnswer else { return }
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

    // MARK: - Stagger appearance

    /// Запускается каждый раз, когда Presenter присылает новый раунд.
    /// Карточки появляются по очереди с задержкой 0.1с × n.
    private func onNewRoundLoaded(optionsCount: Int) {
        // Reset round-local state
        selectedIndex = nil
        feedbackText = nil
        feedbackIsCorrect = nil
        revealAnswer = false
        attemptsUsed = 0
        shakeIndex = nil
        phase = .listening
        visibleCardCount = 0

        guard !reduceMotion else {
            visibleCardCount = optionsCount
            phase = .choosing
            return
        }

        staggerTask?.cancel()
        staggerTask = Task { @MainActor in
            // Сначала проигрываем «слушаем» в течение 700мс, потом показываем карточки.
            try? await Task.sleep(for: .milliseconds(400))
            for idx in 0..<optionsCount {
                if Task.isCancelled { return }
                visibleCardCount = idx + 1
                try? await Task.sleep(for: .milliseconds(100))
            }
            if Task.isCancelled { return }
            phase = .choosing
        }
    }

    private func triggerShake(at index: Int?) {
        guard let index, !reduceMotion else { return }
        shakeIndex = index
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            shakeIndex = nil
        }
    }
}

// MARK: - AudioPlayButton

/// 88×88pt круглая кнопка прослушивания. При isPlaying=true показывает 3
/// концентрические ripple-волны (Circle: scale 1.0→2.0, opacity 0.6→0.0,
/// stagger delay 0.3s × n).
struct AudioPlayButton: View {
    let isPlaying: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var rippleStart: Date = Date()

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isPlaying && !reduceMotion {
                    rippleLayer
                }
                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: isPlaying ? "speaker.wave.3.fill" : "play.fill")
                            .font(TypographyTokens.title(36).weight(.bold))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                            .accessibilityHidden(true)
                    )
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.35), radius: 12, y: 6)
            }
            .frame(width: 140, height: 140)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(String(
            localized: isPlaying ? "a11y.audio.playing" : "a11y.button.play"
        ))
        .onChange(of: isPlaying) { _, newValue in
            if newValue { rippleStart = Date() }
        }
    }

    /// 3 концентрические Circle, каждый разгоняется до scale 2.0 и затухает.
    /// stagger 0.3s между ними, общий цикл 1.5с.
    private var rippleLayer: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(rippleStart)
            ZStack {
                ForEach(0..<3, id: \.self) { idx in
                    let delay = Double(idx) * 0.3
                    let phase = max(0, (elapsed - delay).truncatingRemainder(dividingBy: 1.5)) / 1.5
                    let scale = 1.0 + phase * 1.0
                    let opacity = 0.6 * (1 - phase)
                    Circle()
                        .strokeBorder(ColorTokens.Brand.primary, lineWidth: 2)
                        .frame(width: 88, height: 88)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
        }
        .accessibilityHidden(true)
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
