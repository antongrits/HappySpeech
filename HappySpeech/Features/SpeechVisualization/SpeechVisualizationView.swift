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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SpeechVisualization.View")

    init(word: String, targetSound: String) {
        self.word = word
        self.targetSound = targetSound
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = holder.loadVM {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: SpacingTokens.sp4) {
                            headerSection
                            wordSection(viewModel: viewModel)
                            spectrogramSection
                            summarySection
                            primaryCTA
                        }
                        .padding(.horizontal, SpacingTokens.screenEdge)
                        .padding(.vertical, SpacingTokens.sp4)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    // H v18 — Lyalya hero на loading-экране.
                    VStack(spacing: SpacingTokens.sp3) {
                        LyalyaMascotView(state: .thinking, size: 80)
                            .accessibilityHidden(true)
                        ProgressView()
                            .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(ColorTokens.Kid.bg.ignoresSafeArea())
            .navigationTitle(Text("karaoke.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
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

    // MARK: - Sections

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Picker(
                String(localized: "karaoke.mode.picker.title"),
                selection: Binding<VisualizationMode>(
                    get: { holder.modeVM?.mode ?? .listen },
                    set: { newValue in
                        Task { await interactor?.setMode(request: .init(mode: newValue)) }
                    }
                )
            ) {
                ForEach([VisualizationMode.listen, .practice], id: \.self) { mode in
                    Text(mode.localizedTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if let modeVM = holder.modeVM {
                Text(modeVM.instructionText)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .lineLimit(nil)
            }
        }
    }

    @ViewBuilder
    private func wordSection(viewModel: SpeechVisualizationModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(viewModel.wordDisplay)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .accessibilityHidden(true)

            KaraokeWordView(
                syllables: viewModel.syllables,
                activeSyllableID: holder.activeSyllableID
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(ColorTokens.Kid.surface)
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        )
    }

    @ViewBuilder
    private var spectrogramSection: some View {
        // Reuse существующего компонента (referenceSpectrogram=nil → live-only).
        SpectrogramVisualizerView(referenceSpectrogram: nil, style: .ocean)
            .frame(height: 180)
            .accessibilityLabel(Text("karaoke.spectrogram.a11y"))
    }

    @ViewBuilder
    private var summarySection: some View {
        if let scoreVM = holder.scoreVM {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: scoreVM.confettiBurst ? "sparkles" : "speaker.wave.2")
                    .font(.title2)
                    .foregroundStyle(scoreVM.summaryColor)
                    .accessibilityHidden(true)
                Text(scoreVM.summaryText)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.sp3)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(scoreVM.summaryColor.opacity(0.12))
            )
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var primaryCTA: some View {
        Button {
            Task { await tapPrimary() }
        } label: {
            Text(holder.modeVM?.primaryButtonTitle ?? String(localized: "karaoke.cta.listen"))
                .font(TypographyTokens.cta())
                .frame(maxWidth: .infinity)
                .padding(.vertical, SpacingTokens.sp3)
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorTokens.Brand.primary)
        .accessibilityHint(Text("karaoke.cta.hint"))
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
            // Подсветка от слога к слогу (эмулируем real-time).
            await playListen()
            holder.isPlaying = false
        } else {
            let duration = Date().timeIntervalSince(practiceStartTime ?? Date())
            practiceStartTime = nil
            await interactor?.computeScore(request: .init(attemptDurationSeconds: duration))
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

// NOTE deferred to Block Q (test coverage): snapshot, accuracy color thresholds.
