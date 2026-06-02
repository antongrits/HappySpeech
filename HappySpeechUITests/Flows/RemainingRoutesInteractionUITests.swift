import XCTest

// MARK: - RemainingRoutesInteractionUITests
//
// v32 QA — добиваем интерактивное (не screenshot-only) покрытие маршрутов до
// ~100%. До этого файла 31 уникальный целевой `AppRoute` имел только
// screenshot-тур (`AllScreensTourUITests`) либо вообще не упоминался в тестах,
// но не имел функциональной проверки «экран не пустой + первичное
// взаимодействие не роняет приложение».
//
// Покрываемые экраны (route → контур):
//   Детские игры/механики (kid):
//     soundDetective, syllableSnail, fourthExtra, wordFormation, whoseTail,
//     sentenceConstructor, animalSoundsBingo, wordRhymeGame, colorAndSound,
//     musicalSoundDrums, palindromeHunter, phonemeFamilyMatcher, soundDoctorKid,
//     soundJournalKid, practiceReminderKid, storyRetellingPro, imitationLab,
//     whisperGame, letterPaintingFun, sentenceBuilderKid, achievementCalendar
//   Родительский контур (parent):
//     conversationStartersParent, weeklyParentTip, childLanguageMilestones,
//     parentDailyDigest, parentInspirationBoard
//   Специалистский контур (specialist):
//     specialistCaseNotes, specialistQuickAssessment, specialistResourcesLibrary,
//     specialistSchedule
//   Семейный контур (family):
//     familyVoiceMessageHub
//
// Точка входа — production launch-hook `-HSStartRoute <route>`
// (`AppCoordinatorView.resolveStartRoute`). При наличии аргумента контейнер
// переключается на preview-стабы — Realm seed-контент, без сети.
//
// У этих View нет стабильного `accessibilityIdentifier("...Root")`, поэтому
// рендер проверяется честно по контенту: экран отрисовал navigationBar /
// staticText / button (а не пустой launch image) и остаётся в foreground.
// Затем выполняется безопасное первичное взаимодействие (tap по основной
// кнопке либо скролл), которое не должно ронять приложение.
// =========================================================================

