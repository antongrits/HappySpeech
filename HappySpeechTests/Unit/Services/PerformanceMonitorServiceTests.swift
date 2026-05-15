import Foundation
import XCTest
@testable import HappySpeech

// MARK: - PerformanceMonitorServiceTests
//
// Тесты LivePerformanceMonitorService + MockPerformanceMonitorService.
// LivePerformanceMonitorService хранит consent в UserDefaults и зеркалит
// его в Firebase Performance SDK. Тесты изолируют UserDefaults-ключ.

final class PerformanceMonitorServiceTests: XCTestCase {

    private let defaultsKey = "happyspeech.performance.enabled"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    // MARK: - LivePerformanceMonitorService

    func testLiveDefaultIsDisabled() {
        let service = LivePerformanceMonitorService()
        XCTAssertFalse(service.isEnabled, "По умолчанию OFF — COPPA")
    }

    func testLiveSetEnabledPersists() {
        let service = LivePerformanceMonitorService()
        service.setEnabled(true)
        XCTAssertTrue(service.isEnabled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: defaultsKey))
    }

    func testLiveSetEnabledFalseRoundTrip() {
        let service = LivePerformanceMonitorService()
        service.setEnabled(true)
        service.setEnabled(false)
        XCTAssertFalse(service.isEnabled)
    }

    func testLiveTraceReturnsNoOpWhenDisabled() {
        let service = LivePerformanceMonitorService()
        service.setEnabled(false)
        let trace = service.trace(name: "disabled_trace")
        // No-op trace не должен падать на любых вызовах.
        trace.start()
        trace.setValue(42, forAttribute: "metric")
        trace.stop()
    }

    // Note: enabled-path trace() конструирует FirebasePerformanceTrace, который требует
    // FirebaseApp.configure(). Это тонкий делегат Firebase SDK — не покрывается unit-тестом
    // (residual). Бизнес-логика (consent gate → NoOp vs Firebase) проверена выше.

    func testLiveInitMirrorsStoredConsent() {
        UserDefaults.standard.set(true, forKey: defaultsKey)
        let service = LivePerformanceMonitorService()
        XCTAssertTrue(service.isEnabled, "init читает сохранённое согласие")
    }

    // MARK: - MockPerformanceMonitorService

    func testMockDefaultDisabled() {
        let mock = MockPerformanceMonitorService()
        XCTAssertFalse(mock.isEnabled)
        XCTAssertTrue(mock.startedTraces.isEmpty)
    }

    func testMockSetEnabled() {
        let mock = MockPerformanceMonitorService()
        mock.setEnabled(true)
        XCTAssertTrue(mock.isEnabled)
    }

    func testMockTraceRecordsName() {
        let mock = MockPerformanceMonitorService()
        let trace = mock.trace(name: "report_export")
        trace.start()
        trace.stop()
        XCTAssertEqual(mock.startedTraces, ["report_export"])
    }

    func testMockTraceRecordsMultipleNames() {
        let mock = MockPerformanceMonitorService()
        _ = mock.trace(name: "a")
        _ = mock.trace(name: "b")
        _ = mock.trace(name: "c")
        XCTAssertEqual(mock.startedTraces, ["a", "b", "c"])
    }

    func testMockTraceSetValueDoesNotCrash() {
        let mock = MockPerformanceMonitorService()
        let trace = mock.trace(name: "x")
        trace.setValue(7, forAttribute: "count")
    }
}
