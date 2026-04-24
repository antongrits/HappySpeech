import Foundation
import AVFoundation
import Accelerate
import OSLog

// MARK: - RhythmBusinessLogic

@MainActor
protocol RhythmBusinessLogic: AnyObject {
    func loadPattern(_ request: RhythmModels.LoadPattern.Request) async
    func playPattern(_ request: RhythmModels.PlayPattern.Request) async
    func startRecord(_ request: RhythmModels.StartRecord.Request) async
    func evaluateRhythm(_ request: RhythmModels.EvaluateRhythm.Request) async
    func nextPattern(_ request: RhythmModels.NextPattern.Request) async
    func complete(_ request: RhythmModels.Complete.Request) async
    func cancel() async
}

// MARK: - RhythmInteractor
//
// Серцевина игры. Держит каталог ритмических паттернов по группам звуков,
// управляет state-machine (.preview → .playing → .recording → .feedback)
// и считает слоговые события по RMS с микрофона.
//
//   AVAudioEngine tap (1024-frame buffer @ 16 kHz)
//     → vDSP_rmsqv
//     → handleRMS(_:): детектируем фронты (burst start/end с дебаунсом)
//     → presenter.presentUpdateRMS / evaluateRhythm
//
// Один "слог" = один период, где RMS > 0.15 (с дебаунсом ≥100 мс),
// разделённый тишиной RMS < 0.05. Каждый такой burst инкрементирует
// `detectedBeats`, и по истечении окна записи мы сравниваем с ожидаемым.

@MainActor
final class RhythmInteractor: RhythmBusinessLogic {

    // MARK: - Dependencies

    var presenter: (any RhythmPresentationLogic)?

    private let soundGroup: String
    private let totalPatternsPerSession: Int

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Rhythm")
    private let synthesizer = AVSpeechSynthesizer()

    // Audio engine — lazy-init, мы создаём его только когда нужен рекординг.
    private var audioEngine: AVAudioEngine?
    private var isTapInstalled: Bool = false
    private let audioSession = AVAudioSession.sharedInstance()

    // MARK: - Tuning

    /// Порог RMS, выше которого считаем, что ребёнок начал слог.
    private let beatOnThreshold: Float = 0.15
    /// Порог RMS, ниже которого слог считается законченным.
    private let beatOffThreshold: Float = 0.05
    /// Минимальная длительность burst'а — антидребезг (мс).
    private let minBeatDurationMs: Int = 100
    /// Максимальное окно записи, мс.
    private let maxRecordingMs: Int = 4000
    /// Пауза между слогами при TTS-воспроизведении паттерна (сек).
    private let ttsSyllablePause: Double = 0.35
    /// Длительность активации одного бита при показе паттерна (сек).
    private let beatAnimationSec: Double = 0.45

    // MARK: - Session state

    private var currentPatternIndex: Int = 0
    private var correctPatterns: Int = 0
    private var currentPattern: RhythmPattern?

    // Recording state
    private var isRecording: Bool = false
    private var detectedBeats: Int = 0
    private var beatActiveSince: Date?
    private var recordingStartedAt: Date?
    private var recordingTimer: Timer?

    // MARK: - Init

    init(soundGroup: String, totalPatternsPerSession: Int = 5) {
        self.soundGroup = soundGroup
        self.totalPatternsPerSession = totalPatternsPerSession
    }

    // MARK: - loadPattern

    func loadPattern(_ request: RhythmModels.LoadPattern.Request) async {
        let group = request.soundGroup.isEmpty ? soundGroup : request.soundGroup
        let pool = Self.patternCatalog[group] ?? Self.patternCatalog["sonants"] ?? []
        guard !pool.isEmpty else {
            logger.error("Rhythm: empty pattern pool for group=\(group, privacy: .public)")
            await complete(.init())
            return
        }
        let index = request.index % pool.count
        let pattern = pool[index]
        currentPattern = pattern
        let response = RhythmModels.LoadPattern.Response(
            pattern: pattern,
            patternIndex: currentPatternIndex,
            totalPatterns: totalPatternsPerSession
        )
        presenter?.presentLoadPattern(response)
        logger.info("Rhythm: loaded pattern=\(pattern.targetWord, privacy: .public) idx=\(self.currentPatternIndex)")
    }

