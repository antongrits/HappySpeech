@testable import HappySpeech
import ARKit
import XCTest

// MARK: - PoseSimilarityWorkerTests
//
// 6 тестов для PoseSimilarityWorker.
// Покрывает: identical poses → 100, opposite → 0, half match → ~50,
// empty current → 0, empty targets → 0, single joint.

final class PoseSimilarityWorkerTests: XCTestCase {

    private var worker: PoseSimilarityWorker!

    override func setUp() {
        super.setUp()
        worker = PoseSimilarityWorker()
    }

    override func tearDown() {
        worker = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeTarget(joints: [ARSkeleton.JointName: SIMD3<Float>]) -> TargetPose {
        TargetPose(
            id: "test",
            name: "Тест",
            hint: "Подсказка",
            jointTargets: joints
        )
    }

    // MARK: - Tests

    /// Идентичные позы: текущие = целевые → score = 100.
    func testIdenticalPoses_returns100() async {
        let joints: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root:     .zero,
            .head:     SIMD3(0, 1.7, 0),
            .leftHand: SIMD3(-0.5, 1.4, 0),
            .rightHand: SIMD3(0.5, 1.4, 0)
        ]
        let target = makeTarget(joints: joints)
        let score = await worker.score(current: joints, target: target)
        XCTAssertEqual(score, 100, "Идентичные позы должны давать score=100, получено \(score)")
    }

    /// Противоположные векторы (180 градусов): score = 0.
    func testOppositePoses_returns0() async {
        let current: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root:     .zero,
            .leftHand: SIMD3(-1, 0, 0)
        ]
        let target = makeTarget(joints: [
            .root:     .zero,
            .leftHand: SIMD3(1, 0, 0)   // противоположное направление
        ])
        let score = await worker.score(current: current, target: target)
        XCTAssertEqual(score, 0, "Противоположные векторы должны давать score=0, получено \(score)")
    }

    /// Половина суставов совпадает: score около 50.
    func testHalfMatchPoses_returnsApprox50() async {
        // leftHand совпадает, rightHand противоположный
        let current: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root:      .zero,
            .leftHand:  SIMD3(-1, 0, 0),
            .rightHand: SIMD3(1, 0, 0)
        ]
        let target = makeTarget(joints: [
            .root:      .zero,
            .leftHand:  SIMD3(-1, 0, 0),   // совпадает
            .rightHand: SIMD3(-1, 0, 0)    // противоположный
        ])
        let score = await worker.score(current: current, target: target)
        // cosine(-1,0,0 vs -1,0,0) = 1.0 → 100%, cosine(1,0,0 vs -1,0,0) = 0 → avg = 0.5 * 100 = 50
        XCTAssertEqual(score, 50, accuracy: 5, "Половинное совпадение должно давать ~50, получено \(score)")
    }

    /// Пустой current: score = 0.
    func testEmptyCurrent_returns0() async {
        let target = makeTarget(joints: [
            .root:     .zero,
            .leftHand: SIMD3(-0.5, 1.4, 0)
        ])
        let score = await worker.score(current: [:], target: target)
        XCTAssertEqual(score, 0, "Пустой current должен давать score=0")
    }

    /// Пустые целевые суставы: score = 0.
    func testEmptyTarget_returns0() async {
        let current: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root:     .zero,
            .leftHand: SIMD3(-0.5, 1.4, 0)
        ]
        let target = makeTarget(joints: [:])
        let score = await worker.score(current: current, target: target)
        XCTAssertEqual(score, 0, "Пустые целевые суставы должны давать score=0")
    }

    /// Один сустав, 90 градусов (перпендикулярные векторы): cosine = 0 → score = 0.
    func testPerpendicularJoint_returns0() async {
        let current: [ARSkeleton.JointName: SIMD3<Float>] = [
            .root:     .zero,
            .leftHand: SIMD3(1, 0, 0)
        ]
        let target = makeTarget(joints: [
            .root:     .zero,
            .leftHand: SIMD3(0, 1, 0)   // перпендикуляр
        ])
        let score = await worker.score(current: current, target: target)
        XCTAssertEqual(score, 0, "Перпендикулярные векторы: cosine=0 → score=0, получено \(score)")
    }
}

// MARK: - Int equality with accuracy helper

private func XCTAssertEqual(
    _ expression1: Int,
    _ expression2: Int,
    accuracy: Int,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        abs(expression1 - expression2) <= accuracy,
        "\(expression1) не равно \(expression2) с точностью \(accuracy). \(message())",
        file: file,
        line: line
    )
}
