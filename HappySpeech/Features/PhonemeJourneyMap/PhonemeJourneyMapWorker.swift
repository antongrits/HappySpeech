import Foundation
import OSLog

// MARK: - PhonemeJourneyProgressLoading

/// Worker, вычисляющий РЕАЛЬНЫЙ прогресс по этапам коррекции звука из истории.
///
/// Источник данных:
/// - `ChildRepository.fetch(id:)` — целевые звуки ребёнка (`targetSounds`);
/// - `SessionRepository.fetchAll(childId:)` — завершённые сессии, по которым
///   определяется максимально достигнутый этап (`CorrectionStage`) для звука.
///
/// Этап считается «пройденным», если по нему есть сессия с реальной точностью
/// ≥ 70% (correct/total). Никакого выдуманного прогресса: без данных все этапы
/// открыты (не завершены), что Presenter показывает честно.
@MainActor
protocol PhonemeJourneyProgressLoading: AnyObject {
    func loadProgress(childId: String) async -> PhonemeJourneyProgress
}

// MARK: - PhonemeJourneyProgress

struct PhonemeJourneyProgress: Sendable, Equatable {
    let targetSound: String
    /// Стадии этапа коррекции (упрощённая лестница экрана) и их завершённость.
    let completed: [PhonemeJourneyMapModels.Stage: Bool]

    static let empty = PhonemeJourneyProgress(targetSound: "", completed: [:])
}

// MARK: - PhonemeJourneyMapWorker

@MainActor
final class PhonemeJourneyMapWorker: PhonemeJourneyProgressLoading {

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository
    private let logger = Logger(subsystem: "ru.happyspeech", category: "PhonemeJourneyMapWorker")

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    func loadProgress(childId: String) async -> PhonemeJourneyProgress {
        guard !childId.isEmpty else { return .empty }

        let targetSound = await resolveTargetSound(childId: childId)
        guard !targetSound.isEmpty else { return .empty }

        let sessions: [SessionDTO]
        do {
            sessions = try await sessionRepository.fetchAll(childId: childId)
        } catch {
            logger.error("loadProgress: fetchAll failed \(error.localizedDescription, privacy: .public)")
            return PhonemeJourneyProgress(targetSound: targetSound, completed: [:])
        }

        let completed = Self.completedStages(sessions: sessions, sound: targetSound)
        return PhonemeJourneyProgress(targetSound: targetSound, completed: completed)
    }

    private func resolveTargetSound(childId: String) async -> String {
        do {
            let child = try await childRepository.fetch(id: childId)
            return child.targetSounds.first ?? ""
        } catch {
            logger.debug("resolveTargetSound: profile unavailable")
            return ""
        }
    }
}

// MARK: - Pure mapping (тестируемое, без I/O)

extension PhonemeJourneyMapWorker {

    /// Какие этапы упрощённой лестницы экрана пройдены по звуку.
    /// Сопоставление `CorrectionStage` → стадия экрана:
    /// - prep/isolated → .isolated
    /// - syllable → .syllables
    /// - wordInit/wordMed/wordFinal → .words
    /// - phrase/sentence → .phrases
    /// - story → .freeSpeech
    static func completedStages(
        sessions: [SessionDTO],
        sound: String
    ) -> [PhonemeJourneyMapModels.Stage: Bool] {
        // Берём успешные сессии (точность ≥ 70%) по целевому звуку.
        let relevant = sessions.filter {
            $0.targetSound == sound && $0.totalAttempts > 0 && $0.successRate >= 0.70
        }

        var reached: Set<PhonemeJourneyMapModels.Stage> = []
        for session in relevant {
            guard let correction = CorrectionStage(rawValue: session.stage),
                  let mapped = stage(for: correction) else { continue }
            reached.insert(mapped)
        }

        // Этап считается пройденным, если достигнут он сам или более поздний
        // (нельзя дойти до «фраз», не пройдя «слова»).
        var result: [PhonemeJourneyMapModels.Stage: Bool] = [:]
        let maxReachedRank = reached.map(\.rawValue).max()
        for stage in PhonemeJourneyMapModels.Stage.allCases {
            if let maxRank = maxReachedRank {
                result[stage] = stage.rawValue <= maxRank
            } else {
                result[stage] = false
            }
        }
        return result
    }

    private static func stage(for correction: CorrectionStage) -> PhonemeJourneyMapModels.Stage? {
        switch correction {
        case .prep, .isolated:                  return .isolated
        case .syllable:                         return .syllables
        case .wordInit, .wordMed, .wordFinal:   return .words
        case .phrase, .sentence:                return .phrases
        case .story, .diff:                     return .freeSpeech
        }
    }
}
