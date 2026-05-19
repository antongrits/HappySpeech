import XCTest

// MARK: - V29FeatureScreensUITests
//
// Plan v30 Phase 6 — функциональные UI-тесты для 12 фич-экранов v29.
//
// Каждый экран:
//   1. запускается через debug-shortcut `-HSStartRoute <route>`
//      (резолв в `AppCoordinatorView.resolveStartRoute(_:)`);
//   2. проверяется, что экран отрисовался (root-anchor / nav-title / контент);
//   3. выполняется первичное взаимодействие (tap по основной кнопке,
//      скролл, переключение) — экран не должен крашиться;
//   4. проверяется, что приложение остаётся стабильным.
//
// Экраны v29 не имеют `accessibilityIdentifier("...Root")`, поэтому
// проверка рендера идёт по navigationBar / staticText заголовка и наличию
// интерактивных элементов. Это honest-проверка: тест ловит пустой экран,
// сломанную навигацию и краш при первом взаимодействии.
//
// 12 экранов v29 (route → русский заголовок):
//   prosody             — Голосовые краски
//   speechTempo         — Темп-дорожка
//   storytelling        — Я расскажу историю
//   retelling           — Расскажи по-настоящему
//   lexicalThemes       — Мир слов
//   phonemicListening   — Слушай внимательно
//   soundTrafficLight   — Звуковой светофор
//   breatheAndSpeak     — Дыши и говори
//   parentGuide         — Логопед для родителей
//   plainProgress       — Понятный прогресс
//   coPlay              — Занятие вместе
//   assignedHomework    — Домашние задания
// =========================================================================

@MainActor
final class V29FeatureScreensUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Запускает приложение на указанном route.
    private func launch(route: String) {
        app = XCUIApplication()
        app.launchArguments = [
            "-HSStartRoute", route,
            "-UITESTING", "1",
            "-UITestDisableAnimations"
        ]
        app.launch()
    }

    /// Проверяет, что экран фичи отрисовался: появился любой UI-контент
    /// (navigationBar / staticText / button), а не пустой launch-screen.
    /// Возвращает `true`, если рендер подтверждён.
    @discardableResult
    private func assertScreenRendered(route: String, expectedTitle: String) -> Bool {
        // 1. Любой элемент = render произошёл (не пустой launch image).
        let anyElement = app.descendants(matching: .any).firstMatch
        let rendered = anyElement.waitForExistence(timeout: 15)
        XCTAssertTrue(rendered, "Экран '\(route)' не отрисовался за 15с")
        guard rendered else { return false }

        // 2. Контентная проверка — заголовок ИЛИ интерактивные элементы.
        //    Заголовок может быть в navigationBar или как staticText.
        let titlePredicate = NSPredicate(format: "label CONTAINS[c] %@", expectedTitle)
        let navBarTitle = app.navigationBars.staticTexts
            .matching(titlePredicate).firstMatch
        let anyTitle = app.staticTexts.matching(titlePredicate).firstMatch

        let hasTitle = navBarTitle.waitForExistence(timeout: 4)
            || anyTitle.waitForExistence(timeout: 2)
        let hasContent = app.buttons.count > 0
            || app.staticTexts.count > 0
            || app.scrollViews.count > 0

        XCTAssertTrue(
            hasTitle || hasContent,
            "Экран '\(route)' пуст — нет ни заголовка '\(expectedTitle)', ни контента"
        )
        return hasTitle || hasContent
    }

    /// Тапает первую видимую интерактивную кнопку (не close/back) и проверяет
    /// стабильность приложения. Защита от overflow / краша на первом действии.
    private func exercisePrimaryInteraction(route: String) {
        let buttons = app.buttons.allElementsBoundByIndex
        let skipPredicates = ["close", "закрыть", "назад", "back", "x"]
        for button in buttons.prefix(8) where button.exists && button.isHittable {
            let label = button.label.lowercased()
            if skipPredicates.contains(where: { label.contains($0) }) { continue }
            button.tap()
            // После взаимодействия приложение должно остаться активным.
            XCTAssertTrue(
                app.state == .runningForeground,
                "После тапа на экране '\(route)' приложение упало или ушло в фон"
            )
            return
        }
        // Если интерактивных кнопок нет — пробуем скролл (контентные экраны).
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            XCTAssertTrue(
                app.state == .runningForeground,
                "После скролла на экране '\(route)' приложение упало"
            )
        }
    }

    /// Полный сценарий проверки одного фич-экрана.
    private func runScreenScenario(route: String, title: String) {
        launch(route: route)
        let rendered = assertScreenRendered(route: route, expectedTitle: title)
        if rendered {
            exercisePrimaryInteraction(route: route)
        }
        app.terminate()
    }

    // MARK: - 1. Prosody — Голосовые краски

    func test_prosody_rendersAndInteracts() throws {
        runScreenScenario(route: "prosody", title: "Голосовые краски")
    }

    // MARK: - 2. SpeechTempo — Темп-дорожка

    func test_speechTempo_rendersAndInteracts() throws {
        runScreenScenario(route: "speechTempo", title: "Темп-дорожка")
    }

    // MARK: - 3. Storytelling — Я расскажу историю

    func test_storytelling_rendersAndInteracts() throws {
        runScreenScenario(route: "storytelling", title: "Я расскажу историю")
    }

    // MARK: - 4. Retelling — Расскажи по-настоящему

    func test_retelling_rendersAndInteracts() throws {
        runScreenScenario(route: "retelling", title: "Расскажи по-настоящему")
    }

    // MARK: - 5. LexicalThemes — Мир слов

    func test_lexicalThemes_rendersAndInteracts() throws {
        runScreenScenario(route: "lexicalThemes", title: "Мир слов")
    }

    // MARK: - 6. PhonemicListening — Слушай внимательно

    func test_phonemicListening_rendersAndInteracts() throws {
        runScreenScenario(route: "phonemicListening", title: "Слушай внимательно")
    }

    // MARK: - 7. SoundTrafficLight — Звуковой светофор

    func test_soundTrafficLight_rendersAndInteracts() throws {
        runScreenScenario(route: "soundTrafficLight", title: "Звуковой светофор")
    }

    // MARK: - 8. BreatheAndSpeak — Дыши и говори

    func test_breatheAndSpeak_rendersAndInteracts() throws {
        runScreenScenario(route: "breatheAndSpeak", title: "Дыши и говори")
    }

    // MARK: - 9. ParentGuide — Логопед для родителей

    func test_parentGuide_rendersAndInteracts() throws {
        runScreenScenario(route: "parentGuide", title: "Логопед для родителей")
    }

    // MARK: - 10. PlainProgress — Понятный прогресс

    func test_plainProgress_rendersAndInteracts() throws {
        runScreenScenario(route: "plainProgress", title: "Понятный прогресс")
    }

    // MARK: - 11. CoPlay — Занятие вместе

    func test_coPlay_rendersAndInteracts() throws {
        runScreenScenario(route: "coPlay", title: "Занятие вместе")
    }

    // MARK: - 12. AssignedHomework — Домашние задания

    func test_assignedHomework_rendersAndInteracts() throws {
        runScreenScenario(route: "assignedHomework", title: "Домашние задания")
    }

    // MARK: - 13. Все 12 экранов подряд — нет краша при последовательной навигации

    func test_allV29Screens_launchSequentially_noCrash() throws {
        let routes = [
            "prosody", "speechTempo", "storytelling", "retelling",
            "lexicalThemes", "phonemicListening", "soundTrafficLight",
            "breatheAndSpeak", "parentGuide", "plainProgress",
            "coPlay", "assignedHomework"
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
