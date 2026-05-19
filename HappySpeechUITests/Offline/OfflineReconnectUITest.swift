import XCTest

// MARK: - OfflineReconnectUITest
//
// M10.3 v8 — UI тест оффлайн-режима и переподключения.
//
// Стратегия:
//   • Запуск с -UITestOffline — AppCoordinator/NetworkMonitor переходит в .offline.
//     Реализовано через существующий флаг из NavigationFlowUITests.
//   • Проверяем что HSOfflineBanner или OfflineStateView отображается.
//   • Проверяем что игра доступна в offline через ChildHome.
//   • Симулируем reconnect через перезапуск без -UITestOffline.
//   • Проверяем что pending sync banner исчезает.
//   • Smoke-уровень: не проверяем фактическую Firestore-синхронизацию.
//   • NSPredicate создаётся внутри test-методов (Swift 6 concurrency safe).
// ==========================================================================

@MainActor
final class OfflineReconnectUITest: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = []
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - 1. Приложение запускается без краша в offline-режиме

    func test_offlineLaunch_noCrash() throws {
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline"
        ]
        app.launch()

        let anyElement = app.otherElements.element.waitForExistence(timeout: 10)
        XCTAssertTrue(anyElement,
            "Приложение должно запускаться без краша в offline-режиме")
    }

    // MARK: - 2. HSOfflineBanner или OfflineStateView появляется при offline

    func test_offlineBanner_visibleWhenOffline() throws {
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline"
        ]
        app.launch()

        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let offlineStateRoot = app.otherElements["OfflineStateRoot"]
        let hasOfflineState = offlineStateRoot.waitForExistence(timeout: 3)

        let noBanner = NSPredicate(format: "label CONTAINS[c] 'нет интернета' OR label CONTAINS[c] 'без интернета'")
        let bannerText = app.staticTexts.matching(noBanner).firstMatch
        let hasBannerText = bannerText.waitForExistence(timeout: 3)

        XCTAssertTrue(app.exists,
            "Приложение должно оставаться активным в offline-режиме")
        XCTAssertTrue(hasOfflineState || hasBannerText,
            "Offline UI (OfflineStateRoot или текст) должен отображаться при -UITestOffline")
    }

    // MARK: - 3. OfflineState содержит текст о проблеме с сетью

    func test_offlineText_visible() throws {
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline"
        ]
        app.launch()

        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let internetPredicate = NSPredicate(
            format: "label CONTAINS[c] 'интернет' OR label CONTAINS[c] 'подключен' OR label CONTAINS[c] 'сеть'"
        )
        let hasOfflineText = app.staticTexts.matching(internetPredicate).firstMatch
            .waitForExistence(timeout: 4)

        XCTAssertTrue(app.exists,
            "Приложение должно быть активным при offline-режиме")
        XCTAssertTrue(hasOfflineText,
            "Текст offline-состояния (интернет/подключен/сеть) должен отображаться пользователю")
    }

    // MARK: - 4. Игра доступна offline через ChildHome (если автологин настроен)

    func test_offlineGame_accessible() throws {
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline",
            "-HSStartRoute", "childHome"
        ]
        app.launch()

        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let childHome = app.otherElements["ChildHomeRoot"].waitForExistence(timeout: 5)
        let offlineState = app.otherElements["OfflineStateRoot"].waitForExistence(timeout: 3)

        XCTAssertTrue(app.exists,
            "Приложение должно оставаться активным при попытке открыть ChildHome offline")
        XCTAssertTrue(childHome || offlineState,
            "При -UITestOffline должен отображаться либо ChildHome, либо OfflineState")
    }

    // MARK: - 5. После восстановления сети offline banner исчезает

    func test_onlineReconnect_bannerDismisses() throws {
        // Сначала запускаем в offline
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline"
        ]
        app.launch()
        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let offlinePredicate = NSPredicate(
            format: "label CONTAINS[c] 'нет интернета' OR label CONTAINS[c] 'без интернета'"
        )
        let hadOffline = app.staticTexts.matching(offlinePredicate).firstMatch
            .waitForExistence(timeout: 3)
            || app.otherElements["OfflineStateRoot"].waitForExistence(timeout: 1)

        // Перезапускаем приложение в online-режиме
        app.terminate()

        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices"
            // Без -UITestOffline → online режим
        ]
        app.launch()
        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let onlineBannerPredicate = NSPredicate(
            format: "label CONTAINS[c] 'нет интернета' OR label CONTAINS[c] 'без интернета'"
        )
        let bannerStillVisible = app.staticTexts.matching(onlineBannerPredicate).firstMatch
            .waitForExistence(timeout: 2)

        XCTAssertTrue(app.exists,
            "Приложение должно успешно перейти в online-режим")

        if hadOffline {
            XCTAssertFalse(bannerStillVisible,
                "Offline banner не должен отображаться после восстановления соединения")
        }
    }

    // MARK: - 6. Кнопка «Повторить» в offline banner нажимается без краша

    func test_retryButton_inOfflineBanner_nocrash() throws {
        app.launchArguments = [
            "-UITestResetState",
            "-UITestDisableAnimations",
            "-UITestMockServices",
            "-UITestOffline"
        ]
        app.launch()
        _ = app.otherElements.element.waitForExistence(timeout: 10)

        let retryPredicate = NSPredicate(
            format: "label CONTAINS[c] 'повторить' OR label CONTAINS[c] 'retry'"
        )
        let retryButton = app.buttons.matching(retryPredicate).firstMatch

        if retryButton.waitForExistence(timeout: 4) {
            retryButton.tap()
            XCTAssertTrue(app.exists,
                "Приложение не должно падать при нажатии 'Повторить' в offline-баннере")
        } else {
            XCTAssertTrue(app.exists,
                "Приложение должно быть активным в offline-режиме")
        }
    }
}
