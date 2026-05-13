import Foundation
import OSLog

// MARK: - DeviceTier

/// Performance tier устройства для адаптивного выбора Whisper-модели.
///
/// Plan v22 Block 1.2 (ADR-V22-WHISPER-ADAPTIVE):
/// - `.low` — iPhone SE 3 и более старые устройства; используют `base` (140 MB).
/// - `.mid` — iPhone 12–14 серии; могут грузить `base` или `small` (зависит от возраста).
/// - `.high` — iPhone 15+ / 15 Pro / 16 серии; способны грузить `small` (~460 MB) без деградации.
public enum DeviceTier: String, Sendable, CaseIterable {
    case low
    case mid
    case high
}

// MARK: - WhisperAdaptiveSelector

/// Адаптивный выбор Whisper-модели на основе возраста ребёнка и performance tier устройства.
///
/// Plan v22 Block 1.2 (ADR-V22-WHISPER-ADAPTIVE):
/// - Age <6 OR device tier `.low` → `WhisperKitModelPack.base` (быстрее, меньше батареи).
/// - Age 6–8 AND device tier `.mid`/`.high` → `WhisperKitModelPack.small` (точнее для старших).
///
/// Используется на старте ASR-сессии для определения подходящего пака до `loadModel(tier:)`.
public enum WhisperAdaptiveSelector {

    /// Выбирает оптимальный Whisper-пак по возрасту ребёнка + tier'у устройства.
    ///
    /// - Parameters:
    ///   - age: возраст ребёнка (полные годы).
    ///   - deviceTier: performance tier текущего устройства (см. `currentDeviceTier()`).
    /// - Returns: рекомендованный пак (`.base` или `.small`).
    public static func selectModel(age: Int, deviceTier: DeviceTier) -> WhisperKitModelPack {
        if age < 6 || deviceTier == .low {
            return .base
        }
        return .small
    }

    /// Определяет performance tier текущего устройства по `utsname().machine`.
    ///
    /// Идентификаторы взяты из публичной базы Apple Device Identifiers (например
    /// https://gist.github.com/adamawolf/3048717). Список расширяется по мере выхода новых
    /// моделей; неизвестные устройства считаются `.mid` (безопасный middle ground).
    /// Симулятор тоже считается `.mid`.
    public static func currentDeviceTier() -> DeviceTier {
        let identifier = deviceIdentifier()

        switch identifier {
        // iPhone SE 3rd gen — slowest current-gen device.
        case "iPhone14,6":
            return .low

        // iPhone 13 family.
        case "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5":
            return .mid

        // iPhone 14 / 14 Plus.
        case "iPhone14,7", "iPhone14,8":
            return .mid

        // iPhone 14 Pro / 14 Pro Max (A16).
        case "iPhone15,2", "iPhone15,3":
            return .mid

        // iPhone 15 / 15 Plus (A16).
        case "iPhone15,4", "iPhone15,5":
            return .mid

        // iPhone 15 Pro / 15 Pro Max (A17 Pro).
        case "iPhone16,1", "iPhone16,2":
            return .high

        // iPhone 16 / 16 Plus / 16 Pro / 16 Pro Max (A18 / A18 Pro).
        case "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4":
            return .high

        // Simulator and unknown — assume `.mid` (safe default).
        case "x86_64", "arm64", "i386":
            return .mid

        default:
            return .mid
        }
    }

    // MARK: - Private

    /// Hardware identifier (например, `"iPhone16,1"`). На симуляторе возвращает
    /// `SIMULATOR_MODEL_IDENTIFIER` или `arm64`/`x86_64`.
    private static func deviceIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModel
        }
        #endif

        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}

// MARK: - ASRTier bridging

public extension WhisperAdaptiveSelector {

    /// Мостик к существующему `ASRTier` API (`ASRService.loadModel(tier:)`).
    ///
    /// - `.base`  → `ASRTier.parentQuality` (bundled whisper-base).
    /// - `.small` → `ASRTier.specialistQuality` (bundled whisper-small).
    /// - `.tiny`  → `ASRTier.kidOnDevice` (whisper-tiny, on-demand).
    static func asrTier(for pack: WhisperKitModelPack) -> ASRTier {
        switch pack {
        case .tiny:  return .kidOnDevice
        case .base:  return .parentQuality
        case .small: return .specialistQuality
        }
    }

    /// Удобная обёртка: выбирает пак + сразу логирует выбор для метрик.
    ///
    /// Лог попадает в категорию `HSLogger.asr` и используется аналитикой v22
    /// (см. ADR-V22-WHISPER-ADAPTIVE) для отслеживания распределения моделей.
    static func selectAndLog(age: Int, deviceTier: DeviceTier) -> WhisperKitModelPack {
        let pack = selectModel(age: age, deviceTier: deviceTier)
        HSLogger.asr.info(
            "whisper_model_selected: \(pack.rawValue, privacy: .public), age: \(age, privacy: .public), tier: \(deviceTier.rawValue, privacy: .public)"
        )
        return pack
    }
}
