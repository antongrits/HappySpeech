import SwiftUI
import OSLog

// MARK: - RhythmView
//
// "Повтори ритм!" — Лала произносит слово по слогам с разной ударной схемой
// (например "РА-ке-та"), ребёнок повторяет. Каждый слог детектируется по RMS,
// и мы сверяем количество слогов. За 5 паттернов в сессии — до 3 звёзд.
//
// Архитектура — Clean Swift VIP с @Observable Store:
//   RhythmView (SwiftUI)
//     └── RhythmStore ──► displayLogic  ←── RhythmPresenter
//                                                    ▲
//                                                    │ Response
//                                                    │
//                                             RhythmInteractor
//                                                    ↕
//                                          AVAudioEngine + AVSpeechSynthesizer

struct RhythmView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @State private var store: RhythmStore
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rhythm")

    init(activity: SessionActivity, onComplete: @escaping (Float) -> Void) {
        self.activity = activity
        self.onComplete = onComplete

        let group = RhythmInteractor.soundGroup(for: activity.soundTarget)
        let interactor = RhythmInteractor(soundGroup: group, totalPatternsPerSession: 5)
        let presenter = RhythmPresenter()
        interactor.presenter = presenter
        let store = RhythmStore(interactor: interactor, presenter: presenter)
        _store = State(initialValue: store)
    }

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            VStack(spacing: SpacingTokens.large) {
                header
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                actionArea
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.medium)
        }
        .task {
            store.presenter.viewModel = store
            await store.interactor.loadPattern(.init(
                soundGroup: RhythmInteractor.soundGroup(for: activity.soundTarget),
                index: 0
            ))
        }
        .onChange(of: store.display.phase) { _, newPhase in
            if newPhase == .preview {
                Task { await autoAdvanceToPlaying() }
            }
        }
        .onChange(of: store.finalScoreToReport) { _, value in
            if let score = value { onComplete(score) }
        }
        .onDisappear {
            Task { await store.interactor.cancel() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Игра «Повтори ритм». Слушай Лалу и повторяй слово по слогам."))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .center, spacing: SpacingTokens.tiny) {
            HStack {
                Text(String(localized: "Повтори ритм"))
                    .font(TypographyTokens.title())
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(String(
                    format: String(localized: "%d из %d"),
                    min(store.display.patternIndex + 1, store.display.totalPatterns),
                    store.display.totalPatterns
                ))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            HSProgressBar(value: store.display.progressFraction, style: .kid)
                .frame(height: 10)
        }
    }

    // MARK: - Content (phase switcher)

    @ViewBuilder
    private var content: some View {
        switch store.display.phase {
        case .loading:
            ProgressView().controlSize(.large)
        case .preview:
            previewContent
        case .playing:
            playingContent
        case .recording:
            recordingContent
        case .feedback:
            feedbackContent
        case .completed:
            completedContent
        }
    }

    // MARK: - Preview

    private var previewContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Text(store.display.emoji)
                .font(.system(size: 88))
                .accessibilityHidden(true)
            Text(store.display.targetWord)
                .font(TypographyTokens.title(28))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(store.display.displayPattern)
                .font(TypographyTokens.headline(20))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .tracking(2)
                .accessibilityLabel(String(
                    format: String(localized: "Ритмический рисунок: %@"),
                    store.display.displayPattern
                ))
            beatsRow
        }
    }

    // MARK: - Playing

    private var playingContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Text(store.display.emoji)
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(String(localized: "Слушай внимательно…"))
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Brand.primary)
            beatsRow
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Text(String(localized: "Теперь ты!"))
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text(store.display.targetWord)
                .font(TypographyTokens.title(30))
                .foregroundStyle(ColorTokens.Kid.ink)
                .accessibilityLabel(String(
                    format: String(localized: "Скажи слово %@"),
                    store.display.targetWord
                ))

            rmsMeter

            Text(String(
                format: String(localized: "Обнаружено слогов: %d из %d"),
                store.display.detectedBeats,
                store.display.beats.count
            ))
            .font(TypographyTokens.caption())
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .accessibilityAddTraits(.updatesFrequently)

            beatsRow
        }
    }

    // MARK: - Feedback

    private var feedbackContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Text(store.display.feedbackCorrect ? "🎉" : "💫")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(store.display.feedbackText)
                .font(TypographyTokens.headline())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < store.display.starsPreview ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            i < store.display.starsPreview
                                ? ColorTokens.Brand.primary
                                : ColorTokens.Kid.inkSoft
                        )
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(String(
                format: String(localized: "Заработано звёзд: %d из 3"),
                store.display.starsPreview
            ))
            beatsRow
        }
    }

    // MARK: - Completed

    private var completedContent: some View {
        VStack(spacing: SpacingTokens.large) {
            Text("🏆")
                .font(.system(size: 72))
                .accessibilityHidden(true)
            Text(store.display.completionMessage)
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: SpacingTokens.tiny) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < store.display.starsEarned ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            i < store.display.starsEarned
                                ? ColorTokens.Brand.primary
                                : ColorTokens.Kid.inkSoft
                        )
                        .scaleEffect(i < store.display.starsEarned ? 1.0 : 0.9)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(String(
                format: String(localized: "Звёзд заработано: %d из 3"),
                store.display.starsEarned
            ))
            Text(store.display.scoreLabel)
                .font(TypographyTokens.body())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    // MARK: - Beats row

    private var beatsRow: some View {
        HStack(spacing: SpacingTokens.small) {
            ForEach(store.display.beats.indices, id: \.self) { i in
                BeatDot(
                    strength: store.display.beats[i].strength,
                    isActive: i == store.display.currentActiveBeat,
                    wasHit: store.display.beats[i].wasHit,
                    reduceMotion: reduceMotion
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: String(localized: "Паттерн из %d слогов"),
            store.display.beats.count
        ))
    }

    // MARK: - RMS meter

    private var rmsMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ColorTokens.Kid.surfaceAlt)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primary, ColorTokens.Brand.lilac],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(store.display.rmsLevel))
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.1),
                        value: store.display.rmsLevel
                    )
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    // MARK: - Action area

    @ViewBuilder
    private var actionArea: some View {
        switch store.display.phase {
        case .preview:
            HSButton(String(localized: "Слушай!"), style: .primary) {
                Task { await store.interactor.playPattern(.init()) }
            }
        case .completed:
            HSButton(String(localized: "Завершить"), style: .primary) {
                store.finalScoreToReport = store.display.finalScore
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func autoAdvanceToPlaying() async {
        // Держим .preview визуально, позволяем пользователю нажать CTA.
        // Этот метод оставлен как hook — если дизайн попросит автопереход,
        // его можно активировать через Task.sleep + playPattern.
    }
}

// MARK: - BeatDot

private struct BeatDot: View {
    let strength: BeatStrength
    let isActive: Bool
    let wasHit: Bool
    let reduceMotion: Bool

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: dotSize, height: dotSize)
            .overlay(
                Circle()
                    .stroke(wasHit ? Color.green : .clear, lineWidth: 3)
            )
            .scaleEffect(isActive ? 1.2 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6),
                value: isActive
            )
    }

    private var dotSize: CGFloat {
        strength == .strong ? 54 : 36
    }

    private var fillColor: Color {
        switch (strength, isActive) {
        case (.strong, true):  return ColorTokens.Brand.primary
        case (.strong, false): return ColorTokens.Brand.lilac
        case (.weak,   true):  return ColorTokens.Brand.primary.opacity(0.8)
        case (.weak,   false): return ColorTokens.Kid.surfaceAlt
        }
    }
}

