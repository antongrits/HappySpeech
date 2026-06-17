import OSLog
import SwiftUI

// MARK: - BreatheAndSpeakViewModelHolder

@MainActor
@Observable
final class BreatheAndSpeakViewModelHolder: BreatheAndSpeakDisplayLogic {

    var startVM: BreatheAndSpeakModels.Start.ViewModel?
    var currentStep: BreatheAndSpeakModels.Start.StepViewModel?
    var summary: BreatheAndSpeakModels.Advance.SummaryViewModel?
    var isFinished: Bool = false

    func displayStart(viewModel: BreatheAndSpeakModels.Start.ViewModel) async {
        self.startVM = viewModel
        self.currentStep = viewModel.firstStep
        self.isFinished = false
        self.summary = nil
    }

    func displayAdvance(viewModel: BreatheAndSpeakModels.Advance.ViewModel) async {
        self.isFinished = viewModel.isFinished
        self.summary = viewModel.summary
        if let next = viewModel.nextStep {
            self.currentStep = next
        }
    }
}

// MARK: - BreatheAndSpeakView (Clean Swift: View)
//
// v29 Фаза 8, Функция 10 «Дыши и говори».
//
// Ведёт ребёнка по «комплексу дня»: на каждом шаге — упражнение с
// иллюстрацией, инструкцией и счётчиком удержания позы / выдоха. После
// удержания ребёнок переходит к следующему упражнению.
//
// Accessibility:
//   • Kid circuit: кнопки ≥ 56pt
//   • VoiceOver: шаг — описательный label (тип, название, инструкция)
//   • Dynamic Type: VStack + minimumScaleFactor
//   • Reduced Motion: пульсация круга-таймера гейтится reduceMotion
//   • Light + Dark: ColorTokens.Kid адаптируются

struct BreatheAndSpeakView: View {

    let childId: String

    @State private var holder = BreatheAndSpeakViewModelHolder()
    @State private var interactor: BreatheAndSpeakInteractor?
    @State private var presenter: BreatheAndSpeakPresenter?
    @State private var router: BreatheAndSpeakRouter?
    @State private var holdRemaining: Int = 0
    @State private var isHolding: Bool = false
    /// Идентификатор текущего удержания: устаревшие тик-таски прекращаются,
    /// чтобы счётчик не убывал вдвое быстрее при быстрой смене шагов.
    @State private var holdGeneration: Int = 0

