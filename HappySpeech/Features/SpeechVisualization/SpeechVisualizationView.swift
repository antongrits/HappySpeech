import OSLog
import SwiftUI

// MARK: - SpeechVisualizationDisplayLogic

@MainActor
protocol SpeechVisualizationDisplayLogic: AnyObject {
    func displayLoad(viewModel: SpeechVisualizationModels.Load.ViewModel) async
    func displaySetMode(viewModel: SpeechVisualizationModels.SetMode.ViewModel) async
    func displayScore(viewModel: SpeechVisualizationModels.Score.ViewModel) async
}

// MARK: - SpeechVisualizationViewModel

@MainActor
@Observable
final class SpeechVisualizationViewModelHolder: SpeechVisualizationDisplayLogic {
    var loadVM: SpeechVisualizationModels.Load.ViewModel?
    var modeVM: SpeechVisualizationModels.SetMode.ViewModel?
    var scoreVM: SpeechVisualizationModels.Score.ViewModel?
    var activeSyllableID: String?
    var isPlaying: Bool = false

    func displayLoad(viewModel: SpeechVisualizationModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }
    func displaySetMode(viewModel: SpeechVisualizationModels.SetMode.ViewModel) async {
        self.modeVM = viewModel
    }
    func displayScore(viewModel: SpeechVisualizationModels.Score.ViewModel) async {
        self.scoreVM = viewModel
        // Заменим syllables в loadVM на updated.
        if let lvm = loadVM {
            self.loadVM = SpeechVisualizationModels.Load.ViewModel(
                title: lvm.title,
                wordDisplay: lvm.wordDisplay,
                syllables: viewModel.updatedSyllables,
                totalDurationLabel: lvm.totalDurationLabel
            )
        }
    }
}

// MARK: - SpeechVisualizationView (Clean Swift: View)
//
// Block S.3 v16 — Karaoke-mode визуализация.
//
// Layout:
//   1. Title bar + mode picker (listen/practice)
//   2. Word as syllable pills (KaraokeWordView)
//   3. SpectrogramVisualizerView (existing reusable component)
//   4. Primary CTA button (Listen / Record)
//   5. Score summary (после practice)

struct SpeechVisualizationView: View {

    let word: String
    let targetSound: String

    @State private var holder = SpeechVisualizationViewModelHolder()
    @State private var interactor: SpeechVisualizationInteractor?
    @State private var presenter: SpeechVisualizationPresenter?
    @State private var practiceStartTime: Date?
    @State private var isRecordingPractice = false

    @Environment(AppContainer.self) private var container
    @Environment(\.exitToParentHome) private var exitToParentHome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SpeechVisualization.View")

