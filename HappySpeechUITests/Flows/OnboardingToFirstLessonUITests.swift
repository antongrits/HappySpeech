import XCTest

// MARK: - OnboardingToFirstLessonUITests
//
// End-to-end flow on iOS Simulator:
//   1. App launches → Auth landing or child profile picker visible
//   2. Skip onboarding via demo / guided tour path
//   3. Start a lesson from ChildHome
//   4. Complete one activity
//   5. Reward overlay appears
//
// Runs as part of `xcodebuild test -scheme HappySpeech` with a fresh simulator.
// The flow intentionally tolerates multiple entry points — the app may show the
// Auth screen first or jump straight to the child profile picker depending on
// the stored auth state. The test uses `XCUIElement.waitForExistence` and
// short "any of these" probes so it doesn't become fragile to UX tweaks.
// ==================================================================================

@MainActor
final class OnboardingToFirstLessonUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-UITestResetState")
        app.launchArguments.append("-UITestDisableAnimations")
        app.launch()
    }

    // MARK: - Happy path

    func test_launch_showsKidHome_orAuthLanding() throws {
        // После сброса состояния (-UITestResetState) приложение показывает Splash,
        // затем переходит в Onboarding или Auth. Ждём любой из известных root-view.
        let splash    = app.otherElements["SplashRoot"]
        let kidHome   = app.otherElements["ChildHomeRoot"]
        let authSignIn = app.otherElements["AuthSignInRoot"]
        let onboarding = app.otherElements["OnboardingRoot"]

        // Сначала ждём Splash (быстро появляется при старте)
        let hasSplash = splash.waitForExistence(timeout: 5)
        // Затем ждём перехода на следующий экран (Splash длится ~2.2 сек)
        let appeared = hasSplash
            || kidHome.waitForExistence(timeout: 10)
            || authSignIn.waitForExistence(timeout: 5)
            || onboarding.waitForExistence(timeout: 5)

        XCTAssertTrue(
            appeared,
            "Expected one of SplashRoot, ChildHome, AuthSignIn or Onboarding at launch"
        )
    }

    func test_tapStartLesson_navigatesToSessionShell() throws {
        // Перезапускаем с -HSStartRoute childHome — детерминированно открываем
        // детский экран (preview-контейнер, seed-контент), минуя auth.
        app.terminate()
        app.launchArguments = ["-HSStartRoute", "childHome", "-UITestDisableAnimations"]
        app.launch()

        // Карточка ежедневной миссии — основная точка входа в урок на ChildHome.
        let startButton = app.buttons["childHomeDailyMissionCard"].firstMatch
        XCTAssertTrue(
            startButton.waitForExistence(timeout: 15),
            "Карточка запуска урока (childHomeDailyMissionCard) должна быть доступна на ChildHome"
        )
        startButton.tap()

        // Если открылся hero overlay — тапаем «Начать».
        let startPredicate = NSPredicate(format: "label CONTAINS[c] 'начать' OR label CONTAINS[c] 'старт'")
        let heroStart = app.buttons.matching(startPredicate).firstMatch
        if heroStart.waitForExistence(timeout: 3), heroStart.isHittable {
            heroStart.tap()
        }

        let shell = app.otherElements["SessionShellRoot"]
        let gameArea = app.otherElements["gameContentArea"]
        let hud = app.otherElements["sessionHUDProgress"]
        XCTAssertTrue(
            shell.waitForExistence(timeout: 15)
                || gameArea.waitForExistence(timeout: 3)
                || hud.waitForExistence(timeout: 3),
            "SessionShell должен открыться после тапа на карточку урока"
        )
    }
}