    // MARK: - playPattern

    func playPattern(_ request: RhythmModels.PlayPattern.Request) async {
        guard let pattern = currentPattern else { return }
        logger.info("Rhythm: playing pattern \(pattern.targetWord, privacy: .public)")

        // Разбиваем syllableWord на слоги по '-' и произносим их с паузами,
        // параллельно подсвечивая биты в UI через presenter.
        let syllables = pattern.syllableWord.split(separator: "-").map(String.init)
        for (idx, syllable) in syllables.enumerated() {
            presenter?.presentPlayPattern(.init(activeBeatIndex: idx))
            speakSyllable(syllable, isStrong: idx < pattern.beats.count && pattern.beats[idx] == .strong)
            try? await Task.sleep(for: .seconds(beatAnimationSec))
            presenter?.presentPlayPattern(.init(activeBeatIndex: -1))
            if idx < syllables.count - 1 {
                try? await Task.sleep(for: .seconds(ttsSyllablePause))
            }
        }

        // Небольшая пауза между показом и записью — ребёнок "переключается".
        try? await Task.sleep(for: .milliseconds(500))
        await startRecord(.init())
    }

    // MARK: - startRecord

    func startRecord(_ request: RhythmModels.StartRecord.Request) async {
        guard !isRecording else { return }
        presenter?.presentStartRecord(.init())

        // Настраиваем аудиосессию под record+speaker, чтобы после TTS
        // корректно переключились на микрофон.
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Rhythm: audio session setup failed — \(error.localizedDescription, privacy: .public)")
        }

