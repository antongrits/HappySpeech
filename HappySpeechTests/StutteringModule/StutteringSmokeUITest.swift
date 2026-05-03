@testable import HappySpeech
import XCTest

// MARK: - StutteringSmokeUITest
//
// 1 smoke-тест для Stuttering module (F5-step6).
// Проверяет запуск StutteringInteractor + loadScreen без крашей.
// Не требует симулятор / audio-сессию.

@MainActor
final class StutteringSmokeUITest: XCTestCase {

    // MARK: - 1. Smoke: StutteringInteractor запускается и рендерит 4 карточки без краша

    func test_stutteringInteractor_smoke_launchWithoutCrash() {
        UserDefaults.standard.removeObject(forKey: "stuttering_welcome_shown")

        let spy = SpySmokePresenter()
        let sut = StutteringInteractor()
        sut.presenter = spy

        // Запуск не должен крашить
        XCTAssertNoThrow(sut.loadScreen(.init()))

        XCTAssertTrue(spy.presentLoadScreenCalled,
                      "Smoke: loadScreen должен вызывать presenter без краша")
        XCTAssertEqual(spy.cardCount, 7,
                       "Smoke: должно быть 7 карточек упражнений")
    }

    // MARK: - Spy

    @MainActor
    private final class SpySmokePresenter: StutteringPresentationLogic {
        var presentLoadScreenCalled = false
        var cardCount: Int = 0

        func presentLoadScreen(_ response: StutteringModels.LoadScreen.Response) {
            presentLoadScreenCalled = true
            cardCount = response.cards.count
        }

        func presentSelectMode(_ response: StutteringModels.SelectMode.Response) {}
        func presentLoadProgress(_ response: StutteringModels.LoadProgress.Response) {}
        func presentAdaptiveRecommendation(_ response: StutteringModels.LoadAdaptiveRecommendation.Response) {}
    }
}
