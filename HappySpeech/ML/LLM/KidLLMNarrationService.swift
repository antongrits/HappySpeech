import Foundation
import OSLog

// MARK: - KidLLMNarrationServiceProtocol

public protocol KidLLMNarrationServiceProtocol: Sendable {

    /// Генерирует игровое повествование для NarrativeQuest.
    func generatePlayfulNarration(context: NarrationContext) async -> String

    /// Персонализированный feedback после попытки произношения.
    /// score: 0–100.
    func generateAdaptiveFeedback(score: Int, soundId: String) async -> String

    /// Контекстная подсказка для игры.
    func generateHint(gameType: String, currentStep: String) async -> String
}

// MARK: - NarrationContext

public struct NarrationContext: Sendable {
    public let questId: String
    public let currentStep: Int
    public let totalSteps: Int
    public let mood: NarrationMood
    public let targetSound: String
    public let collectedItems: [String]

    public init(
        questId: String,
        currentStep: Int,
        totalSteps: Int,
        mood: NarrationMood,
        targetSound: String = "",
        collectedItems: [String] = []
    ) {
        self.questId = questId
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.mood = mood
        self.targetSound = targetSound
        self.collectedItems = collectedItems
    }
}

// MARK: - NarrationMood

public enum NarrationMood: String, Sendable {
    case calm
    case excited
    case encouraging
}

// MARK: - LiveKidLLMNarrationService
// ==================================================================================
// Kid circuit narration поверх LLMDecisionServiceProtocol.
//
// COPPA compliance:
//   - Никакого Tier B (HF API) — только on-device Qwen или rule-based.
//   - Никаких личных данных ребёнка в prompts (нет имён, школы, etc.)
//   - Все outputs проходят через KidSafetyFilter перед показом.
//   - Fallback на PrecannedNarrations если LLM недоступен или output unsafe.
//
// Caching:
//   - NSCache<NSString, NSString> для частых одинаковых prompts.
//   - TTL: 1 час (проверяется через timestamp в ключе).
// ==================================================================================