// MARK: - RhythmStore
//
// Тонкий @Observable контейнер, реализующий RhythmDisplayLogic. Presenter
// пушит в него ViewModels, View читает `display`.

@Observable @MainActor
final class RhythmStore: RhythmDisplayLogic {

    let interactor: RhythmInteractor
    let presenter: RhythmPresenter
    var display = RhythmDisplay()

    /// Финальный score, который View отдаст в onComplete. Nil пока игра идёт.
    var finalScoreToReport: Float?

    init(interactor: RhythmInteractor, presenter: RhythmPresenter) {
        self.interactor = interactor
        self.presenter = presenter
    }

    // MARK: - RhythmDisplayLogic

    func displayLoadPattern(_ viewModel: RhythmModels.LoadPattern.ViewModel) {
        display.beats = viewModel.beats
        display.syllableWord = viewModel.syllableWord
        display.targetWord = viewModel.targetWord
        display.displayPattern = viewModel.displayPattern
        display.emoji = viewModel.emoji
        display.patternIndex = viewModel.patternIndex
        display.totalPatterns = viewModel.totalPatterns
        display.progressFraction = viewModel.progressFraction
        display.currentActiveBeat = -1
        display.detectedBeats = 0
        display.rmsLevel = 0
        display.phase = .preview
    }

    func displayPlayPattern(_ viewModel: RhythmModels.PlayPattern.ViewModel) {
        display.phase = .playing
        display.currentActiveBeat = viewModel.activeBeatIndex
    }

    func displayStartRecord(_ viewModel: RhythmModels.StartRecord.ViewModel) {
        display.phase = .recording
        display.currentActiveBeat = -1
        display.detectedBeats = 0
        display.rmsLevel = 0
        display.beats = display.beats.map {
            RhythmBeatDisplay(strength: $0.strength, isActive: false, wasHit: false)
        }
    }

    func displayUpdateRMS(_ viewModel: RhythmModels.UpdateRMS.ViewModel) {
        display.rmsLevel = viewModel.rmsLevel
        display.detectedBeats = viewModel.detectedBeats
    }

    func displayEvaluateRhythm(_ viewModel: RhythmModels.EvaluateRhythm.ViewModel) {
        display.feedbackText = viewModel.feedbackText
        display.feedbackCorrect = viewModel.feedbackCorrect
        display.starsPreview = viewModel.starsPreview
        display.lastScore = viewModel.lastScore
        // Отмечаем попадания в биты.
        var updated = display.beats
        for i in updated.indices where i < viewModel.beatsWasHit.count {
            updated[i] = RhythmBeatDisplay(
                strength: updated[i].strength,
                isActive: false,
                wasHit: viewModel.beatsWasHit[i]
            )
        }
        display.beats = updated
        display.phase = .feedback
    }

    func displayNextPattern(_ viewModel: RhythmModels.NextPattern.ViewModel) {
        display.phase = .loading
    }

    func displayComplete(_ viewModel: RhythmModels.Complete.ViewModel) {
        display.completionMessage = viewModel.completionMessage
        display.scoreLabel = viewModel.scoreLabel
        display.starsEarned = viewModel.starsEarned
        display.finalScore = viewModel.finalScore
        display.phase = .completed
    }
}

#Preview {
    RhythmView(
        activity: SessionActivity(
            id: "preview",
            gameType: .rhythm,
            lessonId: "l1",
            soundTarget: "Р",
            difficulty: 1,
            isCompleted: false,
            score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
