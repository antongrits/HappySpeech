@testable import HappySpeech
import XCTest

// MARK: - AppContainerLiveLLMWiringTests
//
// Закрывает регрессию из матрицы v29 → v30 «On-device LLM ещё в активной развилке»:
// в `AppContainer.live()` к `LLMInferenceActor` должен быть подключён MLX-обёртка
// `LocalLLMServiceLive`, а не заглушка, которая молча уводит всё в rule-based.
//
// Если кто-то снова подменит `localLLMServiceFactory` на стаб, этот тест упадёт.
final class AppContainerLiveLLMWiringTests: XCTestCase {

    func test_liveContainer_wiresMLXBackedLocalLLM_notRuleBasedStub() {
        let container = AppContainer.live()
        let service = container.localLLMService

        XCTAssertTrue(
            service is LocalLLMServiceLive,
            "AppContainer.live() обязан подключать MLX-обёртку LocalLLMServiceLive — " +
            "rule-based fallback допустим только внутри LiveLLMDecisionService как " +
            "наблюдаемая страховка."
        )
    }

    func test_liveContainer_wiresLiveLLMDecisionService_notMock() {
        let container = AppContainer.live()
        let decision = container.llmDecisionService

        XCTAssertTrue(
            decision is LiveLLMDecisionService,
            "AppContainer.live() обязан подключать LiveLLMDecisionService — " +
            "иначе все 25 точек принятия решений уходят в Mock и не используют MLX."
        )
    }

    func test_previewContainer_keepsMockLocalLLM() {
        // Зеркальный smoke: убеждаемся, что preview-контейнер не таскает live MLX —
        // иначе превью грузили бы 839 MB модели в SwiftUI Canvas.
        let container = AppContainer.preview()
        XCTAssertFalse(
            container.localLLMService is LocalLLMServiceLive,
            "Preview-контейнер должен использовать MockLocalLLMService"
        )
    }
}
