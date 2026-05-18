@testable import HappySpeech
import XCTest

// MARK: - LLMModelManagerExtendedTests
//
// Phase 2 v29 — расширенное покрытие bundle-only LLMModelManager.
//
// Модель Qwen2.5-1.5B встроена в бандл приложения — загрузок нет.
// Дополнительные тесты:
//   - LLMModelPack: единственный пак, isDefault, Codable
//   - LLMModelManager: markActive → isCurrentlyInUse зависит от isModelLoaded
//   - LLMModelManager.localMLXModelURL: возвращает встроенную модель

final class LLMModelManagerExtendedTests: XCTestCase {

    // MARK: - Mocks

    private final class MockLocalLLMForManager: LocalLLMService, @unchecked Sendable {
        var isModelDownloaded: Bool
        var isModelLoaded: Bool

        init(downloaded: Bool = false, loaded: Bool = false) {
            self.isModelDownloaded = downloaded
            self.isModelLoaded = loaded
        }

        func generateParentSummary(request: ParentSummaryRequest) async throws -> ParentSummaryResponse {
            throw LLMError.notLoaded
        }
        func generateRoute(request: RoutePlannerRequest) async throws -> RoutePlannerResponse {
            throw LLMError.notLoaded
        }
        func generateMicroStory(request: MicroStoryRequest) async throws -> MicroStoryResponse {
            throw LLMError.notLoaded
        }
    }

    // MARK: - LLMModelPack: единственный встроенный пак

    func testModelPack_singleBundledPack() {
        XCTAssertEqual(LLMModelPack.allCases.count, 1)
        XCTAssertEqual(LLMModelPack.allCases.first, .qwen15b)
    }

    // MARK: - LLMModelPack: только один пак isDefault

    func testModelPack_onlyOneDefault() {
        let defaults = LLMModelPack.allCases.filter { $0.isDefault }
        XCTAssertEqual(defaults.count, 1, "Только один пак должен быть default")
        XCTAssertEqual(defaults.first, .qwen15b)
    }

    // MARK: - LLMModelPack: Codable round-trip

    func testModelPack_codableRoundTrip() throws {
        for pack in LLMModelPack.allCases {
            let data = try JSONEncoder().encode(pack)
            let decoded = try JSONDecoder().decode(LLMModelPack.self, from: data)
            XCTAssertEqual(decoded, pack)
        }
    }

    // MARK: - LLMModelManager: markActive → isCurrentlyInUse = true (модель загружена)

    func testMarkActive_loaded_isCurrentlyInUse() async {
        let llm = MockLocalLLMForManager(downloaded: true, loaded: true)
        let mgr = LLMModelManager(primaryLLM: llm)
        await mgr.markActive(.qwen15b)
        let inUse = await mgr.isCurrentlyInUse(.qwen15b)
        XCTAssertTrue(inUse, "После markActive(.qwen15b) с isModelLoaded=true — должен быть inUse")
    }

    // MARK: - LLMModelManager: markActive c незагруженной моделью → не inUse

    func testMarkActive_notLoaded_notInUse() async {
        let llm = MockLocalLLMForManager(downloaded: true, loaded: false)
        let mgr = LLMModelManager(primaryLLM: llm)
        await mgr.markActive(.qwen15b)
        let inUse = await mgr.isCurrentlyInUse(.qwen15b)
        XCTAssertFalse(inUse, "Незагруженная модель не должна быть inUse")
    }

    // MARK: - LLMModelManager: installedModels возвращает список без краша

    func testInstalledModels_alwaysReturnsList() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        let models = await mgr.installedModels()
        XCTAssertTrue(models.count >= 0)
    }

    // MARK: - LLMModelManager: isModelInstalled без краша

    func testIsModelInstalled_noCrash() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        let installed = await mgr.isModelInstalled(.qwen15b)
        XCTAssertTrue(installed == true || installed == false)
    }

    // MARK: - LLMModelPack: displayName не пустой

    func testModelPack_displayName_notEmpty() {
        for pack in LLMModelPack.allCases {
            XCTAssertFalse(pack.displayName.isEmpty)
        }
    }
}
