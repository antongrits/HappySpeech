import Foundation
import OSLog

// MARK: - TongueTwistersRhythmWorker
//
// Изолированный воркер ритма для «Чистоговорок». Переиспользует
// `MetronomeWorker` из StutteringModule (timer-based tick + клик-звук). Метроном
// ОПЦИОНАЛЕН и замедляем: для заикающихся ритм можно выключить совсем (без
// таймера/соревнования — см. ethical-boundaries). Каждый тик продвигает
// активную ритм-долю разминки (для пульса пилюли в такт).
//
// BPM мягкий по умолчанию (72) — спокойный темп под детскую артикуляцию;
// доступно замедление до 56. Не более одного активного метронома за раз.

@MainActor
final class TongueTwistersRhythmWorker {

    // MARK: - Dependencies

    private let metronome: any MetronomeWorkerProtocol

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "TongueTwisters.Rhythm"
    )

    // MARK: - Tunables

    /// Мягкий темп по умолчанию (спокойный, под детскую артикуляцию).
    static let defaultBPM = 72
    /// Замедленный темп (для заикающихся / трудных звуков).
    static let slowBPM = 56
    /// Допустимый диапазон BPM.
    static let bpmRange = 48...96

    // MARK: - State

    private(set) var isRunning = false
    private var beatCount = 0
    private var onBeat: (@MainActor (Int) -> Void)?

    // MARK: - Init

    init(metronome: any MetronomeWorkerProtocol = MetronomeWorker()) {
        self.metronome = metronome
    }

    // MARK: - API

    /// Запускает мягкий метроном. `onBeat` вызывается на каждый тик с текущим
    /// номером доли (для подсветки/пульса ритм-пилюли разминки).
    func start(bpm: Int, beatsPerCycle: Int, onBeat: @escaping @MainActor (Int) -> Void) {
        let clamped = min(max(bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
        let cycle = max(1, beatsPerCycle)
        self.onBeat = onBeat
        beatCount = 0
        isRunning = true
        metronome.start(bpm: clamped) { [weak self] in
            // Колбэк таймера @Sendable; возвращаемся на main actor к состоянию.
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                let beat = self.beatCount % cycle
                self.beatCount += 1
                self.onBeat?(beat)
            }
        }
        Self.logger.info("rhythm start bpm=\(clamped, privacy: .public) cycle=\(cycle, privacy: .public)")
    }

    /// Останавливает метроном (выключение пользователем, уход со стадии, выход).
    func stop() {
        guard isRunning else { return }
        isRunning = false
        onBeat = nil
        metronome.stop()
        Self.logger.info("rhythm stop")
    }

    deinit {
        // metronome.stop() — @MainActor; deinit может быть вне main. Таймер
        // инвалидируется самим MetronomeWorker.deinit (RAII), доп. вызова не нужно.
    }
}
