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

    /// Тёплая heat-шкала: коралл → butter → золото (default детского контура).
    /// Без холодных тонов — соответствует тёплой палитре приложения.
    case warm

    /// Нейтральная — стандартный синий→красный градиент.
    case neutral

    // MARK: - Hue ranges (HSB)

    /// Начальный оттенок (low magnitude), градусы HSB 0–360.
    var lowHue: Double {
        switch self {
        case .warm:    return 18
        case .neutral: return 240
        }
    }

    /// Конечный оттенок (high magnitude), градусы HSB 0–360.
    var highHue: Double {
        switch self {
        case .warm:    return 48
        case .neutral: return 0
        }
    }

    /// `true` для тёплых heat-шкал, рендерящихся через явный
    /// коралл→butter→золото-рамп (а не HSB-hue интерполяцию).
    var usesWarmHeatRamp: Bool { self == .warm }
}

// MARK: - Warm heat ramp

/// Тёплая шкала интенсивности спектрограммы/питча: коралл → butter → золото.
/// Без холодных цветов — соответствует палитре приложения (см. дизайн-эталон
/// speech-visualization: heat-шкала «тихо → звонко»).
public enum SpectrogramHeatRamp {

    /// Контрольные точки рампа: (позиция 0…1, R, G, B) в sRGB 0…1.
    /// От тёмно-ржавого (почти фон) к коралловому к золотому.
    private static let stops: [(Double, Double, Double, Double)] = [
        (0.00, 0.078, 0.055, 0.035),   // ~viz-bg, едва видимый
        (0.20, 0.314, 0.157, 0.118),   // глубокий ржавый
        (0.42, 0.647, 0.275, 0.188),   // обожжённый коралл
        (0.60, 1.000, 0.482, 0.329),   // primary коралл
        (0.78, 1.000, 0.604, 0.478),   // коралл hi
        (1.00, 1.000, 0.843, 0.251)    // butter / золото
    ]

    /// Возвращает (R, G, B) sRGB-компоненты тёплого цвета для интенсивности `t` ∈ [0, 1].
    public static func color(for t: Double) -> (red: Double, green: Double, blue: Double) {
        let clamped = min(max(t, 0), 1)
        for index in 1..<stops.count where clamped <= stops[index].0 {
            let lower = stops[index - 1]
            let upper = stops[index]
            let span = upper.0 - lower.0
            let f = span > 0 ? (clamped - lower.0) / span : 0
            return (
                lower.1 + (upper.1 - lower.1) * f,
                lower.2 + (upper.2 - lower.2) * f,
                lower.3 + (upper.3 - lower.3) * f
            )
        }
        let last = stops[stops.count - 1]
        return (last.1, last.2, last.3)
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
