import SwiftUI
import OSLog

// MARK: - RhythmView
//
// "Повтори ритм": система показывает последовательность тапов с паузами,
// ребёнок должен повторить. Развивает слоговой анализ (1 тап = 1 слог).
// Последовательности увеличиваются: 2 → 3 → 4 → 5 тапов за 4 раунда.
//
// Score = (правильные_раунды / всего_раундов).

struct RhythmView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @State private var phase: Phase = .idle
    @State private var currentPattern: [Int] = []   // indices 0 or 1 (два барабана)
    @State private var userSequence: [Int] = []
    @State private var roundIndex: Int = 0
    @State private var correctRounds: Int = 0
    @State private var activePad: Int?

    enum Phase: Sendable { case idle, playing, listening, feedback, finished }

    private let totalRounds = 4
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rhythm")

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            Spacer()
            drumsRow
            Spacer()
            actionButton
        }
        .padding(SpacingTokens.screenEdge)
        .onAppear { startNextRound() }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "rhythm.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "rhythm.round.\(roundIndex + 1)_of_\(totalRounds)"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var drumsRow: some View {
        HStack(spacing: SpacingTokens.large) {
            drumPad(index: 0, color: ColorTokens.Brand.primary)
            drumPad(index: 1, color: Color.orange)
        }
    }

    private func drumPad(index: Int, color: Color) -> some View {
        let isActive = activePad == index
        return Button {
            tap(index: index)
        } label: {
            Circle()
                .fill(color.opacity(isActive ? 0.9 : 0.45))
                .frame(width: 120, height: 120)
                .overlay(Image(systemName: "music.note").font(.system(size: 40)).foregroundStyle(Color.white))
                .scaleEffect(isActive ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: activePad)
        }
        .buttonStyle(.plain)
        .disabled(phase != .listening)
        .accessibilityLabel(index == 0 ? "Левый барабан" : "Правый барабан")
    }

    @ViewBuilder
    private var actionButton: some View {
        switch phase {
        case .listening:
            Text(String(localized: "rhythm.your_turn"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        case .feedback:
            HSButton(String(localized: "rhythm.next"), style: .primary) { startNextRound() }
        case .finished:
            HSButton(String(localized: "rhythm.done"), style: .primary, action: finish)
        default:
            EmptyView()
        }
    }

    // MARK: - Game flow

    private func startNextRound() {
        guard roundIndex < totalRounds else {
            phase = .finished
            return
        }
        userSequence.removeAll()
        let length = 2 + roundIndex   // 2,3,4,5
        currentPattern = (0..<length).map { _ in Int.random(in: 0...1) }
        phase = .playing
        Task { await playPattern() }
    }

    private func playPattern() async {
        for (idx, pad) in currentPattern.enumerated() {
            try? await Task.sleep(for: .milliseconds(idx == 0 ? 400 : 50))
            await MainActor.run {
                activePad = pad
                container.soundService.playUISound(.tap)
            }
            try? await Task.sleep(for: .milliseconds(350))
            await MainActor.run { activePad = nil }
        }
        await MainActor.run { phase = .listening }
    }

    private func tap(index: Int) {
        guard phase == .listening else { return }
        activePad = index
        container.soundService.playUISound(.tap)
        userSequence.append(index)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            activePad = nil
        }
        if userSequence.count == currentPattern.count {
            evaluateRound()
        }
    }

    private func evaluateRound() {
        let isCorrect = userSequence == currentPattern
        if isCorrect { correctRounds += 1 }
        container.hapticService.notification(isCorrect ? .success : .warning)
        container.soundService.playUISound(isCorrect ? .correct : .incorrect)
        roundIndex += 1
        phase = .feedback
    }

    private func finish() {
        let s = Float(correctRounds) / Float(totalRounds)
        logger.info("rhythm score=\(s, privacy: .public)")
        onComplete(s)
    }
}

#Preview {
    RhythmView(
        activity: SessionActivity(
            id: "preview", gameType: .rhythm, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}
