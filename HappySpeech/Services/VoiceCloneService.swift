import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceCloneService Protocol

/// Сервис клонирования голоса маскота Ляли — placeholder для post-v1.0.
///
/// `VoiceCloneService` определяет API для синтеза речи с кастомным голосом.
/// В v1.0 реализовано только `loadReference(speakerIndex:)` — загрузка
/// эталонного аудио-файла. Клонирование голоса (`cloneVoice`) не реализовано.
///
/// Reference data: `Resources/Models/voice_clone_reference.wav`
/// (47.4 MB, 25.9 минут синтетической русской речи, 10 голосов через edge-tts).
///
/// ### v1.0 ограничения
/// - `isCloneSupported` возвращает `false`
/// - `cloneVoice` бросает `VoiceCloneError.unsupportedInVersion10`
/// - `loadReference` работает корректно
///
/// ### Roadmap
/// - v1.1: XTTS-v2 / TortoiseTTS Core ML интеграция
/// - v1.2: Реальные голоса ребёнка с parent consent UI
/// - v1.3: Per-child custom mascot voice в настройках
///
/// ## Пример
/// ```swift
/// let service: VoiceCloneService = LiveVoiceCloneService()
///
/// // Всегда работает в v1.0
/// let url = try await service.loadReference(speakerIndex: 0)
///
/// // Выбрасывает unsupportedInVersion10 в v1.0
/// let data = try await service.cloneVoice(text: "Привет!", speakerIndex: 0)
/// ```
///
/// ## See Also
/// - ``AmbientSoundService``
/// - ``NotificationServiceLive``
public protocol VoiceCloneService: Sendable {
    /// Возвращает URL embedded reference audio файла для указанного диктора.
    /// В v1.0 file существует но клонирование не поддерживается.
    func loadReference(speakerIndex: Int) async throws -> URL

    /// Клонирует голос на основе reference data. НЕ РЕАЛИЗОВАН в v1.0.
    /// Бросает `VoiceCloneError.unsupportedInVersion10`.
    func cloneVoice(text: String, speakerIndex: Int) async throws -> Data

    /// `true` если полная реализация клонирования доступна. Всегда `false` в v1.0.
    var isCloneSupported: Bool { get }
}

// MARK: - VoiceCloneError

public enum VoiceCloneError: LocalizedError, Sendable {
    case notImplemented
    case referenceNotFound
    case unsupportedSpeaker(Int)
    case unsupportedInVersion10

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return String(localized: "voice_clone_error_not_implemented",
                          defaultValue: "Функция не реализована",
                          bundle: .main)
        case .referenceNotFound:
            return String(localized: "voice_clone_error_reference_not_found",
                          defaultValue: "Reference-файл голоса не найден в бандле",
                          bundle: .main)
        case .unsupportedSpeaker(let index):
            return String(localized: "voice_clone_error_unsupported_speaker",
                          defaultValue: "Диктор с индексом \(index) не поддерживается (допустимо 0–9)",
                          bundle: .main)
        case .unsupportedInVersion10:
            return String(localized: "voice_clone_error_v10",
                          defaultValue: "Клонирование голоса недоступно в версии 1.0",
                          bundle: .main)
        }
    }
}

// MARK: - VoiceCloneSpeaker

/// Перечисление дикторов, соответствующих reference data (Block C.4 v11).
///
/// Reference corpus: 18 логопедических текстов, 4 группы звуков
/// (свистящие / шипящие / соноры / заднеязычные).
///
/// Индексы совпадают с порядком треков в `voice_clone_reference.wav`.
public enum VoiceCloneSpeaker: Int, CaseIterable, Sendable {
    case dmitryBase       = 0
    case dmitrySlowHigh   = 1
    case dmitryFast       = 2
    case dmitryChildSim   = 3
    case dmitryBright     = 4
    case svetlanaBase     = 5
    case svetlanaSlowHigh = 6
    case svetlanaFast     = 7
    case svetlanaChildSim = 8
    case svetlanaLow      = 9

    public var displayName: String {
        switch self {
        case .dmitryBase:       return String(localized: "speaker_dmitry_base",
                                              defaultValue: "Дмитрий (базовый)", bundle: .main)
        case .dmitrySlowHigh:   return String(localized: "speaker_dmitry_slow_high",
                                              defaultValue: "Дмитрий (медленный, высокий)", bundle: .main)
        case .dmitryFast:       return String(localized: "speaker_dmitry_fast",
                                              defaultValue: "Дмитрий (быстрый)", bundle: .main)
        case .dmitryChildSim:   return String(localized: "speaker_dmitry_child_sim",
                                              defaultValue: "Дмитрий (детская имитация)", bundle: .main)
        case .dmitryBright:     return String(localized: "speaker_dmitry_bright",
                                              defaultValue: "Дмитрий (живой)", bundle: .main)
        case .svetlanaBase:     return String(localized: "speaker_svetlana_base",
                                              defaultValue: "Светлана (базовая)", bundle: .main)
        case .svetlanaSlowHigh: return String(localized: "speaker_svetlana_slow_high",
                                              defaultValue: "Светлана (медленная, высокая)", bundle: .main)
        case .svetlanaFast:     return String(localized: "speaker_svetlana_fast",
                                              defaultValue: "Светлана (быстрая)", bundle: .main)
        case .svetlanaChildSim: return String(localized: "speaker_svetlana_child_sim",
                                              defaultValue: "Светлана (детская имитация)", bundle: .main)
        case .svetlanaLow:      return String(localized: "speaker_svetlana_low",
                                              defaultValue: "Светлана (низкая)", bundle: .main)
        }
    }
}

// MARK: - VoiceCloneServicePlaceholder

/// Placeholder-реализация для v1.0.
/// - `loadReference` корректно возвращает URL embedded WAV-файла.
/// - `cloneVoice` немедленно бросает `VoiceCloneError.unsupportedInVersion10`.
/// - `isCloneSupported` = `false`.
public struct VoiceCloneServicePlaceholder: VoiceCloneService {

    private static let logger = Logger(subsystem: "com.happyspeech", category: "VoiceCloneService")

    public init() {}

    public var isCloneSupported: Bool { false }

    public func loadReference(speakerIndex: Int) async throws -> URL {
        guard speakerIndex >= 0 && speakerIndex < VoiceCloneSpeaker.allCases.count else {
            Self.logger.warning("loadReference: unsupported speakerIndex=\(speakerIndex)")
            throw VoiceCloneError.unsupportedSpeaker(speakerIndex)
        }
        guard let url = Bundle.main.url(
            forResource: "voice_clone_reference",
            withExtension: "wav",
            subdirectory: "Models"
        ) else {
            Self.logger.error("loadReference: voice_clone_reference.wav not found in bundle")
            throw VoiceCloneError.referenceNotFound
        }
        Self.logger.debug("loadReference: speakerIndex=\(speakerIndex) → \(url.lastPathComponent)")
        return url
    }

    public func cloneVoice(text: String, speakerIndex: Int) async throws -> Data {
        Self.logger.info("cloneVoice called (placeholder) — throwing unsupportedInVersion10")
        throw VoiceCloneError.unsupportedInVersion10
    }
}