public final class LiveKidLLMNarrationService: KidLLMNarrationServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let llmService: any LLMDecisionServiceProtocol
    private let safetyFilter: KidSafetyFilter
    private let cache: NSCache<NSString, CacheEntry>
    private let logger = Logger(subsystem: "ru.happyspeech", category: "KidLLMNarration")

    // MARK: - Init

    public init(llmService: any LLMDecisionServiceProtocol) {
        self.llmService = llmService
        self.safetyFilter = KidSafetyFilter()
        self.cache = NSCache<NSString, CacheEntry>()
        self.cache.countLimit = 64
    }

    // MARK: - generatePlayfulNarration

    public func generatePlayfulNarration(context: NarrationContext) async -> String {
        let cacheKey = "narration_\(context.questId)_\(context.currentStep)_\(context.mood.rawValue)" as NSString

        if let cached = getCached(cacheKey) {
            logger.debug("KidLLMNarration cache hit for key: \(cacheKey)")
            return cached
        }

        let questState = NarrativeQuestState(
            questId: context.questId,
            currentStep: context.currentStep,
            totalSteps: context.totalSteps,
            collectedItems: context.collectedItems,
            childName: "",
            targetSound: context.targetSound
        )

        let result = await withTimeout(ms: 2_000) { [llmService] in
            let outcome = await llmService.narrativeQuestStep(questState: questState)
            return outcome.narration
        }

        let raw = result ?? PrecannedNarrations.narrativeProgression()
        let sanitized = await applyFilter(raw, fallback: PrecannedNarrations.narrativeProgression())

        setCached(cacheKey, value: sanitized)
        logger.info("KidLLMNarration generated narration step=\(context.currentStep)/\(context.totalSteps)")
        return sanitized
    }

    // MARK: - generateAdaptiveFeedback

    public func generateAdaptiveFeedback(score: Int, soundId: String) async -> String {
        let cacheKey = "feedback_\(soundId)_\(score / 10)" as NSString

        if let cached = getCached(cacheKey) {
            return cached
        }

        let isCorrect = score >= 80
        let attemptContext = AttemptContext(
            childName: "",
            word: soundId,
            targetSound: soundId,
            isCorrect: isCorrect,
            streak: 0,
            recentSuccessRate: Double(score) / 100.0
        )

        let result = await withTimeout(ms: 1_500) { [llmService] in
            let outcome = await llmService.pickEncouragementPhrase(context: attemptContext)
            return outcome.message
        }

        let raw = result ?? PrecannedNarrations.repeatFeedback(score: score)
        let sanitized = await applyFilter(raw, fallback: PrecannedNarrations.repeatFeedback(score: score))

        setCached(cacheKey, value: sanitized)
        logger.info("KidLLMNarration adaptive feedback score=\(score) soundId=\(soundId, privacy: .public)")
        return sanitized
    }

    // MARK: - generateHint

    public func generateHint(gameType: String, currentStep: String) async -> String {
        let cacheKey = "hint_\(gameType)_\(currentStep)" as NSString

        if let cached = getCached(cacheKey) {
            return cached
        }

        let result = await withTimeout(ms: 1_500) { [llmService] in
            let outcome = await llmService.generateCustomPhrase(
                template: .warmup,
                context: ["game_type": gameType, "step": currentStep]
            )
            return outcome.phrase
        }

        let raw = result ?? PrecannedNarrations.hint(for: gameType)
        let sanitized = await applyFilter(raw, fallback: PrecannedNarrations.hint(for: gameType))

        setCached(cacheKey, value: sanitized)
        logger.debug("KidLLMNarration hint gameType=\(gameType, privacy: .public)")
        return sanitized
    }

    // MARK: - Private: Safety filter

    private func applyFilter(_ text: String, fallback: String) async -> String {
        let result = await safetyFilter.sanitize(text)
        switch result {
        case .safe(let clean):
            return clean
        case .needsTruncation:
            return await safetyFilter.truncate(text)
        case .unsafe:
            logger.warning("KidLLMNarration unsafe output, using fallback")
            return fallback
        }
    }

    // MARK: - Private: Cache helpers (NSCache + 1-hour TTL)

    private func getCached(_ key: NSString) -> String? {
        guard let entry = cache.object(forKey: key) else { return nil }
        let age = Date().timeIntervalSince(entry.createdAt)
        guard age < 3_600 else {
            cache.removeObject(forKey: key)
            return nil
        }
        return entry.value
    }

    private func setCached(_ key: NSString, value: String) {
        cache.setObject(CacheEntry(value: value), forKey: key)
    }

    // MARK: - CacheEntry

    private final class CacheEntry: @unchecked Sendable {
        let value: String
        let createdAt: Date

        init(value: String) {
            self.value = value
            self.createdAt = Date()
        }
    }
}

// MARK: - MockKidLLMNarrationService

public final class MockKidLLMNarrationService: KidLLMNarrationServiceProtocol, @unchecked Sendable {

    public private(set) var narrationCallCount: Int = 0
    public private(set) var feedbackCallCount: Int = 0
    public private(set) var hintCallCount: Int = 0

    public var simulateUnsafeOutput: Bool = false

    public init() {}

    public func generatePlayfulNarration(context: NarrationContext) async -> String {
        narrationCallCount += 1
        if simulateUnsafeOutput { return PrecannedNarrations.narrativeProgression() }
        return "Ляля улыбается и зовёт тебя вперёд — этап \(context.currentStep) из \(context.totalSteps)!"
    }

    public func generateAdaptiveFeedback(score: Int, soundId: String) async -> String {
        feedbackCallCount += 1
        if simulateUnsafeOutput { return PrecannedNarrations.repeatFeedback(score: score) }
        return PrecannedNarrations.repeatFeedback(score: score)
    }

    public func generateHint(gameType: String, currentStep: String) async -> String {
        hintCallCount += 1
        return PrecannedNarrations.hint(for: gameType)
    }
}

// MARK: - withTimeout helper (Kid circuit)

private func withTimeout<T: Sendable>(
    ms: Int,
    _ work: @Sendable @escaping () async -> T?
) async -> T? {
    let nanos = UInt64(ms) * 1_000_000
    return await withTaskGroup(of: T?.self, returning: T?.self) { group in
        group.addTask { await work() }
        group.addTask {
            try? await Task.sleep(nanoseconds: nanos)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first ?? nil
    }
}
