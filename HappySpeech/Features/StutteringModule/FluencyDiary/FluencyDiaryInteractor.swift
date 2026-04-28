import AVFoundation
import Foundation
import OSLog
import UIKit

// MARK: - FluencyDiaryInteractor

@MainActor
final class FluencyDiaryInteractor {

    // MARK: - Display state

    @Observable
    final class Display {
        var currentText: String = ""
        var waveformLevels: [Float] = []
        var isRecording: Bool = false
        var showComplete: Bool = false
        var isAnalyzing: Bool = false
        var errorMessage: String? = nil
    }

    let display = Display()

    // MARK: - Dependencies

    private let audioWorker: BreathingAudioWorker
    private let analyzerWorker: any FluencyAnalyzerWorkerProtocol
    private let storageWorker: any DiaryStorageWorkerProtocol
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var textIndex: Int = 0
    private var currentTranscript: String = ""

    // MARK: - Init

    init(
        audioWorker: BreathingAudioWorker = BreathingAudioWorker(),
        analyzerWorker: any FluencyAnalyzerWorkerProtocol = FluencyAnalyzerWorker(),
        storageWorker: any DiaryStorageWorkerProtocol
    ) {
        self.audioWorker = audioWorker
        self.analyzerWorker = analyzerWorker
        self.storageWorker = storageWorker
    }

    // MARK: - Public API

    func startSession() {
        textIndex = Int.random(in: 0..<FluencyDiaryTexts.texts.count)
        display.currentText = FluencyDiaryTexts.text(at: textIndex)
        display.showComplete = false
        display.errorMessage = nil
        display.waveformLevels = []
        logger.info("FluencyDiary: session started textIndex=\(self.textIndex, privacy: .public)")
    }

    func startRecording() async {
        guard !display.isRecording else { return }

        let granted = await audioWorker.requestPermission()
        guard granted else {
            display.errorMessage = String(localized: "stuttering.error.mic_permission")
            return
        }

        display.isRecording = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        do {
            try await audioWorker.start(
                onAmplitude: { [weak self] amp in
                    Task { @MainActor [weak self] in self?.handleAmplitude(amp) }
                },
                onInterrupt: { [weak self] in
                    Task { @MainActor [weak self] in self?.stopRecording() }
                }
            )
        } catch {
            logger.error("FluencyDiary: audio start error \(error.localizedDescription, privacy: .public)")
            display.isRecording = false
        }
    }

    func stopRecording() {
        guard display.isRecording else { return }
        audioWorker.stop()
        display.isRecording = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        analyzeAndSave()
        logger.info("FluencyDiary: recording stopped")
    }

    // MARK: - Amplitude

    private func handleAmplitude(_ amplitude: Float) {
        var levels = display.waveformLevels
        levels.append(amplitude)
        if levels.count > 40 { levels.removeFirst(levels.count - 40) }
        display.waveformLevels = levels
    }

    // MARK: - Analysis & persistence
    //
    // In MVP: WhisperKit is not integrated in this specific path — we use
    // the display text as the transcript stub (since child reads text aloud).
    // Full WhisperKit integration is tracked in Sprint 13.5.

    private func analyzeAndSave() {
        display.isAnalyzing = true
        // Stub: use display text as transcript
        let transcript = display.currentText
        let (repetitions, totalTokens) = analyzerWorker.analyzeDysfluency(transcript: transcript)
        let syllables = analyzerWorker.estimateSyllableCount(in: transcript)
        let rate = analyzerWorker.dysfluencyRate(count: repetitions, syllables: syllables)

        let sessionData = FluencySessionData(
            id: UUID().uuidString,
            date: Date(),
            dysfluencyCount: repetitions,
            totalSyllables: syllables,
            rate: rate,
            transcript: transcript
        )

        logger.info(
            "FluencyDiary: analyzed repetitions=\(repetitions, privacy: .public) syllables=\(syllables, privacy: .public) rate=\(rate, privacy: .public)"
        )

        Task {
            await storageWorker.saveSession(sessionData)
            await MainActor.run {
                self.display.isAnalyzing = false
                self.display.showComplete = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
