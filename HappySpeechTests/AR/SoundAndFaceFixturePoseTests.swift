@testable import HappySpeech
import XCTest

// MARK: - SoundAndFaceFixturePoseTests
//
// A-03 — для каждого целевого звука С/Ш/Р/Л подаём заранее известную позу
// (фикстуры FaceBlendshapes) через VIP-поток updateFrame → scoreAttempt и
// проверяем, что ПРАВИЛЬНАЯ поза даёт высокую posture-confidence (→ успех/звезду),
// а НЕПРАВИЛЬНАЯ — низкую (→ «попробуй ещё», без ложного успеха).
//
// Это детерминированная верификация на симуляторе без TrueDepth-железа: rule-based
// классификатор + фикстуры. Честно: для язык-зависимых Р/Л оценивается
// КОСВЕННАЯ эвристика (раскрытие челюсти / подворот губ / высунутость языка),
// а не положение языка внутри рта — ARKit его не измеряет.

@MainActor
private final class CapturingPresenter: SoundAndFacePresentationLogic {
    var confidences: [Float] = []
    var lastStars: Int?
    var lastMatched: Bool?

    func presentStartGame(_ response: SoundAndFaceModels.StartGame.Response) {}
    func presentUpdateFrame(_ response: SoundAndFaceModels.UpdateFrame.Response) {
        confidences.append(response.postureConfidence)
    }
    func presentScoreAttempt(_ response: SoundAndFaceModels.ScoreAttempt.Response) {
        lastStars = response.stars
        lastMatched = response.transcriptMatched
    }
}

@MainActor
final class SoundAndFaceFixturePoseTests: XCTestCase {

    private func makeSUT() -> (SoundAndFaceInteractor, CapturingPresenter) {
        let sut = SoundAndFaceInteractor(classifier: TonguePostureClassifier())
        let spy = CapturingPresenter()
        sut.presenter = spy
        return (sut, spy)
    }

    /// Прогоняет N кадров одной позы и возвращает среднюю posture-confidence,
    /// как это делает реальная View перед scoreAttempt.
    private func averageConfidence(
        _ sut: SoundAndFaceInteractor,
        _ spy: CapturingPresenter,
        pose: FaceBlendshapes,
        frames: Int = 5
    ) -> Float {
        spy.confidences.removeAll()
        for _ in 0..<frames {
            sut.updateFrame(.init(blendshapes: pose))
        }
        guard !spy.confidences.isEmpty else { return 0 }
        return spy.confidences.reduce(0, +) / Float(spy.confidences.count)
    }

    // MARK: - С (свистящий → улыбка)

    func test_soundS_correctSmilePose_succeeds() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        let avg = averageConfidence(sut, spy, pose: .smile)
        XCTAssertGreaterThanOrEqual(avg, 0.6, "Улыбка должна давать высокую confidence для С")
        sut.scoreAttempt(.init(asrTranscript: "сссс", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 3)
    }

    func test_soundS_wrongPucker_pose_failsPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        let avg = averageConfidence(sut, spy, pose: .pucker)
        XCTAssertLessThan(avg, 0.6, "Трубочка не должна засчитываться как улыбка")
        // ASR совпал, но поза неверна → 2 звезды, НЕ ложный успех (3).
        sut.scoreAttempt(.init(asrTranscript: "сссс", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 2)
    }

    // MARK: - Ш (шипящий → чашечка / хоботок)

    func test_soundSh_correctFunnelPose_succeeds() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Ш"))
        let avg = averageConfidence(sut, spy, pose: .funnel)
        XCTAssertGreaterThanOrEqual(avg, 0.6, "Хоботок должен давать высокую confidence для Ш")
        sut.scoreAttempt(.init(asrTranscript: "шшш", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 3)
    }

    func test_soundSh_wrongSmilePose_failsPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Ш"))
        let avg = averageConfidence(sut, spy, pose: .smile)
        XCTAssertLessThan(avg, 0.6, "Улыбка не должна засчитываться как чашечка")
        sut.scoreAttempt(.init(asrTranscript: "шшш", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 2)
    }

    // MARK: - Р (сонор → «грибок», косвенная эвристика)

    func test_soundR_correctJawOpenPose_succeeds() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Р"))
        let avg = averageConfidence(sut, spy, pose: .jawOpenWide)
        XCTAssertGreaterThanOrEqual(avg, 0.6, "Открытый рот + подворот губ — косвенная эвристика Р")
        sut.scoreAttempt(.init(asrTranscript: "ррр", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 3)
    }

    func test_soundR_wrongSmilePose_failsPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Р"))
        let avg = averageConfidence(sut, spy, pose: .smile)
        XCTAssertLessThan(avg, 0.6, "Улыбка не должна засчитываться как поза Р")
        sut.scoreAttempt(.init(asrTranscript: "ррр", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 2)
    }

    // MARK: - Л (сонор → язык вверх, косвенная эвристика)

    func test_soundL_correctTongueUpPose_succeeds() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Л"))
        let avg = averageConfidence(sut, spy, pose: .tongueUpProxy)
        XCTAssertGreaterThanOrEqual(avg, 0.6, "Высунутый язык + открытый рот — косвенная эвристика Л")
        sut.scoreAttempt(.init(asrTranscript: "ллл", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 3)
    }

    func test_soundL_wrongNeutralPose_failsPosture() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "Л"))
        let avg = averageConfidence(sut, spy, pose: .neutral)
        XCTAssertLessThan(avg, 0.6, "Нейтральное лицо не должно засчитываться как поза Л")
        sut.scoreAttempt(.init(asrTranscript: "ллл", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 2)
    }

    // MARK: - Анти-ложный-успех: молчание + правильная поза не даёт 3 звезды

    func test_silenceWithCorrectPose_noFalseSuccess() {
        let (sut, spy) = makeSUT()
        sut.startGame(.init(targetSound: "С"))
        let avg = averageConfidence(sut, spy, pose: .smile)
        // ASR пустой (молчание) → транскрипт не совпал → максимум 2 звезды.
        sut.scoreAttempt(.init(asrTranscript: "", avgPostureConfidence: avg))
        XCTAssertEqual(spy.lastStars, 2)
        XCTAssertEqual(spy.lastMatched, false)
    }
}
