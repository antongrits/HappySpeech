import SwiftUI
import UIKit

// MARK: - SyllableRaceViewModelHolder

/// Display-слой VIP: зеркалит state презентера в @Observable для SwiftUI.
@MainActor
@Observable
final class SyllableRaceViewModelHolder: SyllableRaceDisplayLogic {

    var startVM: SyllableRaceModels.Start.ViewModel?
    var attemptVM: SyllableRaceModels.Attempt.ViewModel?
    var completeVM: SyllableRaceModels.Complete.ViewModel?
    var failureVM: SyllableRaceModels.Failure.ViewModel?
    var phase: SyllableRaceModels.Phase = .ready

    func displayStart(_ viewModel: SyllableRaceModels.Start.ViewModel) {
        startVM = viewModel
        attemptVM = nil
        failureVM = nil
    }

    func displayPhase(_ phase: SyllableRaceModels.Phase) {
        self.phase = phase
        if phase == .recording || phase == .analyzing {
            failureVM = nil
        }
    }

    func displayAttempt(_ viewModel: SyllableRaceModels.Attempt.ViewModel) {
        attemptVM = viewModel
    }

    func displayComplete(_ viewModel: SyllableRaceModels.Complete.ViewModel) {
        completeVM = viewModel
    }

    func displayFailure(_ viewModel: SyllableRaceModels.Failure.ViewModel) {
        failureVM = viewModel
    }
}

// MARK: - SyllableRaceView (Clean Swift: View)
//
// «Скороговорка-ракета» (kid) — ребёнок быстро и ровно повторяет слоговой ряд
// (па-па-па / па-та-ка), а ракета Ляли взлетает тем выше, чем быстрее и ровнее
// получается (on-device vDSP-анализ темпа слогов, без сети и без ML-моделей).
// Тёплая палитра, Ляля, Reduced Motion, VoiceOver.

struct SyllableRaceView: View {

    let childId: String

