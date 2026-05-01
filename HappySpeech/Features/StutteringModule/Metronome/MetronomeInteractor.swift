import Accelerate
import AVFoundation
import Foundation
import OSLog

// MARK: - MetronomeInteractor

@MainActor
final class MetronomeInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var currentWord: String = ""
        var syllables: [SyllableViewModel] = []
        var currentSyllableIndex: Int = 0
        var waveformLevels: [Float] = []
        var isRunning: Bool = false
        var progressLabel: String = ""
        var showReward: Bool = false
        var bpm: Int = 75
    }

    let display = Display()

    // MARK: - Dependencies

    private let metronomeWorker: any MetronomeWorkerProtocol
    private let audioWorker: BreathingAudioWorker
    private let hapticService: any HapticService
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var wordList: [String] = []
    private var wordIndex: Int = 0
    private var syllableDetectedSet: Set<Int> = []
    private var lastTickTime: Date?
    private var currentAmplitude: Float = 0
    private let adaptiveThreshold: Float = 0.08
    private let syllableWindowMs: TimeInterval = 0.4   // ±200 ms around tick
    private let syllableMinDurationMs: TimeInterval = 0.1

    // MARK: - Stub word list (16 words, syllable structure 1–4)

    private let easyWords: [(String, [String])] = [
        ("кот", ["КОТ"]),
        ("шар", ["ШАР"]),
        ("рот", ["РОТ"]),
        ("рыба", ["РЫ", "БА"]),
        ("луна", ["ЛУ", "НА"]),
        ("небо", ["НЕ", "БО"])
    ]
    private let mediumWords: [(String, [String])] = [
        ("машина", ["МА", "ШИ", "НА"]),
        ("собака", ["СО", "БА", "КА"]),
        ("корова", ["КО", "РО", "ВА"])
    ]
    private let hardWords: [(String, [String])] = [
        ("черепаха", ["ЧЕ", "РЕ", "ПА", "ХА"]),
        ("карандаш", ["КА", "РАН", "ДАШ"]),
        ("электричка", ["Э", "ЛЕК", "ТРИЧ", "КА"])
    ]

    // MARK: - Init

    init(
        metronomeWorker: any MetronomeWorkerProtocol = MetronomeWorker(),
        audioWorker: BreathingAudioWorker = BreathingAudioWorker(),
        hapticService: any HapticService = LiveHapticService()
    ) {
        self.metronomeWorker = metronomeWorker
        self.audioWorker = audioWorker
        self.hapticService = hapticService
    }

    // MARK: - Public API

    func startSession(difficulty: StutteringDifficulty) async {
        self.difficulty = difficulty
        self.display.bpm = difficulty.bpm
        wordList = wordsForDifficulty(difficulty).shuffled().map(\.0)
        wordIndex = 0
        syllableDetectedSet = []

        let granted = await audioWorker.requestPermission()
        guard granted else {
            logger.error("MetronomeInteractor: mic permission denied")
            return
        }

        loadCurrentWord()
        display.isRunning = true

        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in self?.handleAmplitude(amp) }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in self?.stopSession() }
                }
            )
        } catch {
            logger.error("MetronomeInteractor: audio start error \(error.localizedDescription, privacy: .public)")
            return
        }

        metronomeWorker.start(bpm: difficulty.bpm) { [weak self] in
            Task { @MainActor [weak self] in self?.handleTick() }
        }

        logger.info("MetronomeInteractor: session started bpm=\(difficulty.bpm, privacy: .public)")
    }

    func stopSession() {
        metronomeWorker.stop()
        audioWorker.stop()
        display.isRunning = false
        logger.info("MetronomeInteractor: session stopped")
    }

    // MARK: - Tick handling

    private func handleTick() {
        guard display.isRunning else { return }
        let idx = display.currentSyllableIndex
        lastTickTime = Date()

        // Animate active cell
        updateSyllableState(at: idx, state: .active)

        // Advance to next syllable after window
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(syllableWindowMs * 1000)))
            guard self.display.isRunning else { return }
            let detectedThisTick = self.syllableDetectedSet.contains(idx)
            if !detectedThisTick {
                // Still advance visually even if not detected
                self.updateSyllableState(at: idx, state: .waiting)
            }
            self.advanceToNextSyllable()
        }

        Task { await hapticService.play(pattern: .buttonTap) }
    }

    // MARK: - Amplitude handling

    private func handleAmplitude(_ amplitude: Float) {
        currentAmplitude = amplitude

        // Update waveform
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        // Syllable detection: amplitude above threshold within tick window
        guard display.isRunning,
              let tickTime = lastTickTime else { return }
        let elapsed = Date().timeIntervalSince(tickTime)
        guard elapsed <= syllableWindowMs else { return }

        let idx = display.currentSyllableIndex
        if amplitude >= adaptiveThreshold && !syllableDetectedSet.contains(idx) {
            syllableDetectedSet.insert(idx)
            updateSyllableState(at: idx, state: .completed)
            Task { await hapticService.play(pattern: .cardSelect) }
            logger.info("MetronomeInteractor: syllable \(idx) detected")
        }
    }

    // MARK: - Syllable navigation

    private func advanceToNextSyllable() {
        let next = display.currentSyllableIndex + 1
        if next >= display.syllables.count {
            completeWord()
        } else {
            display.currentSyllableIndex = next
            let progressText = String(
                format: String(localized: "stuttering.metronome.progress.format"),
                next + 1,
                display.syllables.count
            )
            display.progressLabel = progressText
        }
    }

    private func completeWord() {
        display.showReward = true
        Task { await hapticService.play(pattern: .celebration) }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            self.display.showReward = false
            self.wordIndex += 1
            if self.wordIndex < self.wordList.count {
                self.syllableDetectedSet = []
                self.loadCurrentWord()
            } else {
                self.stopSession()
            }
        }
    }

    private func loadCurrentWord() {
        guard wordIndex < wordList.count else { return }
        let wordName = wordList[wordIndex]
        let pairs = wordsForDifficulty(difficulty)
        let syllables = pairs.first(where: { $0.0 == wordName })?.1 ?? [wordName]

        display.currentWord = wordName
        display.syllables = syllables.enumerated().map { idx, syl in
            SyllableViewModel(index: idx, state: .waiting, accessibilityLabel: idx == 0 ? String(localized: "stuttering.metronome.tick") : syl)
        }
        display.currentSyllableIndex = 0
        display.progressLabel = String(
            format: String(localized: "stuttering.metronome.progress.format"),
            1, syllables.count
        )
    }

    private func wordsForDifficulty(_ diff: StutteringDifficulty) -> [(String, [String])] {
        switch diff {
        case .easy:   return easyWords
        case .medium: return easyWords + mediumWords
        case .hard:   return easyWords + mediumWords + hardWords
        }
    }

    private func updateSyllableState(at index: Int, state: SyllableState) {
        guard index < display.syllables.count else { return }
        display.syllables[index] = SyllableViewModel(
            index: index,
            state: state,
            accessibilityLabel: state == .completed
                ? String(localized: "stuttering.metronome.syllable_counted")
                : display.syllables[index].accessibilityLabel
        )
    }
}
