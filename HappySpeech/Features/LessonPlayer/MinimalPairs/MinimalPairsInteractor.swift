import Foundation
import AVFoundation
import OSLog

// MARK: - MinimalPairsBusinessLogic

@MainActor
protocol MinimalPairsBusinessLogic: AnyObject {
    func loadSession(_ request: MinimalPairsModels.LoadSession.Request) async
    func startRound(_ request: MinimalPairsModels.StartRound.Request) async
    func selectOption(_ request: MinimalPairsModels.SelectOption.Request) async
    func replayCurrentWord() async
    func completeSession(_ request: MinimalPairsModels.CompleteSession.Request) async
}

// MARK: - MinimalPairsInteractor
//
// Бизнес-логика игры «Минимальные пары».
//
// Жизненный цикл:
//   loadSession(contrast, childName)
//     → startRound(0)
//       → TTS озвучка (AVSpeechSynthesizer, ru-RU)
//       → selectOption(isTarget: Bool)
//         → presentSelectOption(correct, correctAnswer)
//         → auto-advance через 1.5 c
//         → startRound(next) ИЛИ completeSession(result)
//
// Скоринг — доля правильных ответов:
//   ≥ 0.9  → 3 звезды
//   ≥ 0.7  → 2 звезды
//   ≥ 0.5  → 1 звезда
//   иначе  → 0 звёзд
//
// Итоговый `Float` score для SessionShell = correctCount / totalRounds.

@MainActor
final class MinimalPairsInteractor: MinimalPairsBusinessLogic {

    // MARK: Dependencies

    var presenter: (any MinimalPairsPresentationLogic)?
    private let logger = Logger(subsystem: "ru.happyspeech", category: "MinimalPairs")

    // MARK: TTS

    /// Синтезатор для озвучки целевого слова. Держим его как свойство, чтобы
    /// переиспользовать между раундами и не пересоздавать утяжка объект.
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: Session state

    private var rounds: [MinimalPairRound] = []
    private var currentIndex: Int = 0
    private var correctCount: Int = 0
    private var childName: String = ""
    private var advanceTask: Task<Void, Never>?

    // MARK: - loadSession

    func loadSession(_ request: MinimalPairsModels.LoadSession.Request) async {
        childName = request.childName
        rounds = MinimalPairRound.rounds(count: 10, contrast: request.soundContrast)
        currentIndex = 0
        correctCount = 0
        logger.info("Loaded \(self.rounds.count, privacy: .public) rounds for contrast=\(request.soundContrast, privacy: .public)")

        let response = MinimalPairsModels.LoadSession.Response(
            rounds: rounds,
            childName: childName
        )
        presenter?.presentLoadSession(response)
    }

    // MARK: - startRound

    func startRound(_ request: MinimalPairsModels.StartRound.Request) async {
        guard request.roundIndex >= 0, request.roundIndex < rounds.count else {
            logger.error("startRound out of bounds: \(request.roundIndex)")
            return
        }
        currentIndex = request.roundIndex
        let pair = rounds[currentIndex]

        let response = MinimalPairsModels.StartRound.Response(
            pair: pair,
            roundNumber: currentIndex + 1,
            total: rounds.count
        )
        presenter?.presentStartRound(response)

        // Небольшая пауза перед озвучкой, чтобы экран успел обновиться.
        try? await Task.sleep(for: .milliseconds(250))
        speakTargetWord(pair.targetWord)
    }

    // MARK: - selectOption

    func selectOption(_ request: MinimalPairsModels.SelectOption.Request) async {
        guard currentIndex < rounds.count else { return }
        let pair = rounds[currentIndex]
        let correct = request.selectedIsTarget
        if correct { correctCount += 1 }

        logger.info("Round \(self.currentIndex + 1): selectedTarget=\(request.selectedIsTarget), correct=\(correct)")

        let response = MinimalPairsModels.SelectOption.Response(
            correct: correct,
            correctAnswer: pair.targetWord
        )
        presenter?.presentSelectOption(response)

        // Автопереход к следующему раунду / завершению.
        advanceTask?.cancel()
        advanceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard let self, !Task.isCancelled else { return }
            await self.advanceAfterFeedback()
        }
    }

    // MARK: - replayCurrentWord

    func replayCurrentWord() async {
        guard currentIndex < rounds.count else { return }
        speakTargetWord(rounds[currentIndex].targetWord)
    }

    // MARK: - completeSession

    func completeSession(_ request: MinimalPairsModels.CompleteSession.Request) async {
        advanceTask?.cancel()
        synthesizer.stopSpeaking(at: .immediate)

        let response = MinimalPairsModels.CompleteSession.Response(
            correctCount: correctCount,
            totalRounds: max(rounds.count, 1)
        )
        logger.info("Session complete: \(self.correctCount)/\(self.rounds.count)")
        presenter?.presentCompleteSession(response)
    }

    // MARK: - Private

    private func advanceAfterFeedback() async {
        let nextIndex = currentIndex + 1
        if nextIndex >= rounds.count {
            await completeSession(MinimalPairsModels.CompleteSession.Request())
        } else {
            await startRound(MinimalPairsModels.StartRound.Request(roundIndex: nextIndex))
        }
    }

    /// Озвучивает целевое слово системным TTS (русский голос, нормальная скорость).
    private func speakTargetWord(_ word: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
}
