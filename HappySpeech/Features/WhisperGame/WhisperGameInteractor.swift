import Foundation
import OSLog

// MARK: - WhisperGameInteractor

/// Бизнес-логика игры на громкость речи (шёпот / обычно / громко).
///
/// Уровень голоса (`currentLevel`) измеряется РЕАЛЬНО из микрофона: во время
/// записи через `AudioService` интерактор опрашивает `amplitudeBuffer()` и
/// держит сглаженный RMS-уровень. Никакого `Double.random` — если запись не
/// идёт (нет разрешения / симулятор без входа), уровень остаётся 0, и
/// «совпадение» честно не засчитывается без реального голоса.
@MainActor
@Observable
final class WhisperGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhisperGame"
    )

    let childId: String
    var state: WhisperGameModels.ViewState
    /// Доступна ли реальная запись микрофона (нет — UI честно сообщает об ограничении).
    var isMicAvailable: Bool = false

    private let audioService: (any AudioService)?
    private var meterTask: Task<Void, Never>?

    init(childId: String, audioService: (any AudioService)? = nil) {
        self.childId = childId
        self.audioService = audioService
        self.state = .initial
    }

    func setMode(_ mode: WhisperGameModels.Mode) {
        state.mode = mode
        Self.logger.info("setMode \(mode.rawValue, privacy: .public)")
    }

    /// Запускает реальный замер уровня микрофона на время раунда.
    func startListening() {
        guard let audioService else {
            isMicAvailable = false
            return
        }
        meterTask?.cancel()
        meterTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if !audioService.isPermissionGranted {
                let granted = await audioService.requestPermission()
                guard granted else {
                    self.isMicAvailable = false
                    return
                }
            }
            do {
                try await audioService.startRecording()
                self.isMicAvailable = true
            } catch {
                Self.logger.error("startRecording failed: \(error.localizedDescription, privacy: .public)")
                self.isMicAvailable = false
                return
            }
            // Сглаженный RMS из реального буфера амплитуд микрофона.
            while !Task.isCancelled && audioService.isRecording {
                let level = Self.rmsLevel(of: audioService.amplitudeBuffer())
                self.state.currentLevel = self.state.currentLevel * 0.7 + level * 0.3
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    /// Останавливает замер и запись.
    func stopListening() {
        meterTask?.cancel()
        meterTask = nil
        guard let audioService, audioService.isRecording else { return }
        Task { _ = try? await audioService.stopRecording() }
    }

    func completeRound() {
        stopListening()
        state.roundsCompleted += 1
        Self.logger.info("round \(self.state.roundsCompleted) completed level=\(self.state.currentLevel, format: .fixed(precision: 2))")
    }

    /// RMS-уровень буфера амплитуд, нормализованный в [0, 1].
    static func rmsLevel(of buffer: [Float]) -> Double {
        guard !buffer.isEmpty else { return 0 }
        let sumSquares = buffer.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumSquares / Float(buffer.count)).squareRoot()
        return Double(min(max(rms, 0), 1))
    }
}
