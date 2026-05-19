import XCTest

// MARK: - KeyScreensInteractionUITests
//
// Plan v30 Phase 6 — функциональные UI-тесты ключевых экранов, у которых
// раньше был только tour-скриншот (`AllScreensTourUITests`), но не было
// проверки первичного взаимодействия.
//
// Каждый экран запускается через `-HSStartRoute`, проверяется рендер
// и выполняется первичное взаимодействие (скролл / tap), без краша.
//
// Экраны: rewards, progressDashboard, worldMap, sessionHistory,
//         helpCenter, soundDictionary, dailyChallenge, settings,
//         familyCalendar, parentInsightsTimeline.
// =========================================================================

@MainActor
final class KeyScreensInteractionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
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

    /// Проверяет рендер экрана и выполняет безопасное первичное взаимодействие.
    private func renderAndScroll(route: String) {
        launch(route: route)
        let anyElement = app.descendants(matching: .any).firstMatch
        XCTAssertTrue(
            anyElement.waitForExistence(timeout: 15),
            "Экран '\(route)' не отрисовался"
        )
        XCTAssertEqual(
            app.state, .runningForeground,
            "Экран '\(route)' нестабилен после рендера"
        )

        // Контент: есть хотя бы текст или кнопка (не пустой экран).
        let hasContent = app.staticTexts.count > 0 || app.buttons.count > 0
        XCTAssertTrue(hasContent, "Экран '\(route)' пуст — нет контента")

        // Первичное взаимодействие — скролл (overflow-safety).
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            scrollView.swipeDown()
        }
        XCTAssertEqual(
            app.state, .runningForeground,
            "Экран '\(route)' упал при скролле"
        )
        app.terminate()
    }

    /// Проверяет рендер и tap по первой нейтральной кнопке.
    private func renderAndTapPrimary(route: String) {
        launch(route: route)
        let anyElement = app.descendants(matching: .any).firstMatch
        XCTAssertTrue(
            anyElement.waitForExistence(timeout: 15),
            "Экран '\(route)' не отрисовался"
        )
        let skip = ["close", "закрыть", "назад", "back", "выход", "delete", "удалить"]
        for button in app.buttons.allElementsBoundByIndex.prefix(6)
        where button.exists && button.isHittable {
            if skip.contains(where: { button.label.lowercased().contains($0) }) { continue }
            button.tap()
            XCTAssertEqual(
                app.state, .runningForeground,
                "Экран '\(route)' упал после tap по кнопке"
            )
            break
        }
        app.terminate()
    }

    // MARK: - Tests

    func test_rewards_rendersAndScrolls() throws {
        renderAndScroll(route: "rewards")
    }

    func test_progressDashboard_rendersAndScrolls() throws {
        renderAndScroll(route: "progressDashboard")
    }

    func test_worldMap_rendersAndInteracts() throws {
        renderAndTapPrimary(route: "worldMap")
    }

    func test_sessionHistory_rendersAndScrolls() throws {
        renderAndScroll(route: "sessionHistory")
    }

    func test_helpCenter_rendersAndScrolls() throws {
        renderAndScroll(route: "helpCenter")
    }

    func test_soundDictionary_rendersAndInteracts() throws {
        renderAndTapPrimary(route: "soundDictionary")
    }

    func test_dailyChallenge_rendersAndInteracts() throws {
        renderAndTapPrimary(route: "dailyChallenge")
    }

    func test_settings_rendersAndScrolls() throws {
        renderAndScroll(route: "settings")
    }

    func test_familyCalendar_rendersAndScrolls() throws {
        renderAndScroll(route: "familyCalendar")
    }

    func test_parentInsightsTimeline_rendersAndScrolls() throws {
        renderAndScroll(route: "parentInsightsTimeline")
    }

    // MARK: - Accessibility: интерактивные элементы имеют label

    func test_keyScreens_buttonsHaveAccessibilityLabels() throws {
        for route in ["rewards", "progressDashboard", "settings"] {
            launch(route: route)
            _ = app.descendants(matching: .any).firstMatch.waitForExistence(timeout: 12)
            for button in app.buttons.allElementsBoundByIndex.prefix(6)
            where button.isHittable {
                let hasLabel = !button.label.isEmpty || !button.title.isEmpty
                XCTAssertTrue(
                    hasLabel,
                    "Экран '\(route)': кнопка '\(button.identifier)' без accessibility label"
                )
            }
            app.terminate()
        }
    }
}
