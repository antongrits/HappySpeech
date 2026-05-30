import AVFoundation
import Foundation
import OSLog

// MARK: - MockVoiceCloneService

/// Детерминированная реализация ``VoiceCloneService`` для SwiftUI previews и unit-тестов.
///
/// Не использует `AVSpeechSynthesizer` и файловую систему: возвращает заранее заданные
/// данные/режимы, что делает тесты быстрыми и независимыми от голосов устройства.
public actor MockVoiceCloneService: VoiceCloneService {

    // MARK: - Test knobs

    /// Данные, которые вернёт ``synthesize(text:mode:)`` при успехе.
    public var stubbedData: Data

    /// Если задано — ``synthesize(text:mode:)`` бросит эту ошибку.
    public var stubbedError: VoiceCloneError?

    /// Режимы, которые вернёт ``availableModes(for:)``. Если `nil` — рассчитываются
    /// по простому правилу (systemTTS для любой локали).
    public var stubbedModes: [VoiceSynthesisMode]?

    /// Статус Personal Voice, который вернут оба personal-voice метода.
    public var stubbedPersonalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus

    // MARK: - Spies

    public private(set) var synthesizeCallCount = 0
    public private(set) var lastSynthesizedText: String?
    public private(set) var lastMode: VoiceSynthesisMode?
    public private(set) var requestAuthCallCount = 0

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "VoiceClone.Mock")

    // MARK: - Init

    public init(
        stubbedData: Data = Data([0x01, 0x02, 0x03, 0x04]),
        stubbedError: VoiceCloneError? = nil,
        stubbedModes: [VoiceSynthesisMode]? = nil,
        stubbedPersonalVoiceStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus = .notDetermined
    ) {
        self.stubbedData = stubbedData
        self.stubbedError = stubbedError
        self.stubbedModes = stubbedModes
        self.stubbedPersonalVoiceStatus = stubbedPersonalVoiceStatus
    }

    // MARK: - VoiceCloneService

    public nonisolated var isCloneSupported: Bool { true }

    public nonisolated var personalVoiceAuthorizationStatus: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        // nonisolated stored access is not possible; default to notDetermined.
        // Точное значение доступно через synthesize/requestPersonalVoiceAuthorization.
        .notDetermined
    }

    public func requestPersonalVoiceAuthorization() async -> AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus {
        requestAuthCallCount += 1
        return stubbedPersonalVoiceStatus
    }

    public func availableModes(for locale: String) async -> [VoiceSynthesisMode] {
        if let stubbedModes { return stubbedModes }
        var modes: [VoiceSynthesisMode] = []
        if locale.lowercased().hasPrefix("en"), stubbedPersonalVoiceStatus == .authorized {
            modes.append(.personalVoice(voiceIdentifier: nil))
        }
        modes.append(.systemTTS(locale: locale))
        return modes
    }

    public func synthesize(text: String, mode: VoiceSynthesisMode) async throws -> Data {
        synthesizeCallCount += 1
        lastSynthesizedText = text
        lastMode = mode
        if let stubbedError { throw stubbedError }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           case .systemTTS = mode {
            throw VoiceCloneError.emptyText
        }
        return stubbedData
    }

    public func loadReference(speakerIndex: Int) async throws -> URL {
        guard speakerIndex >= 0, speakerIndex < VoiceCloneSpeaker.allCases.count else {
            throw VoiceCloneError.unsupportedSpeaker(speakerIndex)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_clone_reference")
            .appendingPathExtension("wav")
    }

    public func cloneVoice(text: String, speakerIndex: Int) async throws -> Data {
        guard speakerIndex >= 0, speakerIndex < VoiceCloneSpeaker.allCases.count else {
            throw VoiceCloneError.unsupportedSpeaker(speakerIndex)
        }
        return try await synthesize(text: text, mode: .systemTTS(locale: "ru-RU"))
    }
}
