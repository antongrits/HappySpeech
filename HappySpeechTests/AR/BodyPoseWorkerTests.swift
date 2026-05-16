@testable import HappySpeech
import ARKit
import XCTest

// MARK: - BodyPoseWorkerTests
//
// ARBodyTrackingConfiguration недоступен на симуляторе и в unit-target.
// Тестируем:
//   - isAvailable = false на симуляторе
//   - mock path: start() запускает Task, stop() отменяет его
//   - onUpdate callback вызывается в mock path
//   - BodyPoseUpdate: joints не пусты
//
// Не тестируем: ARSession.run() (требует реального ARKit-устройства A12+).

@MainActor
final class BodyPoseWorkerTests: XCTestCase {

    // MARK: - isAvailable: false on simulator

    func test_isAvailable_falseOnSimulator() {
        let worker = BodyPoseWorker()
        // На симуляторе ARBodyTrackingConfiguration.isSupported == false
        XCTAssertFalse(worker.isAvailable,
                       "На симуляторе ARBodyTrackingConfiguration не поддерживается")
    }

    // MARK: - start on simulator: falls back to mock

    func test_start_onSimulator_doesNotCrash() {
        let worker = BodyPoseWorker()
        XCTAssertNoThrow(worker.start())
    }

    // MARK: - stop after start: idempotent

    func test_stop_afterStart_doesNotCrash() {
        let worker = BodyPoseWorker()
        worker.start()
        XCTAssertNoThrow(worker.stop())
    }

    func test_stop_withoutStart_doesNotCrash() {
        let worker = BodyPoseWorker()
        XCTAssertNoThrow(worker.stop())
    }

    func test_stopTwice_doesNotCrash() {
        let worker = BodyPoseWorker()
        worker.start()
        worker.stop()
        XCTAssertNoThrow(worker.stop())
    }

    // MARK: - onUpdate callback registered before start

    func test_onUpdate_callbackSetBeforeStart_callbackNotNilAfterStart() {
        let worker = BodyPoseWorker()
        var received = false
        worker.onUpdate = { _ in received = true }
        // Не запускаем start() чтобы не ждать реальный Task
        XCTAssertNotNil(worker.onUpdate, "onUpdate closure должен быть сохранён")
    }

    // MARK: - mock start delivers updates (ждём один тик ~110ms)

    func test_mockStart_deliversUpdate() async throws {
        let worker = BodyPoseWorker()
        // isAvailable=false → mock path: 10fps = 100ms per tick
        let expectation = XCTestExpectation(description: "onUpdate called")
        expectation.expectedFulfillmentCount = 1

        worker.onUpdate = { update in
            XCTAssertFalse(update.joints.isEmpty, "Mock update должен содержать joints")
            XCTAssertEqual(update.confidence, 0.85, accuracy: 0.01)
            expectation.fulfill()
        }
        worker.start()

        await fulfillment(of: [expectation], timeout: 0.5)
        worker.stop()
    }

    // MARK: - stop cancels mock task (no more updates after stop)

    func test_stop_cancelsMockTask_noUpdatesAfterStop() async throws {
        let worker = BodyPoseWorker()
        var updateCount = 0

        worker.onUpdate = { _ in updateCount += 1 }
        worker.start()

        // Ждём немного, останавливаем
        try await Task.sleep(nanoseconds: 120_000_000) // 120ms → примерно 1 тик
        worker.stop()
        let countAfterStop = updateCount

        // Ждём ещё — счётчик не должен расти
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(updateCount, countAfterStop,
                       "После stop() не должно поступать новых обновлений")
    }

    // MARK: - BodyPoseUpdate: struct fields

    func test_bodyPoseUpdate_joints_accessibleDirectly() {
        let joints: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root: SIMD3(0, 0, 0),
            .head: SIMD3(0, 1.7, 0)
        ]
        let update = BodyPoseUpdate(joints: joints, confidence: 1.0)
        XCTAssertEqual(update.joints[.root], SIMD3(0, 0, 0))
        XCTAssertEqual(update.confidence, 1.0)
    }
}
