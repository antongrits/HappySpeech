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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "BreatheAndSpeak.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Step 10 Batch A — Pattern 1: mesh .calm палитра (mint/sky/lilac) —
                // успокаивающий фон для дыхательных упражнений.
                HSMeshGradientBackground(palette: .calm, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.30 : 0.55)
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
                ToolbarItem(placement: .topBarTrailing) {
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
        VStack(spacing: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(step.stepLabel)
                    .font(TypographyTokens.caption(12).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.inkMuted)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ColorTokens.Kid.surfaceAlt)
                        Capsule()
                            .fill(ColorTokens.Brand.mint)
                            .frame(width: max(0, geo.size.width * step.progressFraction))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)

                Text(startVM.complexTitle)
                    .font(TypographyTokens.caption(13).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp4)

            Spacer()

            stepCard(step)
                .id(step.id)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))

            // Hold timer circle
            holdCircle(step)

            Spacer()

            actionButton(step)
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.bottom, SpacingTokens.sp6)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: step.id)
    }

    private func stepCard(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> some View {
        // Step 10 Batch A — Pattern 2+5: hero обёрнут в HSLiquidGlassCard.elevated;
        // pulse-эффект на символе step реагирует на смену упражнения.
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp5) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: step.symbolName)
                    .font(.system(size: 56))
                    .foregroundStyle(step.kind == .breathing
                        ? ColorTokens.Brand.sky
                        : ColorTokens.Brand.mint)
                    .hsSymbolEffect(.pulse, value: step.id)
                    .accessibilityHidden(true)

                Text(step.name)
                    .font(TypographyTokens.title(26))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(step.instruction)
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    // Без обрезки на SE: текст разворачивается на полную высоту,
                    // а не клипуется родительским VStack между Spacer'ами.
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SpacingTokens.sp4)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.accessibilityLabel))
    }

    private func holdCircle(_ step: BreatheAndSpeakModels.Start.StepViewModel) -> some View {
        // Для дыхательных шагов с активным микрофоном кольцо «дышит» вместе с
        // реальной силой выдоха (живой акустический сигнал), для остальных —
        // ровная заливка прогресса удержания.
        let usesLiveBlow = step.requiresBlow && isHolding && !blowUnavailable
        let ringScale = usesLiveBlow ? CGFloat(0.92 + 0.16 * blowStrength) : 1.0
        return ZStack {
            Circle()
                .stroke(ColorTokens.Kid.surfaceAlt, lineWidth: 10)
            Circle()
                .trim(from: 0, to: holdProgress(step))
                .stroke(ColorTokens.Brand.mint,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: holdRemaining)

            if usesLiveBlow {
                // Реальная сила дутья: пламя свечи отклоняется/тает по сигналу.
                Image(systemName: isBlowing ? "wind" : "flame.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isBlowing ? ColorTokens.Brand.sky : ColorTokens.Brand.gold)
                    .scaleEffect(reduceMotion ? 1.0 : ringScale)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: blowStrength)
                    .accessibilityHidden(true)
            } else {
                Text(isHolding ? "\(holdRemaining)" : "\(step.holdSeconds)")
                    .font(TypographyTokens.title(32).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
        }
        .frame(width: 120, height: 120)
        .scaleEffect(reduceMotion ? 1.0 : ringScale)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: blowStrength)
        .accessibilityLabel(Text("breatheAndSpeak.timer.a11y"))
        .accessibilityValue(Text(verbatim: "\(isHolding ? holdRemaining : step.holdSeconds)"))
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
                .lineLimit(2)
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
