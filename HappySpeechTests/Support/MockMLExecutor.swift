import Foundation

// MARK: - MockMLExecutor

/// Lightweight ML inference simulator для XCTest performance baseline.
///
/// Plan v22 Block 1.5 — закрытие 4 XCTSkip в `MLPerformanceTests`.
///
/// **Зачем нужен:**
/// На симуляторе ANE недоступен, а реальные ML модели (Wav2Vec2 ~302 MB,
/// WhisperKit, RussianPhonemeClassifier) либо не bundled в test target,
/// либо дают нерепрезентативные числа на CPU-only.
///
/// `MockMLExecutor` имитирует latency через `Task.sleep`, что:
/// - Даёт **детерминированный baseline** для performance regression testing
/// - Использует `XCTClockMetric` / `XCTCPUMetric` / `XCTMemoryMetric`
/// - Заменяет «hard-skip с NOT_MEASURABLE» на работающие сценарии
///
/// **Что НЕ покрывает:**
/// - Реальную latency ANE inference (для этого нужен реальный девайс)
/// - Memory footprint реальных моделей (302 MB Wav2Vec2 не симулируется)
/// - Cold start с загрузкой mlpackage из disk
///
/// **Релизные замеры** делаются вручную на iPhone 15 Pro+ через Instruments
/// (см. Plan v22 Block 0.5 SignpostLog + Block 1.4 HSSignpost).
public actor MockMLExecutor {

    /// Симулируемая задержка inference (секунды). По умолчанию 30 ms.
    public var classifyDelay: TimeInterval

    /// Счётчик вызовов для verification в тестах.
    public private(set) var classifyCallCount: Int = 0

    public init(classifyDelay: TimeInterval = 0.03) {
        self.classifyDelay = classifyDelay
    }

    /// Имитирует classification inference (фонемы / эмоция / поза языка).
    /// Возвращает массив из 49 вероятностей (стандартный размер RussianPhonemeClassifier).
    public func classify(audio: Data) async -> [Float] {
        classifyCallCount += 1
        if classifyDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(classifyDelay * 1_000_000_000))
        }
        // Детерминированный вывод — uniform distribution
        return Array(repeating: Float(1.0 / 49.0), count: 49)
    }
}
