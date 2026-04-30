import Testing
@testable import HappySpeech

// MARK: - BiometricGateServiceTests
//
// Тесты BiometricGateService через MockBiometricGateService.
// LiveBiometricGateService (LAContext) нельзя тестировать на симуляторе/CI без real device.

@Suite("BiometricGateService")
struct BiometricGateServiceTests {

    // MARK: - canUseBiometric

    @Suite("canUseBiometric")
    struct CanUseBiometricTests {

        @Test("MockBiometricGateService(available: true) возвращает true")
        func availableTrueReturnsTrue() async {
            let sut = MockBiometricGateService(available: true, result: .success)
            let result = await sut.canUseBiometric()
            #expect(result == true)
        }

        @Test("MockBiometricGateService(available: false) возвращает false")
        func availableFalseReturnsFalse() async {
            let sut = MockBiometricGateService(available: false, result: .fallback)
            let result = await sut.canUseBiometric()
            #expect(result == false)
        }
    }

    // MARK: - authenticate

    @Suite("authenticate")
    struct AuthenticateTests {

        @Test("Результат .success возвращается корректно")
        func mockSuccessReturnsSuccess() async {
            let sut = MockBiometricGateService(available: true, result: .success)
            let result = await sut.authenticate(reason: "тест")
            #expect(result == .success)
        }

        @Test("Результат .fallback возвращается корректно")
        func mockFallbackReturnsFallback() async {
            let sut = MockBiometricGateService(available: true, result: .fallback)
            let result = await sut.authenticate(reason: "тест")
            #expect(result == .fallback)
        }

        @Test("Результат .cancelled возвращается корректно")
        func mockCancelledReturnsCancelled() async {
            let sut = MockBiometricGateService(available: true, result: .cancelled)
            let result = await sut.authenticate(reason: "тест")
            #expect(result == .cancelled)
        }

        @Test("Результат .denied возвращается корректно")
        func mockDeniedReturnsDenied() async {
            let sut = MockBiometricGateService(available: true, result: .denied(reason: "ошибка"))
            let result = await sut.authenticate(reason: "тест")
            #expect(result == .denied(reason: "ошибка"))
        }

        @Test("authenticate не зависит от строки reason (mock)")
        func reasonStringIsIgnoredInMock() async {
            let sut = MockBiometricGateService(available: true, result: .success)
            let r1 = await sut.authenticate(reason: "одна причина")
            let r2 = await sut.authenticate(reason: "другая причина")
            #expect(r1 == r2)
        }

        @Test("Когда unavailable, canUseBiometric=false, authenticate возвращает fallback")
        func unavailableMockFlowFallsToMath() async {
            let sut = MockBiometricGateService(available: false, result: .fallback)
            let canUse = await sut.canUseBiometric()
            #expect(canUse == false)
            let authResult = await sut.authenticate(reason: "тест")
            #expect(authResult == .fallback)
        }
    }

    // MARK: - AuthResult Equatable

    @Suite("AuthResult Equatable")
    struct AuthResultEquatableTests {

        @Test("success == success")
        func successEquality() {
            #expect(AuthResult.success == AuthResult.success)
        }

        @Test("fallback == fallback")
        func fallbackEquality() {
            #expect(AuthResult.fallback == AuthResult.fallback)
        }

        @Test("cancelled == cancelled")
        func cancelledEquality() {
            #expect(AuthResult.cancelled == AuthResult.cancelled)
        }

        @Test("denied(reason:) == denied(reason:) при одинаковом reason")
        func deniedEqualitySameReason() {
            #expect(AuthResult.denied(reason: "abc") == AuthResult.denied(reason: "abc"))
        }

        @Test("denied(reason:) != denied(reason:) при разном reason")
        func deniedInequalityDifferentReason() {
            #expect(AuthResult.denied(reason: "a") != AuthResult.denied(reason: "b"))
        }

        @Test("success != fallback")
        func successNotEqualFallback() {
            #expect(AuthResult.success != AuthResult.fallback)
        }

        @Test("success != cancelled")
        func successNotEqualCancelled() {
            #expect(AuthResult.success != AuthResult.cancelled)
        }

        @Test("fallback != cancelled")
        func fallbackNotEqualCancelled() {
            #expect(AuthResult.fallback != AuthResult.cancelled)
        }
    }
}
