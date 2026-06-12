import SwiftUI
import UIKit

// MARK: - AcousticMirrorViewModelHolder

/// Display-слой VIP: зеркалит state презентера в @Observable для SwiftUI.
@MainActor
@Observable
final class AcousticMirrorViewModelHolder: AcousticMirrorDisplayLogic {

    var startVM: AcousticMirrorModels.Start.ViewModel?
    var attemptVM: AcousticMirrorModels.Attempt.ViewModel?
    var completeVM: AcousticMirrorModels.Complete.ViewModel?
    var failureVM: AcousticMirrorModels.Failure.ViewModel?
    var phase: AcousticMirrorModels.Phase = .ready

    func displayStart(_ viewModel: AcousticMirrorModels.Start.ViewModel) {
        startVM = viewModel
        attemptVM = nil
        completeVM = nil
        failureVM = nil
    }

    func displayPhase(_ phase: AcousticMirrorModels.Phase) {
        self.phase = phase
        if phase == .recording || phase == .analyzing {
            failureVM = nil
        }
    }

    func displayAttempt(_ viewModel: AcousticMirrorModels.Attempt.ViewModel) {
        attemptVM = viewModel
    }

    func displayComplete(_ viewModel: AcousticMirrorModels.Complete.ViewModel) {
        completeVM = viewModel
    }

    func displayFailure(_ viewModel: AcousticMirrorModels.Failure.ViewModel) {
        failureVM = viewModel
    }
}

// MARK: - AcousticMirrorView (Clean Swift: View)
//
// «Акустическое зеркало» (kid) — ребёнок тянет С-С-С / Ш-Ш-Ш, а шарик на
// «горке» показывает, куда реально смещается его звук (on-device vDSP-акустика,
// без сети и без ML-моделей). Тёплая палитра, Ляля, Reduced Motion, VoiceOver.

struct AcousticMirrorView: View {

    let childId: String

