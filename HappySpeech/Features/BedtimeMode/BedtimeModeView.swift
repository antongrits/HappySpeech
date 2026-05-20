import OSLog
import SwiftUI

// MARK: - BedtimeModeViewModelHolder

@MainActor
@Observable
final class BedtimeModeViewModelHolder: BedtimeModeDisplayLogic {

    var startVM: BedtimeModeModels.Start.ViewModel?
    var currentStage: BedtimeStage = .intro

    func displayStart(viewModel: BedtimeModeModels.Start.ViewModel) async {
        startVM = viewModel
        currentStage = .intro
    }

    func displayAdvance(stage: BedtimeStage) async {
        currentStage = stage
    }

    func displayNewStory(viewModel: BedtimeModeModels.Start.ViewModel) async {
        startVM = viewModel
        currentStage = .story
    }
}

// MARK: - BedtimeModeView (Clean Swift: View)
//
// v31 Волна B, Функция Ф.3 «Bedtime mode».
//
// UX-стадии:
//   intro     — приветственная карточка от Ляли + кнопка «Готов».
//   breathing — анимированный круг с подсказками вдох-задержка-выдох
//               (3 цикла). Reduce Motion → статическая инструкция.
//   story     — заголовок + текст истории + кнопка «Послушать» (TTS).
//   farewell  — «Спокойной ночи» + кнопка «Закрыть».
//
// Палитра — глубокий тёплый фиолетово-голубой mesh с пониженной
// насыщенностью, чтобы экран не возбуждал ребёнка перед сном.

struct BedtimeModeView: View {

    let childId: String