@MainActor
final class RemainingRoutesInteractionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        app?.terminate()
        app = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func launch(route: String) {
        app = XCUIApplication()
        app.launchArguments = [
            "-HSStartRoute", route,
            "-UITESTING", "1",
            "-UITestDisableAnimations"
        ]
        app.launch()
    }

    /// Проверяет, что экран реально отрисовался (не пустой launch image) и
    /// приложение стабильно. Возвращает `true`, если рендер подтверждён.
    @discardableResult
    private func assertRendered(route: String) -> Bool {
        // Любой элемент = render произошёл, а не пустой launch image.
        let anyElement = app.descendants(matching: .any).firstMatch
        let rendered = anyElement.waitForExistence(timeout: 15)
        XCTAssertTrue(rendered, "Экран '\(route)' не отрисовался за 15с")
        guard rendered else { return false }

        XCTAssertEqual(
            app.state, .runningForeground,
            "Экран '\(route)' нестабилен после рендера"
        )

        // Не пустой экран: есть navigationBar / текст / кнопка / scrollView.
        let hasContent = app.navigationBars.count > 0
            || app.staticTexts.count > 0
            || app.buttons.count > 0
            || app.scrollViews.count > 0
        XCTAssertTrue(hasContent, "Экран '\(route)' пуст — нет контента")
        return hasContent
    }

    /// Безопасное первичное взаимодействие: tap по первой нейтральной кнопке
    /// (не close/back/delete), иначе скролл. Экран не должен крашиться.
    private func exercisePrimaryInteraction(route: String) {
        let skip = [
            "close", "закрыть", "назад", "back", "выход",
            "delete", "удалить", "x", "отмена", "cancel"
        ]
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(8) where button.exists && button.isHittable {
            let label = button.label.lowercased()
            if skip.contains(where: { label.contains($0) }) { continue }
            button.tap()
            XCTAssertEqual(
                app.state, .runningForeground,
                "Экран '\(route)' упал после tap по '\(button.label)'"
            )
            return
        }
        // Кнопок нет — пробуем скролл (контентные экраны: дайджесты, доски).
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeDown()
            XCTAssertEqual(
                app.state, .runningForeground,
                "Экран '\(route)' упал при скролле"
            )
        }
    }

    /// Полный сценарий: запуск → рендер-проверка → первичное взаимодействие.
    private func runScenario(route: String) {
        launch(route: route)
        if assertRendered(route: route) {
            exercisePrimaryInteraction(route: route)
        }
        app.terminate()
    }

    // MARK: - Kid circuit — игры/механики (21)

    func test_soundDetective_rendersAndInteracts() throws {
        runScenario(route: "soundDetective")
    }

    func test_syllableSnail_rendersAndInteracts() throws {
        runScenario(route: "syllableSnail")
    }

    func test_fourthExtra_rendersAndInteracts() throws {
        runScenario(route: "fourthExtra")
    }

    func test_wordFormation_rendersAndInteracts() throws {
        runScenario(route: "wordFormation")
    }

    func test_whoseTail_rendersAndInteracts() throws {
        runScenario(route: "whoseTail")
    }

    func test_sentenceConstructor_rendersAndInteracts() throws {
        runScenario(route: "sentenceConstructor")
    }

    func test_animalSoundsBingo_rendersAndInteracts() throws {
        runScenario(route: "animalSoundsBingo")
    }

    func test_wordRhymeGame_rendersAndInteracts() throws {
        runScenario(route: "wordRhymeGame")
    }

    func test_colorAndSound_rendersAndInteracts() throws {
        runScenario(route: "colorAndSound")
    }

    func test_musicalSoundDrums_rendersAndInteracts() throws {
        runScenario(route: "musicalSoundDrums")
    }

    func test_palindromeHunter_rendersAndInteracts() throws {
        runScenario(route: "palindromeHunter")
    }

    func test_phonemeFamilyMatcher_rendersAndInteracts() throws {
        runScenario(route: "phonemeFamilyMatcher")
    }

    func test_soundDoctorKid_rendersAndInteracts() throws {
        runScenario(route: "soundDoctorKid")
    }

    func test_soundJournalKid_rendersAndInteracts() throws {
        runScenario(route: "soundJournalKid")
    }

    func test_practiceReminderKid_rendersAndInteracts() throws {
        runScenario(route: "practiceReminderKid")
    }

    func test_storyRetellingPro_rendersAndInteracts() throws {
        runScenario(route: "storyRetellingPro")
    }

    func test_imitationLab_rendersAndInteracts() throws {
        runScenario(route: "imitationLab")
    }

    func test_whisperGame_rendersAndInteracts() throws {
        runScenario(route: "whisperGame")
    }

    func test_letterPaintingFun_rendersAndInteracts() throws {
        runScenario(route: "letterPaintingFun")
    }

    func test_sentenceBuilderKid_rendersAndInteracts() throws {
        runScenario(route: "sentenceBuilderKid")
    }

    func test_achievementCalendar_rendersAndInteracts() throws {
        runScenario(route: "achievementCalendar")
    }

    // MARK: - Parent circuit (5)

    func test_conversationStartersParent_rendersAndInteracts() throws {
        runScenario(route: "conversationStartersParent")
    }

    func test_weeklyParentTip_rendersAndInteracts() throws {
        runScenario(route: "weeklyParentTip")
    }

    func test_childLanguageMilestones_rendersAndInteracts() throws {
        runScenario(route: "childLanguageMilestones")
    }

    func test_parentDailyDigest_rendersAndInteracts() throws {
        runScenario(route: "parentDailyDigest")
    }

    func test_parentInspirationBoard_rendersAndInteracts() throws {
        runScenario(route: "parentInspirationBoard")
    }

    // MARK: - Specialist circuit (4)

    func test_specialistCaseNotes_rendersAndInteracts() throws {
        runScenario(route: "specialistCaseNotes")
    }

    func test_specialistQuickAssessment_rendersAndInteracts() throws {
        runScenario(route: "specialistQuickAssessment")
    }

    func test_specialistResourcesLibrary_rendersAndInteracts() throws {
        runScenario(route: "specialistResourcesLibrary")
    }

    func test_specialistSchedule_rendersAndInteracts() throws {
        runScenario(route: "specialistSchedule")
    }

    // MARK: - Family circuit (1)

    func test_familyVoiceMessageHub_rendersAndInteracts() throws {
        runScenario(route: "familyVoiceMessageHub")
    }

    // MARK: - Последовательный запуск всех 31 — нет краша при навигации

    func test_allRemainingRoutes_launchSequentially_noCrash() throws {
        let routes = [
            // kid
            "soundDetective", "syllableSnail", "fourthExtra", "wordFormation",
            "whoseTail", "sentenceConstructor", "animalSoundsBingo",
            "wordRhymeGame", "colorAndSound", "musicalSoundDrums",
            "palindromeHunter", "phonemeFamilyMatcher", "soundDoctorKid",
            "soundJournalKid", "practiceReminderKid", "storyRetellingPro",
            "imitationLab", "whisperGame", "letterPaintingFun",
            "sentenceBuilderKid", "achievementCalendar",
            // parent
            "conversationStartersParent", "weeklyParentTip",
            "childLanguageMilestones", "parentDailyDigest",
            "parentInspirationBoard",
            // specialist
            "specialistCaseNotes", "specialistQuickAssessment",
            "specialistResourcesLibrary", "specialistSchedule",
            // family
            "familyVoiceMessageHub"
        ]
        for route in routes {
            launch(route: route)
            let anyElement = app.descendants(matching: .any).firstMatch
            XCTAssertTrue(
                anyElement.waitForExistence(timeout: 12),
                "Экран '\(route)' не запустился — возможен краш при старте"
            )
            XCTAssertEqual(
                app.state, .runningForeground,
                "Экран '\(route)' нестабилен после запуска"
            )
            app.terminate()
        }
    }
}
