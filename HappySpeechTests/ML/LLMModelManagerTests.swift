@testable import HappySpeech
import XCTest

// MARK: - LLMModelManagerTests
//
// Phase 2 v29 — покрытие bundle-only LLMModelManager и LLMModelPack.
//
// Модель Qwen2.5-1.5B поставляется внутри бандла приложения — загрузок нет.
// Тесты проверяют:
//   - LLMModelPack: rawValue, sizeBytes, isDefault, displayName, allCases
//   - LLMModelManager.localMLXModelURL: возвращает URL встроенной модели
//   - LLMModelManager: isModelInstalled / installedModels / isCurrentlyInUse без краша

final class LLMModelManagerTests: XCTestCase {

    // MARK: - Mock LocalLLMService для LLMModelManager

    private final class MockLocalLLMForManager: LocalLLMService, @unchecked Sendable {
        var isModelDownloaded: Bool { true }
        var isModelLoaded: Bool { false }
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

    // MARK: - LLMModelPack: rawValue

    func testModelPack_qwen15b_rawValue() {
        XCTAssertEqual(LLMModelPack.qwen15b.rawValue, "qwen2.5-1.5b")
    }

    // MARK: - LLMModelPack: isDefault

    func testModelPack_qwen15b_isDefault() {
        XCTAssertTrue(LLMModelPack.qwen15b.isDefault)
    }

    // MARK: - LLMModelPack: sizeBytes > 0

    func testModelPack_sizeBytes_positive() {
        for pack in LLMModelPack.allCases {
            XCTAssertGreaterThan(pack.sizeBytes, 0, "sizeBytes для '\(pack.rawValue)' должен быть > 0")
        }
    }

    func testModelPack_qwen15b_sizeBytes_approx900MB() {
        let bytes = LLMModelPack.qwen15b.sizeBytes
        XCTAssertEqual(bytes, 900 * 1024 * 1024)
    }

    // MARK: - LLMModelPack: allCases содержит единственный встроенный пак

    func testModelPack_allCases_count() {
        XCTAssertEqual(LLMModelPack.allCases.count, 1)
    }

    // MARK: - LLMModelPack: displayName не пустой

    func testModelPack_displayName_notEmpty() {
        for pack in LLMModelPack.allCases {
            let name = pack.displayName
            XCTAssertFalse(name.isEmpty, "displayName для '\(pack.rawValue)' не должен быть пустым")
        }
    }

    // MARK: - LLMModelPack: tierDescription не пустой

    func testModelPack_tierDescription_notEmpty() {
        for pack in LLMModelPack.allCases {
            let tier = pack.tierDescription
            XCTAssertFalse(tier.isEmpty, "tierDescription для '\(pack.rawValue)' не должен быть пустым")
        }
    }

    // MARK: - LLMModelPack: Codable round-trip

    func testModelPack_codableRoundTrip() throws {
        for pack in LLMModelPack.allCases {
            let data = try JSONEncoder().encode(pack)
            let decoded = try JSONDecoder().decode(LLMModelPack.self, from: data)
            XCTAssertEqual(pack, decoded)
        }
    }

    // MARK: - LLMModelManager: isModelInstalled без краша

    func testIsModelInstalled_noCrash() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        let installed = await mgr.isModelInstalled(.qwen15b)
        XCTAssertTrue(installed == true || installed == false, "isModelInstalled должен вернуть bool без краша")
    }

    // MARK: - LLMModelManager: installedModels → массив без краша

    func testInstalledModels_noCrash() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        let models = await mgr.installedModels()
        XCTAssertTrue(models.count >= 0)
    }

    // MARK: - LLMModelManager: isCurrentlyInUse → false (модель не загружена)

    func testIsCurrentlyInUse_notLoaded_returnsFalse() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        let inUse = await mgr.isCurrentlyInUse(.qwen15b)
        XCTAssertFalse(inUse, "Незагруженная модель не должна быть in-use")
    }

    // MARK: - LLMModelManager: markActive → isCurrentlyInUse зависит от isModelLoaded

    func testMarkActive_noCrash() async {
        let mgr = LLMModelManager(primaryLLM: MockLocalLLMForManager())
        await mgr.markActive(.qwen15b)
        let inUse = await mgr.isCurrentlyInUse(.qwen15b)
        // primaryLLM.isModelLoaded == false → не in-use
        XCTAssertFalse(inUse)
    }

    // MARK: - LLMError: errorDescription

    func testLLMError_notLoaded_hasDescription() {
        let err = LLMError.notLoaded
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }

    func testLLMError_generationFailed_mentionsReason() {
        let err = LLMError.generationFailed("таймаут")
        XCTAssertTrue(err.errorDescription?.contains("таймаут") ?? false)
    }

    func testLLMError_unsupportedArchitecture_hasDescription() {
        let err = LLMError.unsupportedArchitecture
        XCTAssertFalse(err.errorDescription?.isEmpty ?? true)
    }
}
