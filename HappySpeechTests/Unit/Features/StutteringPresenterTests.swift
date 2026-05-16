import XCTest
@testable import HappySpeech

// MARK: - StutteringPresenterTests
//
// Phase 2.6 batch 3 — покрытие StutteringPresenter (0% → цель ≥90%).

@MainActor
final class StutteringPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: StutteringDisplayLogic {
        var loadScreenVM: StutteringModels.LoadScreen.ViewModel?
        var selectModeVM: StutteringModels.SelectMode.ViewModel?
        var loadProgressVM: StutteringModels.LoadProgress.ViewModel?
        var adaptiveVM: StutteringModels.LoadAdaptiveRecommendation.ViewModel?

        func displayLoadScreen(_ viewModel: StutteringModels.LoadScreen.ViewModel) { loadScreenVM = viewModel }
        func displaySelectMode(_ viewModel: StutteringModels.SelectMode.ViewModel) { selectModeVM = viewModel }
        func displayLoadProgress(_ viewModel: StutteringModels.LoadProgress.ViewModel) { loadProgressVM = viewModel }
        func displayAdaptiveRecommendation(_ viewModel: StutteringModels.LoadAdaptiveRecommendation.ViewModel) { adaptiveVM = viewModel }
    }

    private func makeSUT() -> (StutteringPresenter, DisplaySpy) {
        let sut = StutteringPresenter()
        let spy = DisplaySpy()
        sut.view = spy
        return (sut, spy)
    }

    private func makeCard(mode: StutteringMode) -> ExerciseCardData {
        ExerciseCardData(
            mode: mode,
            titleKey: "key.title",
            subtitleKey: "key.subtitle",
            symbol: "waveform",
            symbolColor: .primary,
            duration: "5 мин"
        )
    }

    // MARK: - presentLoadScreen

    func test_presentLoadScreen_cardsCount_matchesResponse() {
        let (sut, spy) = makeSUT()
        let cards = [makeCard(mode: .metronome), makeCard(mode: .breathing)]
        sut.presentLoadScreen(.init(cards: cards, hasSeenWelcome: true))
        XCTAssertNotNil(spy.loadScreenVM)
        XCTAssertEqual(spy.loadScreenVM?.cards.count, 2)
        XCTAssertFalse(spy.loadScreenVM?.showWelcomeSheet ?? true)
    }

    func test_presentLoadScreen_hasNotSeenWelcome_showsWelcomeSheet() {
        let (sut, spy) = makeSUT()
        sut.presentLoadScreen(.init(cards: [], hasSeenWelcome: false))
        XCTAssertTrue(spy.loadScreenVM?.showWelcomeSheet == true)
    }

    func test_presentLoadScreen_eachCard_titleNotEmpty() {
        let (sut, spy) = makeSUT()
        let cards = StutteringMode.allCases.map { makeCard(mode: $0) }
        sut.presentLoadScreen(.init(cards: cards, hasSeenWelcome: true))
        for card in spy.loadScreenVM?.cards ?? [] {
            XCTAssertFalse(card.title.isEmpty, "Title для \(card.mode) не должен быть пустым")
            XCTAssertFalse(card.subtitle.isEmpty, "Subtitle для \(card.mode) не должен быть пустым")
        }
    }

    func test_presentLoadScreen_allModes_differentTitles() {
        let (sut, spy) = makeSUT()
        let cards = StutteringMode.allCases.map { makeCard(mode: $0) }
        sut.presentLoadScreen(.init(cards: cards, hasSeenWelcome: true))
        let titles = spy.loadScreenVM?.cards.map(\.title) ?? []
        let uniqueTitles = Set(titles)
        XCTAssertEqual(uniqueTitles.count, StutteringMode.allCases.count, "Все режимы должны иметь уникальные заголовки")
    }

    func test_presentLoadScreen_allModes_accessibilityLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let cards = StutteringMode.allCases.map { makeCard(mode: $0) }
        sut.presentLoadScreen(.init(cards: cards, hasSeenWelcome: true))
        for card in spy.loadScreenVM?.cards ?? [] {
            XCTAssertFalse(card.accessibilityLabel.isEmpty)
        }
    }

    // MARK: - presentSelectMode

    func test_presentSelectMode_passesMode() {
        let (sut, spy) = makeSUT()
        sut.presentSelectMode(.init(mode: .metronome))
        XCTAssertEqual(spy.selectModeVM?.mode, .metronome)
    }

    func test_presentSelectMode_allModes_passesCorrectly() {
        let (sut, spy) = makeSUT()
        for mode in StutteringMode.allCases {
            sut.presentSelectMode(.init(mode: mode))
            XCTAssertEqual(spy.selectModeVM?.mode, mode, "Режим \(mode) должен передаться в ViewModel")
        }
    }

    // MARK: - presentLoadProgress

    func test_presentLoadProgress_withProgress_rowsNotEmpty() {
        let (sut, spy) = makeSUT()
        var featureProgress: [StutteringMode: FeatureProgress] = [:]
        for mode in StutteringMode.allCases {
            featureProgress[mode] = FeatureProgress(mode: mode, streak: 3, completedToday: true)
        }
        sut.presentLoadProgress(.init(
            featureProgress: featureProgress,
            totalSessions: 10,
            fluencyImprovementPct: 0.25
        ))
        XCTAssertNotNil(spy.loadProgressVM)
        XCTAssertFalse(spy.loadProgressVM?.featureRows.isEmpty ?? true)
    }

    func test_presentLoadProgress_totalSessionsLabel_containsCount() {
        let (sut, spy) = makeSUT()
        sut.presentLoadProgress(.init(featureProgress: [:], totalSessions: 42, fluencyImprovementPct: 0.5))
        let label = spy.loadProgressVM?.totalSessionsLabel ?? ""
        XCTAssertTrue(label.contains("42"), "Метка сессий должна содержать '42'")
    }

    func test_presentLoadProgress_fluencyLabel_containsPercent() {
        let (sut, spy) = makeSUT()
        sut.presentLoadProgress(.init(featureProgress: [:], totalSessions: 0, fluencyImprovementPct: 0.33))
        let label = spy.loadProgressVM?.fluencyLabel ?? ""
        XCTAssertTrue(label.contains("33"), "Метка fluency должна содержать '33'")
    }

    func test_presentLoadProgress_zeroStreak_streakLabelNotEmpty() {
        let (sut, spy) = makeSUT()
        let progress: [StutteringMode: FeatureProgress] = [
            .metronome: FeatureProgress(mode: .metronome, streak: 0, completedToday: false)
        ]
        sut.presentLoadProgress(.init(featureProgress: progress, totalSessions: 1, fluencyImprovementPct: 0.0))
        let row = spy.loadProgressVM?.featureRows.first
        XCTAssertNotNil(row)
        XCTAssertFalse(row?.streakLabel.isEmpty ?? true)
    }

    func test_presentLoadProgress_nonZeroStreak_streakLabelContainsNumber() {
        let (sut, spy) = makeSUT()
        let progress: [StutteringMode: FeatureProgress] = [
            .breathing: FeatureProgress(mode: .breathing, streak: 7, completedToday: true)
        ]
        sut.presentLoadProgress(.init(featureProgress: progress, totalSessions: 5, fluencyImprovementPct: 0.1))
        let row = spy.loadProgressVM?.featureRows.first
        XCTAssertTrue(row?.streakLabel.contains("7") == true, "Streak label должен содержать '7'")
    }

    // MARK: - presentAdaptiveRecommendation

    func test_presentAdaptiveRecommendation_passesMode() {
        let (sut, spy) = makeSUT()
        sut.presentAdaptiveRecommendation(.init(
            recommendedMode: .pacing,
            voicePromptText: "Попробуй ритм",
            shouldShowGlow: true
        ))
        XCTAssertNotNil(spy.adaptiveVM)
        XCTAssertEqual(spy.adaptiveVM?.recommendedMode, .pacing)
        XCTAssertEqual(spy.adaptiveVM?.voicePromptText, "Попробуй ритм")
        XCTAssertTrue(spy.adaptiveVM?.showGlowAnimation == true)
    }

    func test_presentAdaptiveRecommendation_noGlow_showGlowFalse() {
        let (sut, spy) = makeSUT()
        sut.presentAdaptiveRecommendation(.init(
            recommendedMode: .diary,
            voicePromptText: "",
            shouldShowGlow: false
        ))
        XCTAssertFalse(spy.adaptiveVM?.showGlowAnimation ?? true)
    }
}