    @State private var holder = BedtimeModeViewModelHolder()
    @State private var interactor: BedtimeModeInteractor?
    @State private var presenter: BedtimeModePresenter?
    @State private var router: BedtimeModeRouter?
    @State private var breathingProgress: Double = 0
    @State private var breathingPhase: BreathingPhase = .inhale
    @State private var breathingCycleIndex: Int = 0
    @State private var breathingSecondsLeft: Int = 0
    @State private var isBreathingRunning = false
    @State private var breathingGeneration: Int = 0
    @State private var isStoryPlaying = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private enum BreathingPhase { case inhale, hold, exhale }

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BedtimeMode.View"
    )

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack {
                topBar
                contentArea
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .task {
            await setupAndStart()
        }
        .onDisappear {
            interactor?.stopNarration()
            breathingGeneration += 1
            isBreathingRunning = false
            isStoryPlaying = false
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if reduceMotion {
            LinearGradient(
                colors: [
                    ColorTokens.Celebration.backdropIndigo,
                    ColorTokens.Celebration.backdropNight
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Низко-насыщенный градиент — холодный фиолетово-синий, без анимации
            // (детский Reduce Motion-friendly режим по умолчанию).
            LinearGradient(
                colors: [
                    ColorTokens.Celebration.backdropIndigo,
                    ColorTokens.Celebration.backdropNight,
                    ColorTokens.Celebration.backdropDeep
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text(holder.startVM?.title ?? "")
                .font(TypographyTokens.headline(17).weight(.semibold))
                .foregroundStyle(Color.white)
            Spacer()
            Button {
                interactor?.stopNarration()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .accessibilityLabel(Text("bedtime.close.a11y"))
        }
        .padding(.top, SpacingTokens.sp4)
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        Spacer()
        if let startVM = holder.startVM {
            switch holder.currentStage {
            case .intro:     introCard(startVM)
            case .breathing: breathingCard(startVM)
            case .story:     storyCard(startVM)
            case .farewell:  farewellCard(startVM)
            }
        } else {
            ProgressView()
                .controlSize(.large)
                .tint(Color.white)
        }
        Spacer()
    }

    // MARK: - Intro

    private func introCard(
        _ startVM: BedtimeModeModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.white.opacity(0.85))
                .accessibilityHidden(true)
            Text(startVM.introMessage)
                .font(TypographyTokens.title(24))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
            Text(startVM.storiesCountLabel)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(Color.white.opacity(0.7))
            primaryButton(title: String(localized: "bedtime.intro.cta")) {
                Task { await advance() }
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Breathing

    private func breathingCard(
        _ startVM: BedtimeModeModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            Text(startVM.breathingTitle)
                .font(TypographyTokens.title(22))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
            Text(startVM.breathingHint)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)

            breathingCircle(startVM)

            VStack(spacing: SpacingTokens.micro) {
                Text(breathingPhaseLabel())
                    .font(TypographyTokens.title(28).monospacedDigit())
                    .foregroundStyle(Color.white)
                Text(breathingCycleLabel(startVM.breathing))
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)

            if isBreathingRunning {
                Text("bedtime.breathing.holding")
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 56)
            } else {
                primaryButton(title: String(localized: "bedtime.breathing.start")) {
                    startBreathing(cycle: startVM.breathing)
                }
            }
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func breathingCircle(
        _ startVM: BedtimeModeModels.Start.ViewModel
    ) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 6)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .scaleEffect(reduceMotion ? 1.0 : breathingScale)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: breathingScale)
            Text("\(breathingSecondsLeft)")
                .font(TypographyTokens.title(36).monospacedDigit())
                .foregroundStyle(Color.white)
        }
        .frame(width: 160, height: 160)
        .accessibilityLabel(Text("bedtime.breathing.a11y"))
    }

    private var breathingScale: CGFloat {
        switch breathingPhase {
        case .inhale: return 1.18
        case .hold:   return 1.18
        case .exhale: return 0.85
        }
    }

    private func breathingPhaseLabel() -> String {
        switch breathingPhase {
        case .inhale: return String(localized: "bedtime.breathing.inhale")
        case .hold:   return String(localized: "bedtime.breathing.hold")
        case .exhale: return String(localized: "bedtime.breathing.exhale")
        }
    }

    private func breathingCycleLabel(_ cycle: BedtimeBreathingCycle) -> String {
        String(
            format: String(localized: "bedtime.breathing.cycle"),
            min(breathingCycleIndex + 1, cycle.totalCycles),
            cycle.totalCycles
        )
    }

    // MARK: - Story

    private func storyCard(
        _ startVM: BedtimeModeModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.white.opacity(0.85))
                .accessibilityHidden(true)
            Text(startVM.storyTitle)
                .font(TypographyTokens.title(22))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            ScrollView(showsIndicators: false) {
                Text(startVM.storyText)
                    .font(TypographyTokens.body(17))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding(.horizontal, SpacingTokens.sp2)
            }
            .frame(maxHeight: 240)

            HStack(spacing: SpacingTokens.sp2) {
                Button {
                    Task { await pickNewStory() }
                } label: {
                    Label {
                        Text("bedtime.story.another")
                            .font(TypographyTokens.headline(16))
                    } icon: {
                        Image(systemName: "shuffle")
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(Color.white.opacity(0.10))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("bedtime.story.another.hint"))

                primaryButton(title: storyButtonTitle, disabled: false) {
                    Task { await toggleStoryNarration() }
                }
            }

            Button {
                Task { await advance() }
            } label: {
                Text("bedtime.story.done")
                    .font(TypographyTokens.caption(13).weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var storyButtonTitle: String {
        isStoryPlaying
            ? String(localized: "bedtime.story.stop")
            : String(localized: "bedtime.story.listen")
    }

    // MARK: - Farewell

    private func farewellCard(
        _ startVM: BedtimeModeModels.Start.ViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.white.opacity(0.85))
                .accessibilityHidden(true)
            Text(startVM.farewell)
                .font(TypographyTokens.title(26))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
            Button {
                interactor?.stopNarration()
                dismiss()
            } label: {
                Text("bedtime.farewell.close")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Celebration.backdropIndigo)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(Color.white.opacity(0.9))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(SpacingTokens.sp4)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Primary button

    private func primaryButton(
        title: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Celebration.backdropIndigo)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(disabled ? Color.white.opacity(0.40) : Color.white.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(Text(title))
    }

    // MARK: - Wiring

    private func setupAndStart() async {
        if interactor == nil {
            let presenter = BedtimeModePresenter(displayLogic: holder)
            let worker = BedtimeModeWorker()
            let interactor = BedtimeModeInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = BedtimeModeRouter(dismissAction: { dismiss() })
        }
        await interactor?.start(request: .init(childId: childId))
    }

    private func advance() async {
        breathingGeneration += 1
        isBreathingRunning = false
        await interactor?.advance(request: .init(currentStage: holder.currentStage))
    }

    private func startBreathing(cycle: BedtimeBreathingCycle) {
        breathingGeneration += 1
        let generation = breathingGeneration
        isBreathingRunning = true
        breathingCycleIndex = 0

        Task { @MainActor in
            for cycleIndex in 0..<cycle.totalCycles {
                guard generation == breathingGeneration else { return }
                breathingCycleIndex = cycleIndex
                await runBreathingPhase(.inhale, seconds: cycle.inhaleSeconds, gen: generation)
                guard generation == breathingGeneration else { return }
                await runBreathingPhase(.hold, seconds: cycle.holdSeconds, gen: generation)
                guard generation == breathingGeneration else { return }
                await runBreathingPhase(.exhale, seconds: cycle.exhaleSeconds, gen: generation)
            }
            guard generation == breathingGeneration else { return }
            isBreathingRunning = false
            container.hapticService.notification(.success)
            await advance()
        }
    }

    private func runBreathingPhase(_ phase: BreathingPhase, seconds: Int, gen: Int) async {
        breathingPhase = phase
        breathingSecondsLeft = seconds
        while breathingSecondsLeft > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard gen == breathingGeneration else { return }
            breathingSecondsLeft -= 1
        }
    }

    private func toggleStoryNarration() async {
        if isStoryPlaying {
            interactor?.stopNarration()
            isStoryPlaying = false
        } else {
            isStoryPlaying = true
            await interactor?.narrateStory()
            isStoryPlaying = false
        }
    }

    private func pickNewStory() async {
        interactor?.stopNarration()
        isStoryPlaying = false
        await interactor?.pickNewStory(request: .init(excludeId: nil))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BedtimeMode") {
    BedtimeModeView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
