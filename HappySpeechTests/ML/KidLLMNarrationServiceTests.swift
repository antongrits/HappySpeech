@testable import HappySpeech
import XCTest

// MARK: - KidLLMNarrationServiceTests
// ==================================================================================
// Тесты LiveKidLLMNarrationService и MockKidLLMNarrationService.
// Проверяет:
//   1. Sanitization — unsafe output заменяется pre-canned fallback.
//   2. Caching — повторный вызов с тем же ключом не идёт в LLM.
//   3. Mock счётчики — правильно инкрементируются.
//   4. Fallback на PrecannedNarrations когда LLM недоступен.
// ==================================================================================

final class KidLLMNarrationServiceTests: XCTestCase {

    // MARK: - Fixtures

    private func makeNarrationContext(step: Int = 1, totalSteps: Int = 4) -> NarrationContext {
        NarrationContext(
            questId: "jungle-quest",
            currentStep: step,
            totalSteps: totalSteps,
            mood: .encouraging,
            targetSound: "С",
            collectedItems: []
        )
    }

    // MARK: - H7-12: Mock вызывает правильные методы.

    func testMockNarrationService_incrementsCallCounters() async {
        let mock = MockKidLLMNarrationService()
        XCTAssertEqual(mock.narrationCallCount, 0)
        XCTAssertEqual(mock.feedbackCallCount, 0)
        XCTAssertEqual(mock.hintCallCount, 0)

        _ = await mock.generatePlayfulNarration(context: makeNarrationContext())
        _ = await mock.generateAdaptiveFeedback(score: 90, soundId: "С")
        _ = await mock.generateHint(gameType: "narrative_quest", currentStep: "1")

        XCTAssertEqual(mock.narrationCallCount, 1)
        XCTAssertEqual(mock.feedbackCallCount, 1)
        XCTAssertEqual(mock.hintCallCount, 1)
    }

    // MARK: - H7-13: Mock с unsafe flag возвращает pre-canned фразы.

    func testMockNarrationService_withUnsafeFlag_returnsPrecanned() async {
        let mock = MockKidLLMNarrationService()
        mock.simulateUnsafeOutput = true

        let feedback = await mock.generateAdaptiveFeedback(score: 40, soundId: "Р")

        // Pre-canned фразы для encourage bucket не пустые и не содержат unsafe слов.
        XCTAssertFalse(feedback.isEmpty)
        let lowered = feedback.lowercased()
        let bannedWords = ["убить", "страшно", "деньги", "плохо"]
        for word in bannedWords {
            XCTAssertFalse(lowered.contains(word), "Feedback must not contain '\(word)'")
        }
    }

    // MARK: - H7-14: PrecannedNarrations fallback для каждого score bucket.

    func testPrecannedFeedback_allBuckets_nonEmpty() {
        let perfect = PrecannedNarrations.repeatFeedback(score: 95)
        let almost = PrecannedNarrations.repeatFeedback(score: 65)
        let encourage = PrecannedNarrations.repeatFeedback(score: 30)

        XCTAssertFalse(perfect.isEmpty)
        XCTAssertFalse(almost.isEmpty)
        XCTAssertFalse(encourage.isEmpty)
    }

    // MARK: - H7-15: PrecannedNarrations progression — всегда не пустая.

    func testPrecannedNarrationProgression_nonEmpty() {
        let phrase = PrecannedNarrations.narrativeProgression()
        XCTAssertFalse(phrase.isEmpty)
    }

    // MARK: - H7-16: PrecannedNarrations hint для разных gameType.

    func testPrecannedHints_allGameTypes_nonEmpty() {
        let gameTypes = ["narrative_quest", "repeat_after_model", "general", "unknown_game"]
        for gameType in gameTypes {
            let hint = PrecannedNarrations.hint(for: gameType)
            XCTAssertFalse(hint.isEmpty, "Hint must not be empty for gameType=\(gameType)")
        }
    }

    // MARK: - H7-17: LiveKidLLMNarrationService с MockLLMDecisionService — narration не пустой.

    func testLiveNarrationService_withMockLLM_returnsNonEmptyNarration() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true)
        let service = LiveKidLLMNarrationService(llmService: mockLLM)

        let narration = await service.generatePlayfulNarration(context: makeNarrationContext())

        XCTAssertFalse(narration.isEmpty)
    }

    // MARK: - H7-18: LiveKidLLMNarrationService — caching работает (второй вызов не идёт в LLM).

    func testLiveNarrationService_caching_doesNotCallLLMTwice() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true)
        let service = LiveKidLLMNarrationService(llmService: mockLLM)
        let context = makeNarrationContext(step: 1)

        let first = await service.generatePlayfulNarration(context: context)
        let callsAfterFirst = mockLLM.callLog.filter { $0 == "narrativeStep" }.count

        let second = await service.generatePlayfulNarration(context: context)
        let callsAfterSecond = mockLLM.callLog.filter { $0 == "narrativeStep" }.count

        // Второй вызов должен использовать кэш — без дополнительного LLM вызова.
        XCTAssertEqual(callsAfterFirst, callsAfterSecond, "Caching must prevent duplicate LLM calls")
        XCTAssertEqual(first, second, "Cached result must be identical")
    }

    // MARK: - H7-19: LiveKidLLMNarrationService с fallback LLM — использует pre-canned.

    func testLiveNarrationService_withFallbackLLM_returnsNonEmpty() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: false, useFallbackFlag: true)
        let service = LiveKidLLMNarrationService(llmService: mockLLM)

        let feedback = await service.generateAdaptiveFeedback(score: 75, soundId: "Ш")

        XCTAssertFalse(feedback.isEmpty)
    }

    // MARK: - H7-20: LiveKidLLMNarrationService — output не содержит banned words.

    func testLiveNarrationService_output_noBannedWords() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true)
        let service = LiveKidLLMNarrationService(llmService: mockLLM)

        let narration = await service.generatePlayfulNarration(context: makeNarrationContext())
        let lowered = narration.lowercased()

        let bannedWords = ["убить", "умереть", "страшно", "боль", "деньги"]
        for word in bannedWords {
            XCTAssertFalse(
                lowered.contains(word),
                "Narration output must not contain banned word '\(word)'"
            )
        }
    }
}