    @State private var holder = SyllableRaceViewModelHolder()
    @State private var interactor: SyllableRaceInteractor?
    @State private var presenter: SyllableRacePresenter?
    /// Анимируемая высота ракеты (0…1).
    @State private var rocketHeight: Double = 0

    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.calmMode) private var calmMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !calmMode)
                    .ignoresSafeArea()
                    .opacity(calmMode ? 0.14 : (colorScheme == .dark ? 0.20 : 0.30))
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                content
            }
            .navigationTitle(Text(String(localized: "syllableRace.screen.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        interactor?.cancel()
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "syllableRace.close.a11y")))
                }
            }
            .task { await bootstrap() }
            .onChange(of: holder.attemptVM?.rocketHeight) { _, newValue in
                guard let newValue, holder.attemptVM?.hasMeasurement == true else { return }
                animateRocket(to: newValue)
            }
            .onChange(of: holder.phase) { _, newValue in
                if newValue == .recording { rocketHeight = 0 }
            }
            .onDisappear { interactor?.cancel() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if holder.phase == .completed, let completion = holder.completeVM {
            completionView(completion)
        } else if let start = holder.startVM {
            sessionView(start)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    // MARK: - Session

    @ViewBuilder
    private func sessionView(_ start: SyllableRaceModels.Start.ViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.regular) {
                RecordLessonHeader(
                    sound: start.sequenceDisplay,
                    subtitle: String(
                        format: String(localized: "syllableRace.progress.a11y"),
                        holder.attemptVM?.roundNumber ?? start.roundNumber,
                        start.totalRounds
                    ),
                    progress: progressValue
                )

                // Карточка задания: ряд + ракета-«взлёт» + блок результата.
                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
                    VStack(spacing: SpacingTokens.sp4) {
                        sequenceChips(start.syllables)
                        rocketGauge
                        resultBlock(start: start)
                    }
                }

                HStack(alignment: .center, spacing: SpacingTokens.small) {
                    micButton(start: start)
                    HSMascotView(mood: mascotMood, size: 72)
                        .accessibilityHidden(true)
                }

                if let failure = holder.failureVM {
                    failureBlock(failure)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp4)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Sequence chips

    @ViewBuilder
    private func sequenceChips(_ syllables: [String]) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(Array(syllables.enumerated()), id: \.offset) { _, syllable in
                Text(syllable)
                    .font(TypographyTokens.headline(20).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .padding(.horizontal, SpacingTokens.small)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(
                        Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.55))
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "syllableRace.sequence.a11y"),
            syllables.joined(separator: " ")
        )))
    }

    // MARK: - Rocket gauge (вертикальный «взлёт»)

    @ViewBuilder
    private var rocketGauge: some View {
        GeometryReader { geo in
            let height = geo.size.height
            ZStack(alignment: .bottom) {
                // Дорожка взлёта: тёплый градиент butter → gold снизу вверх.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                ColorTokens.Brand.butter.opacity(0.5),
                                ColorTokens.Brand.gold.opacity(0.6),
                                ColorTokens.Brand.primaryLo.opacity(0.55)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 26)

                // Ракета — поднимается вверх по высоте rocketHeight.
                if holder.attemptVM?.hasMeasurement == true {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .rotationEffect(.degrees(-45))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(ColorTokens.Kid.surface)
                                .shadow(color: ColorTokens.Brand.primary.opacity(0.3), radius: 5, y: 2)
                        )
                        .offset(y: -rocketOffset(height: height))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(gaugeA11yLabel))
    }

    private func rocketOffset(height: CGFloat) -> CGFloat {
        let usable = max(0, height - 40)
        return usable * CGFloat(min(1, max(0, rocketHeight)))
    }

    private var gaugeA11yLabel: String {
        guard let attempt = holder.attemptVM, attempt.hasMeasurement else {
            return String(localized: "syllableRace.gauge.empty.a11y")
        }
        let percent = Int((attempt.rocketHeight * 100).rounded())
        return String(format: String(localized: "syllableRace.gauge.height.a11y"), percent)
    }

    // MARK: - Result block

    @ViewBuilder
    private func resultBlock(start: SyllableRaceModels.Start.ViewModel) -> some View {
        switch holder.phase {
        case .recording:
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .hsSymbolEffect(.variableColor, value: holder.phase == .recording)
                    .accessibilityHidden(true)
                Text(start.instruction)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        case .analyzing:
            ProgressView(String(localized: "syllableRace.analyzing"))
                .controlSize(.regular)
        case .result, .completed:
            if let attempt = holder.attemptVM {
                attemptResult(attempt)
            } else {
                readyInstruction(start)
            }
        case .ready:
            readyInstruction(start)
        }
    }

    @ViewBuilder
    private func attemptResult(_ attempt: SyllableRaceModels.Attempt.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            starsRow(count: attempt.stars)
            Text(attempt.title)
                .font(TypographyTokens.title(22).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            if attempt.hasMeasurement {
                HStack(spacing: SpacingTokens.sp3) {
                    metricPill(icon: "speedometer", text: attempt.rateLabel)
                    if let steadiness = attempt.steadinessLabel {
                        metricPill(icon: "metronome.fill", text: steadiness)
                    }
                }
            }
            if let hint = attempt.hint {
                Text(hint)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    @ViewBuilder
    private func metricPill(icon: String, text: String) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text(text)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, SpacingTokens.small)
        .padding(.vertical, SpacingTokens.tiny)
        .background(Capsule().fill(ColorTokens.Kid.surface))
    }

    @ViewBuilder
    private func readyInstruction(_ start: SyllableRaceModels.Start.ViewModel) -> some View {
        Text(start.instruction)
            .font(TypographyTokens.headline(17))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    @ViewBuilder
    private func starsRow(count: Int) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            ForEach(0 ..< 3, id: \.self) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .font(TypographyTokens.headline(20))
                    .foregroundStyle(ColorTokens.Brand.gold)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "syllableRace.stars.a11y"),
            count
        )))
    }

    // MARK: - Mic button

    @ViewBuilder
    private func micButton(start: SyllableRaceModels.Start.ViewModel) -> some View {
        let isBusy = holder.phase == .recording || holder.phase == .analyzing
        RecordMicButton(
            state: micState,
            hint: isBusy
                ? String(localized: "syllableRace.cta.listening")
                : start.instruction
        ) {
            guard !isBusy else { return }
            Task { await interactor?.performAttempt(.init()) }
        }
        .accessibilityHint(Text(start.instruction))
    }

    private var micState: RecordMicState {
        switch holder.phase {
        case .recording: return .recording
        case .analyzing: return .processing
        case .ready, .result, .completed: return .idle
        }
    }

    // MARK: - Failure block

    @ViewBuilder
    private func failureBlock(_ failure: SyllableRaceModels.Failure.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(failure.message)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            if failure.isPermissionIssue {
                HSButton(
                    String(localized: "syllableRace.cta.openSettings"),
                    style: .secondary,
                    size: .medium,
                    icon: "gear"
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    // MARK: - Completion

    @ViewBuilder
    private func completionView(_ completion: SyllableRaceModels.Complete.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.large) {
            Spacer(minLength: 0)
            LyalyaHeroView(state: completion.sessionStars >= 2 ? .celebrating : .encouraging, size: 150)
            starsRow(count: completion.sessionStars)
            Text(completion.title)
                .font(TypographyTokens.title(26).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Text(completion.subtitle)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            VStack(spacing: SpacingTokens.sp3) {
                HSButton(
                    String(localized: "syllableRace.cta.again"),
                    style: .primary,
                    icon: "arrow.counterclockwise"
                ) {
                    Task {
                        await interactor?.startSession(.init(childId: resolvedChildId))
                    }
                }
                HSButton(
                    String(localized: "syllableRace.cta.done"),
                    style: .secondary,
                    icon: "house.fill"
                ) {
                    exitGame()
                }
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.large)
    }

    // MARK: - Helpers

    private var progressValue: Double {
        let total = Double(holder.startVM?.totalRounds ?? SyllableRaceModels.roundsPerSession)
        guard total > 0 else { return 0 }
        return Double(holder.attemptVM?.roundNumber ?? 0) / total
    }

    private var mascotMood: MascotMood {
        switch holder.phase {
        case .recording: return .singing
        case .analyzing: return .thinking
        case .result, .completed:
            return (holder.attemptVM?.mascotCelebrates ?? false) ? .celebrating : .encouraging
        case .ready: return .waving
        }
    }

    // MARK: - Bootstrap (Clean Swift wiring)

    private func bootstrap() async {
        guard interactor == nil else { return }
        let presenterInstance = SyllableRacePresenter()
        presenterInstance.display = holder
        let interactorInstance = SyllableRaceInteractor(
            childId: resolvedChildId,
            audioService: container.audioService,
            raceService: container.syllableRaceService,
            childRepository: container.childRepository,
            adaptivePlanner: container.adaptivePlannerService,
            sessionPersistence: container.sessionPersistenceCoordinator
        )
        interactorInstance.presenter = presenterInstance
        presenter = presenterInstance
        interactor = interactorInstance

        await interactorInstance.startSession(.init(childId: resolvedChildId))
    }

    /// Пустой childId из навигационных выходов → активный ребёнок контейнера.
    private var resolvedChildId: String {
        childId.isEmpty ? container.currentChildId : childId
    }

    // MARK: - Rocket animation

    private func animateRocket(to height: Double) {
        if reduceMotion || calmMode {
            rocketHeight = height
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                rocketHeight = height
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SyllableRace") {
    SyllableRaceView(childId: "preview-child-1")
        .environment(AppContainer.preview())
}
#endif
