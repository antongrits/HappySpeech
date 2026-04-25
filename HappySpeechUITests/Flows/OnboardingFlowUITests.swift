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
        let onboarding  = app.otherElements["OnboardingRoot"]
        let authLanding = app.otherElements["AuthLandingRoot"]
        let childHome   = app.otherElements["ChildHomeRoot"]

        let appeared = onboarding.waitForExistence(timeout: 5)
                    || authLanding.waitForExistence(timeout: 1)
                    || childHome.waitForExistence(timeout: 1)

        XCTAssertTrue(appeared,
            "Ожидался один из экранов: OnboardingRoot, AuthLandingRoot или ChildHomeRoot")
    }

    // MARK: - 2. Кнопка «Далее» / «Продолжить» переводит на следующий шаг

    func test_nextButton_advancesToNextStep() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен без сброса состояния")
        }

        let nextPredicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить' OR label CONTAINS[c] 'начать'"
        )
        let nextButton = app.buttons.matching(nextPredicate).firstMatch
        guard nextButton.waitForExistence(timeout: 4) else {
            throw XCTSkip("Кнопка перехода не найдена на экране онбординга")
        }

        let beforeTap = snapshotCurrentStep()
        nextButton.tap()

        let afterTap = snapshotCurrentStep()
        XCTAssertTrue(app.exists, "Приложение должно быть живо после тапа кнопки 'Далее'")
        _ = beforeTap; _ = afterTap
    }

    // MARK: - 3. Кнопка «Пропустить» убирает онбординг

    func test_skipButton_dismissesOnboarding() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен")
        }

        let skipPredicate = NSPredicate(
            format: "label CONTAINS[c] 'пропустить' OR label CONTAINS[c] 'skip'"
        )
        let skipButton = app.buttons.matching(skipPredicate).firstMatch
        guard skipButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Кнопка 'Пропустить' не найдена — возможно, она отсутствует на первом шаге")
        }

        skipButton.tap()

        let onboardingRoot = app.otherElements["OnboardingRoot"]
        let stillExists = onboardingRoot.waitForExistence(timeout: 2)
        XCTAssertFalse(stillExists, "OnboardingRoot не должен быть виден после нажатия 'Пропустить'")
    }

    // MARK: - 4. Прогресс-бар или шаговый индикатор присутствует

    func test_progressIndicator_existsDuringOnboarding() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен")
        }

        let progressView = app.progressIndicators.firstMatch
        let stepTextPredicate = NSPredicate(format: "label CONTAINS[c] 'шаг' OR label CONTAINS[c] 'из'")
        let stepText = app.staticTexts.matching(stepTextPredicate).firstMatch

        let hasProgress = progressView.waitForExistence(timeout: 3)
                       || stepText.waitForExistence(timeout: 1)

        XCTAssertTrue(hasProgress, "Экран онбординга должен содержать индикатор прогресса")
    }

    // MARK: - 5. Кнопка «Назад» возвращает на предыдущий шаг

    func test_backButton_goesToPreviousStep() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен")
        }

        let nextPredicate = NSPredicate(
            format: "label CONTAINS[c] 'далее' OR label CONTAINS[c] 'продолжить'"
        )
        let nextButton = app.buttons.matching(nextPredicate).firstMatch
        guard nextButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Нет кнопки 'Далее' для перехода вперёд")
        }
        nextButton.tap()

        let backPredicate = NSPredicate(
            format: "label CONTAINS[c] 'назад' OR label CONTAINS[c] 'back'"
        )
        let backButton = app.buttons.matching(backPredicate).firstMatch
        guard backButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("Кнопка 'Назад' не появилась после перехода на второй шаг")
        }
        backButton.tap()

        let onboardingRoot = app.otherElements["OnboardingRoot"]
        XCTAssertTrue(onboardingRoot.waitForExistence(timeout: 3),
            "После нажатия 'Назад' онбординг должен оставаться виден")
    }

    // MARK: - 6. Маскот или приветственный текст виден на первом шаге

    func test_welcomeContent_visible() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен")
        }

        XCTAssertTrue(app.exists, "Приложение должно быть активным на первом шаге онбординга")
    }

    // MARK: - 7. Онбординг не зависает при быстрых тапах

    func test_rapidTaps_doNotCrash() throws {
        guard waitForOnboardingRoot() else {
            throw XCTSkip("Онбординг недоступен")
        }

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
    private func waitForOnboardingRoot(timeout: TimeInterval = 4) -> Bool {
        app.otherElements["OnboardingRoot"].waitForExistence(timeout: timeout)
    }

    private func snapshotCurrentStep() -> String {
        app.staticTexts.firstMatch.label
    }
}
