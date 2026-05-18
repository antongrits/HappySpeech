import Foundation
import OSLog

// MARK: - PacingInteractor
//
// Управляет упражнением «Темп речи» (фразовый пейсинг).
//
// Механика:
//   1. startSession — загружает фразы по уровню сложности, разбивает первую
//      фразу на слоги, готовит ViewModel.
//   2. play — запускает «бегунок»: каждые beatIntervalSec активируется
//      следующий слог. Ребёнок проговаривает фразу, ведя речь за подсветкой.
//   3. Когда бегунок прошёл все слоги фразы — фраза засчитана, награда,
//      переход к следующей фразе.
//   4. После roundCount фраз — сессия завершена.
//
// В отличие от метронома здесь нет микрофонной детекции: пейсинг тренирует
// темповый самоконтроль ребёнка, а бегунок служит безопасным визуальным
// ориентиром. Темп намеренно замедлен (Easy медленнее метронома), чтобы
// исключить спешку и дать время на моторное планирование фразы.

@MainActor
final class PacingInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var syllables: [PacingSyllableViewModel] = []
        var phraseText: String = ""
        var progressLabel: String = ""
        var isRunning: Bool = false
        var isPaused: Bool = false
        var sliderProgress: Double = 0          // 0.0–1.0
        var activeSyllableIndex: Int = -1
        var showRoundReward: Bool = false
        var isSessionComplete: Bool = false
        var summaryText: String = ""
    }

    let display = Display()

    // MARK: - Dependencies

    private let hapticService: any HapticService
    private let logger = HSLogger.ui

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var phrases: [PacingPhrase] = []
    private var phraseIndex: Int = 0
    private var roundCount: Int = 5
    private var beatIntervalSec: TimeInterval = 0.8
    private var beatTask: Task<Void, Never>?

    // MARK: - Init

    init(hapticService: any HapticService = LiveHapticService()) {
        self.hapticService = hapticService
    }

    // MARK: - Public API

    /// Запускает сессию: подбирает фразы и готовит первую.
    func startSession(difficulty: StutteringDifficulty) {
        self.difficulty = difficulty
        roundCount = min(difficulty.roundCount, PacingPhrases.phrases(for: difficulty).count)
        beatIntervalSec = pacingBeatInterval(for: difficulty)
        phrases = PacingPhrases.phrases(for: difficulty).shuffled()
        phraseIndex = 0
        display.isSessionComplete = false
        display.showRoundReward = false
        display.summaryText = ""
        loadCurrentPhrase()
        logger.info("PacingInteractor: startSession difficulty=\(difficulty.rawValue, privacy: .public) rounds=\(self.roundCount, privacy: .public)")
    }

    /// Запускает/возобновляет движение бегунка по слогам.
    func play() {
        guard !display.isRunning, !display.isSessionComplete else { return }
        display.isRunning = true
        display.isPaused = false
        Task { await hapticService.play(pattern: .buttonTap) }
        startBeatLoop()
    }

    /// Ставит бегунок на паузу (ребёнок может перевести дыхание).
    func pause() {
        guard display.isRunning else { return }
        beatTask?.cancel()
        beatTask = nil
        display.isRunning = false
        display.isPaused = true
        logger.info("PacingInteractor: paused at syllable \(self.display.activeSyllableIndex, privacy: .public)")
    }

    /// Полная остановка и сброс текущей фразы в начало.
    func stop() {
        beatTask?.cancel()
        beatTask = nil
        display.isRunning = false
        display.isPaused = false
        resetPhraseHighlight()
        logger.info("PacingInteractor: stopped")
    }

    // MARK: - Phrase loading

    private func loadCurrentPhrase() {
        guard phraseIndex < phrases.count else {
            finalizeSession()
            return
        }
        let phrase = phrases[phraseIndex]
        var flatIndex = 0
        var vms: [PacingSyllableViewModel] = []
        for word in phrase.words {
            for (sylIdx, syllable) in word.syllables.enumerated() {
                let isLast = sylIdx == word.syllables.count - 1
                vms.append(
                    PacingSyllableViewModel(
                        index: flatIndex,
                        text: syllable,
                        wordIndex: word.id,
                        isWordEnd: isLast,
                        state: .waiting,
                        accessibilityLabel: syllable
                    )
                )
                flatIndex += 1
            }
        }
        display.syllables = vms
        display.phraseText = phrase.plainText
        display.activeSyllableIndex = -1
        display.sliderProgress = 0
        display.progressLabel = makeProgressLabel()
    }

    private func makeProgressLabel() -> String {
        String(
            format: String(localized: "stuttering.pacing.progress.format"),
            phraseIndex + 1,
            roundCount
        )
    }

    // MARK: - Beat loop

    private func startBeatLoop() {
        beatTask?.cancel()
        let interval = beatIntervalSec
        beatTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                self.advanceBeat()
                if self.display.activeSyllableIndex >= self.display.syllables.count {
                    self.completePhrase()
                    return
                }
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
            }
        }
    }

    private func advanceBeat() {
        let nextIndex = display.activeSyllableIndex + 1
        guard nextIndex < display.syllables.count else {
            display.activeSyllableIndex = display.syllables.count
            return
        }
        // Предыдущий слог считается произнесённым.
        if display.activeSyllableIndex >= 0,
           display.activeSyllableIndex < display.syllables.count {
            updateSyllableState(at: display.activeSyllableIndex, to: .spoken)
        }
        updateSyllableState(at: nextIndex, to: .active)
        display.activeSyllableIndex = nextIndex

        let total = max(1, display.syllables.count)
        display.sliderProgress = Double(nextIndex + 1) / Double(total)
        Task { await hapticService.play(pattern: .cardSelect) }
    }

    private func updateSyllableState(at index: Int, to state: PacingSyllableState) {
        guard index >= 0, index < display.syllables.count else { return }
        var syllable = display.syllables[index]
        syllable.state = state
        display.syllables[index] = syllable
    }

    private func resetPhraseHighlight() {
        display.activeSyllableIndex = -1
        display.sliderProgress = 0
        for index in display.syllables.indices {
            updateSyllableState(at: index, to: .waiting)
        }
    }

    // MARK: - Phrase / session completion

    private func completePhrase() {
        beatTask = nil
        display.isRunning = false
        // Все слоги фразы — произнесены.
        for index in display.syllables.indices {
            updateSyllableState(at: index, to: .spoken)
        }
        display.sliderProgress = 1.0
        display.showRoundReward = true
        Task { await hapticService.play(pattern: .celebration) }
        logger.info("PacingInteractor: phrase \(self.phraseIndex, privacy: .public) complete")

        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(1.6))
            self.display.showRoundReward = false
            self.phraseIndex += 1
            if self.phraseIndex >= self.roundCount {
                self.finalizeSession()
            } else {
                self.loadCurrentPhrase()
            }
        }
    }

    private func finalizeSession() {
        beatTask?.cancel()
        beatTask = nil
        display.isRunning = false
        display.isSessionComplete = true
        display.summaryText = String(
            format: String(localized: "stuttering.pacing.summary.format"),
            roundCount
        )
        Task { await hapticService.play(pattern: .perfectRound) }
        logger.info("PacingInteractor: session complete rounds=\(self.roundCount, privacy: .public)")
    }

    // MARK: - Tempo helper

    /// Интервал на один слог для пейсинга. Намеренно медленнее метронома:
    /// фразовая речь требует больше времени на моторное планирование.
    /// Easy 65 BPM, Medium 80 BPM, Hard 95 BPM.
    private func pacingBeatInterval(for difficulty: StutteringDifficulty) -> TimeInterval {
        switch difficulty {
        case .easy:   return 60.0 / 65.0
        case .medium: return 60.0 / 80.0
        case .hard:   return 60.0 / 95.0
        }
    }

    // MARK: - Test hooks

    #if DEBUG
    // swiftlint:disable identifier_name
    /// Прокси к `pacingBeatInterval` для unit-тестов темпа.
    func _test_beatInterval(for difficulty: StutteringDifficulty) -> TimeInterval {
        pacingBeatInterval(for: difficulty)
    }

    /// Прокси к `advanceBeat` для пошаговых unit-тестов без таймера.
    func _test_advanceBeat() {
        advanceBeat()
    }

    /// Прокси к `loadCurrentPhrase` для подготовки состояния в тестах.
    func _test_loadCurrentPhrase() {
        loadCurrentPhrase()
    }
    // swiftlint:enable identifier_name
    #endif
}
