import Accelerate
import AVFoundation
import Foundation
import OSLog
import UIKit

// MARK: - SoftOnsetInteractor

@MainActor
final class SoftOnsetInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var currentWord: String = ""
        var lanternState: LanternState = .off
        var waveformColorMode: OnsetColorMode = .neutral
        var feedbackText: String? = nil
        var feedbackStyle: FeedbackStyle = .neutral
        var attemptNumber: Int = 1
        var maxAttempts: Int = 5
        var isListening: Bool = false
        var isRecording: Bool = false
        var waveformLevels: [Float] = []
        var sessionComplete: Bool = false
        var wordsSucceeded: Int = 0
        var totalWords: Int = 5
    }

    let display = Display()

    // MARK: - Dependencies

    private let audioWorker: BreathingAudioWorker
    private let analyzerWorker: any FluencyAnalyzerWorkerProtocol
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var difficulty: StutteringDifficulty = .easy
    private var wordList: [String] = []
    private var wordIndex: Int = 0
    private var attemptNumber: Int = 1
    private let maxAttempts = 5
    private let wordsPerSession = 5

    // RMS capture buffer for attack time analysis
    private var rmsBuffer: [Float] = []
    private var isCapturingOnset: Bool = false
    private let captureWindowTicks = 10  // 10 × 50ms = 500ms

    // MARK: - Init

    init(
        audioWorker: BreathingAudioWorker = BreathingAudioWorker(),
        analyzerWorker: any FluencyAnalyzerWorkerProtocol = FluencyAnalyzerWorker()
    ) {
        self.audioWorker = audioWorker
        self.analyzerWorker = analyzerWorker
    }

    // MARK: - Public API

    func startSession(difficulty: StutteringDifficulty) async {
        self.difficulty = difficulty
        display.maxAttempts = maxAttempts
        display.totalWords = wordsPerSession
        display.wordsSucceeded = 0
        wordList = SoftOnsetWords.words(for: difficulty).shuffled().prefix(wordsPerSession).map { $0 }
        wordIndex = 0
        loadCurrentWord()
    }

    func startListening() async {
        guard !display.isRecording else { return }
        rmsBuffer.removeAll()
        isCapturingOnset = false
        display.isRecording = true
        display.lanternState = .off
        display.waveformColorMode = .neutral
        display.feedbackText = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let granted = await audioWorker.requestPermission()
        guard granted else {
            display.feedbackText = String(localized: "stuttering.error.mic_permission")
            display.feedbackStyle = .error
            display.isRecording = false
            return
        }

        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in self?.handleAmplitude(amp) }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in self?.stopListening() }
                }
            )
        } catch {
            logger.error("SoftOnsetInteractor: audio start error \(error.localizedDescription, privacy: .public)")
            display.isRecording = false
        }
    }

    func stopListening() {
        audioWorker.stop()
        display.isRecording = false
        analyzeRecording()
    }

    // MARK: - Amplitude handling

    private func handleAmplitude(_ amplitude: Float) {
        // Update waveform
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels

        // Start capturing once signal appears
        let noiseFloor: Float = 0.04
        if amplitude > noiseFloor {
            isCapturingOnset = true
        }
        if isCapturingOnset && rmsBuffer.count < captureWindowTicks {
            rmsBuffer.append(amplitude)
        }
        // Auto-stop capture window
        if rmsBuffer.count >= captureWindowTicks && display.isRecording {
            stopListening()
        }
    }

    // MARK: - Analysis

    private func analyzeRecording() {
        let threshold: Float = 0.08
        let (classification, attackTimeMs) = analyzerWorker.classifyOnset(
            rmsBuffer: rmsBuffer,
            threshold: threshold,
            difficulty: difficulty
        )

        switch classification {
        case .soft:
            display.lanternState = .bright
            display.waveformColorMode = .soft
            display.feedbackText = String(localized: "stuttering.soft_start.feedback.soft")
            display.feedbackStyle = .success
            display.wordsSucceeded += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        case .borderline:
            display.lanternState = .flicker
            display.waveformColorMode = .borderline
            display.feedbackText = String(localized: "stuttering.soft_start.feedback.borderline")
            display.feedbackStyle = .warning
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

        case .hard:
            display.lanternState = .flicker
            display.waveformColorMode = .hard
            display.feedbackText = String(localized: "stuttering.soft_start.feedback.hard")
            display.feedbackStyle = .error
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        logger.info("SoftOnset analysis: attackMs=\(attackTimeMs, privacy: .public) class=\(String(describing: classification), privacy: .public)")

        advanceAttempt(succeeded: classification == .soft)
    }

    private func advanceAttempt(succeeded: Bool) {
        if succeeded {
            // Move to next word
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                self.nextWord()
            }
        } else {
            display.attemptNumber += 1
            attemptNumber += 1
            if attemptNumber > maxAttempts {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.0))
                    self.nextWord()
                }
            }
        }
    }

    private func nextWord() {
        wordIndex += 1
        attemptNumber = 1
        display.attemptNumber = 1
        if wordIndex >= wordList.count {
            display.sessionComplete = true
        } else {
            loadCurrentWord()
            display.lanternState = .off
            display.feedbackText = nil
            display.waveformColorMode = .neutral
        }
    }

    private func loadCurrentWord() {
        guard wordIndex < wordList.count else { return }
        display.currentWord = wordList[wordIndex].uppercased()
    }
}