    init(word: String, targetSound: String) {
        self.word = word
        self.targetSound = targetSound
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = holder.loadVM {
                    mainContent(viewModel: viewModel)
                } else {
                    loadingView
                }
            }
            // Тёплый статичный однотонный фон (кремовое семейство).
            .background(
                ZStack {
                    ColorTokens.Kid.bg.ignoresSafeArea()
                    HSMeshGradientBackground(palette: .kidWarm, animated: false)
                        .ignoresSafeArea()
                        .opacity(colorScheme == .dark ? 0.18 : 0.30)
                        .blendMode(.softLight)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            )
            .navigationTitle(Text("karaoke.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { exitToParentHome() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("karaoke.close.a11y"))
                }
            }
        }
        .task { await setupAndLoad() }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .thinking, size: 80)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main Content
    //
    // open-design layout (non-scrollable flex column):
    //   1. topbar (back + title + hint) — handled by NavigationStack
    //   2. task section: lead label + large word + sound chip
    //   3. mascot row: Ляля + speech bubble
    //   4. viz-card (flex-fill, dark canvas, heat legend + live blip inside)
    //   5. controls row: listen pill | mic circle | retry ghost

    private func mainContent(viewModel: SpeechVisualizationModels.Load.ViewModel) -> some View {
        GeometryReader { geo in
            VStack(spacing: SpacingTokens.sp3) {
                // Task section
                taskSection(viewModel: viewModel)

                // Mascot row
                mascotRow

                // Viz card — flex fills remaining space
                vizCard(viewModel: viewModel)
                    .frame(minHeight: max(160, geo.size.height * 0.38))

                // Score summary (shown above controls when available)
                if let scoreVM = holder.scoreVM {
                    summaryBadge(scoreVM: scoreVM)
                }

                // Controls
                controlsRow
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp4)
        }
        .safeAreaPadding(.bottom)
    }

    // MARK: - Task Section
    //
    // open-design: .task — "Задание N из M · sound-name" lead + "Скажи: Р-р-р" h2 + sound-chip pill.

    private func taskSection(viewModel: SpeechVisualizationModels.Load.ViewModel) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp3) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                if let modeVM = holder.modeVM {
                    Text(modeVM.instructionText)
                        .font(TypographyTokens.caption(14).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                // Word display with active syllable highlights (karaoke)
                KaraokeWordView(
                    syllables: viewModel.syllables,
                    activeSyllableID: holder.activeSyllableID
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sound chip (open-design: .sound-chip — target sound letter badge)
            SoundBadge(letter: targetSound)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mascot Row (open-design: .mascot-row — Ляля + speech bubble)

    private var mascotRow: some View {
        HStack(alignment: .center, spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: mascotState, size: 54)
                .accessibilityHidden(true)

            // Speech bubble
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
                    .frame(width: 14, height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: -7)

                Text(bubbleText)
                    .font(TypographyTokens.body(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.vertical, SpacingTokens.sp2)
                    .padding(.horizontal, SpacingTokens.sp3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                    )
                    .padding(.leading, SpacingTokens.sp2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text(bubbleText))
    }

    private var mascotState: LyalyaState {
        if holder.isPlaying { return .happy }
        if holder.scoreVM != nil { return .celebrating }
        return .idle
    }

    private var bubbleText: String {
        if holder.isPlaying {
            return String(localized: "karaoke.bubble.listen",
                          defaultValue: "Слушай внимательно!")
        }
        if holder.scoreVM?.confettiBurst == true {
            return String(localized: "karaoke.bubble.great",
                          defaultValue: "Отлично! Молодец!")
        }
        if holder.modeVM?.mode == .practice {
            return String(localized: "karaoke.bubble.practice",
                          defaultValue: "Повтори так же — держи голос в зоне!")
        }
        return String(localized: "karaoke.bubble.ready",
                      defaultValue: "Послушай, потом попробуй сам.")
    }

    // MARK: - Viz Card (open-design: .viz-card — dark canvas, heat legend + blip inside)

    @ViewBuilder
    private func vizCard(viewModel: SpeechVisualizationModels.Load.ViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            // Dark warm canvas background
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Viz.canvasBg)

            VStack(alignment: .leading, spacing: 0) {
                // viz-head: title/blip + heat legend
                vizCardHeader

                // Spectrogram (fills remaining space, no fixed height)
                SpectrogramVisualizerView(referenceSpectrogram: nil, style: .warm)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: RadiusTokens.concentric(
                                outer: RadiusTokens.lg,
                                inset: SpacingTokens.sp3
                            ),
                            style: .continuous
                        )
                    )
                    .padding(.horizontal, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp3)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel(Text("karaoke.spectrogram.a11y"))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(
                    Color(hue: 0.06, saturation: 0.6, brightness: 0.22),
                    lineWidth: 1
                )
        )
        .shadow(
            color: ColorTokens.Overlay.shadowMedium,
            radius: 14,
            y: 8
        )
    }

    // open-design .viz-head: recording blip + title, heat ramp label
    private var vizCardHeader: some View {
        HStack(spacing: SpacingTokens.sp2) {
            // live blip (open-design: animated dot)
            Circle()
                .fill(ColorTokens.Brand.primary)
                .frame(width: 9, height: 9)
                .opacity(holder.isPlaying ? 1.0 : 0.55)
                .animation(
                    holder.isPlaying && !reduceMotion
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: holder.isPlaying
                )

            Text(holder.modeVM?.mode == .practice
                 ? String(localized: "karaoke.vizcard.practice", defaultValue: "Твой голос · запись")
                 : String(localized: "karaoke.vizcard.listen", defaultValue: "Спектр голоса · образец"))
                .font(TypographyTokens.caption(13).weight(.heavy))
                .foregroundStyle(Color(red: 1.0, green: 0.9, blue: 0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: SpacingTokens.sp2)

            // Heat legend (open-design: тихо · ramp · звонко)
            heatLegendInline
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.top, SpacingTokens.sp3)
        .padding(.bottom, SpacingTokens.sp2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("karaoke.heat.a11y"))
    }

    private var heatLegendInline: some View {
        HStack(spacing: SpacingTokens.sp1) {
            Text("karaoke.heat.quiet")
                .font(TypographyTokens.caption(9).weight(.bold))
                .foregroundStyle(Color(red: 0.91, green: 0.80, blue: 0.71))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            ColorTokens.Brand.primary.opacity(0.35),
                            ColorTokens.Brand.primary,
                            ColorTokens.Brand.primaryHi,
                            ColorTokens.Brand.butter
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 8)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            Text("karaoke.heat.loud")
                .font(TypographyTokens.caption(9).weight(.bold))
                .foregroundStyle(Color(red: 0.91, green: 0.80, blue: 0.71))
        }
    }

    // MARK: - Summary Badge (floats above controls)

    @ViewBuilder
    private func summaryBadge(scoreVM: SpeechVisualizationModels.Score.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            // Checkmark badge (open-design: .feedback .badge — mint circle)
            ZStack {
                Circle()
                    .fill(scoreVM.confettiBurst
                          ? ColorTokens.Brand.butter
                          : ColorTokens.Brand.mint)
                    .frame(width: 28, height: 28)
                Image(systemName: scoreVM.confettiBurst ? "star.fill" : "checkmark")
                    .font(TypographyTokens.caption(13).weight(.heavy))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            .hsSymbolEffect(.variableColor, value: scoreVM.summaryText)

            Text(scoreVM.summaryText)
                .font(TypographyTokens.headline(14).weight(.heavy))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            Capsule()
                .fill(ColorTokens.Kid.surface.opacity(0.88))
                .shadow(color: ColorTokens.Overlay.shadow, radius: 10, y: 4)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    scoreVM.summaryColor.opacity(0.40),
                    lineWidth: 1
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(reduceMotion ? .none : MotionTokens.spring, value: holder.scoreVM != nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreVM.summaryText)
    }

    // MARK: - Controls Row (open-design: pill left | mic center | ghost right)

    private var controlsRow: some View {
        HStack(spacing: SpacingTokens.sp4) {
            // Left — "Послушай образец" pill (open-design .pill)
            Button {
                Task { await playListen() }
            } label: {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "play.fill")
                        .font(TypographyTokens.caption(13))
                    Text(String(localized: "karaoke.cta.listen",
                                defaultValue: "Слушать"))
                        .font(TypographyTokens.caption(13).weight(.heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.vertical, SpacingTokens.sp3)
                .padding(.horizontal, SpacingTokens.sp3)
                .frame(maxWidth: 110)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                .strokeBorder(
                                    ColorTokens.Brand.primary.opacity(0.45),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: ColorTokens.Overlay.shadow, radius: 8, y: 3)
                )
            }
            .disabled(holder.isPlaying)
            .accessibilityLabel(Text("karaoke.cta.listen"))

            Spacer(minLength: 0)

            // Center — mic button (open-design: large coral circle, pulsing rings)
            Button {
                Task { await tapPrimary() }
            } label: {
                ZStack {
                    // Pulsing ring (only in practice-recording mode, not reduceMotion)
                    if holder.isPlaying && !reduceMotion {
                        Circle()
                            .stroke(ColorTokens.Brand.primary.opacity(0.35), lineWidth: 2)
                            .frame(width: 100, height: 100)
                            .scaleEffect(1.15)
                            .opacity(0)
                            .animation(
                                .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                                value: holder.isPlaying
                            )
                    }
                    // Main circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                                center: .init(x: 0.4, y: 0.3),
                                startRadius: 4,
                                endRadius: 44
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(
                            color: ColorTokens.Brand.primary.opacity(0.50),
                            radius: 16,
                            y: 6
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                                .frame(width: 84, height: 84)
                        )
                    Image(
                        systemName: holder.isPlaying
                            ? (holder.modeVM?.mode == .practice ? "stop.fill" : "pause.fill")
                            : "mic.fill"
                    )
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(Color.white)
                }
                .frame(width: 84, height: 84)
            }
            .accessibilityLabel(
                holder.isPlaying
                    ? Text("karaoke.cta.stop")
                    : Text("karaoke.cta.record")
            )
            .accessibilityHint(Text("karaoke.cta.hint"))

            Spacer(minLength: 0)

            // Right — "Ещё раз" ghost button (open-design: .ghost — surface bg, no tint)
            Button {
                holder.activeSyllableID = nil
                // Reset score display so user can re-attempt
                // (keeping interactor state intact for new recording)
            } label: {
                VStack(spacing: SpacingTokens.sp1) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .frame(width: 54, height: 54)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                            )
                            .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 2)
                        Image(systemName: "arrow.counterclockwise")
                            .font(TypographyTokens.headline(20))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    Text(String(localized: "karaoke.cta.again", defaultValue: "Ещё раз"))
                        .font(TypographyTokens.caption(11).weight(.heavy))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
            }
            .frame(maxWidth: 96)
            .accessibilityLabel(Text("karaoke.cta.again"))
        }
    }

    // MARK: - Actions

    private func tapPrimary() async {
        guard let modeVM = holder.modeVM else { return }
        switch modeVM.mode {
        case .listen:
            await playListen()
        case .practice:
            await togglePractice()
        }
    }

    private func playListen() async {
        guard let viewModel = holder.loadVM else { return }
        // Анимируем последовательную подсветку слогов с длительностью каждого.
        for syllable in viewModel.syllables {
            holder.activeSyllableID = syllable.id
            try? await Task.sleep(for: .seconds(syllable.durationSeconds))
        }
        holder.activeSyllableID = nil
    }

    private func togglePractice() async {
        if practiceStartTime == nil {
            practiceStartTime = Date()
            holder.isPlaying = true
            // Старт реальной записи речи ребёнка (для акустической оценки).
            await startPracticeRecording()
            // Подсветка от слога к слогу (визуальный гид во время записи).
            await playListen()
            holder.isPlaying = false
        } else {
            let duration = Date().timeIntervalSince(practiceStartTime ?? Date())
            practiceStartTime = nil
            if isRecordingPractice {
                // Реальная акустическая оценка из записанного аудио.
                isRecordingPractice = false
                let url = try? await container.audioService.stopRecording()
                await interactor?.computeScore(fromAudioURL: url)
            } else {
                // Запись недоступна — честная оценка только темпа по длительности.
                await interactor?.computeScore(request: .init(attemptDurationSeconds: duration))
            }
        }
    }

    private func startPracticeRecording() async {
        let audio = container.audioService
        if !audio.isPermissionGranted {
            let granted = await audio.requestPermission()
            guard granted else { isRecordingPractice = false; return }
        }
        do {
            try await audio.startRecording()
            isRecordingPractice = true
        } catch {
            Self.logger.error("practice recording failed: \(error.localizedDescription, privacy: .public)")
            isRecordingPractice = false
        }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = SpeechVisualizationPresenter(displayLogic: holder)
            let interactor = SpeechVisualizationInteractor()
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
        }
        await interactor?.load(request: .init(word: word, targetSound: targetSound))
        await interactor?.setMode(request: .init(mode: .listen))
    }
}

// MARK: - SoundBadge
//
// open-design: .sound-chip — circular pill showing target phoneme letter.
// Used inside SpeechVisualizationView task section; intentionally simple
// (no tap action, display-only).

private struct SoundBadge: View {
    let letter: String

    var body: some View {
        Text(letter)
            .font(TypographyTokens.title(20).weight(.black))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.40), radius: 8, y: 3)
            )
            .accessibilityLabel(
                String(localized: "karaoke.soundbadge.a11y",
                       defaultValue: "Целевой звук: \(letter)")
            )
    }
}

// NOTE deferred to Block Q (test coverage): snapshot, accuracy color thresholds.