    @State private var holder = AcousticMirrorViewModelHolder()
    @State private var interactor: AcousticMirrorInteractor?
    @State private var presenter: AcousticMirrorPresenter?
    /// Анимируемая позиция шарика (0 — Ш, 1 — С).
    @State private var ballPosition: Double = 0.5

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
            .navigationTitle(Text(String(localized: "acousticMirror.screen.title")))
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
                    .accessibilityLabel(Text(String(localized: "acousticMirror.close.a11y")))
                }
            }
            .task { await bootstrap() }
            .onChange(of: holder.attemptVM?.continuumPosition) { _, newValue in
                guard let newValue, holder.attemptVM?.hasMeasurement == true else { return }
                animateBall(to: newValue)
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
    private func sessionView(_ start: AcousticMirrorModels.Start.ViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sp4) {
                soundPicker(selected: start.targetSound)

                HSProgressBar(
                    value: progressValue,
                    style: .kid,
                    tint: ColorTokens.Brand.primary
                )
                .accessibilityLabel(Text(String(
                    format: String(localized: "acousticMirror.progress.a11y"),
                    holder.attemptVM?.roundNumber ?? 0,
                    start.totalRounds
                )))

                HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
                    VStack(spacing: SpacingTokens.sp4) {
                        Text(start.targetHint)
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)

                        continuumGauge(target: start.targetSound)

                        resultBlock
                    }
                }

                micButton(start: start)

                if let failure = holder.failureVM {
                    failureBlock(failure)
                }

                HStack {
                    Spacer()
                    HSMascotView(mood: mascotMood, size: 92)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp4)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Sound picker

    /// Переключатель целевого звука: пары «свистящий ↔ шипящий».
    @ViewBuilder
    private func soundPicker(selected: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(AcousticMirrorModels.supportedSounds, id: \.self) { sound in
                    Button {
                        guard sound != selected else { return }
                        Task { await interactor?.switchTargetSound(to: sound) }
                    } label: {
                        Text(sound)
                            .font(TypographyTokens.headline(18))
                            .foregroundStyle(
                                sound == selected
                                    ? ColorTokens.Overlay.onAccent
                                    : ColorTokens.Kid.ink
                            )
                            .frame(minWidth: 44, minHeight: 44)
                            .background(
                                Circle().fill(
                                    sound == selected
                                        ? ColorTokens.Brand.primary
                                        : ColorTokens.Kid.surface
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(
                        format: String(localized: "acousticMirror.sound.a11y"),
                        sound
                    )))
                    .accessibilityAddTraits(sound == selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, SpacingTokens.micro)
        }
    }

    // MARK: - Continuum gauge («горка» Ш ↔ С)

    @ViewBuilder
    private func continuumGauge(target: String) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // Дорожка: тёплый градиент от полюса Ш (rose) к полюсу С (butter).
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ColorTokens.Brand.rose.opacity(0.55),
                                    ColorTokens.Brand.butter.opacity(0.55),
                                    ColorTokens.Brand.gold.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 26)

                    // Целевая зона.
                    targetZone(width: width)

                    // Шарик-индикатор позиции звука ребёнка.
                    if holder.attemptVM?.hasMeasurement == true {
                        Circle()
                            .fill(ColorTokens.Brand.primary)
                            .overlay(
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                            )
                            .frame(width: 38, height: 38)
                            .offset(x: ballOffset(width: width), y: -6)
                            .shadow(color: ColorTokens.Brand.primary.opacity(0.35), radius: 6, y: 2)
                    }
                }
            }
            .frame(height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(gaugeA11yLabel))

            HStack {
                Text(String(localized: "acousticMirror.pole.sh.label"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Brand.rose)
                Spacer()
                Text(String(localized: "acousticMirror.pole.s.label"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Brand.gold)
            }
            .accessibilityHidden(true)
        }
    }

    /// Подсветка целевой трети дорожки.
    @ViewBuilder
    private func targetZone(width: CGFloat) -> some View {
        let isWhistlingTarget = isWhistlingPole
        let zoneWidth = width * 0.32
        RoundedRectangle(cornerRadius: RadiusTokens.button)
            .strokeBorder(ColorTokens.Brand.primary, lineWidth: 2)
            .frame(width: zoneWidth, height: 32)
            .offset(x: isWhistlingTarget ? width - zoneWidth : 0, y: -3)
            .accessibilityHidden(true)
    }

    private func ballOffset(width: CGFloat) -> CGFloat {
        let usable = max(0, width - 38)
        return usable * CGFloat(min(1, max(0, ballPosition)))
    }

    private var isWhistlingPole: Bool {
        SibilantPole.pole(forTargetSound: holder.startVM?.targetSound ?? "С") == .whistling
    }

    private var gaugeA11yLabel: String {
        guard let attempt = holder.attemptVM, attempt.hasMeasurement else {
            return String(localized: "acousticMirror.gauge.empty.a11y")
        }
        let percent = Int((attempt.continuumPosition * 100).rounded())
        return String(
            format: String(localized: "acousticMirror.gauge.position.a11y"),
            percent
        )
    }

    // MARK: - Result block

    @ViewBuilder
    private var resultBlock: some View {
        switch holder.phase {
        case .recording:
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .hsSymbolEffect(.variableColor, value: holder.phase == .recording)
                    .accessibilityHidden(true)
                Text(holder.startVM?.instruction ?? "")
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
        case .analyzing:
            ProgressView(String(localized: "acousticMirror.analyzing"))
                .controlSize(.regular)
        case .result, .completed:
            if let attempt = holder.attemptVM {
                VStack(spacing: SpacingTokens.sp2) {
                    starsRow(count: attempt.stars)
                    Text(attempt.title)
                        .font(TypographyTokens.title(22).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                    if let hint = attempt.hint {
                        Text(hint)
                            .font(TypographyTokens.body(15))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                }
            } else {
                readyInstruction
            }
        case .ready:
            readyInstruction
        }
    }

    @ViewBuilder
    private var readyInstruction: some View {
        Text(holder.startVM?.instruction ?? "")
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
            format: String(localized: "acousticMirror.stars.a11y"),
            count
        )))
    }

    // MARK: - Mic button

    @ViewBuilder
    private func micButton(start: AcousticMirrorModels.Start.ViewModel) -> some View {
        let isBusy = holder.phase == .recording || holder.phase == .analyzing
        HSButton(
            isBusy
                ? String(localized: "acousticMirror.cta.listening")
                : String(localized: "acousticMirror.cta.start"),
            style: .primary,
            icon: "mic.fill",
            isLoading: holder.phase == .analyzing
        ) {
            guard !isBusy else { return }
            Task { await interactor?.performAttempt(.init()) }
        }
        .disabled(isBusy)
        .accessibilityHint(Text(start.instruction))
    }

    // MARK: - Failure block

    @ViewBuilder
    private func failureBlock(_ failure: AcousticMirrorModels.Failure.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(failure.message)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            if failure.isPermissionIssue {
                HSButton(
                    String(localized: "acousticMirror.cta.openSettings"),
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
    private func completionView(_ completion: AcousticMirrorModels.Complete.ViewModel) -> some View {
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
                    String(localized: "acousticMirror.cta.again"),
                    style: .primary,
                    icon: "arrow.counterclockwise"
                ) {
                    Task {
                        await interactor?.startSession(
                            .init(childId: childId, preferredSound: holder.startVM?.targetSound ?? "")
                        )
                    }
                }
                HSButton(
                    String(localized: "acousticMirror.cta.done"),
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
        let total = Double(holder.startVM?.totalRounds ?? AcousticMirrorModels.roundsPerSession)
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
        let presenterInstance = AcousticMirrorPresenter()
        presenterInstance.display = holder
        let interactorInstance = AcousticMirrorInteractor(
            childId: resolvedChildId,
            audioService: container.audioService,
            mirrorService: container.acousticMirrorService,
            childRepository: container.childRepository,
            adaptivePlanner: container.adaptivePlannerService,
            sessionPersistence: container.sessionPersistenceCoordinator
        )
        interactorInstance.presenter = presenterInstance
        presenter = presenterInstance
        interactor = interactorInstance

        await interactorInstance.startSession(
            .init(childId: resolvedChildId, preferredSound: "")
        )
    }

    /// Пустой childId из навигационных выходов → активный ребёнок контейнера.
    private var resolvedChildId: String {
        childId.isEmpty ? container.currentChildId : childId
    }

    // MARK: - Ball animation

    private func animateBall(to position: Double) {
        if reduceMotion || calmMode {
            ballPosition = position
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                ballPosition = position
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AcousticMirror") {
    AcousticMirrorView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif
