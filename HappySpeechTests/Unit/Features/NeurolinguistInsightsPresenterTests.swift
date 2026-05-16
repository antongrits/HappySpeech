@testable import HappySpeech
import XCTest

// MARK: - NeurolinguistInsightsPresenterTests
//
// Phase 2.6 batch 2 v25 — покрытие NeurolinguistInsightsPresenter (0% → цель ≥90%).
//
// Presenter использует @Observable ViewModel (не DisplayLogic). Тесты
// создают ViewModel, присоединяют к presenter и проверяют свойства ViewModel.

@MainActor
final class NeurolinguistInsightsPresenterTests: XCTestCase {

    private func makeSUT() -> (NeurolinguistInsightsPresenter, NeurolinguistInsightsViewModel) {
        let viewModel = NeurolinguistInsightsViewModel()
        let presenter = NeurolinguistInsightsPresenter()
        presenter.viewModel = viewModel
        return (presenter, viewModel)
    }

    private func makeInsightData(
        trendLabel: String = NeurolinguistInsights.TrendKind.stable.rawValue,
        summaryText: String = "Стабильный прогресс",
        primarySoundFocus: String = "С",
        recommendation: String = "Продолжайте занятия"
    ) -> InsightData {
        InsightData(
            id: UUID().uuidString,
            childId: "c-1",
            generatedAt: Date(),
            summaryText: summaryText,
            trendLabel: trendLabel,
            sessionsAnalyzedCount: 5,
            primarySoundFocus: primarySoundFocus,
            recommendation: recommendation
        )
    }

    private func makeMetrics(
        sessionsCount: Int = 5,
        totalAttempts: Int = 50,
        averageAccuracy: Double = 0.75,
        bestSound: String? = "С",
        challengingSound: String? = "Р",
        totalMinutes: Int = 30,
        consecutiveDays: Int = 3,
        trend: NeurolinguistInsights.TrendKind = .stable
    ) -> NeurolinguistInsights.MetricsSnapshot {
        NeurolinguistInsights.MetricsSnapshot(
            sessionsCount: sessionsCount,
            totalAttempts: totalAttempts,
            averageAccuracy: averageAccuracy,
            bestSound: bestSound,
            challengingSound: challengingSound,
            totalMinutes: totalMinutes,
            consecutiveDays: consecutiveDays,
            trend: trend
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_setsStateReady() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(sessionsCount: 3)))
        XCTAssertEqual(vm.state, .ready)
    }

    func test_presentLoad_zeroSessions_setsStateEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(sessionsCount: 0)))
        XCTAssertEqual(vm.state, .empty)
    }

    func test_presentLoad_cardNotNil() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics()))
        XCTAssertNotNil(vm.card)
    }

    func test_presentLoad_cardTitleNotEmpty() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics()))
        XCTAssertFalse(vm.card?.title.isEmpty ?? true)
    }

    func test_presentLoad_summaryMarkdownPassedThrough() {
        let (sut, vm) = makeSUT()
        let summary = "Прогресс за неделю хороший"
        sut.presentLoad(.init(insight: makeInsightData(summaryText: summary), metricsSnapshot: makeMetrics()))
        XCTAssertEqual(vm.card?.summaryMarkdown, summary)
    }

    func test_presentLoad_improvingTrend_colorTokenSuccess() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(
            insight: makeInsightData(trendLabel: NeurolinguistInsights.TrendKind.improving.rawValue),
            metricsSnapshot: makeMetrics()
        ))
        XCTAssertEqual(vm.card?.trendColorToken, "success")
    }

    func test_presentLoad_decliningTrend_colorTokenWarning() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(
            insight: makeInsightData(trendLabel: NeurolinguistInsights.TrendKind.declining.rawValue),
            metricsSnapshot: makeMetrics()
        ))
        XCTAssertEqual(vm.card?.trendColorToken, "warning")
    }

    func test_presentLoad_stableTrend_colorTokenInfo() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(
            insight: makeInsightData(trendLabel: NeurolinguistInsights.TrendKind.stable.rawValue),
            metricsSnapshot: makeMetrics()
        ))
        XCTAssertEqual(vm.card?.trendColorToken, "info")
    }

    func test_presentLoad_unknownTrend_colorTokenNeutral() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(
            insight: makeInsightData(trendLabel: "unknown"),
            metricsSnapshot: makeMetrics()
        ))
        XCTAssertEqual(vm.card?.trendColorToken, "neutral")
    }

    func test_presentLoad_chipsBuilt() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics()))
        XCTAssertFalse(vm.metricChips.isEmpty)
    }

    func test_presentLoad_highAccuracy_accuracyChipIsSuccess() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(averageAccuracy: 0.75)))
        let accuracyChip = vm.metricChips.first { $0.icon == "target" }
        XCTAssertEqual(accuracyChip?.colorToken, "success")
    }

    func test_presentLoad_lowAccuracy_accuracyChipIsWarning() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(averageAccuracy: 0.5)))
        let accuracyChip = vm.metricChips.first { $0.icon == "target" }
        XCTAssertEqual(accuracyChip?.colorToken, "warning")
    }

    func test_presentLoad_hasBestSound_extraChipAdded() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(bestSound: "С")))
        let bestChip = vm.metricChips.first { $0.icon == "star.fill" }
        XCTAssertNotNil(bestChip)
        XCTAssertEqual(bestChip?.value, "С")
    }

    func test_presentLoad_noBestSound_noExtraChip() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(bestSound: nil, challengingSound: nil)))
        let bestChip = vm.metricChips.first { $0.icon == "star.fill" }
        XCTAssertNil(bestChip)
    }

    func test_presentLoad_hasChallengingSound_differentFromBest() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(bestSound: "С", challengingSound: "Р")))
        let challengeChip = vm.metricChips.first { $0.icon == "exclamationmark.triangle.fill" }
        XCTAssertNotNil(challengeChip)
    }

    func test_presentLoad_challengingEqualssBest_noExtraChip() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(bestSound: "С", challengingSound: "С")))
        let challengeChip = vm.metricChips.first { $0.icon == "exclamationmark.triangle.fill" }
        XCTAssertNil(challengeChip)
    }

    func test_presentLoad_consecutiveDays_streakChipColorWarning() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(consecutiveDays: 5)))
        let streakChip = vm.metricChips.first { $0.icon == "flame.fill" }
        XCTAssertEqual(streakChip?.colorToken, "warning")
    }

    func test_presentLoad_zeroStreak_streakChipColorNeutral() {
        let (sut, vm) = makeSUT()
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics(consecutiveDays: 0)))
        let streakChip = vm.metricChips.first { $0.icon == "flame.fill" }
        XCTAssertEqual(streakChip?.colorToken, "neutral")
    }

    func test_presentLoad_clearsErrorMessage() {
        let (sut, vm) = makeSUT()
        vm.errorMessage = "Старая ошибка"
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: makeMetrics()))
        XCTAssertNil(vm.errorMessage)
    }

    func test_presentLoad_setsMetricsSnapshot() {
        let (sut, vm) = makeSUT()
        let metrics = makeMetrics(sessionsCount: 7)
        sut.presentLoad(.init(insight: makeInsightData(), metricsSnapshot: metrics))
        XCTAssertEqual(vm.metricsSnapshot?.sessionsCount, 7)
    }

    // MARK: - presentError

    func test_presentError_setsStateError() {
        let (sut, vm) = makeSUT()
        sut.presentError("Нет подключения")
        if case .error(let msg) = vm.state {
            XCTAssertEqual(msg, "Нет подключения")
        } else {
            XCTFail("Expected .error state")
        }
    }

    func test_presentError_setsErrorMessage() {
        let (sut, vm) = makeSUT()
        sut.presentError("Сервер недоступен")
        XCTAssertEqual(vm.errorMessage, "Сервер недоступен")
    }
}
