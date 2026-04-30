import XCTest

@testable import HappySpeech

// MARK: - UnifiedFacePoseWorkerTests
//
// 5 unit-тестов для UnifiedFacePoseWorker.currentViseme(_:).
// Используют mock UnifiedFacePose без реальных ARKit/Vision вызовов.
// Все пороги взяты из UnifiedFacePoseWorker.currentViseme.

@MainActor
final class UnifiedFacePoseWorkerTests: XCTestCase {

    // MARK: - SUT

    private var sut: UnifiedFacePoseWorker!

    override func setUp() {
        super.setUp()
        sut = UnifiedFacePoseWorker()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makePose(
        mouthOpen: Float = 0,
        lipsPucker: Float = 0,
        lipsFunnel: Float = 0,
        lipsSmile: Float = 0,
        tongueOut: Float = 0,
        lipSymmetry: Float = 1.0
    ) -> UnifiedFacePose {
        UnifiedFacePose(
            mouthOpen:   mouthOpen,
            lipsPucker:  lipsPucker,
            lipsFunnel:  lipsFunnel,
            lipsSmile:   lipsSmile,
            tongueOut:   tongueOut,
            lipSymmetry: lipSymmetry,
            landmarks76: nil
        )
    }

    // MARK: - Test 1

    /// lipsPucker > 0.5 → визема .o (высший приоритет)
    func test_currentViseme_lipsPucker_returnsO() {
        let pose = makePose(lipsPucker: 0.7)
        let viseme = sut.currentViseme(pose)
        XCTAssertEqual(viseme, .o)
    }

    // MARK: - Test 2

    /// lipsFunnel > 0.5, pucker не превышает порог → визема .u
    func test_currentViseme_lipsFunnel_returnsU() {
        let pose = makePose(lipsPucker: 0.1, lipsFunnel: 0.8)
        let viseme = sut.currentViseme(pose)
        XCTAssertEqual(viseme, .u)
    }

    // MARK: - Test 3

    /// mouthOpen > 0.6, pucker и funnel ниже порогов → визема .a
    func test_currentViseme_jawOpen60_returnsA() {
        let pose = makePose(mouthOpen: 0.75, lipsPucker: 0.2, lipsFunnel: 0.1)
        let viseme = sut.currentViseme(pose)
        XCTAssertEqual(viseme, .a)
    }

    // MARK: - Test 4

    /// lipsSmile > 0.4, mouth едва открыт, pucker/funnel < порога → визема .e
    func test_currentViseme_smile_returnsE() {
        let pose = makePose(mouthOpen: 0.3, lipsPucker: 0.1, lipsFunnel: 0.1, lipsSmile: 0.6)
        let viseme = sut.currentViseme(pose)
        XCTAssertEqual(viseme, .e)
    }

    // MARK: - Test 5

    /// Все значения у нуля → визема .closed
    func test_currentViseme_closed_returnsClosed() {
        let pose = makePose(
            mouthOpen:  0.05,
            lipsPucker: 0.05,
            lipsFunnel: 0.05,
            lipsSmile:  0.05
        )
        let viseme = sut.currentViseme(pose)
        XCTAssertEqual(viseme, .closed)
    }
}
