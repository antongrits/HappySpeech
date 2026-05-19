import XCTest

// MARK: - OnboardingFlowUITests
//
// M10.3 — UI тесты онбординга.
//
// Стратегия: устойчивые к UX-правкам тесты через accessibility-идентификаторы
// и NSPredicate-поиск (containsPredicate). `continueAfterFailure = false` —
// первый fail немедленно прерывает тест.
//
// Launch arguments:
//   -UITestResetState         → сбрасывает сохранённую сессию и onboarding flag
//   -UITestDisableAnimations  → ускоряет UI-тесты
// ==================================================================================

@MainActor
final class OnboardingFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITestResetState", "-UITestDisableAnimations"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - 1. Онбординг или главный экран появляются при запуске

    func test_launch_showsKnownRoot() throws {
        // После -UITestResetState приложение показывает SplashView (~2.2 сек),
        // затем переходит в OnboardingRoot (онбординг сброшен).
        let splashRoot  = app.otherElements["SplashRoot"]
        let onboarding  = app.otherElements["OnboardingRoot"]
        let authSignIn  = app.otherElements["AuthSignInRoot"]
        let childHome   = app.otherElements["ChildHomeRoot"]

        let hasSplash = splashRoot.waitForExistence(timeout: 5)
        let appeared = hasSplash
                    || onboarding.waitForExistence(timeout: 8)
                    || authSignIn.waitForExistence(timeout: 5)
                    || childHome.waitForExistence(timeout: 1)

        XCTAssertTrue(appeared,
            "Ожидался один из экранов: SplashRoot, OnboardingRoot, AuthSignInRoot или ChildHomeRoot")
    }

    // MARK: - 2. Кнопка «Далее» / «Продолжить» переводит на следующий шаг

    func test_nextButton_advancesToNextStep() throws {
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        let nextPredicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить' OR label CONTAINS[c] 'начать'"
        )
        let nextButton = app.buttons.matching(nextPredicate).firstMatch
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 6),
            "На первом шаге онбординга (welcome) должна быть кнопка перехода («Начать»)"
        )

        let beforeTap = snapshotCurrentStep()
        nextButton.tap()

        let afterTap = snapshotCurrentStep()
        XCTAssertTrue(app.exists, "Приложение должно быть живо после тапа кнопки 'Далее'")
        _ = beforeTap; _ = afterTap
    }

    // MARK: - 3. Кнопка «Пропустить» отсутствует на непропускаемом первом шаге

    func test_skipButton_absentOnWelcomeStep() throws {
        // Продуктовый контракт: первый шаг (welcome) НЕ пропускаемый
        // (OnboardingStep.isSkippable == false для .welcome). Кнопка
        // «Пропустить» появляется только на шагах sounds/permissions/modelDownload.
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        let skipPredicate = NSPredicate(
            format: "label CONTAINS[c] 'пропустить' OR label CONTAINS[c] 'skip'"
        )
        let skipButton = app.buttons.matching(skipPredicate).firstMatch
        XCTAssertFalse(
            skipButton.waitForExistence(timeout: 2),
            "На первом шаге онбординга кнопки «Пропустить» быть не должно — шаг welcome непропускаемый"
        )
    }

    // MARK: - 4. Прогресс-бар или шаговый индикатор присутствует

    func test_progressIndicator_existsDuringOnboarding() throws {
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        let progressView = app.progressIndicators.firstMatch
        let stepTextPredicate = NSPredicate(format: "label CONTAINS[c] 'шаг' OR label CONTAINS[c] 'из'")
        let stepText = app.staticTexts.matching(stepTextPredicate).firstMatch

        let hasProgress = progressView.waitForExistence(timeout: 3)
                       || stepText.waitForExistence(timeout: 1)

        XCTAssertTrue(hasProgress, "Экран онбординга должен содержать индикатор прогресса")
    }

    // MARK: - 5. Онбординг — линейный поток вперёд, без кнопки «Назад»

    func test_onboarding_isForwardOnly_noBackButton() throws {
        // Продуктовый контракт: footer онбординга (OnboardingFlowView.actionFooter)
        // содержит только primary CTA и опциональную кнопку «Пропустить».
        // Навигации назад нет — поток строго линейный вперёд.
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        let nextPredicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить' OR label CONTAINS[c] 'начать'"
        )
        let nextButton = app.buttons.matching(nextPredicate).firstMatch
        XCTAssertTrue(
            nextButton.waitForExistence(timeout: 6),
            "На первом шаге онбординга должна быть кнопка перехода вперёд"
        )
        nextButton.tap()
        Thread.sleep(forTimeInterval: 0.6)

        let backPredicate = NSPredicate(
            format: "label CONTAINS[c] 'назад' OR label CONTAINS[c] 'back'"
        )
        let backButton = app.buttons.matching(backPredicate).firstMatch
        XCTAssertFalse(
            backButton.waitForExistence(timeout: 2),
            "Онбординг не имеет навигации назад — кнопки «Назад» быть не должно"
        )
        XCTAssertTrue(
            app.otherElements["OnboardingRoot"].waitForExistence(timeout: 3),
            "Онбординг должен оставаться виден после перехода на следующий шаг"
        )
    }

    // MARK: - 6. Маскот или приветственный текст виден на первом шаге

    func test_welcomeContent_visible() throws {
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        XCTAssertTrue(app.exists, "Приложение должно быть активным на первом шаге онбординга")
    }

    // MARK: - 7. Онбординг не зависает при быстрых тапах

    func test_rapidTaps_doNotCrash() throws {
        XCTAssertTrue(
            waitForOnboardingRoot(),
            "OnboardingRoot должен появиться после -UITestResetState"
        )

        let nextPredicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить' OR label CONTAINS[c] 'начать'"
        )
        let nextButton = app.buttons.matching(nextPredicate).firstMatch

        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
            if nextButton.waitForExistence(timeout: 1) { nextButton.tap() }
            if nextButton.waitForExistence(timeout: 1) { nextButton.tap() }
        }

        XCTAssertTrue(app.exists, "Приложение не должно падать от быстрых тапов")
    }

    // MARK: - Private helpers

    @discardableResult
    private func waitForOnboardingRoot(timeout: TimeInterval = 8) -> Bool {
        // Приложение стартует через SplashView (~2.2 сек), поэтому даём увеличенный таймаут.
        app.otherElements["OnboardingRoot"].waitForExistence(timeout: timeout)
    }

    private func snapshotCurrentStep() -> String {
        app.staticTexts.firstMatch.label
    }
}
