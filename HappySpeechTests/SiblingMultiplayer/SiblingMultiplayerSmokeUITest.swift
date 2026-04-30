@testable import HappySpeech
import SwiftUI
import UIKit
import XCTest

// MARK: - SiblingMultiplayerSmokeUITest
//
// 1 smoke-тест: запуск с -HSStartRoute siblingMultiplayer →
// проверяем что приложение рендерится без crash.
//
// Требования к тесту (из задачи Блок L2):
// - Route уже добавлен в AppCoordinator.
// - MCP-функциональность (поиск пиров, connect) НЕ тестируется — требует 2 устройства + LAN.
// - Smoke проверяет только: View появляется, нет crash.

@MainActor
final class SiblingMultiplayerSmokeUITest: XCTestCase {

    // MARK: - 1. Smoke: приложение не крашится при запуске с маршрутом siblingMultiplayer

    func test_siblingMultiplayer_smoke_noCrash() {
        // Создаём SiblingMultiplayerView напрямую (без XCUIApplication)
        // для unit-level smoke: View инициализируется, не крашится.
        let coordinator = AppCoordinator()
        let container = AppContainer.preview()
        let view = SiblingMultiplayerView(childId: "smoke-child-001")
            .environment(coordinator)
            .environment(container)

        // Хостим через UIHostingController — проверяем что layout не падает
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        host.view.layoutIfNeeded()

        // Если дошли сюда — crash отсутствует
        XCTAssertNotNil(host.view, "SiblingMultiplayerView должен рендериться без crash")
    }
}
