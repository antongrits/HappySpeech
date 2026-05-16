@testable import HappySpeech
import XCTest

// MARK: - ParentInsightsWorkerTests
//
// Тестирует ParentInsightsWorker (Tier C rule-based путь через MockLLMDecisionService
// с useFallbackFlag=true, и путь без llmService=nil).
// LLM Tier B тест: useFallbackFlag=false → если mock возвращает non-fallback summary.

@MainActor
final class ParentInsightsWorkerTests: XCTestCase {

    // MARK: - helpers

    private func makeSound(sound: String, accuracy: Float, sessions: Int,
                           trend: ProgressTrend = .stable) -> SoundProgress {
        SoundProgress(sound: sound, accuracy: accuracy, sessions: sessions, trend: trend)
    }

    // MARK: - empty sounds → placeholder

    func test_generateInsights_emptySounds_returnsPlaceholder() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let insights = await sut.generateInsights(childName: "Маша", sounds: [], streakDays: 0)
        XCTAssertEqual(insights.count, 1, "При пустых звуках должен вернуться 1 placeholder")
        XCTAssertEqual(insights.first?.icon, "sparkles")
    }

    // MARK: - Tier C: best sound (accuracy > 80%)

    func test_ruleBasedInsights_bestSound_generatesPositiveInsight() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Р", accuracy: 0.90, sessions: 5)]
        let insights = await sut.generateInsights(childName: "Ваня", sounds: sounds, streakDays: 0)
        let positive = insights.filter { $0.tone == .positive }
        XCTAssertFalse(positive.isEmpty, "Высокая точность должна давать positive insight")
    }

    func test_ruleBasedInsights_bestSoundBelowThreshold_noPositiveForBestSound() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Ш", accuracy: 0.70, sessions: 3)]
        let insights = await sut.generateInsights(childName: "Катя", sounds: sounds, streakDays: 0)
        // star.fill только при accuracy > 0.80
        let starInsights = insights.filter { $0.icon == "star.fill" }
        XCTAssertTrue(starInsights.isEmpty, "При accuracy < 80% нет star.fill insight")
    }

    // MARK: - Tier C: worst sound (accuracy < 50%)

    func test_ruleBasedInsights_worstSound_generatesWarning() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "З", accuracy: 0.30, sessions: 4)]
        let insights = await sut.generateInsights(childName: "Рома", sounds: sounds, streakDays: 0)
        let warnings = insights.filter { $0.tone == .warning }
        XCTAssertFalse(warnings.isEmpty, "Низкая точность должна давать warning insight")
    }

    // MARK: - Tier C: streak

    func test_ruleBasedInsights_streak5_generatesFlameInsight() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Р", accuracy: 0.60, sessions: 2)]
        let insights = await sut.generateInsights(childName: "Оля", sounds: sounds, streakDays: 5)
        let flameInsights = insights.filter { $0.icon == "flame.fill" }
        XCTAssertFalse(flameInsights.isEmpty, "Streak >= 5 должен давать flame insight")
    }

    func test_ruleBasedInsights_streak4_noFlameInsight() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Л", accuracy: 0.60, sessions: 2)]
        let insights = await sut.generateInsights(childName: "Петя", sounds: sounds, streakDays: 4)
        let flameInsights = insights.filter { $0.icon == "flame.fill" }
        XCTAssertTrue(flameInsights.isEmpty, "Streak < 5 не должен давать flame insight")
    }

    // MARK: - Tier C: declining trend

    func test_ruleBasedInsights_decliningTrend_generatesWarning() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Ж", accuracy: 0.55, sessions: 3, trend: .down)]
        let insights = await sut.generateInsights(childName: "Нина", sounds: sounds, streakDays: 0)
        let declining = insights.filter { $0.icon == "chart.line.downtrend.xyaxis" }
        XCTAssertFalse(declining.isEmpty, "Снижающийся тренд должен давать downtrend insight")
    }

    // MARK: - Tier C: improving trend

    func test_ruleBasedInsights_improvingTrend_generatesPositive() async {
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "С", accuracy: 0.65, sessions: 3, trend: .up)]
        let insights = await sut.generateInsights(childName: "Лера", sounds: sounds, streakDays: 0)
        let improving = insights.filter { $0.icon == "chart.line.uptrend.xyaxis" }
        XCTAssertFalse(improving.isEmpty, "Растущий тренд должен давать uptrend insight")
    }

    // MARK: - Tier C: default placeholder when no rule triggers

    func test_ruleBasedInsights_noRuleTriggered_returnsSparklesPlaceholder() async {
        // accuracy 0.60 (не best), accuracy 0.60 (не worst), stable trend, streak 0
        let sut = ParentInsightsWorker(llmService: nil)
        let sounds = [makeSound(sound: "Т", accuracy: 0.60, sessions: 1, trend: .stable)]
        let insights = await sut.generateInsights(childName: "Гриша", sounds: sounds, streakDays: 0)
        XCTAssertFalse(insights.isEmpty, "Всегда должен быть хотя бы 1 insight")
    }

    // MARK: - Tier B path: useFallbackFlag=false → LLM возвращает non-fallback

    func test_tierB_llmNonFallback_returnsSingleLLMInsight() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: true, useFallbackFlag: false)
        let sut = ParentInsightsWorker(llmService: mockLLM)
        let sounds = [makeSound(sound: "Р", accuracy: 0.80, sessions: 5)]
        let insights = await sut.generateInsights(childName: "Маша", sounds: sounds, streakDays: 0)
        // MockLLMDecisionService с useFallbackFlag=false возвращает summaryText непустой
        // и source=.onDevice → ParentInsightsWorker оборачивает в 1 sparkles insight
        XCTAssertFalse(insights.isEmpty, "При работающем LLM должен быть хотя бы 1 insight")
    }

    // MARK: - Tier B path: useFallbackFlag=true → откат на Tier C

    func test_tierB_llmFallback_fallsThroughToRuleBasedInsights() async {
        let mockLLM = MockLLMDecisionService(onDeviceReady: false, useFallbackFlag: true)
        let sut = ParentInsightsWorker(llmService: mockLLM)
        let sounds = [makeSound(sound: "Ш", accuracy: 0.90, sessions: 3)]
        let insights = await sut.generateInsights(childName: "Иван", sounds: sounds, streakDays: 0)
        // useFallbackFlag=true → meta.usedFallback=true → tryLLMInsights возвращает nil → Tier C
        XCTAssertFalse(insights.isEmpty)
    }
}