        detectedBeats = 0
        beatActiveSince = nil
        recordingStartedAt = Date()

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, _ in
            let rms = Self.computeRMS(from: buffer)
            Task { @MainActor [weak self] in
                self?.handleRMS(rms)
            }
        }
        isTapInstalled = true

        do {
            engine.prepare()
            try engine.start()
            isRecording = true
            scheduleRecordingTimer()
            logger.info("Rhythm: recording started")
        } catch {
            logger.error("Rhythm: engine start failed — \(error.localizedDescription, privacy: .public)")
            isRecording = false
            await evaluateRhythm(.init(
                detectedBeats: 0,
                expectedBeats: currentPattern?.beats.count ?? 0
            ))
        }
    }

    // MARK: - evaluateRhythm

    func evaluateRhythm(_ request: RhythmModels.EvaluateRhythm.Request) async {
        stopRecording()

        guard let pattern = currentPattern else { return }
        let expected = pattern.beats.count
        let detected = request.detectedBeats

        let diff = abs(detected - expected)
        let score: Float
        switch diff {
        case 0: score = 1.0
        case 1: score = 0.8
        case 2: score = 0.6
        default: score = 0.3
        }

        let correct = diff == 0
        if correct {
            correctPatterns += 1
        }

        // Отмечаем, в какие биты "попал" ребёнок: до detected — true.
        var beatsWasHit: [Bool] = Array(repeating: false, count: expected)
        let hits = min(detected, expected)
        for i in 0..<hits {
            beatsWasHit[i] = true
        }

        let response = RhythmModels.EvaluateRhythm.Response(
            score: score,
            correct: correct,
            detectedBeats: detected,
            expectedBeats: expected,
            beatsWasHit: beatsWasHit
        )
        presenter?.presentEvaluateRhythm(response)
        logger.info("Rhythm: eval detected=\(detected) expected=\(expected) score=\(score, privacy: .public)")

        // Через 1.5с переходим к следующему паттерну.
        try? await Task.sleep(for: .milliseconds(1500))
        await nextPattern(.init())
    }

    // MARK: - nextPattern

    func nextPattern(_ request: RhythmModels.NextPattern.Request) async {
        currentPatternIndex += 1
        if currentPatternIndex >= totalPatternsPerSession {
            await complete(.init())
            return
        }
        presenter?.presentNextPattern(.init())
        await loadPattern(.init(soundGroup: soundGroup, index: currentPatternIndex))
    }

    // MARK: - complete

    func complete(_ request: RhythmModels.Complete.Request) async {
        stopRecording()
        synthesizer.stopSpeaking(at: .immediate)
        let final = Float(correctPatterns) / Float(max(1, totalPatternsPerSession))
        let response = RhythmModels.Complete.Response(
            finalScore: final,
            correctPatterns: correctPatterns,
            totalPatterns: totalPatternsPerSession
        )
        presenter?.presentComplete(response)
        logger.info("Rhythm: completed score=\(final, privacy: .public) correct=\(self.correctPatterns)/\(self.totalPatternsPerSession)")
    }

    // MARK: - cancel

    func cancel() async {
        stopRecording()
        synthesizer.stopSpeaking(at: .immediate)
        logger.info("Rhythm: cancelled")
    }

    // MARK: - RMS handling

    private func handleRMS(_ rms: Float) {
        // Всегда пушим в UI — в т.ч. для отрисовки уровня громкости.
        presenter?.presentUpdateRMS(.init(rmsLevel: rms, detectedBeats: detectedBeats))

        guard isRecording else { return }
        let now = Date()

        if rms >= beatOnThreshold {
            if beatActiveSince == nil {
                beatActiveSince = now
            }
        } else if rms < beatOffThreshold {
            if let start = beatActiveSince {
                let durationMs = Int(now.timeIntervalSince(start) * 1000)
                if durationMs >= minBeatDurationMs {
                    detectedBeats += 1
                    logger.debug("Rhythm: beat detected, total=\(self.detectedBeats) durMs=\(durationMs)")
                }
                beatActiveSince = nil
            }
        }
    }

    private func scheduleRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pulseRecordingTimer()
            }
        }
    }

    private func pulseRecordingTimer() {
        guard isRecording, let startedAt = recordingStartedAt else { return }
        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        let expected = currentPattern?.beats.count ?? 0

        // Условия завершения:
        // 1) Прошло maxRecordingMs
        // 2) Ребёнок произнёс > expected+2 слогов (давим длинные отрывки)
        if elapsedMs >= maxRecordingMs || detectedBeats >= expected + 2 {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.evaluateRhythm(.init(
                    detectedBeats: self.detectedBeats,
                    expectedBeats: expected
                ))
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        beatActiveSince = nil

        if isTapInstalled, let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            if engine.isRunning { engine.stop() }
        }
        audioEngine = nil
    }

    // MARK: - TTS

    private func speakSyllable(_ syllable: String, isStrong: Bool) {
        let utterance = AVSpeechUtterance(string: syllable)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        // Сильный бит — чуть громче и ниже тембром.
        utterance.volume = isStrong ? 1.0 : 0.75
        utterance.pitchMultiplier = isStrong ? 1.05 : 0.95
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    // MARK: - RMS computation

    nonisolated static func computeRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        let samples = channelData[0]
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
        // Немного растягиваем диапазон, как в BreathingAudioWorker.
        return min(1, rms * 3.0)
    }

    // MARK: - Pattern catalog

    /// Каталог: 4 группы звуков × 5 ритмических паттернов.
    /// Паттерны разнородны по длине (2–4 слога) и ударной схеме.
    static let patternCatalog: [String: [RhythmPattern]] = [
        "whistling": [
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "СО-ва",
                targetWord: "сова",
                soundGroup: "whistling",
                emoji: "🦉",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak, .weak],
                syllableWord: "СА-мо-лёт",
                targetWord: "самолёт",
                soundGroup: "whistling",
                emoji: "✈️",
                displayPattern: "ТА • та • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong],
                syllableWord: "со-СНА",
                targetWord: "сосна",
                soundGroup: "whistling",
                emoji: "🌲",
                displayPattern: "та • ТА"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak],
                syllableWord: "ка-ПУС-та",
                targetWord: "капуста",
                soundGroup: "whistling",
                emoji: "🥬",
                displayPattern: "та • ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak, .weak, .weak],
                syllableWord: "ЗА-ле-за-ет",
                targetWord: "залезает",
                soundGroup: "whistling",
                emoji: "🧗",
                displayPattern: "ТА • та • та • та"
            )
        ],
        "hissing": [
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "ШАП-ка",
                targetWord: "шапка",
                soundGroup: "hissing",
                emoji: "🧢",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong],
                syllableWord: "чу-ДО",
                targetWord: "чудо",
                soundGroup: "hissing",
                emoji: "✨",
                displayPattern: "та • ТА"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak, .weak],
                syllableWord: "ШО-ко-лад",
                targetWord: "шоколад",
                soundGroup: "hissing",
                emoji: "🍫",
                displayPattern: "ТА • та • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak],
                syllableWord: "ма-ШИ-на",
                targetWord: "машина",
                soundGroup: "hissing",
                emoji: "🚗",
                displayPattern: "та • ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak, .weak, .weak],
                syllableWord: "ЩУ-ка-плы-вёт",
                targetWord: "щука плывёт",
                soundGroup: "hissing",
                emoji: "🐟",
                displayPattern: "ТА • та • та • та"
            )
        ],
        "sonants": [
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "РЫ-ба",
                targetWord: "рыба",
                soundGroup: "sonants",
                emoji: "🐟",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak],
                syllableWord: "ра-КЕ-та",
                targetWord: "ракета",
                soundGroup: "sonants",
                emoji: "🚀",
                displayPattern: "та • ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "ЛО-шадь",
                targetWord: "лошадь",
                soundGroup: "sonants",
                emoji: "🐴",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong],
                syllableWord: "ру-КА",
                targetWord: "рука",
                soundGroup: "sonants",
                emoji: "✋",
                displayPattern: "та • ТА"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak, .weak],
                syllableWord: "ра-ДУ-га-ет",
                targetWord: "радуется",
                soundGroup: "sonants",
                emoji: "🌈",
                displayPattern: "та • ТА • та • та"
            )
        ],
        "velar": [
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "КОТ-ик",
                targetWord: "котик",
                soundGroup: "velar",
                emoji: "🐱",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak],
                syllableWord: "ко-РО-ва",
                targetWord: "корова",
                soundGroup: "velar",
                emoji: "🐄",
                displayPattern: "та • ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak, .weak],
                syllableWord: "ГУ-сё-нок",
                targetWord: "гусёнок",
                soundGroup: "velar",
                emoji: "🐥",
                displayPattern: "ТА • та • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.strong, .weak],
                syllableWord: "ХЛЕ-бец",
                targetWord: "хлебец",
                soundGroup: "velar",
                emoji: "🍞",
                displayPattern: "ТА • та"
            ),
            RhythmPattern(
                id: UUID(),
                beats: [.weak, .strong, .weak, .weak],
                syllableWord: "ка-РА-мель-ка",
                targetWord: "карамелька",
                soundGroup: "velar",
                emoji: "🍬",
                displayPattern: "та • ТА • та • та"
            )
        ]
    ]

    // MARK: - Group mapping

    /// Маппит SessionActivity.soundTarget (буква) в группу звуков.
    static func soundGroup(for target: String) -> String {
        let normalized = target.uppercased()
        if ["С", "З", "Ц"].contains(normalized) { return "whistling" }
        if ["Ш", "Ж", "Ч", "Щ"].contains(normalized) { return "hissing" }
        if ["Р", "РЬ", "Л", "ЛЬ"].contains(normalized) { return "sonants" }
        if ["К", "Г", "Х"].contains(normalized) { return "velar" }
        return "sonants"
    }

    // MARK: - Test hooks

    #if DEBUG
    func _test_pushRMS(_ rms: Float) {
        handleRMS(rms)
    }

    func _test_setCurrentPattern(_ pattern: RhythmPattern) {
        currentPattern = pattern
    }

    func _test_currentDetectedBeats() -> Int {
        detectedBeats
    }

    func _test_forceRecording(_ recording: Bool) {
        isRecording = recording
    }
    #endif
}
