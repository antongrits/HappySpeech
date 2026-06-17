@testable import HappySpeech
import XCTest

// MARK: - LiveSoundsInteractorTests
//
// Проверяет бизнес-логику «Живых звуков» (устный фонематический синтез):
// старт сессии, выбор картинки (collect — верно/мягкая подсказка), постановку
// звуков-человечков в ряд (bench), управление темпом пауз, скоринг по решённым
// с первой попытки раундам, запись результата в планировщик и персистентность.
//
// Озвучка идёт через `LessonVoiceWorker.shared` — в тестовой среде без аудио-
// устройства это silent skip (no-op), поэтому не влияет на проверяемые ветки
// state-машины. Персистентность мокается шпионом `SessionPersistenceSpy`.

@MainActor
final class LiveSoundsInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class SpyPresenter: LiveSoundsPresentationLogic {
        var startResponse: LiveSoundsModels.Start.Response?
        var loadRoundResponses: [LiveSoundsModels.LoadRound.Response] = []
        var choosePictureResponses: [LiveSoundsModels.ChoosePicture.Response] = []
        var placeCharacterResponses: [LiveSoundsModels.PlaceCharacter.Response] = []
        var completeResponse: LiveSoundsModels.Complete.Response?
        var playingLog: [Bool] = []
        var nowSoundLog: [Int?] = []
        var paceLog: [LiveSoundsPace] = []
        var lastPlacedLetters: [String] = []
        var lastUsedBench: Set<Int> = []

