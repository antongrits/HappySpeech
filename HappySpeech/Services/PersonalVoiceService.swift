import AVFoundation
import Foundation
import OSLog

// MARK: - PersonalVoiceStatus

/// Упрощённый статус доступности Personal Voice для UI родительского контура.
public enum PersonalVoiceStatus: Sendable, Equatable {
    /// Авторизация ещё не запрашивалась.
    case notDetermined
    /// Пользователь отказал в доступе (или Personal Voice выключен системно).
    case denied
    /// Доступ есть, но на устройстве не создан ни один Personal Voice.
    case authorizedNoVoices
    /// Доступ есть и доступен хотя бы один Personal Voice.
    case available(count: Int)
    /// Personal Voice не поддерживается на этом устройстве/ОС.
    case unsupported
}

// MARK: - PersonalVoiceService Protocol

/// Опциональный приватный TTS-движок на базе **Apple Personal Voice** для
/// **только взрослого контура** (родитель / специалист).
///
/// ## Идея
/// Родитель может один раз создать свой Personal Voice в системных настройках iOS
/// (Settings → Accessibility → Personal Voice). После авторизации приложение может
/// озвучивать короткие мотивационные фразы «голосом родителя» — приватный аналог
/// peer-modeling из конкурентов, но без передачи чего-либо на сервер.
///
/// ## Честные ограничения (см. ADR-V33-PERSONAL-VOICE)
/// - Personal Voice доступен с **iOS 17**, требует явного согласия владельца устройства
///   и наличия созданного голоса. У большинства пользователей его нет.
/// - Apple Personal Voice создаётся в локали устройства; **русский** Personal Voice
///   системно не предусмотрен Apple на момент iOS 17–18 (поддержаны en-US / zh-CN / es-MX).
///   Поэтому для русского контента это **не замена** основной озвучки (bundled m4a голосом
///   Ляли), а опциональный мотиватор/англоязычный fallback.
/// - Если Personal Voice недоступен — ``speak(_:)`` прозрачно откатывается на системный
///   TTS (`AVSpeechSynthesizer`, ru-RU), а при невозможности и этого — тихо завершается.
///
/// ## COPPA
/// Сервис вызывается **исключительно** из родительского/специалистского контура за
/// ParentalGate. Никогда — из детского. Никакой сети, никаких трекеров.
@MainActor
public protocol PersonalVoiceServicing: AnyObject, Sendable {
    /// Текущий обобщённый статус (без показа системного диалога).
    var status: PersonalVoiceStatus { get }

    /// Запрашивает авторизацию Personal Voice (показывает системный диалог при первом вызове).
    /// - Returns: обновлённый ``PersonalVoiceStatus``.
    @discardableResult
    func requestAuthorization() async -> PersonalVoiceStatus

    /// Озвучивает текст. Использует Personal Voice, если доступен; иначе системный TTS (`fallbackLocale`).
    /// Метод воспроизводит речь напрямую (без рендера в файл) и завершается по окончании.
    /// - Parameters:
    ///   - text: текст для озвучивания.
    ///   - fallbackLocale: локаль системного TTS, если Personal Voice недоступен (по умолчанию ru-RU).
    func speak(_ text: String, fallbackLocale: String) async

    /// Останавливает текущее воспроизведение.
    func stop()
}

public extension PersonalVoiceServicing {
    func speak(_ text: String) async { await speak(text, fallbackLocale: "ru-RU") }
}

// MARK: - LivePersonalVoiceService

/// Production-реализация ``PersonalVoiceServicing`` поверх `AVSpeechSynthesizer`.
///
/// `@MainActor`-класс: `AVSpeechSynthesizer` и его делегат удобнее держать на главном
/// акторе; синтез короткий (мотивационные фразы), поэтому это не блокирует UI.
@MainActor
public final class LivePersonalVoiceService: NSObject, PersonalVoiceServicing {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "PersonalVoice")
    private let synthesizer = AVSpeechSynthesizer()
    private var speakContinuation: CheckedContinuation<Void, Never>?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Status

    public var status: PersonalVoiceStatus {
        switch AVSpeechSynthesizer.personalVoiceAuthorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied, .unsupported:
            return AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .unsupported
                ? .unsupported
                : .denied
        case .authorized:
            let voices = Self.personalVoices()
            return voices.isEmpty ? .authorizedNoVoices : .available(count: voices.count)
        @unknown default:
            return .unsupported
        }
    }

    // MARK: - Authorization

    @discardableResult
    public func requestAuthorization() async -> PersonalVoiceStatus {
        let raw = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        logger.info("Personal Voice authorization: \(String(describing: raw), privacy: .public)")
        return status
    }

    // MARK: - Speak

    public func speak(_ text: String, fallbackLocale: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ensurePlaybackSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        if let personal = Self.personalVoices().first,
           AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .authorized {
            utterance.voice = personal
            logger.debug("Speaking with Personal Voice (\(personal.language, privacy: .public))")
        } else if let fallback = Self.bestVoice(for: fallbackLocale) {
            utterance.voice = fallback
            logger.debug("Personal Voice unavailable — system TTS \(fallbackLocale, privacy: .public)")
        } else {
            logger.warning("No voice available for \(fallbackLocale, privacy: .public) — skipping")
            return
        }

        // Прерываем предыдущее воспроизведение, если оно идёт.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            resumeContinuation()
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            speakContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        resumeContinuation()
    }

    // MARK: - Private

    private func resumeContinuation() {
        let cont = speakContinuation
        speakContinuation = nil
        cont?.resume()
    }

    private func ensurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            logger.warning("AVAudioSession setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Все голоса с трейтом Personal Voice.
    static func personalVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.voiceTraits.contains(.isPersonalVoice) }
    }

    /// Лучший системный голос для локали (premium > enhanced > default).
    static func bestVoice(for locale: String) -> AVSpeechSynthesisVoice? {
        let normalized = locale.lowercased().replacingOccurrences(of: "_", with: "-")
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            let lang = $0.language.lowercased().replacingOccurrences(of: "_", with: "-")
            return lang == normalized || lang.hasPrefix(String(normalized.prefix(2)) + "-")
        }
        let ranked = candidates.sorted { rank($0.quality) > rank($1.quality) }
        return ranked.first ?? AVSpeechSynthesisVoice(language: locale)
    }

    private static func rank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium:  return 2
        case .enhanced: return 1
        default:        return 0
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension LivePersonalVoiceService: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.resumeContinuation() }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in self?.resumeContinuation() }
    }
}

// MARK: - MockPersonalVoiceService

/// Детерминированный мок для preview / unit-тестов: не трогает `AVSpeechSynthesizer`.
@MainActor
public final class MockPersonalVoiceService: PersonalVoiceServicing {

    public var stubbedStatus: PersonalVoiceStatus
    public private(set) var requestAuthCallCount = 0
    public private(set) var speakCallCount = 0
    public private(set) var lastSpokenText: String?
    public private(set) var stopCallCount = 0

    public init(status: PersonalVoiceStatus = .notDetermined) {
        self.stubbedStatus = status
    }

    public var status: PersonalVoiceStatus { stubbedStatus }

    @discardableResult
    public func requestAuthorization() async -> PersonalVoiceStatus {
        requestAuthCallCount += 1
        return stubbedStatus
    }

    public func speak(_ text: String, fallbackLocale: String) async {
        speakCallCount += 1
        lastSpokenText = text
    }

    public func stop() { stopCallCount += 1 }
}
