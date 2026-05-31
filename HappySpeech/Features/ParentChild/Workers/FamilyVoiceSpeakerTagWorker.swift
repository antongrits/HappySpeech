import AVFoundation
import Foundation
import OSLog

// MARK: - SpeakerTag

/// COPPA-метка происхождения семейной голосовой записи.
///
/// Используется, чтобы детские записи не считались родительскими и наоборот —
/// функции только для родителей не открываются по детскому голосу.
public enum SpeakerTag: String, Sendable, Equatable {
    /// Голос совпал с зарегистрированным профилем родителя.
    case parent
    /// Голос не совпал с родительским профилем — вероятно ребёнок.
    case child
    /// Недостаточно данных / профиль ещё не зарегистрирован / модель недоступна.
    case unknown
}

// MARK: - FamilyVoiceSpeakerTagWorker

/// Помечает семейные голосовые записи как parent / child через
/// ``SpeakerVerificationServiceProtocol`` (ECAPA d-vector, on-device).
///
/// Контур: родительский / семейный (за ParentalGate). Полностью on-device,
/// без сети, аудио не сохраняется — только результат сравнения.
///
/// Логика:
///   • Если родительский профиль ещё не зарегистрирован — первая родительская
///     запись регистрирует его (`enroll`) и помечается `.parent`.
///   • Последующие записи сравниваются (`verify`) с профилем родителя:
///     совпадение → `.parent`, явное несовпадение → `.child`, иначе `.unknown`.
///   • При отсутствии сервиса / модели возвращается `.unknown` (graceful).
///
/// `@unchecked Sendable`: единственное mutable хранилище — `UserDefaults`,
/// которое потокобезопасно по контракту Foundation (внутренняя синхронизация).
final class FamilyVoiceSpeakerTagWorker: @unchecked Sendable {

    private let speakerVerification: (any SpeakerVerificationServiceProtocol)?
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.happyspeech", category: "FamilyVoiceSpeakerTag")

    init(
        speakerVerification: (any SpeakerVerificationServiceProtocol)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.speakerVerification = speakerVerification
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Помечает запись родителя. Первая запись регистрирует профиль (enroll),
    /// последующие — сверяются с ним (verify).
    /// - Returns: метка говорящего (`.parent` в ожидаемом сценарии).
    func tagParentRecording(audioPath: String, ownerId: String) async -> SpeakerTag {
        guard let speakerVerification, !ownerId.isEmpty else { return .unknown }

        guard let pcmData = loadPCMData(audioPath: audioPath) else { return .unknown }

        // Профиль ещё не зарегистрирован → регистрируем по этой записи.
        if VoiceProfileStore.load(ownerId: ownerId, defaults: defaults) == nil {
            do {
                let profile = try await speakerVerification.enroll(pcmData: pcmData, ownerId: ownerId)
                VoiceProfileStore.save(profile, defaults: defaults)
                logger.info("Зарегистрирован профиль родителя ownerId=\(ownerId.prefix(8), privacy: .private)")
                return .parent
            } catch {
                logger.warning("Enroll профиля родителя не удался: \(error.localizedDescription)")
                return .unknown
            }
        }

        // Профиль есть → сверяем.
        return await verifyTag(pcmData: pcmData, ownerId: ownerId)
    }

    /// Помечает запись из детской области split-режима. Сверяет с профилем
    /// родителя: ожидается `.child` (несовпадение). Если профиля нет —
    /// возвращает `.child` как безопасный дефолт COPPA.
    func tagChildRecording(audioPath: String, parentOwnerId: String) async -> SpeakerTag {
        guard let speakerVerification, !parentOwnerId.isEmpty else { return .child }
        guard VoiceProfileStore.load(ownerId: parentOwnerId, defaults: defaults) != nil else {
            // Нет родительского профиля для сравнения — детская область → ребёнок.
            return .child
        }
        guard let pcmData = loadPCMData(audioPath: audioPath) else { return .child }
        let tag = await verifyTag(pcmData: pcmData, ownerId: parentOwnerId, sv: speakerVerification)
        // В детской области даже совпадение трактуем консервативно: если модель
        // уверенно опознала родителя — `.parent`, иначе всё прочее → `.child`.
        return tag == .parent ? .parent : .child
    }

    // MARK: - Private

    private func verifyTag(pcmData: Data, ownerId: String) async -> SpeakerTag {
        guard let speakerVerification else { return .unknown }
        return await verifyTag(pcmData: pcmData, ownerId: ownerId, sv: speakerVerification)
    }

    private func verifyTag(
        pcmData: Data,
        ownerId: String,
        sv: any SpeakerVerificationServiceProtocol
    ) async -> SpeakerTag {
        guard let profile = VoiceProfileStore.load(ownerId: ownerId, defaults: defaults) else {
            return .unknown
        }
        let result = await sv.verify(pcmData: pcmData, referenceVoice: profile)
        let tag: SpeakerTag
        switch result.speakerType {
        case .parent:  tag = .parent
        case .child:   tag = .child
        case .unknown: tag = .unknown
        }
        logger.debug("Speaker tag=\(tag.rawValue, privacy: .public) sim=\(result.similarity, format: .fixed(precision: 3))")
        return tag
    }

    /// Читает аудиофайл как Float32 PCM Data (16kHz mono ожидается из рекордера).
    private func loadPCMData(audioPath: String) -> Data? {
        do {
            let url = try FamilyVoiceRecorderWorker.resolveFilePath(audioPath)
            let audioFile = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else {
                return nil
            }
            try audioFile.read(into: buffer)
            guard let channelData = buffer.floatChannelData?[0] else { return nil }
            let count = Int(buffer.frameLength)
            return Data(bytes: channelData, count: count * MemoryLayout<Float>.size)
        } catch {
            logger.warning("Не удалось прочитать PCM из '\(audioPath)': \(error.localizedDescription)")
            return nil
        }
    }
}
