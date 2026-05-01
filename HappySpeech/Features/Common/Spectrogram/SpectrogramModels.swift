import Foundation

// MARK: - Spectrogram

/// Иммутабельная структура данных спектрограммы.
///
/// Содержит mel-частотные кадры, извлечённые vDSP FFT-пайплайном
/// из 16 kHz mono PCM аудио.
///
/// - `frames`: массив временных кадров, каждый — 40 mel-бинов (log-mel энергия).
/// - `sampleRate`: частота дискретизации (16 000 Гц для всего пайплайна).
/// - `duration`: общая длительность в секундах.
///
/// ## See Also
/// - ``SpectrogramAudioRecorder``
/// - ``SpectrogramCanvasView``
public struct Spectrogram: Sendable, Equatable {

    // MARK: - Public API

    /// Временные кадры: [time][freq], 40 mel-бинов на кадр.
    public let frames: [[Float]]

    /// Частота дискретизации источника (Гц).
    public let sampleRate: Double

    /// Длительность записи (секунды).
    public let duration: TimeInterval

    // MARK: - Init

    public init(frames: [[Float]], sampleRate: Double, duration: TimeInterval) {
        self.frames = frames
        self.sampleRate = sampleRate
        self.duration = duration
    }

    // MARK: - Constants

    /// Число mel-бинов на один кадр.
    public static let melBinCount: Int = 40

    /// Пустая спектрограмма — безопасный дефолт.
    public static let empty = Spectrogram(frames: [], sampleRate: 16_000, duration: 0)
}

// MARK: - SpectrogramStyle

/// Цветовая тема спектрограммы.
///
/// Управляет градиентом `cool→warm` при рендере через ``SpectrogramCanvasView``.
public enum SpectrogramStyle: String, Sendable, CaseIterable {

    /// Лесная — зелёно-золотые тона (default для детского контура).
    case forest

    /// Океанская — сине-бирюзовые тона.
    case ocean

    /// Космическая — тёмно-фиолетовые + сиреневые тона.
    case space

    /// Нейтральная — стандартный синий→красный градиент.
    case neutral

    // MARK: - Hue ranges (HSB)

    /// Начальный оттенок (low magnitude), градусы HSB 0–360.
    var lowHue: Double {
        switch self {
        case .forest:  return 130
        case .ocean:   return 200
        case .space:   return 260
        case .neutral: return 240
        }
    }

    /// Конечный оттенок (high magnitude), градусы HSB 0–360.
    var highHue: Double {
        switch self {
        case .forest:  return 50
        case .ocean:   return 170
        case .space:   return 300
        case .neutral: return 0
        }
    }
}

// MARK: - SpectrogramRenderConfig

/// Параметры рендера спектрограммы.
public struct SpectrogramRenderConfig: Sendable {

    /// Минимальный log-mel порог (всё ниже отображается как «пусто»).
    public let logMin: Float

    /// Максимальный log-mel порог (всё выше — полная яркость).
    public let logMax: Float

    /// Насыщенность HSB для всех бинов.
    public let saturation: Double

    /// Яркость HSB для всех бинов.
    public let brightness: Double

    /// Дефолтная конфигурация — оптимизирована под детский контур.
    public static let defaultConfig = SpectrogramRenderConfig(
        logMin: -3.0,
        logMax: 3.0,
        saturation: 0.85,
        brightness: 0.9
    )

    public init(logMin: Float, logMax: Float, saturation: Double, brightness: Double) {
        self.logMin = logMin
        self.logMax = logMax
        self.saturation = saturation
        self.brightness = brightness
    }
}
