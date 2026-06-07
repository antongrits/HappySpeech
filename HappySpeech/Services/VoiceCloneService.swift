import AVFoundation
import Foundation
import OSLog

// MARK: - VoiceSynthesisMode

/// Режим синтеза речи для ``VoiceCloneService``.
///
/// Честный контекст продукта: настоящее «клонирование голоса на лету» (zero-shot TTS
/// вроде XTTS-v2) не входит в объём продукта и не выполняется on-device. Вместо этого
/// сервис предоставляет реально работающий синтез/воспроизведение речи с трёхуровневым
/// fallback. Apple Personal Voice поддерживает только en-US / zh-CN / es-MX и создаётся
/// пользователем вручную в системных настройках, поэтому русский Personal Voice
/// технически невозможен — режим ``personalVoice(voiceIdentifier:)`` доступен лишь
/// для английских локалей и только после авторизации пользователя.
public enum VoiceSynthesisMode: Sendable, Equatable {
    /// Воспроизведение заранее записанного семейного голоса родителя.
    /// `audioFilePath` — относительный путь внутри `Documents/family_recordings/`
    /// (или абсолютный путь к существующему `.m4a`).
    case familyVoice(audioFilePath: String)

    /// Системный синтез речи `AVSpeechSynthesizer` с голосом указанной локали
    /// (по умолчанию `ru-RU`). Результат рендерится в `.m4a` через `AVAudioConverter`.
    case systemTTS(locale: String)

    /// Воспроизведение pre-rendered аудио из бандла приложения
    /// (например, Chirp3-HD-Aoede озвучка голосом Ляли). `resourceName` — имя файла
    /// без расширения; ищется как `.m4a` в бандле.
    case bundledAudio(resourceName: String)

    /// Синтез голосом Personal Voice. Доступно только на en-локалях и только
    /// после авторизации пользователя. `voiceIdentifier` — `AVSpeechSynthesisVoice.identifier`
    /// конкретного personal voice; `nil` означает «первый доступный personal voice».
    case personalVoice(voiceIdentifier: String?)
}

// MARK: - VoiceCloneService Protocol

/// Сервис синтеза/воспроизведения речи для озвучивания контента приложения.
///
/// Несмотря на историческое имя «VoiceClone», в v1.0 это полнофункциональный TTS-сервис
/// с трёхуровневым fallback (семейный голос → системный TTS → bundled-аудио), плюс
/// опциональный Apple Personal Voice (только en-локали). Подлинное ML-клонирование голоса
/// (zero-shot voice cloning) — вне продуктового объёма и сознательно не реализуется; метод
/// ``cloneVoice(text:speakerIndex:)`` маршрутизируется в системный TTS как разумный путь.
///
/// ### Контуры использования
/// - Синтез произвольного текста — только parent / specialist контур за ParentalGate.
/// - Озвучка контент-паков (детский контур) использует bundled-аудио или семейный голос.
/// - Personal Voice авторизация запрашивается только в родительских настройках.
///
/// ## Пример
/// ```swift
/// let service: any VoiceCloneService = LiveVoiceCloneService()
/// let data = try await service.synthesize(text: "Привет!", mode: .systemTTS(locale: "ru-RU"))
/// ```
///
/// ## See Also
/// - ``LiveVoiceCloneService``
/// - ``FallbackVoiceSynthesisChain``
/// - ``MockVoiceCloneService``
public protocol VoiceCloneService: Sendable {
    /// Синтезирует/загружает речь для текста в указанном режиме и возвращает
    /// аудио-данные (контейнер `.m4a`/AAC). Бросает ``VoiceCloneError`` при сбое.
    func synthesize(text: String, mode: VoiceSynthesisMode) async throws -> Data

    /// Возвращает список режимов, реально доступных для указанной локали в порядке
    /// предпочтения (от наиболее «персонального» к наиболее надёжному fallback).
    func availableModes(for locale: String) async -> [VoiceSynthesisMode]

    /// Запрашивает у пользователя авторизацию на использование Personal Voice.
    /// Возвращает текущий статус авторизации.
    func requestPersonalVoiceAuthorization() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus

    /// Текущий статус авторизации Personal Voice (без запроса диалога).
    var personalVoiceAuthorizationStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus { get }

    /// Возвращает URL аудио-сегмента эталонного диктора (`speakerIndex` 0…9) из
    /// reference-корпуса `voice_clone_reference.wav`.
    ///
    /// ### ADR — Voice Cloning (отложено post-v1.0)
    /// Reference-корпус (10 синтетических русских дикторов, ~26 мин) — обучающий
    /// материал для будущего zero-shot voice cloning (XTTS-v2 / Tortoise). On-device
    /// ML-клонирование **сознательно отложено** post-v1.0: NC-лицензии моделей +
    /// требования COPPA/152-ФЗ к детским голосам (нужны реальные голоса с согласием
    /// родителей, синтетику нельзя выдавать за детский голос в клинике). Корпус
    /// остаётся в репозитории как реальный артефакт запланированной фичи (НЕ фабрикация).
    /// `loadReference` уже честно режет корпус по `speakerIndex` — точка интеграции
    /// готова к подключению, когда фича выйдет из отложенного статуса.
    func loadReference(speakerIndex: Int) async throws -> URL

    /// «Клонирование» голоса по тексту. Подлинное zero-shot ML-клонирование отложено
    /// post-v1.0 (см. ADR в ``loadReference(speakerIndex:)``); вместо немедленного отказа
    /// метод маршрутизирует синтез в системный TTS (`.systemTTS`) как разумный рабочий путь.
    func cloneVoice(text: String, speakerIndex: Int) async throws -> Data

    /// `true` — синтез речи реально работает (TTS + fallback-цепочка функциональны).
    var isCloneSupported: Bool { get }
}

// MARK: - VoiceCloneError

public enum VoiceCloneError: LocalizedError, Sendable {
    case notImplemented
    case referenceNotFound
    case unsupportedSpeaker(Int)
    case unsupportedInVersion10
    case emptyText
    case voiceUnavailable(locale: String)
    case synthesisFailed
    case audioConversionFailed
    case fileNotFound(String)
    case personalVoiceNotAuthorized

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
        case .emptyText:
            return String(localized: "voice_clone_error_empty_text",
                          defaultValue: "Текст для синтеза пуст",
                          bundle: .main)
        case .voiceUnavailable(let locale):
            return String(localized: "voice_clone_error_voice_unavailable",
                          defaultValue: "Голос для локали \(locale) недоступен на устройстве",
                          bundle: .main)
        case .synthesisFailed:
            return String(localized: "voice_clone_error_synthesis_failed",
                          defaultValue: "Не удалось синтезировать речь",
                          bundle: .main)
        case .audioConversionFailed:
            return String(localized: "voice_clone_error_conversion_failed",
                          defaultValue: "Не удалось преобразовать аудио",
                          bundle: .main)
        case .fileNotFound(let path):
            return String(localized: "voice_clone_error_file_not_found",
                          defaultValue: "Аудио-файл не найден: \(path)",
                          bundle: .main)
        case .personalVoiceNotAuthorized:
            return String(localized: "voice_clone_error_personal_voice_unauthorized",
                          defaultValue: "Доступ к Personal Voice не предоставлен",
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
