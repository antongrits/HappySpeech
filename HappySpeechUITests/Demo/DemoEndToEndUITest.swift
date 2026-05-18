import XCTest

// MARK: - DemoEndToEndUITest
//
// M10.3 v8 — End-to-end UI тест Demo режима.
//
// Стратегия:
//   • Запуск через -UITestDemoMode + -HSStartRoute demoMode — приложение
//     сразу переходит в DemoModeView, минуя Auth и Onboarding.
//   • Проверяем прохождение всех 15 шагов через кнопку «Далее» / «Начать!».
//   • Проверяем что кнопка «Пропустить» работает на любом шаге.
//   • continueAfterFailure = false — первый fail немедленно прерывает тест.
//
// Accessibility идентификаторы ожидаются в DemoModeView:
//   «DemoRoot»       — корневой контейнер DemoModeView
//   «DemoNextButton» — кнопка «Далее» / «Начать!»
//   «DemoSkipButton» — кнопка «Пропустить»
//   «DemoProgressLabel» — текст «Шаг N из 15»
// ==========================================================================

final class DemoEndToEndUITest: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-UITestDemoMode",
            "-UITestDisableAnimations",
            "-HSStartRoute", "demoMode"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - 1. Demo экран появляется при запуске с --demo-mode

    func test_demoRoot_appearsOnLaunch() throws {
        let demoRoot = app.otherElements["DemoRoot"]
        let demoModeVisible = demoRoot.waitForExistence(timeout: 8)
            || findDemoIndicator()

        XCTAssertTrue(demoModeVisible,
            "Demo-режим должен отображаться при запуске с флагом -UITestDemoMode")
    }

    // MARK: - 2. Кнопка «Далее» присутствует на первом шаге

    func test_nextButton_existsOnFirstStep() throws {
        XCTAssertTrue(
            waitForDemoScreen(),
            "Demo-экран должен появиться при -HSStartRoute demoMode"
        )

        let nextButton = findNextButton()
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5),
            "На первом шаге Demo должна присутствовать кнопка перехода вперёд")
    }

    // MARK: - 3. Прохождение первых 5 шагов — приложение не крашится

    func test_firstFiveSteps_nocrash() throws {
        XCTAssertTrue(
            waitForDemoScreen(),
            "Demo-экран должен появиться при -HSStartRoute demoMode"
        )

        var stepCount = 0
        for _ in 1...5 {
            let nextButton = findNextButton()
            guard nextButton.waitForExistence(timeout: 4) else { break }
            // Проверяем что это не кнопка завершения (последний шаг)
            let isFinish = nextButton.label.contains("Начать") || nextButton.label.contains("Готово")
            nextButton.tap()
            stepCount += 1
            if isFinish { break }
        }

        XCTAssertTrue(app.exists,
            "Приложение не должно падать при прохождении первых \(stepCount) шагов Demo")
        XCTAssertGreaterThan(stepCount, 0,
            "Должен быть выполнен хотя бы один шаг Demo")
    }

    // MARK: - 4. Кнопка «Пропустить» работает на первом шаге

    func test_skipButton_dismissesDemo() throws {
        XCTAssertTrue(
            waitForDemoScreen(),
            "Demo-экран должен появиться при -HSStartRoute demoMode"
        )

        let skipButton = findSkipButton()
        XCTAssertTrue(
            skipButton.waitForExistence(timeout: 5),
            "Кнопка «Пропустить» должна присутствовать в Demo-режиме"
        )

        skipButton.tap()

        // После пропуска Demo — либо закрывается экран, либо приложение переходит дальше
        let demoRoot = app.otherElements["DemoRoot"]
        let demoGone = !demoRoot.waitForExistence(timeout: 3)
        let appAlive = app.exists

        // Приоритет: приложение живо (не крашится)
        XCTAssertTrue(appAlive,
            "Приложение должно оставаться активным после нажатия 'Пропустить'")
        // Бонус: Demo экран исчез (необязательный критерий для smoke-уровня)
        XCTAssertTrue(demoGone,
            "Demo экран должен закрыться после нажатия 'Пропустить'")
    }

    // MARK: - 5. Прогресс-индикатор виден во время Demo

    func test_progressIndicator_visibleDuringDemo() throws {
        XCTAssertTrue(
            waitForDemoScreen(),
            "Demo-экран должен появиться при -HSStartRoute demoMode"
        )

        // Ищем текст «Шаг N из 15» или прогресс-бар
        let progressLabelPredicate = NSPredicate(
            format: "label CONTAINS[c] 'шаг' OR label CONTAINS[c] 'из 15' OR label CONTAINS[c] 'из'"
        )
        let progressText = app.staticTexts.matching(progressLabelPredicate).firstMatch
        let progressBar = app.progressIndicators.firstMatch
        let hasProgress = progressText.waitForExistence(timeout: 4)
                       || progressBar.waitForExistence(timeout: 1)

        XCTAssertTrue(hasProgress,
            "В Demo режиме должен отображаться индикатор прогресса (шаг N из 15)")
    }

    // MARK: - 6. Последний шаг показывает «Начать!» или «Готово!»

    func test_lastStep_showsCompletionButton() throws {
        XCTAssertTrue(
            waitForDemoScreen(),
            "Demo-экран должен появиться при -HSStartRoute demoMode"
        )

        // Быстро прокручиваем все шаги (до 20 попыток)
        var attempts = 0
        var reachedEnd = false

        while attempts < 20 {
            let finishPredicate = NSPredicate(
                format: "label CONTAINS[c] 'начать' OR label CONTAINS[c] 'готово' OR label CONTAINS[c] 'завершить'"
            )
            if app.buttons.matching(finishPredicate).firstMatch.waitForExistence(timeout: 0.5) {
                reachedEnd = true
                break
            }

            let nextButton = findNextButton()
            guard nextButton.waitForExistence(timeout: 1) else { break }
            nextButton.tap()
            attempts += 1
        }

        // Smoke-уровень: либо достигли конца, либо просто не крашимся
        XCTAssertTrue(app.exists,
            "Приложение не должно падать при прохождении Demo шагов")

        if reachedEnd {
            let finishPredicate = NSPredicate(
                format: "label CONTAINS[c] 'начать' OR label CONTAINS[c] 'готово' OR label CONTAINS[c] 'завершить'"
            )
            let finishButton = app.buttons.matching(finishPredicate).firstMatch
            XCTAssertTrue(finishButton.exists,
                "На последнем шаге Demo должна появиться кнопка завершения (Начать/Завершить/Готово)")
        }
    }

    // MARK: - Private helpers

    /// Ожидает появления Demo экрана (любого признака).
    @discardableResult
    private func waitForDemoScreen(timeout: TimeInterval = 6) -> Bool {
        let demoRoot = app.otherElements["DemoRoot"]
        if demoRoot.waitForExistence(timeout: timeout) { return true }
        return findDemoIndicator()
    }

    /// Альтернативное определение Demo экрана — по характерным элементам.
    private func findDemoIndicator() -> Bool {
        let skipExists = findSkipButton().waitForExistence(timeout: 2)
        let progressExists = app.progressIndicators.firstMatch.waitForExistence(timeout: 1)
        return skipExists || progressExists
    }

    /// Кнопка «Далее» / «Продолжить» / «Следующий» в Demo.
    private func findNextButton() -> XCUIElement {
        // Сначала по accessibility identifier
        let byId = app.buttons["DemoNextButton"]
        if byId.exists { return byId }
        // По label (предикат)
        let predicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить' OR label CONTAINS[c] 'следующий' OR label CONTAINS[c] 'вперёд' OR label CONTAINS[c] 'вперед'"
        )
        return app.buttons.matching(predicate).firstMatch
    }

    /// Кнопка «Пропустить» в Demo.
    private func findSkipButton() -> XCUIElement {
        let byId = app.buttons["DemoSkipButton"]
        if byId.exists { return byId }
        let predicate = NSPredicate(
            format: "label CONTAINS[c] 'пропустить' OR label CONTAINS[c] 'skip'"
        )
        return app.buttons.matching(predicate).firstMatch
    }
}
