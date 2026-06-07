import Foundation
import OSLog

// MARK: - StoryRetellingScoring

/// Результат скоринга пересказа по покрытию ключевых фактов.
struct StoryRetellingScoring: Sendable, Equatable {
    let coverage: Double
    let matched: [String]
    let missed: [String]
}

// MARK: - StoryRetellingProWorkerProtocol

@MainActor
protocol StoryRetellingProWorkerProtocol: AnyObject {
    /// Старт записи пересказа.
    func startRecording() async throws
    /// Останов записи, ASR-распознавание, скоринг по фактам, персист в Realm.
    func stopRecordAndScore(
        story: StoryRetellingProModels.Story,
        childId: String,
        startedAt: Date
    ) async -> (scoring: StoryRetellingScoring, transcript: String)
    /// Загружает по каждой сказке лучшее покрытие из реальных пересказов Realm.
    func loadCompletion(
        childId: String,
        stories: [StoryRetellingProModels.Story]
    ) async -> [String: Double]
    /// Скоринг произвольного транскрипта по фактам (для повторной оценки/тестов).
    func score(transcript: String, keyFacts: [String]) -> StoryRetellingScoring
}

// MARK: - StoryRetellingProWorker (Clean Swift: Worker)
//
// Реальная запись через `AudioService`, распознавание через `ASRService`,
// скоринг по покрытию ключевых фактов сказки, персист пересказа в Realm
// (`ChildOralStoryObject`). Завершённость сказки восстанавливается из реальных
// сохранённых пересказов (повторный скоринг транскрипта по фактам).

@MainActor
final class StoryRetellingProWorker: StoryRetellingProWorkerProtocol {

    private let audioService: any AudioService
    private let asrService: any ASRService
    private let realmActor: RealmActor
    private let calculator = LexicalDiversityCalculator()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "StoryRetellingPro.Worker"
    )

    init(
        audioService: any AudioService,
        asrService: any ASRService,
        realmActor: RealmActor
    ) {
        self.audioService = audioService
        self.asrService = asrService
        self.realmActor = realmActor
    }

    // MARK: - Recording

    func startRecording() async throws {
        try await audioService.startRecording()
        Self.logger.info("Retelling recording started")
    }

    func stopRecordAndScore(
        story: StoryRetellingProModels.Story,
        childId: String,
        startedAt: Date
    ) async -> (scoring: StoryRetellingScoring, transcript: String) {
        do {
            let url = try await audioService.stopRecording()
            let duration = Date().timeIntervalSince(startedAt)
            let result = try await asrService.transcribe(url: url)
            let transcript = result.transcript
            let scoring = score(transcript: transcript, keyFacts: story.keyFacts)
            await persist(
                story: story,
                childId: childId,
                transcript: transcript,
                duration: duration
            )
            Self.logger.info(
                "Retelling scored coverage=\(Int(scoring.coverage * 100), privacy: .public)%"
            )
            return (scoring, transcript)
        } catch {
            Self.logger.error(
                "Retelling stop/ASR failed: \(error.localizedDescription, privacy: .public)"
            )
            return (StoryRetellingScoring(coverage: 0, matched: [], missed: story.keyFacts), "")
        }
    }

    // MARK: - Persistence

    private func persist(
        story: StoryRetellingProModels.Story,
        childId: String,
        transcript: String,
        duration: Double
    ) async {
        let analysis = calculator.analyse(transcript: transcript)
        let data = ChildOralStoryData(
            id: UUID().uuidString,
            childId: childId,
            createdAt: Date(),
            transcript: transcript,
            durationSeconds: duration,
            stimulusIds: [story.id],
            lexicalDiversity: analysis.ttr,
            totalWords: analysis.total,
            uniqueWords: analysis.unique
        )
        await realmActor.persistOralStory(data)
    }

    func loadCompletion(
        childId: String,
        stories: [StoryRetellingProModels.Story]
    ) async -> [String: Double] {
        let saved = await realmActor.fetchOralStories(childId: childId)
        let keyFactsByStory = Dictionary(
            uniqueKeysWithValues: stories.map { ($0.id, $0.keyFacts) }
        )
        var best: [String: Double] = [:]
        for record in saved {
            // Пересказ помечен сказкой через stimulusIds.
            guard let storyId = record.stimulusIds.first,
                  let keyFacts = keyFactsByStory[storyId] else { continue }
            let coverage = score(transcript: record.transcript, keyFacts: keyFacts).coverage
            best[storyId] = max(best[storyId] ?? 0, coverage)
        }
        return best
    }

    // MARK: - Scoring

    /// Покрытие фактов: доля ключевых слов, найденных в транскрипте.
    /// Сопоставление учитывает русскую флексию через сравнение основ
    /// (первые ≥4 буквы / общий префикс).
    func score(transcript: String, keyFacts: [String]) -> StoryRetellingScoring {
        guard !keyFacts.isEmpty else {
            return StoryRetellingScoring(coverage: 0, matched: [], missed: [])
        }
        let tokens = calculator.tokenise(transcript)
        var matched: [String] = []
        var missed: [String] = []
        for fact in keyFacts {
            let factTokens = calculator.tokenise(fact)
            let isMatch = factTokens.allSatisfy { factToken in
                tokens.contains { token in stemMatch(token, factToken) }
            }
            if isMatch {
                matched.append(fact)
            } else {
                missed.append(fact)
            }
        }
        let coverage = Double(matched.count) / Double(keyFacts.count)
        return StoryRetellingScoring(coverage: coverage, matched: matched, missed: missed)
    }

    /// Совпадение основ слов: одинаковые целиком или общий префикс ≥ 4 букв
    /// (для коротких слов ≤4 — точное совпадение).
    private func stemMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let minLen = min(a.count, b.count)
        guard minLen >= 4 else { return false }
        let prefixLen = max(4, minLen - 2)
        return a.prefix(prefixLen) == b.prefix(prefixLen)
    }
}