        func presentStart(_ response: LiveSoundsModels.Start.Response) { startResponse = response }
        func presentLoadRound(_ response: LiveSoundsModels.LoadRound.Response) { loadRoundResponses.append(response) }
        func presentPlaying(_ isPlaying: Bool) { playingLog.append(isPlaying) }
        func presentNowSound(_ index: Int?) { nowSoundLog.append(index) }
        func presentPace(_ pace: LiveSoundsPace) { paceLog.append(pace) }
        func presentChoosePicture(_ response: LiveSoundsModels.ChoosePicture.Response) {
            choosePictureResponses.append(response)
        }
        func presentPlaceCharacter(
            _ response: LiveSoundsModels.PlaceCharacter.Response,
            placedLetters: [String],
            usedBenchIndices: Set<Int>
        ) {
            placeCharacterResponses.append(response)
            lastPlacedLetters = placedLetters
            lastUsedBench = usedBenchIndices
        }
        func presentComplete(_ response: LiveSoundsModels.Complete.Response) { completeResponse = response }
    }

    // MARK: - Planner spy

    private final class PlannerSpy: AdaptivePlannerService, @unchecked Sendable {
        private(set) var sessionResults: [(sound: String, quality: SM2Quality)] = []
        private(set) var itemOutcomes: [(itemId: String, correct: Bool)] = []

        func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
            AdaptiveRoute(steps: [], maxDurationSec: 0, fatigueLevel: .fresh, disorder: .dyslalia)
        }
        func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
        func recordSessionResult(childId: String, soundTarget: String, qualityScore: SM2Quality) async throws {
            sessionResults.append((soundTarget, qualityScore))
        }
        func recordItemOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
            itemOutcomes.append((itemId, correct))
        }
        func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
    }

    // MARK: - Persistence spy

    private final class SessionPersistenceSpy: SessionPersistenceCoordinating, @unchecked Sendable {
        private(set) var persisted: [SessionDTO] = []
        func persistAndSync(_ session: SessionDTO) async { persisted.append(session) }
    }

    // MARK: - Fixtures

    private func unit(_ l: String, _ t: LiveSoundType, _ p: Int) -> LiveSoundUnit {
        LiveSoundUnit(letter: l, type: t, position: p)
    }

    /// КОТ (consonant, vowel, consonant), collect-режим.
    /// Правильный вариант — id 1 (намеренно не первый, чтобы проверить индексы).
    private func kotCollect() -> LiveSoundsRound {
        LiveSoundsRound(
            id: "kot",
            word: "кот",
            imageAsset: "word_kot",
            sounds: [unit("К", .consonant, 0), unit("О", .vowel, 1), unit("Т", .consonant, 2)],
            options: [
                PictureOption(id: 0, word: "пёс", imageAsset: "word_dog", isCorrect: false),
                PictureOption(id: 1, word: "кот", imageAsset: "word_kot", isCorrect: true),
                PictureOption(id: 2, word: "рот", imageAsset: "word_rot", isCorrect: false),
                PictureOption(id: 3, word: "кит", imageAsset: "word_kit", isCorrect: false)
            ],
            benchLetters: [],
            mode: .collect
        )
    }

    /// ДОМ (consonant, vowel, consonant), bench-режим. Скамейка: Д, О, М + лишний Т.
    private func domBench() -> LiveSoundsRound {
        LiveSoundsRound(
            id: "dom",
            word: "дом",
            imageAsset: "word_dom",
            sounds: [unit("Д", .consonant, 0), unit("О", .vowel, 1), unit("М", .consonant, 2)],
            options: [
                PictureOption(id: 0, word: "дом", imageAsset: "word_dom", isCorrect: true),
                PictureOption(id: 1, word: "сом", imageAsset: "word_som", isCorrect: false),
                PictureOption(id: 2, word: "кот", imageAsset: "word_kot", isCorrect: false),
                PictureOption(id: 3, word: "нос", imageAsset: "word_nos", isCorrect: false)
            ],
            // Индексы скамейки: 0=Д, 1=О, 2=М, 3=Т(лишний).
            benchLetters: [unit("Д", .consonant, 0), unit("О", .vowel, 1), unit("М", .consonant, 2), unit("Т", .consonant, 3)],
            mode: .bench
        )
    }

    private func makeSUT(rounds: [LiveSoundsRound])
        -> (LiveSoundsInteractor, SpyPresenter, PlannerSpy, SessionPersistenceSpy) {
        let spy = SpyPresenter()
        let planner = PlannerSpy()
        let persistence = SessionPersistenceSpy()
        let sut = LiveSoundsInteractor(
            childId: "child-1",
            childAge: 7,
            builder: LiveSoundsBuilder(),
            adaptivePlanner: planner,
            sessionPersistence: persistence,
            seededRounds: rounds
        )
        sut.presenter = spy
        return (sut, spy, planner, persistence)
    }

    // MARK: - start

    func test_start_presentsSeededRounds() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect(), domBench()])
        await sut.start(.init(childId: "child-1"))
        XCTAssertEqual(spy.startResponse?.rounds.count, 2)
        XCTAssertEqual(spy.startResponse?.rounds.first?.word, "кот")
    }

    // MARK: - collect: correct picture

    func test_choosePicture_correct_marksSolved() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 1)) // кот — верно
        let r = spy.choosePictureResponses.last
        XCTAssertEqual(r?.isCorrect, true)
        XCTAssertEqual(r?.correctIndex, 1)
        XCTAssertEqual(r?.word, "кот")
    }

    func test_choosePicture_wrong_givesSoftHint_notSolved() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 0)) // пёс — неверно
        let r = spy.choosePictureResponses.last
        XCTAssertEqual(r?.isCorrect, false)
        XCTAssertEqual(r?.correctIndex, 1, "Подсказка указывает на правильную картинку")
    }

    func test_choosePicture_wrongThenCorrect_recovers() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 2)) // рот — неверно
        sut.choosePicture(.init(optionIndex: 1)) // кот — верно
        XCTAssertEqual(spy.choosePictureResponses.last?.isCorrect, true)
    }

    // MARK: - bench: place characters

    func test_placeCharacter_correctOrder_buildsRow() async {
        let (sut, spy, _, _) = makeSUT(rounds: [domBench()])
        await sut.start(.init(childId: "child-1"))
        sut.placeCharacter(.init(benchIndex: 0)) // Д
        XCTAssertEqual(spy.placeCharacterResponses.last?.isCorrect, true)
        XCTAssertEqual(spy.placeCharacterResponses.last?.slotIndex, 0)
        XCTAssertEqual(spy.lastPlacedLetters, ["Д"])
    }

    func test_placeCharacter_wrongCharacter_softHint() async {
        let (sut, spy, _, _) = makeSUT(rounds: [domBench()])
        await sut.start(.init(childId: "child-1"))
        sut.placeCharacter(.init(benchIndex: 3)) // Т — лишний, на месте 0 ждём Д
        XCTAssertEqual(spy.placeCharacterResponses.last?.isCorrect, false)
        XCTAssertEqual(spy.placeCharacterResponses.last?.slotIndex, 0, "Остаёмся на том же месте")
    }

    func test_placeCharacter_fullRow_marksComplete() async {
        let (sut, spy, _, _) = makeSUT(rounds: [domBench()])
        await sut.start(.init(childId: "child-1"))
        sut.placeCharacter(.init(benchIndex: 0)) // Д
        sut.placeCharacter(.init(benchIndex: 1)) // О
        sut.placeCharacter(.init(benchIndex: 2)) // М
        XCTAssertEqual(spy.placeCharacterResponses.last?.rowComplete, true)
        XCTAssertEqual(spy.lastPlacedLetters, ["Д", "О", "М"])
        XCTAssertEqual(spy.lastUsedBench, [0, 1, 2])
    }

    func test_placeCharacter_usedBenchIndex_ignored() async {
        let (sut, spy, _, _) = makeSUT(rounds: [domBench()])
        await sut.start(.init(childId: "child-1"))
        sut.placeCharacter(.init(benchIndex: 0)) // Д
        let countAfterFirst = spy.placeCharacterResponses.count
        sut.placeCharacter(.init(benchIndex: 0)) // повторно тот же — игнор
        XCTAssertEqual(spy.placeCharacterResponses.count, countAfterFirst, "Использованный человечек игнорируется")
    }

    // MARK: - pace

    func test_setPace_updatesPaceAndNotifies() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.setPace(.init(pace: .slow))
        XCTAssertEqual(sut.currentPace, .slow)
        XCTAssertEqual(spy.paceLog.last, .slow)
    }

    // MARK: - scoring & persistence

    func test_completeSession_firstTryCorrect_scoreOne_recordsAll() async {
        let (sut, spy, planner, persistence) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 1)) // верно с первой попытки
        await sut.advanceRound() // last round → complete

        XCTAssertEqual(spy.completeResponse?.score ?? -1, Float(1.0), accuracy: 0.001)
        XCTAssertEqual(spy.completeResponse?.totalRounds, 1)
        XCTAssertEqual(planner.sessionResults.count, 1)
        XCTAssertEqual(planner.sessionResults.first?.quality, .perfect)
        XCTAssertEqual(planner.itemOutcomes.first?.correct, true)
        XCTAssertEqual(persistence.persisted.count, 1, "Сессия персистится один раз")
        XCTAssertEqual(persistence.persisted.first?.correctAttempts, 1)
    }

    func test_completeSession_withError_lowersScore() async {
        let (sut, spy, planner, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 0)) // ошибка
        sut.choosePicture(.init(optionIndex: 1)) // исправил
        await sut.advanceRound()

        // Раунд решён НЕ с первой попытки → score 0 при 1 раунде.
        XCTAssertEqual(spy.completeResponse?.score ?? -1, Float(0.0), accuracy: 0.001)
        XCTAssertEqual(planner.itemOutcomes.first?.correct, false)
    }

    func test_advanceRound_movesToNextRound() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect(), domBench()])
        await sut.start(.init(childId: "child-1"))
        sut.choosePicture(.init(optionIndex: 1))
        await sut.advanceRound()
        XCTAssertEqual(spy.loadRoundResponses.last?.round.word, "дом")
        XCTAssertEqual(spy.loadRoundResponses.last?.roundIndex, 1)
        XCTAssertNil(spy.completeResponse, "Сессия ещё не завершена")
    }

    func test_cancel_stopsFurtherPresentation() async {
        let (sut, spy, _, _) = makeSUT(rounds: [kotCollect()])
        await sut.start(.init(childId: "child-1"))
        sut.cancel()
        sut.choosePicture(.init(optionIndex: 1))
        XCTAssertTrue(spy.choosePictureResponses.isEmpty, "После cancel выборы игнорируются")
    }

    // MARK: - builder pure logic

    func test_builder_classify_vowelAndConsonant() {
        XCTAssertEqual(LiveSoundsBuilder.classify("О"), .vowel)
        XCTAssertEqual(LiveSoundsBuilder.classify("А"), .vowel)
        XCTAssertEqual(LiveSoundsBuilder.classify("К"), .consonant)
        XCTAssertEqual(LiveSoundsBuilder.classify("Р"), .consonant)
    }

    func test_builder_stableShuffle_isDeterministic() {
        let input = Array(0..<8)
        let a = LiveSoundsBuilder.stableShuffle(input, seed: "kot")
        let b = LiveSoundsBuilder.stableShuffle(input, seed: "kot")
        XCTAssertEqual(a, b, "Перемешивание детерминировано по seed")
        XCTAssertEqual(a.sorted(), input, "Сохраняет все элементы")
    }

    func test_builder_buildSession_alternatesModes() {
        let rounds = LiveSoundsBuilder.fallbackRounds()
        let builder = LiveSoundsBuilder()
        let session = builder.buildSession(from: rounds, age: 7, count: 3)
        XCTAssertEqual(session.count, 3)
        // Режимы чередуются: collect, bench, collect …
        XCTAssertEqual(session[0].mode, .collect)
        if session.count > 1 { XCTAssertEqual(session[1].mode, .bench) }
        if session.count > 2 { XCTAssertEqual(session[2].mode, .collect) }
    }

    func test_builder_loadRounds_nonEmpty() {
        let builder = LiveSoundsBuilder()
        let rounds = builder.loadRounds()
        XCTAssertFalse(rounds.isEmpty, "Пак или fallback всегда даёт раунды")
        // Каждый раунд: ровно одна правильная картинка.
        for round in rounds {
            XCTAssertEqual(round.options.filter { $0.isCorrect }.count, 1, "Раунд \(round.id): ровно один верный вариант")
            XCTAssertFalse(round.sounds.isEmpty, "Раунд \(round.id): есть звуки")
        }
    }
}
