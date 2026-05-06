import Accelerate
import AVFoundation
import Foundation
import OSLog

// MARK: - MetronomeInteractor
//
// Управляет логопедическим метрономом — упражнение на слоговую синхронизацию.
//
// Функциональность (D.1 v15):
//   1. Запуск сессии: загрузка слов по сложности, BPM по уровню.
//   2. Tick handling: определение слога в окне ±200ms вокруг тика.
//   3. Адаптивный BPM: снижение на 5 BPM если 3 слова подряд < 50% попаданий.
//   4. Amplitude detection: порог зависит от difficulty (easy=0.07, medium=0.09, hard=0.11).
//   5. Сессионная статистика: процент попаданий, среднее по словам, итоговый балл.
//   6. История сессий в памяти: до 10 последних сессий (для построения графика).
//   7. Итоговый отчёт: SessionReport с уровнем (excellent/good/fair/needsWork).
//   8. Смена темпа в реальном времени через changeBPM().

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
        // D.1 v15 — новые поля отображения
        var sessionScore: Double = 0       // 0.0–1.0
        var wordAccuracyLabel: String = ""
        var adaptiveBPMLabel: String = ""
        var showSessionReport: Bool = false
        var sessionReportLabel: String = ""
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
    private let syllableWindowMs: TimeInterval = 0.4
    private let syllableMinDurationMs: TimeInterval = 0.1

    // MARK: - Adaptive BPM tracking (D.1 v15)

    private var currentBPM: Int = 75
    private var consecutiveLowAccuracyWords: Int = 0
    private static let adaptiveBPMReductionStep = 5
    private static let adaptiveBPMMin = 50
    private static let adaptiveBPMMax = 120

    // MARK: - Per-word statistics (D.1 v15)

    private var wordHits: [Int] = []      // попаданий на текущее слово
    private var wordTotals: [Int] = []    // всего слогов на текущее слово
    private var currentWordHits: Int = 0
    private var currentWordTotalSyllables: Int = 0

    // MARK: - Session history (D.1 v15)

    private var sessionHistory: [MetronomeSessionRecord] = []
    private static let maxHistoryCount = 10

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

    // MARK: - Adaptive amplitude threshold (D.1 v15)

    private var adaptiveThreshold: Float {
        switch difficulty {
        case .easy:   return 0.07
        case .medium: return 0.09
        case .hard:   return 0.11
        }
    }

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
        currentBPM = difficulty.bpm
        display.bpm = currentBPM
        wordList = wordsForDifficulty(difficulty).shuffled().map(\.0)
        wordIndex = 0
        syllableDetectedSet = []
        wordHits = []
        wordTotals = []
        currentWordHits = 0
        currentWordTotalSyllables = 0
        consecutiveLowAccuracyWords = 0

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
            logger.error(
                "MetronomeInteractor: audio start error \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        metronomeWorker.start(bpm: currentBPM) { [weak self] in
            Task { @MainActor [weak self] in self?.handleTick() }
        }

        logger.info("MetronomeInteractor: session started bpm=\(self.currentBPM, privacy: .public)")
    }

    func stopSession() {
        metronomeWorker.stop()
        audioWorker.stop()

        if display.isRunning {
            // Сохраняем запись сессии перед остановкой.
            let record = buildSessionRecord()
            addToHistory(record)
            showFinalReport(record)
        }

        display.isRunning = false
        logger.info("MetronomeInteractor: session stopped")
    }

    // MARK: - Change BPM in real-time (D.1 v15)

    func changeBPM(to newBPM: Int) {
        let clamped = max(
            Self.adaptiveBPMMin,
            min(Self.adaptiveBPMMax, newBPM)
        )
        guard clamped != currentBPM else { return }
        currentBPM = clamped
        display.bpm = clamped
        // Перезапускаем метроном с новым темпом без прерывания сессии.
        metronomeWorker.stop()
        metronomeWorker.start(bpm: clamped) { [weak self] in
            Task { @MainActor [weak self] in self?.handleTick() }
        }
        display.adaptiveBPMLabel = String(
            format: String(localized: "stuttering.metronome.bpm.label"),
            clamped
        )
        logger.info("MetronomeInteractor: BPM changed to \(clamped, privacy: .public)")
    }

    // MARK: - Session history (D.1 v15)

    func loadHistory() -> [MetronomeSessionRecord] {
        sessionHistory
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
            currentWordHits += 1
            updateSyllableState(at: idx, state: .completed)
            Task { await hapticService.play(pattern: .cardSelect) }
            logger.info("MetronomeInteractor: syllable \(idx, privacy: .public) detected")
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
        // Сохраняем статистику завершённого слова.
        let wordAccuracy = currentWordTotalSyllables > 0
            ? Double(currentWordHits) / Double(currentWordTotalSyllables)
            : 0.0
        wordHits.append(currentWordHits)
        wordTotals.append(currentWordTotalSyllables)

        // Обновляем лейбл точности.
        let pct = Int(wordAccuracy * 100)
        display.wordAccuracyLabel = String(
            format: String(localized: "stuttering.metronome.word_accuracy"),
            pct
        )

        // Адаптивный BPM: если точность < 50% → считаем слово «слабым».
        if wordAccuracy < 0.5 {
            consecutiveLowAccuracyWords += 1
        } else {
            consecutiveLowAccuracyWords = 0
        }

        if consecutiveLowAccuracyWords >= 3 {
            consecutiveLowAccuracyWords = 0
            changeBPM(to: currentBPM - Self.adaptiveBPMReductionStep)
        }

        // Обновляем общий прогресс сессии.
        let totalHits = wordHits.reduce(0, +)
        let totalSlots = wordTotals.reduce(0, +)
        let sessionAcc = totalSlots > 0 ? Double(totalHits) / Double(totalSlots) : 0.0
        display.sessionScore = sessionAcc

        display.showReward = true
        Task { await hapticService.play(pattern: .celebration) }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            self.display.showReward = false
            self.wordIndex += 1
            if self.wordIndex < self.wordList.count {
                self.syllableDetectedSet = []
                self.currentWordHits = 0
                self.currentWordTotalSyllables = 0
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

        currentWordTotalSyllables = syllables.count

        display.currentWord = wordName
        display.syllables = syllables.enumerated().map { idx, syl in
            SyllableViewModel(
                index: idx,
                state: .waiting,
                accessibilityLabel: idx == 0 ? String(localized: "stuttering.metronome.tick") : syl
            )
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

    // MARK: - Session record (D.1 v15)

    private func buildSessionRecord() -> MetronomeSessionRecord {
        let totalHits = wordHits.reduce(0, +)
        let totalSlots = wordTotals.reduce(0, +)
        let accuracy = totalSlots > 0 ? Double(totalHits) / Double(totalSlots) : 0.0
        let level = MetronomeResultLevel.from(accuracy: accuracy)
        return MetronomeSessionRecord(
            date:         Date(),
            difficulty:   difficulty,
            bpmUsed:      currentBPM,
            wordsTotal:   wordTotals.count,
            accuracy:     accuracy,
            resultLevel:  level
        )
    }

    private func addToHistory(_ record: MetronomeSessionRecord) {
        sessionHistory.insert(record, at: 0)
        if sessionHistory.count > Self.maxHistoryCount {
            sessionHistory.removeLast()
        }
    }

    private func showFinalReport(_ record: MetronomeSessionRecord) {
        let pct = Int(record.accuracy * 100)
        let levelLabel = record.resultLevel.localizedLabel
        display.sessionReportLabel = String(
            format: String(localized: "stuttering.metronome.report.format"),
            pct, levelLabel
        )
        display.showSessionReport = true
    }
}

// MARK: - MetronomeSessionRecord (D.1 v15)

struct MetronomeSessionRecord: Identifiable, Sendable {
    let id = UUID()
    let date:       Date
    let difficulty: StutteringDifficulty
    let bpmUsed:    Int
    let wordsTotal: Int
    let accuracy:   Double
    let resultLevel: MetronomeResultLevel
}

// MARK: - MetronomeResultLevel (D.1 v15)

enum MetronomeResultLevel: String, Sendable {
    case excellent
    case good
    case fair
    case needsWork

    static func from(accuracy: Double) -> MetronomeResultLevel {
        switch accuracy {
        case 0.85...: return .excellent
        case 0.65..<0.85: return .good
        case 0.45..<0.65: return .fair
        default:          return .needsWork
        }
    }

    var localizedLabel: String {
        switch self {
        case .excellent: return String(localized: "metronome.result.excellent")
        case .good:      return String(localized: "metronome.result.good")
        case .fair:      return String(localized: "metronome.result.fair")
        case .needsWork: return String(localized: "metronome.result.needs_work")
        }
    }
}
