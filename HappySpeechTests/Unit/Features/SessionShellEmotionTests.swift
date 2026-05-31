@testable import HappySpeech
import XCTest

// MARK: - SessionShellEmotionTests
//
// Подключение EmotionDetectionService в адаптивный сессионный воркер.
// Проверяет, что frustrated/sad-эмоция (выше порога) ускоряет предложение
// перерыва (дренирует «сердце усталости»), а позитив/нейтрал сбрасывает счётчик.
// Аддитивно: без emotionDetectionService поведение не меняется.

@MainActor
final class SessionShellEmotionTests: XCTestCase {

    // MARK: - Spy Presenter

    private final class SpyPresenter: SessionShellPresentationLogic {
        var startResponses: [SessionShellModels.StartSession.Response] = []
        var completeResponses: [SessionShellModels.CompleteActivity.Response] = []
        var emotionResponses: [SessionShellModels.AnalyzeEmotion.Response] = []
        var pauseCalled = 0

        func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
            startResponses.append(response)
        }
        func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {
            completeResponses.append(response)
        }
        func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {
            pauseCalled += 1
        }
        func presentAnalyzeEmotion(_ response: SessionShellModels.AnalyzeEmotion.Response) {
            emotionResponses.append(response)
        }
    }

    // MARK: - SUT

    private func makeSUT(
        emotion: (any EmotionDetectionServiceProtocol)?
    ) -> (SessionShellInteractor, SpyPresenter) {
        let interactor = SessionShellInteractor(
            contentService: MockContentService(),
            adaptivePlannerService: MockAdaptivePlannerService(),
            sessionRepository: MockSessionRepository(),
            hapticService: MockHapticService(),
            emotionDetectionService: emotion
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy)
    }

    private func startedSUT(
        emotion: (any EmotionDetectionServiceProtocol)?
    ) async -> (SessionShellInteractor, SpyPresenter) {
        let (sut, spy) = makeSUT(emotion: emotion)
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .adaptive))
        return (sut, spy)
    }

    private func samplePCM() -> Data {
        Data(repeating: 0x10, count: 16_000 * MemoryLayout<Float>.size)
    }

    // MARK: - Без сервиса — no-op (аддитивность)

    func test_analyzeEmotion_withoutService_isNoOp() async {
        let (sut, spy) = await startedSUT(emotion: nil)
        await sut.analyzeEmotion(.init(pcmData: samplePCM()))
        XCTAssertTrue(spy.emotionResponses.isEmpty, "Без emotionDetectionService — анализ эмоции не вызывается")
    }

    func test_analyzeEmotion_emptyPCM_isNoOp() async {
        let mock = MockEmotionDetectionService(emotion: .frustrated, confidence: 0.95)
        let (sut, spy) = await startedSUT(emotion: mock)
        await sut.analyzeEmotion(.init(pcmData: Data()))
        XCTAssertTrue(spy.emotionResponses.isEmpty, "Пустой PCM — нет анализа")
    }

    // MARK: - Сервис вызывается на нужном пути

    func test_analyzeEmotion_callsService_andRespondsToPresenter() async {
        let mock = MockEmotionDetectionService(emotion: .happy, confidence: 0.9)
        let (sut, spy) = await startedSUT(emotion: mock)
        await sut.analyzeEmotion(.init(pcmData: samplePCM()))
        XCTAssertEqual(spy.emotionResponses.count, 1, "EmotionDetectionService реально вызван на пути сессии")
        XCTAssertEqual(spy.emotionResponses.first?.fatigueHearts, 3, "Радость не дренирует сердце")
        XCTAssertFalse(spy.emotionResponses.first?.suggestBreak ?? true)
    }

    // MARK: - Негативная эмоция дренирует сердце

    func test_repeatedFrustration_drainsHeart() async {
        let mock = MockEmotionDetectionService(emotion: .frustrated, confidence: 0.95)
        let (sut, spy) = await startedSUT(emotion: mock)
        let pcm = samplePCM()

        // negativeEmotionsPerHeart == 2 → второй frustrated дренирует одно сердце.
        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(spy.emotionResponses[0].fatigueHearts, 3, "Первый негатив ещё не дренирует")

        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(spy.emotionResponses[1].fatigueHearts, 2, "Второй подряд негатив дренирует одно сердце")
    }

    func test_sadEmotion_alsoCountsAsNegative() async {
        let mock = MockEmotionDetectionService(emotion: .sad, confidence: 0.9)
        let (sut, spy) = await startedSUT(emotion: mock)
        let pcm = samplePCM()
        await sut.analyzeEmotion(.init(pcmData: pcm))
        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(spy.emotionResponses.last?.fatigueHearts, 2, "Грусть тоже считается негативом")
    }

    // MARK: - Низкая уверенность не учитывается

    func test_lowConfidenceNegative_doesNotDrainHeart() async {
        let mock = MockEmotionDetectionService(emotion: .frustrated, confidence: 0.4)
        let (sut, spy) = await startedSUT(emotion: mock)
        let pcm = samplePCM()
        await sut.analyzeEmotion(.init(pcmData: pcm))
        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(
            spy.emotionResponses.last?.fatigueHearts, 3,
            "Негатив ниже порога уверенности (0.6) не должен дренировать сердце"
        )
    }

    // MARK: - Позитив сбрасывает счётчик негативов

    func test_positiveResetsNegativeStreak() async {
        let mock = MockEmotionDetectionService(emotion: .frustrated, confidence: 0.95)
        let (sut, spy) = await startedSUT(emotion: mock)
        let pcm = samplePCM()

        // Один негатив (streak=1, сердце ещё 3).
        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(spy.emotionResponses.last?.fatigueHearts, 3)

        // Позитив сбрасывает streak.
        mock.mockEmotion = .happy
        mock.mockConfidence = 0.9
        await sut.analyzeEmotion(.init(pcmData: pcm))

        // Снова один негатив — снова streak=1, сердце по-прежнему 3 (а не дренировано).
        mock.mockEmotion = .frustrated
        mock.mockConfidence = 0.95
        await sut.analyzeEmotion(.init(pcmData: pcm))
        XCTAssertEqual(
            spy.emotionResponses.last?.fatigueHearts, 3,
            "После позитивной эмоции streak сброшен — одиночный негатив не дренирует"
        )
    }
}
