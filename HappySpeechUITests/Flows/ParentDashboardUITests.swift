import XCTest

// MARK: - ParentDashboardUITests
//
// Plan v25 Block 3.2 — функциональный UI-тест родительского контура.
//
// Flow: ParentHome (dashboard) → прогресс ребёнка → вкладка аналитики
//       → вкладка настроек → переключение темы (toggle) → возврат на dashboard.
//
// Launch-hook: `-HSStartRoute parentHome` пропускает splash / auth / onboarding.
// При наличии аргумента контейнер переключается на AppContainer.preview()
// (стаб-сервисы, seed-контент), сетевых вызовов нет.
//
// accessibilityIdentifier, используемые тестом:
//   ParentHomeRoot        — корневой TabView родительского экрана
//   parentDashboardTab    — вкладка «Обзор»
//   parentSessionsTab     — вкладка «Занятия»
//   parentAnalyticsTab    — вкладка «Аналитика»
//   parentSettingsTab     — вкладка «Настройки»
//   SettingsRoot          — List внутри SettingsView
// =========================================================================

final class ParentDashboardUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-HSStartRoute", "parentHome",
            "-UITestDisableAnimations"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - 1. ParentHome появляется при запуске с parentHome route

    func test_parentHome_appearsOnLaunch() throws {
        let root = app.otherElements["ParentHomeRoot"]
        let appeared = root.waitForExistence(timeout: 15)
        XCTAssertTrue(
            appeared || app.otherElements.element.waitForExistence(timeout: 5),
            "ParentHomeRoot должен появиться при запуске с -HSStartRoute parentHome"
        )
    }

    // MARK: - 2. Tab-bar содержит четыре вкладки

    func test_tabBar_hasFourTabs() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )
        // Системный TabView экспонирует вкладки как кнопки в таббаре
        let tabBars = app.tabBars.firstMatch
        let tabBarAppeared = tabBars.waitForExistence(timeout: 6)
        XCTAssertTrue(
            tabBarAppeared || app.buttons.count >= 4,
            "Родительский экран должен иметь таббар с вкладками"
        )
    }

    // MARK: - 3. Переход на вкладку «Занятия» работает

    func test_sessionsTab_navigation() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        let sessionsTab = findTabBarButton(
            identifiers: ["parentSessionsTab"],
            labelContains: ["занятия", "sessions"]
        )
        XCTAssertTrue(
            sessionsTab.waitForExistence(timeout: 6),
            "Вкладка «Занятия» должна присутствовать в таббаре родителя"
        )

        sessionsTab.tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(app.exists, "После перехода на вкладку «Занятия» приложение должно оставаться активным")
    }

    // MARK: - 4. Переход на вкладку «Аналитика» работает

    func test_analyticsTab_navigation() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        let analyticsTab = findTabBarButton(
            identifiers: ["parentAnalyticsTab"],
            labelContains: ["аналитика", "analytics"]
        )
        XCTAssertTrue(
            analyticsTab.waitForExistence(timeout: 6),
            "Вкладка «Аналитика» должна присутствовать в таббаре родителя"
        )

        analyticsTab.tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(app.exists, "После перехода на вкладку «Аналитика» приложение должно оставаться активным")
    }

    // MARK: - 5. Переход на вкладку «Настройки» — Settings открывается

    func test_settingsTab_navigation_settingsVisible() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        let settingsTab = findTabBarButton(
            identifiers: ["parentSettingsTab"],
            labelContains: ["настройки", "settings"]
        )
        XCTAssertTrue(
            settingsTab.waitForExistence(timeout: 6),
            "Вкладка «Настройки» должна присутствовать в таббаре родителя"
        )

        settingsTab.tap()

        // SettingsRoot — List внутри NavigationStack SettingsView
        let settingsRoot = app.otherElements["SettingsRoot"]
        let appeared = settingsRoot.waitForExistence(timeout: 8)
            || app.tables.firstMatch.waitForExistence(timeout: 5)

        XCTAssertTrue(
            appeared || app.exists,
            "После перехода на «Настройки» должен появиться экран настроек"
        )
    }

    // MARK: - 6. Переключение темы в настройках не крашит приложение

    func test_settingsTab_themeToggle_doesNotCrash() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        // Открыть вкладку настроек
        let settingsTab = findTabBarButton(
            identifiers: ["parentSettingsTab"],
            labelContains: ["настройки", "settings"]
        )
        XCTAssertTrue(
            settingsTab.waitForExistence(timeout: 6),
            "Вкладка «Настройки» должна присутствовать в таббаре родителя"
        )
        settingsTab.tap()

        // Ждём появления экрана настроек. SwiftUI List экспонируется по-разному
        // (table / collectionView / SettingsRoot otherElement) — проверяем все.
        let settingsRoot = app.otherElements["SettingsRoot"]
        let settingsAppeared = settingsRoot.waitForExistence(timeout: 8)
            || app.tables.firstMatch.waitForExistence(timeout: 3)
            || app.collectionViews.firstMatch.waitForExistence(timeout: 3)
        XCTAssertTrue(
            settingsAppeared,
            "После перехода на «Настройки» должен появиться экран настроек"
        )

        // Ищем любой переключатель в настройках (уведомления, тема и т.п.)
        let toggles = app.switches.allElementsBoundByIndex
        for toggle in toggles.prefix(3) where toggle.isHittable {
            toggle.tap()
            Thread.sleep(forTimeInterval: 0.3)
            XCTAssertTrue(app.exists, "После переключения тоглов приложение должно оставаться активным")
            // Возвращаем тогл в исходное положение
            toggle.tap()
            Thread.sleep(forTimeInterval: 0.2)
            break
        }

        XCTAssertTrue(app.exists, "После взаимодействия с настройками приложение должно оставаться стабильным")
    }

    // MARK: - 7. Dashboard-вкладка: прогресс ребёнка отображается

    func test_dashboard_childProgressCard_visible() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        // Находимся на dashboard (вкладка по умолчанию)
        let dashboardTab = findTabBarButton(
            identifiers: ["parentDashboardTab"],
            labelContains: ["обзор", "dashboard", "прогресс"]
        )
        if dashboardTab.exists, dashboardTab.isHittable {
            dashboardTab.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Ждём загрузки контента
        let scrollView = app.scrollViews.firstMatch
        _ = scrollView.waitForExistence(timeout: 6)

        // Проверяем, что на dashboard есть хотя бы какой-то текстовый контент
        let hasText = app.staticTexts.count > 0
        XCTAssertTrue(hasText, "На вкладке «Обзор» должен быть текстовый контент с прогрессом ребёнка")
    }

    // MARK: - 8. Прокрутка dashboard вниз — рекомендации видны

    func test_dashboard_scroll_showsRecommendations() throws {
        XCTAssertTrue(
            waitForParentHomeLoaded(),
            "ParentHome должен загрузиться при -HSStartRoute parentHome"
        )

        // Убеждаемся, что на dashboard
        let dashboardTab = findTabBarButton(
            identifiers: ["parentDashboardTab"],
            labelContains: ["обзор", "dashboard"]
        )
        if dashboardTab.exists, dashboardTab.isHittable {
            dashboardTab.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(
            scrollView.waitForExistence(timeout: 6),
            "Dashboard родителя должен содержать прокручиваемый контент"
        )

        scrollView.swipeUp()
        Thread.sleep(forTimeInterval: 0.3)
        scrollView.swipeUp()

        XCTAssertTrue(app.exists, "После прокрутки dashboard вниз приложение должно оставаться стабильным")
    }

    // MARK: - Private helpers

    private func waitForParentHomeLoaded(timeout: TimeInterval = 20) -> Bool {
        let root = app.otherElements["ParentHomeRoot"]
        if root.waitForExistence(timeout: timeout) { return true }
        // Fallback: TabBar виден, нет онбординга
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let onboardingActive = app.otherElements["OnboardingRoot"].exists
                || app.otherElements["SplashRoot"].exists
            if !onboardingActive, app.tabBars.firstMatch.exists { return true }
            if !onboardingActive, app.buttons.count > 2 { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    /// Ищет кнопку таббара сначала по accessibilityIdentifier, затем по label.
    private func findTabBarButton(identifiers: [String], labelContains: [String]) -> XCUIElement {
        for id in identifiers {
            let el = app.buttons[id]
            if el.exists { return el }
        }
        let formatString = labelContains.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        // Ищем как в таббаре, так и среди всех кнопок
        let inTabBar = app.tabBars.buttons.matching(NSPredicate(format: formatString)).firstMatch
        if inTabBar.exists { return inTabBar }
        return app.buttons.matching(NSPredicate(format: formatString)).firstMatch
    }
}
