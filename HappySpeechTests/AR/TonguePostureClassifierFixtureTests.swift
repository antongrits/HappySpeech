@testable import HappySpeech
import XCTest

// MARK: - TonguePostureClassifierFixtureTests
//
// A-03 — детерминированная классификация поз rule-based классификатором по
// фикстурам FaceBlendshapes. ВАЖНО (честность): это интерпретируемая эвристика
// по внешним blendshapes (улыбка, форма губ, раскрытие челюсти, высунутость
// языка), а НЕ измерение положения языка внутри рта — ARKit его не видит.

final class TonguePostureClassifierFixtureTests: XCTestCase {

    private let sut = TonguePostureClassifier()

    // MARK: - classify(): фикстура → ожидаемая поза

    func test_classify_smileFixture_isSmile() {
        XCTAssertEqual(sut.classify(.smile), .smile)
    }

    func test_classify_funnelFixture_isCupShape() {
        XCTAssertEqual(sut.classify(.funnel), .cupShape)
    }

    func test_classify_puckerFixture_isPucker() {
        XCTAssertEqual(sut.classify(.pucker), .pucker)
    }

    func test_classify_tongueOutLowJaw_isShoveling() {
        // tongueOut при почти закрытом рте → «лопаточка».
        XCTAssertEqual(sut.classify(.tongueOut), .shoveling)
    }

    func test_classify_tongueOutOpenJaw_isTongueUp() {
        // tongueOut + открытый рот → косвенный прокси «язык вверх».
        XCTAssertEqual(sut.classify(.tongueUpProxy), .tongueUp)
    }

    func test_classify_jawOpenRoll_isMushroom() {
        // Открытый рот + подворот губ → косвенный прокси «грибок» (Р).
        XCTAssertEqual(sut.classify(.jawOpenWide), .mushroom)
    }

    func test_classify_neutralFixture_isNeutral() {
        XCTAssertEqual(sut.classify(.neutral), .neutral)
    }

    func test_classify_asymmetricFixture_notClassifiedAsSmile() {
        // Однобокая улыбка не должна считаться полноценной симметричной улыбкой.
        XCTAssertNotEqual(sut.classify(.asymmetric), .smile)
    }

    // MARK: - confidence(): правильная поза высокая, неправильная низкая

    func test_confidence_smileFixture_highForSmile_lowForPucker() {
        XCTAssertGreaterThanOrEqual(sut.confidence(.smile, for: .smile), 0.6)
        XCTAssertLessThan(sut.confidence(.smile, for: .pucker), 0.4)
    }

    func test_confidence_funnelFixture_highForCupShape_lowForSmile() {
        XCTAssertGreaterThanOrEqual(sut.confidence(.funnel, for: .cupShape), 0.6)
        XCTAssertLessThan(sut.confidence(.funnel, for: .smile), 0.4)
    }

    func test_confidence_jawOpenWide_highForMushroom_lowForSmile() {
        XCTAssertGreaterThanOrEqual(sut.confidence(.jawOpenWide, for: .mushroom), 0.6)
        XCTAssertLessThan(sut.confidence(.jawOpenWide, for: .smile), 0.4)
    }

    func test_confidence_tongueUpProxy_highForTongueUp() {
        XCTAssertGreaterThanOrEqual(sut.confidence(.tongueUpProxy, for: .tongueUp), 0.6)
    }

    func test_confidence_neutralFixture_highForNeutral() {
        XCTAssertGreaterThanOrEqual(sut.confidence(.neutral, for: .neutral), 0.9)
    }

    // MARK: - confidenceMap — все позы покрыты

    func test_confidenceMap_coversAllPostures() {
        let map = sut.confidenceMap(.smile)
        XCTAssertEqual(map.count, ArticulationPosture.allCases.count)
        for value in map.values {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }
}
