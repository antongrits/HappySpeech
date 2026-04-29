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
        /// true если последний анализ был выполнен без WhisperKit (stub-путь)
        var isStubAnalysis: Bool = true
    }

    let display = Display()

    // MARK: - Dependencies

    private let audioWorker: BreathingAudioWorker
    private let analyzerWorker: any FluencyAnalyzerWorkerProtocol
    private let storageWorker: any DiaryStorageWorkerProtocol
    private let whisperWorker: WhisperTranscriptionWorker
    private let logger = HSLogger.audio

    // MARK: - Session state

    private var textIndex: Int = 0
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?

    // MARK: - Init

    init(
        audioWorker: BreathingAudioWorker = BreathingAudioWorker(),
        analyzerWorker: any FluencyAnalyzerWorkerProtocol = FluencyAnalyzerWorker(),
        storageWorker: any DiaryStorageWorkerProtocol,
        whisperWorker: WhisperTranscriptionWorker = WhisperTranscriptionWorker()
    ) {
        self.audioWorker = audioWorker
        self.analyzerWorker = analyzerWorker
        self.storageWorker = storageWorker
        self.whisperWorker = whisperWorker
    }

    // MARK: - Public API

    func startSession() {
        textIndex = Int.random(in: 0..<FluencyDiaryTexts.texts.count)
        display.currentText = FluencyDiaryTexts.text(at: textIndex)
        display.showComplete = false
        display.errorMessage = nil
        display.waveformLevels = []
        display.isStubAnalysis = true
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

        startFileRecording()

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
            stopFileRecording()
        }
    }

    func stopRecording() {
        guard display.isRecording else { return }
        audioWorker.stop()
        stopFileRecording()
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

    // MARK: - File recording (параллельно с RMS-тапом для получения URL аудио)

    private func startFileRecording() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fluency_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        do {
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.record()
            audioRecorder = recorder
            recordedFileURL = tempURL
            logger.info("FluencyDiary: file recorder started → \(tempURL.lastPathComponent, privacy: .public)")
        } catch {
            logger.warning("FluencyDiary: file recorder failed — \(error.localizedDescription, privacy: .public)")
            audioRecorder = nil
            recordedFileURL = nil
        }
    }

    private func stopFileRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
    }

    // MARK: - Analysis & persistence

    private func analyzeAndSave() {
        display.isAnalyzing = true
        let capturedFileURL = recordedFileURL
        let fallbackText = display.currentText
        recordedFileURL = nil

        Task {
            let analysis: DysfluencyAnalysis

            if let fileURL = capturedFileURL,
               FileManager.default.fileExists(atPath: fileURL.path),
               let realTranscript = await whisperWorker.transcribe(audioURL: fileURL) {
                // Реальный путь: WhisperKit транскрипция + анализ
                analysis = (analyzerWorker as? FluencyAnalyzerWorker)?
                    .analyzeRealTranscript(realTranscript)
                    ?? makeFallbackAnalysis(text: realTranscript.fullText)
                logger.info("FluencyDiary: real WhisperKit analysis completed isStub=false")
            } else {
                // Graceful fallback: stub-анализ по тексту упражнения
                analysis = (analyzerWorker as? FluencyAnalyzerWorker)?
                    .makeStubAnalysis(text: fallbackText)
                    ?? makeFallbackAnalysis(text: fallbackText)
                logger.info("FluencyDiary: WhisperKit недоступен — fallback to stub analysis")
            }

            // Удаляем временный файл
            if let fileURL = capturedFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }

            let sessionData = FluencySessionData(
                id: UUID().uuidString,
                date: Date(),
                dysfluencyCount: analysis.repetitions + analysis.prolongations + analysis.insideWordPauses,
                totalSyllables: analysis.totalSyllables,
                rate: analysis.rate,
                transcript: analysis.isStub ? fallbackText : ""
            )

            await storageWorker.saveSession(sessionData)

            await MainActor.run {
                self.display.isStubAnalysis = analysis.isStub
                self.display.isAnalyzing = false
                self.display.showComplete = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    /// Простой fallback-расчёт без доступа к FluencyAnalyzerWorker.
    private func makeFallbackAnalysis(text: String) -> DysfluencyAnalysis {
        let vowels: Set<Character> = ["а", "е", "ё", "и", "о", "у", "ы", "э", "ю", "я"]
        let syllables = text.lowercased().filter { vowels.contains($0) }.count
        return DysfluencyAnalysis(
            repetitions: 0,
            prolongations: 0,
            insideWordPauses: 0,
            totalSyllables: syllables,
            rate: 0,
            isStub: true
        )
    }
}