    /// Акустический детектор выдоха/дутья (Apple Sound Analysis + DSP).
    /// Создаётся лениво при первом дыхательном шаге.
    @State private var blowDetector: (any BlowDetecting)?
    /// Живая сила потока 0…1 — управляет пламенем свечи и кольцом таймера.
    @State private var blowStrength: Float = 0
    /// Идёт ли сейчас реальный выдох (для подсказки/гаптики).
    @State private var isBlowing: Bool = false
    /// Микрофон недоступен (нет разрешения / симулятор без аудиовхода) —
    /// дыхательный шаг честно откатывается на таймер.
    @State private var blowUnavailable: Bool = false

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BreatheAndSpeak.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Спокойный тёплый статичный фон (кремовое семейство).
                HSMeshGradientBackground(palette: .calm, animated: false)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                if holder.isFinished, let summary = holder.summary {
                    summarySection(summary)
                } else if let startVM = holder.startVM,
                          let step = holder.currentStep {
                    complexSection(startVM: startVM, step: step)
                } else {
                    loadingSection
                }
            }
            .navigationTitle(Text("breatheAndSpeak.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("breatheAndSpeak.close.a11y"))
                }
            }
            .task {
                await setupAndStart()
            }
            .onDisappear {
                teardownBlowDetection()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Complex

    private func complexSection(
        startVM: BreatheAndSpeakModels.Start.ViewModel,
        step: BreatheAndSpeakModels.Start.StepViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            // Шапка: название упражнения + подзаголовок комплекса + прогресс-точки.
            VStack(spacing: SpacingTokens.sp3) {
                VStack(spacing: SpacingTokens.sp1) {
                    Text(step.name)
                        .font(TypographyTokens.kidTitle(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.8)

                    if !startVM.complexTitle.isEmpty {
                        Text(startVM.complexTitle)
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                progressDots(startVM: startVM, step: step)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)

            Spacer(minLength: 0)

            // Центральный дыхательный орб — ведёт вдох/выдох.
            HSBreathingOrb(
                expansion: orbExpansion(step),
                ringProgress: holdProgress(step),
                phaseTitle: orbPhaseTitle(step),
                phaseCount: orbPhaseCount(step),
                size: 240
            )
            .id(step.id)

            Text(step.instruction)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, SpacingTokens.sp4)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer(minLength: 0)

            mascotBubble(step)
                .padding(.horizontal, SpacingTokens.screenEdge)

            actionButton(step)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: step.id)
    }

    // MARK: - Progress dots

    private func progressDots(
        startVM: BreatheAndSpeakModels.Start.ViewModel,
        step: BreatheAndSpeakModels.Start.StepViewModel
    ) -> some View {
        let total = max(startVM.totalSteps, 1)
        let current = min(total - 1, Int((step.progressFraction * Double(total)).rounded(.down)))
        return VStack(spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index <= current
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Kid.line)
                        .frame(
                            width: index == current ? 13 : 9,
                            height: index == current ? 13 : 9
                        )
                }
            }
            Text(step.stepLabel)
                .font(TypographyTokens.caption(13).weight(.semibold).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: step.stepLabel))
    }

    // MARK: - Orb phase mapping

    /// Доля раскрытия орба: пока ребёнок держит выдох — орб сжимается к нулю;
    /// пока готовится / завершил — раскрыт (вдох). Для не-дыхательных поз орб
    /// держит наполнение пропорционально удержанию позы.
    private func orbExpansion(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> CGFloat {
        guard isHolding, step.holdSeconds > 0 else { return 1.0 }
        let done = CGFloat(step.holdSeconds - holdRemaining) / CGFloat(step.holdSeconds)
        // Дыхательный шаг: вдох сделан, выдыхаем → орб сжимается.
        // Артикуляция: поза наполняет орб → орб растёт.
        return step.requiresBlow ? (1.0 - done) : done
    }

    private func orbPhaseTitle(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> String {
        guard isHolding else { return String(localized: "Готовься") }
        if step.requiresBlow {
            return isBlowing
                ? String(localized: "Выдох…")
                : String(localized: "Вдохни")
        }
        return String(localized: "Держи…")
    }

    private func orbPhaseCount(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> String? {
        isHolding ? "\(holdRemaining)" : nil
    }

    // MARK: - Mascot bubble

    private func mascotBubble(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> some View {
        let phrase: String = {
            guard isHolding else { return String(localized: "Дыши вместе со мной") }
            if step.requiresBlow {
                return isBlowing
                    ? String(localized: "Молодец, дыши спокойно")
                    : String(localized: "Дыши спокойно и ровно")
            }
            return String(localized: "Держим — ты молодец")
        }()
        return HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: isHolding ? .encouraging : .idle, size: 60)
                .accessibilityHidden(true)
            Text(phrase)
                .font(TypographyTokens.body(15).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(SpacingTokens.sp3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .stroke(ColorTokens.Kid.line, lineWidth: 1)
                        )
                )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func holdProgress(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> CGFloat {
        guard step.holdSeconds > 0 else { return 0 }
        let done = step.holdSeconds - holdRemaining
        return isHolding
            ? CGFloat(done) / CGFloat(step.holdSeconds)
            : 0
    }

    @ViewBuilder
    private func actionButton(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> some View {
        if isHolding {
            // Для дыхательных шагов с живым микрофоном даём реальную обратную
            // связь: «дуй сильнее» пока сигнала нет, «молодец» когда реально дует.
            let holdingText: LocalizedStringKey = (step.requiresBlow && !blowUnavailable)
                ? (isBlowing ? "breatheAndSpeak.blow.detected" : "breatheAndSpeak.blow.prompt")
                : "breatheAndSpeak.holding"
            Text(holdingText)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(isBlowing ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 56)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        } else if holdRemaining == 0 && holdWasStarted {
            Button {
                Task { await advance() }
            } label: {
                Text("breatheAndSpeak.next")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("breatheAndSpeak.next.hint"))
        } else {
            Button {
                startHold(step)
            } label: {
                Text("breatheAndSpeak.start")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("breatheAndSpeak.start.hint"))
        }
    }

    @State private var holdWasStarted: Bool = false

    // MARK: - Summary

    private func summarySection(
        _ summary: BreatheAndSpeakModels.Advance.SummaryViewModel
    ) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            // Верхний отступ меньше нижней распорки — контент сидит в верхней
            // трети, без большой пустоты над иконкой.
            Spacer(minLength: SpacingTokens.sp4)

            Image(systemName: "lungs.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.title)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)

            // Реальный итог упражнения (из ViewModel) — заполняет середину
            // экрана осмысленным результатом, а не пустотой.
            Text(String(
                format: String(localized: "breatheAndSpeak.summary.steps %lld %lld"),
                summary.completedSteps,
                summary.totalSteps
            ))
            .font(TypographyTokens.headline(20).monospacedDigit())
            .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button {
                    Task { await setupAndStart(forceRestart: true) }
                } label: {
                    Text("breatheAndSpeak.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("breatheAndSpeak.summary.again.hint"))

                Button {
                    exitGame()
                } label: {
                    Text("breatheAndSpeak.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("breatheAndSpeak.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hold timer

    private func startHold(_ step: BreatheAndSpeakModels.Start.StepViewModel) {
        holdGeneration += 1
        let generation = holdGeneration
        holdRemaining = step.holdSeconds
        isHolding = true
        holdWasStarted = true
        blowStrength = 0
        isBlowing = false
        container.hapticService.impact(.light)

        if step.requiresBlow {
            // Дыхательный шаг — прогресс удержания управляется РЕАЛЬНЫМ выдохом.
            startBlowGatedHold(step, generation: generation)
        } else {
            // Артикуляционная поза — удержание по таймеру (аудио не нужно).
            startTimerHold(generation: generation)
        }
    }

    /// Артикуляционная поза: ровный посекундный отсчёт.
    private func startTimerHold(generation: Int) {
        Task {
            while holdRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard isHolding, generation == holdGeneration else { return }
                holdRemaining -= 1
            }
            guard generation == holdGeneration else { return }
            isHolding = false
            container.hapticService.notification(.success)
        }
    }

    /// Дыхательный шаг: запускает live-детекцию выдоха и продвигает отсчёт
    /// только пока ребёнок реально дует. Если микрофон недоступен (нет
    /// разрешения / симулятор без аудиовхода) — честно откатывается на таймер.
    private func startBlowGatedHold(
        _ step: BreatheAndSpeakModels.Start.StepViewModel,
        generation: Int
    ) {
        let detector = blowDetector ?? LiveBlowDetectionService()
        blowDetector = detector
        blowUnavailable = false

        Task {
            let started = await detector.startLive()
            guard generation == holdGeneration, isHolding else {
                await detector.stopLive()
                return
            }
            if !started {
                // Graceful fallback: без живого аудио ведём шаг по таймеру.
                blowUnavailable = true
                startTimerHold(generation: generation)
                return
            }
            await consumeBlowStream(detector, generation: generation)
        }
    }

    /// Потребляет поток `BlowSample`: накапливает реальное время выдоха и сводит
    /// его к целым секундам обратного отсчёта; завершает шаг по достижении нуля.
    private func consumeBlowStream(
        _ detector: any BlowDetecting,
        generation: Int
    ) async {
        var accumulatedSeconds: Double = 0
        var lastTimestamp: TimeInterval?
        let totalSeconds = Double(holdRemaining)

        for await sample in detector.liveStream {
            guard generation == holdGeneration, isHolding else { break }

            blowStrength = sample.strength
            if sample.isBlowing != isBlowing {
                isBlowing = sample.isBlowing
                if sample.isBlowing { container.hapticService.impact(.light) }
            }

            // Накопление РЕАЛЬНОГО времени выдоха по дельте меток времени кадров.
            if let last = lastTimestamp, sample.isBlowing {
                let delta = max(0, sample.timestamp - last)
                accumulatedSeconds += delta
            }
            lastTimestamp = sample.timestamp

            let remaining = max(0, Int((totalSeconds - accumulatedSeconds).rounded(.up)))
            if remaining != holdRemaining { holdRemaining = remaining }

            if accumulatedSeconds >= totalSeconds {
                holdRemaining = 0
                break
            }
        }

        await detector.stopLive()
        guard generation == holdGeneration else { return }
        isHolding = false
        isBlowing = false
        blowStrength = 0
        if holdRemaining == 0 {
            container.hapticService.notification(.success)
        }
    }

    // MARK: - Wiring

    private func setupAndStart(forceRestart: Bool = false) async {
        if interactor == nil {
            let presenter = BreatheAndSpeakPresenter(displayLogic: holder)
            let worker = BreatheAndSpeakWorker(childRepository: container.childRepository)
            let interactor = BreatheAndSpeakInteractor(
                childId: childId,
                worker: worker,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = BreatheAndSpeakRouter(dismissAction: { exitGame() })
        }
        _ = forceRestart
        resetHoldState()
        await interactor?.start(request: .init(childId: childId))
    }

    private func advance() async {
        resetHoldState()
        await interactor?.advance(request: .init())
    }

    private func resetHoldState() {
        holdGeneration += 1
        isHolding = false
        holdWasStarted = false
        holdRemaining = 0
        isBlowing = false
        blowStrength = 0
        if let detector = blowDetector {
            Task { await detector.stopLive() }
        }
    }

    /// Останавливает живую детекцию при уходе с экрана (освобождает микрофон).
    private func teardownBlowDetection() {
        guard let detector = blowDetector else { return }
        Task { await detector.stopLive() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("BreatheAndSpeak / complex") {
    BreatheAndSpeakView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
