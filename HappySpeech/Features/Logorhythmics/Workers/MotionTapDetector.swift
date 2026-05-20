import CoreMotion
import Foundation
import OSLog

// MARK: - MotionTapDetector
//
// Высокочастотный accelerometer (100 Гц), детект пиков по второй производной
// вертикального ускорения. Каждый пик с |jerk| > threshold и спустя >= минимум
// от предыдущего считается «тапом». Производим AsyncStream<Date>.
//
// Калибровка: эмпирический порог 2.0 g/s (CTO-decision-default Wave F Ф.7).
// Адаптивный порог — следующая волна.
//
// Sendable: CMMotionManager — Apple-type, не Sendable; обёртка через
// @unchecked Sendable, потому что вся работа делегирована handler-queue.

final class MotionTapDetector: @unchecked Sendable {

    // MARK: - Config

    /// Минимальный |jerk| (производная ускорения, g/s) для регистрации пика.
    let jerkThresholdGPerSec: Double
    /// Минимальный интервал между тапами (защита от двойного срабатывания).
    let minIntervalSeconds: Double
    /// Update interval accelerometer'а (секунды). 0.01 = 100 Hz.
    let updateIntervalSeconds: Double

    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    private let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Logorhythmics.TapDetector"
    )

    // MARK: - State (lock-protected, потому что доступаем из background-queue)

    private let stateLock = NSLock()
    private var previousAccelerationZ: Double = -1.0 // gravity baseline
    private var previousTimestamp: TimeInterval = 0
    private var lastTapTimestamp: TimeInterval = 0
    private var continuation: AsyncStream<Date>.Continuation?

    // MARK: - Init

    init(
        jerkThresholdGPerSec: Double = 2.0,
        minIntervalSeconds: Double = 0.12,
        updateIntervalSeconds: Double = 0.01
    ) {
        self.jerkThresholdGPerSec = max(0.5, jerkThresholdGPerSec)
        self.minIntervalSeconds = max(0.05, minIntervalSeconds)
        self.updateIntervalSeconds = max(0.005, min(0.05, updateIntervalSeconds))
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
    }

    // MARK: - Public

    /// Запускает детектор и возвращает stream Date-меток каждого тапа.
    /// Если accelerometer недоступен — возвращает пустой завершённый stream.
    func start() -> AsyncStream<Date> {
        let stream = AsyncStream<Date> { continuation in
            self.setContinuation(continuation)
        }
        guard manager.isAccelerometerAvailable else {
            logger.error("Accelerometer not available — emitting empty stream.")
            DispatchQueue.main.async { [weak self] in
                self?.finishStream()
            }
            return stream
        }
        resetState()
        manager.accelerometerUpdateInterval = updateIntervalSeconds
        manager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let self else { return }
            if let error {
                self.logger.error("Accelerometer error: \(error.localizedDescription)")
                return
            }
            guard let data else { return }
            self.processSample(data)
        }
        return stream
    }

    /// Останов детектора и закрытие stream'а.
    func stop() {
        if manager.isAccelerometerActive {
            manager.stopAccelerometerUpdates()
        }
        finishStream()
    }

    // MARK: - Private

    private func setContinuation(_ c: AsyncStream<Date>.Continuation) {
        stateLock.lock()
        continuation = c
        stateLock.unlock()
    }

    private func finishStream() {
        stateLock.lock()
        continuation?.finish()
        continuation = nil
        stateLock.unlock()
    }

    private func resetState() {
        stateLock.lock()
        previousAccelerationZ = -1.0
        previousTimestamp = 0
        lastTapTimestamp = 0
        stateLock.unlock()
    }

    /// Алгоритм: jerk = dA_z/dt. Если |jerk| > threshold И прошло
    /// >= minInterval от предыдущего тапа — регистрируем тап.
    private func processSample(_ data: CMAccelerometerData) {
        // CMAccelerometerData — final, доступ из background-queue OK.
        let aZ = data.acceleration.z
        let now = data.timestamp
        stateLock.lock()
        defer { stateLock.unlock() }
        let dt = previousTimestamp == 0 ? 0 : (now - previousTimestamp)
        if dt > 0 {
            let jerk = (aZ - previousAccelerationZ) / dt
            let intervalOK = (now - lastTapTimestamp) >= minIntervalSeconds
            if abs(jerk) > jerkThresholdGPerSec && intervalOK {
                lastTapTimestamp = now
                let date = Date()
                continuation?.yield(date)
            }
        }
        previousAccelerationZ = aZ
        previousTimestamp = now
    }
}
