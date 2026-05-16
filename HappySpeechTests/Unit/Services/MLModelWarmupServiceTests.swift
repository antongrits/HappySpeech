@testable import HappySpeech
import XCTest

// MARK: - MLModelWarmupServiceTests
//
// 2.10 v25 — покрытие MLModelWarmupService.
//
// LiveMLModelWarmupService.warmUp() — genuinely SDK-bound (документировано для
// ADR-V25-COVERAGE): помимо прогрева Pronunciation + ASR оно вызывает глобальную
// makeVAD(), которая инициализирует CoreML-runtime (SileroVAD.mlpackage). В
// headless unit-окружении симулятора этот путь аварийно завершает test-process
// (CoreML model compilation вне bundle-контекста), поэтому LiveMLModelWarmupService
// не инстанцируется в unit-тестах — его оркестрация проверяется на уровне
// онбординг-flow интеграционными прогонами.
//
// Здесь покрываем:
//   • контракт протокола MLModelWarmupServiceProtocol через MockMLModelWarmupService;
//   • идемпотентность no-op mock-реализации.

final class MLModelWarmupServiceTests: XCTestCase {

    // MARK: - Mock implementation — protocol contract

    func test_mock_warmUp_isNoOpAndDoesNotThrow() async {
        let mock = MockMLModelWarmupService()
        await mock.warmUp()
    }

    func test_mock_warmUp_isIdempotent() async {
        let mock = MockMLModelWarmupService()
        await mock.warmUp()
        await mock.warmUp()
        await mock.warmUp()
        // Mock — чистый no-op: повторные вызовы безопасны и не меняют состояние.
    }

    func test_mock_conformsToProtocol() async {
        let service: any MLModelWarmupServiceProtocol = MockMLModelWarmupService()
        await service.warmUp()
    }
}
