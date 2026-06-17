@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubVoicingWorker: VoicingSoftnessWorkerProtocol {
    var response: VoicingSoftnessModels.Start.Response
    private(set) var buildCallCount = 0
    private(set) var lastPreferredMode: VoicingSoftnessMode?

    init(response: VoicingSoftnessModels.Start.Response) {
        self.response = response
    }

    func buildSession(
        childId: String,
        preferredMode: VoicingSoftnessMode?
    ) async -> VoicingSoftnessModels.Start.Response {
        buildCallCount += 1
        lastPreferredMode = preferredMode
        return response
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyVoicingPresenter: VoicingSoftnessPresentationLogic, @unchecked Sendable {
    var startCount = 0
    var answerCount = 0
    var lastAnswer: VoicingSoftnessModels.Answer.Response?

    func presentStart(response: VoicingSoftnessModels.Start.Response) async {
        startCount += 1
    }
    func presentAnswer(response: VoicingSoftnessModels.Answer.Response) async {
        answerCount += 1
        lastAnswer = response
    }
}

// MARK: - Spy AdaptivePlanner

private final class SpyVoicingPlanner: AdaptivePlannerService, @unchecked Sendable {
    private let lock = NSLock()
    private var _sessionCount = 0
    private var _itemCount = 0
    private var _lastSound: String?
    private var _lastQuality: SM2Quality?

    var sessionCount: Int { lock.withLock { _sessionCount } }
    var itemCount: Int { lock.withLock { _itemCount } }
    var lastSound: String? { lock.withLock { _lastSound } }
    var lastQuality: SM2Quality? { lock.withLock { _lastQuality } }

    func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
        AdaptiveRoute(steps: [], maxDurationSec: 600, fatigueLevel: .normal)
    }
    func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
    func recordSessionResult(
        childId: String, soundTarget: String, qualityScore: SM2Quality
    ) async throws {
        lock.withLock {
            _sessionCount += 1
            _lastSound = soundTarget
            _lastQuality = qualityScore
        }
    }
    func recordItemOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
        lock.withLock { _itemCount += 1 }
    }
    func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
}

// MARK: - Builders

@MainActor
private func voicedItem(id: String, zone: VoicingZone, token: String = "Б", base: String = "Б") -> VoicingSoftnessItem {
    .init(id: id, token: token, correctZone: zone, soundFamily: "губно-губные", baseSound: base, audioId: "phoneme_\(token)")
}

@MainActor
private func sortResponse(
    items: [VoicingSoftnessItem],
    mode: VoicingSoftnessMode = .voicing,
    target: String = "Б"
) -> VoicingSoftnessModels.Start.Response {
    .init(mode: mode, sortRounds: items, trapRounds: [], targetSound: target)
}

@MainActor
private func trapResponse(
    rounds: [VoicingSoftnessTrapRound],
    target: String = "З"
) -> VoicingSoftnessModels.Start.Response {
    .init(mode: .trapWords, sortRounds: [], trapRounds: rounds, targetSound: target)
}

@MainActor
private func trapRound(
    id: String,
    targetIsVoicedOrSoft: Bool = true,
    contrast: VoicingSoftnessContrast = .voicing
) -> VoicingSoftnessTrapRound {
    .init(
        id: id, contrast: contrast, targetWord: "коза", diffLetter: "з",
        targetIsVoicedOrSoft: targetIsVoicedOrSoft,
        options: [
            .init(id: "\(id)-a", word: "коза", imageAsset: "word_goat", diffIndex: 2, isTarget: true),
            .init(id: "\(id)-b", word: "коса", imageAsset: "word_kosa", diffIndex: 2, isTarget: false)
        ],
        baseSound: "З"
    )
}

// MARK: - Interactor Tests

@MainActor
final class VoicingSoftnessInteractorTests: XCTestCase {

    private func makeSortSUT(
        items: [VoicingSoftnessItem],
        mode: VoicingSoftnessMode = .voicing
    ) -> (VoicingSoftnessInteractor, SpyVoicingPresenter, SpyHapticService, SpyVoicingPlanner) {
        let worker = StubVoicingWorker(response: sortResponse(items: items, mode: mode))
        let haptic = SpyHapticService()
        let planner = SpyVoicingPlanner()
        let sut = VoicingSoftnessInteractor(
            childId: "child-1", worker: worker, hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyVoicingPresenter()
        sut.presenter = spy
        return (sut, spy, haptic, planner)
    }

    private func makeTrapSUT(
        rounds: [VoicingSoftnessTrapRound]
    ) -> (VoicingSoftnessInteractor, SpyVoicingPresenter, SpyHapticService, SpyVoicingPlanner) {
        let worker = StubVoicingWorker(response: trapResponse(rounds: rounds))
        let haptic = SpyHapticService()
        let planner = SpyVoicingPlanner()
        let sut = VoicingSoftnessInteractor(
            childId: "child-1", worker: worker, hapticService: haptic, adaptivePlanner: planner
        )
        let spy = SpyVoicingPresenter()
        sut.presenter = spy
        return (sut, spy, haptic, planner)
    }

    // MARK: Start

    func test_start_buildsSessionAndPresents() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless, token: "П", base: "П")]
        let (sut, spy, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        XCTAssertEqual(spy.startCount, 1)
        XCTAssertEqual(sut.mode, .voicing)
        XCTAssertEqual(sut.totalRounds, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_resetsProgress() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless)]
        let (sut, _, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(sut.correctCount, 0)
    }

    func test_start_passesPreferredModeToWorker() async {
        let items = [voicedItem(id: "i1", zone: .voiced)]
        let worker = StubVoicingWorker(response: sortResponse(items: items))
        let sut = VoicingSoftnessInteractor(
            childId: "c", worker: worker, hapticService: SpyHapticService(), adaptivePlanner: SpyVoicingPlanner()
        )
        sut.presenter = SpyVoicingPresenter()
        await sut.start(request: .init(childId: "c", preferredMode: .softness))
        XCTAssertEqual(worker.lastPreferredMode, .softness)
    }

    // MARK: Classification («светофор»)

    func test_answer_correctVoicedZone_isHit_andTriggersVoicedHaptic() async {
        // Звонкий «Б» → зона voiced → hit + виброотдача (метафора голоса).
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless)]
        let (sut, spy, haptic, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertTrue(spy.lastAnswer?.triggerVoicedHaptic ?? false, "Звонкий звук — виброотдача")
        XCTAssertEqual(haptic.notificationCount, 1)
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false)
    }

    func test_answer_correctVoicelessZone_isHit_noVoicedHaptic() async {
        // Глухой «П» → зона voiceless → hit, но БЕЗ «гудящей» виброотдачи.
        let items = [voicedItem(id: "i1", zone: .voiceless, token: "П", base: "П"), voicedItem(id: "i2", zone: .voiced)]
        let (sut, spy, haptic, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertFalse(spy.lastAnswer?.triggerVoicedHaptic ?? true, "Глухой звук — без вибро-метафоры голоса")
        XCTAssertEqual(haptic.selectionCount, 1, "Глухой верный — мягкая selection-хаптика")
    }

    func test_answer_wrongZone_firstMiss_isAlmost_doesNotAdvance() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless)]
        let (sut, spy, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        // Звонкий «Б» нужно в voiced; кладём в voiceless → промах.
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost)
        XCTAssertEqual(sut.currentIndex, 0, "Первый промах не продвигает раунд")
        XCTAssertFalse(spy.lastAnswer?.advancedToNextRound ?? true)
        XCTAssertFalse(spy.lastAnswer?.showThroatHint ?? true)
    }

    func test_answer_secondMiss_isRetry_showsThroatHint_andAdvances() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless)]
        let (sut, spy, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 2))
        XCTAssertEqual(spy.lastAnswer?.feedback, .retry)
        XCTAssertTrue(spy.lastAnswer?.showThroatHint ?? false, "После 2 промахов — подсказка «потрогай горлышко»")
        XCTAssertTrue(spy.lastAnswer?.advancedToNextRound ?? false, "Errorless: мягко идём дальше")
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(sut.attemptsInRound, 0)
    }

    func test_answer_neverProducesWrongTier() async {
        // Методика: только hit/almost/retry, никакого «неправильно».
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless)]
        let (sut, spy, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        let tier1 = spy.lastAnswer?.feedback
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 2))
        let tier2 = spy.lastAnswer?.feedback
        XCTAssertEqual(tier1, .almost)
        XCTAssertEqual(tier2, .retry)
        XCTAssertEqual(Set([FeedbackTier.hit, .almost, .retry]).count, 3)
    }

    // MARK: Softness mode

    func test_softness_hardSyllableToHardZone_isHit() async {
        let items = [
            VoicingSoftnessItem(id: "h", token: "ЛА", correctZone: .hard, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛА"),
            VoicingSoftnessItem(id: "s", token: "ЛИ", correctZone: .soft, soundFamily: "соноры", baseSound: "Л", audioId: "syllable_ЛИ")
        ]
        let (sut, spy, _, _) = makeSortSUT(items: items, mode: .softness)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        XCTAssertEqual(sut.mode, .softness)
        await sut.answer(request: .init(chosenZone: .hard, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertFalse(
            spy.lastAnswer?.triggerVoicedHaptic ?? true,
            "Твёрдость-мягкость — без вибро-метафоры звонкости"
        )
    }

    // MARK: Trap words

    func test_trap_correctPicture_isHit() async {
        let (sut, spy, _, _) = makeTrapSUT(rounds: [trapRound(id: "t1"), trapRound(id: "t2")])
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        XCTAssertEqual(sut.mode, .trapWords)
        await sut.answer(request: .init(chosenZone: nil, chosenOptionId: "t1-a", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .hit)
        XCTAssertEqual(spy.lastAnswer?.correctOptionId, "t1-a")
        XCTAssertEqual(sut.correctCount, 1)
        XCTAssertFalse(spy.lastAnswer?.showThroatHint ?? true)
    }

    func test_trap_wrongPicture_showsThroatHintImmediately_noPenalty() async {
        let (sut, spy, _, _) = makeTrapSUT(rounds: [trapRound(id: "t1"), trapRound(id: "t2")])
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        // Дистрактор «коса» (t1-b) вместо целевой «коза» (t1-a).
        await sut.answer(request: .init(chosenZone: nil, chosenOptionId: "t1-b", attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.feedback, .almost, "Первая ошибка — мягко, без штрафа")
        XCTAssertTrue(spy.lastAnswer?.showThroatHint ?? false, "Слова-ловушки: ошибка → сразу «потрогай горлышко»")
        XCTAssertEqual(spy.lastAnswer?.trapDiffLetter, "з", "Подсветка различающейся буквы")
        XCTAssertTrue(spy.lastAnswer?.trapTargetIsVoicedOrSoft ?? false)
        XCTAssertEqual(sut.currentIndex, 0, "Первая ошибка не продвигает")
    }

    // MARK: Progress / finish

    func test_answer_advancesThroughRounds_andFinishes() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless, token: "П", base: "П")]
        let (sut, spy, _, planner) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(spy.lastAnswer?.isFinished, false)
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.lastAnswer?.isFinished, true)
        XCTAssertEqual(spy.lastAnswer?.correctCount, 2)
        XCTAssertEqual(sut.accuracyFraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(planner.itemCount, 2, "Каждое слово — recordItemOutcome")
    }

    func test_answer_afterFinish_isIgnored() async {
        let items = [voicedItem(id: "i1", zone: .voiced)]
        let (sut, spy, _, _) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        let after = spy.answerCount
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(spy.answerCount, after)
    }

    // MARK: Adaptive

    func test_finish_recordsSessionResult_perfect() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless, token: "П", base: "П")]
        let (sut, _, _, planner) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        XCTAssertEqual(planner.sessionCount, 1)
        XCTAssertEqual(planner.lastSound, "Б")
        XCTAssertEqual(planner.lastQuality, .perfect)
    }

    func test_finish_lowAccuracy_recordsBlackout() async {
        let items = [voicedItem(id: "i1", zone: .voiced), voicedItem(id: "i2", zone: .voiceless, token: "П", base: "П")]
        let (sut, _, _, planner) = makeSortSUT(items: items)
        await sut.start(request: .init(childId: "child-1", preferredMode: nil))
        // r1: 2 промаха → retry advance (0 верных).
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .voiceless, chosenOptionId: nil, attemptInRound: 2))
        // r2: 2 промаха → retry advance (0 верных).
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 1))
        await sut.answer(request: .init(chosenZone: .voiced, chosenOptionId: nil, attemptInRound: 2))
        XCTAssertEqual(planner.sessionCount, 1)
        XCTAssertEqual(planner.lastQuality, .blackout, "0% → blackout")
    }
}

// MARK: - Worker Mode Resolution Tests

@MainActor
final class VoicingSoftnessWorkerModeTests: XCTestCase {

    func test_ageGate_age5_isVoicing() {
        XCTAssertEqual(VoicingSoftnessWorker.ageAllowedMode(age: 5), .voicing)
    }

    func test_ageGate_age6_isSoftness() {
        XCTAssertEqual(VoicingSoftnessWorker.ageAllowedMode(age: 6), .softness)
    }

    func test_ageGate_age7_isTrapWords() {
        XCTAssertEqual(VoicingSoftnessWorker.ageAllowedMode(age: 7), .trapWords)
    }

    func test_ageGate_age8_isTrapWords() {
        XCTAssertEqual(VoicingSoftnessWorker.ageAllowedMode(age: 8), .trapWords)
    }

    func test_resolveMode_capsPreferredAtAgeGate() {
        // 5-летке нельзя trapWords, даже если просят.
        XCTAssertEqual(VoicingSoftnessWorker.resolveMode(preferredMode: .trapWords, age: 5), .voicing)
    }

    func test_resolveMode_allowsLowerThanGate() {
        XCTAssertEqual(VoicingSoftnessWorker.resolveMode(preferredMode: .voicing, age: 8), .voicing)
    }

    func test_resolveMode_nilUsesAgeGate() {
        XCTAssertEqual(VoicingSoftnessWorker.resolveMode(preferredMode: nil, age: 6), .softness)
    }

    // MARK: Session building

    func test_makeSession_voicing_buildsSortRounds() {
        let response = VoicingSoftnessWorker.makeSession(mode: .voicing, targetSounds: ["Б"])
        XCTAssertEqual(response.mode, .voicing)
        XCTAssertFalse(response.sortRounds.isEmpty)
        XCTAssertTrue(response.trapRounds.isEmpty)
        XCTAssertEqual(response.sortRounds.count, VoicingSoftnessCorpus.roundsPerSession)
    }

    func test_makeSession_trapWords_buildsTrapRounds() {
        let response = VoicingSoftnessWorker.makeSession(mode: .trapWords, targetSounds: [])
        XCTAssertEqual(response.mode, .trapWords)
        XCTAssertTrue(response.sortRounds.isEmpty)
        XCTAssertFalse(response.trapRounds.isEmpty)
        XCTAssertEqual(response.trapRounds.count, VoicingSoftnessCorpus.roundsPerSession)
    }

    func test_makeSortRounds_avoidsConsecutiveSameZone() {
        let pool: [VoicingSoftnessItem] = [
            voicedItem(id: "a", zone: .voiced),
            voicedItem(id: "b", zone: .voiced, token: "Г", base: "Г"),
            voicedItem(id: "c", zone: .voiceless, token: "П", base: "П"),
            voicedItem(id: "d", zone: .voiceless, token: "К", base: "К")
        ]
        let rounds = VoicingSoftnessWorker.makeSortRounds(pool: pool, count: 8)
        var repeats = 0
        for index in 1..<rounds.count where rounds[index].correctZone == rounds[index - 1].correctZone {
            repeats += 1
        }
        XCTAssertLessThanOrEqual(repeats, 1, "Антифатиговое чередование зон")
    }

    func test_makeSortRounds_emptyPool_returnsEmpty() {
        XCTAssertTrue(VoicingSoftnessWorker.makeSortRounds(pool: [], count: 8).isEmpty)
    }
}

// MARK: - Corpus Tests

final class VoicingSoftnessCorpusTests: XCTestCase {

    @MainActor
    func test_voicingItems_haveCorrectZones() {
        let items = VoicingSoftnessCorpus.sortItems(for: .voicing, targetSounds: [])
        XCTAssertFalse(items.isEmpty)
        // Все токены voicing-режима — только voiced/voiceless.
        let zones = Set(items.map(\.correctZone))
        XCTAssertTrue(zones.isSubset(of: [.voiced, .voiceless]))
        XCTAssertTrue(zones.contains(.voiced))
        XCTAssertTrue(zones.contains(.voiceless))
    }

    @MainActor
    func test_softnessItems_haveHardSoftZones() {
        let items = VoicingSoftnessCorpus.sortItems(for: .softness, targetSounds: [])
        XCTAssertFalse(items.isEmpty)
        let zones = Set(items.map(\.correctZone))
        XCTAssertTrue(zones.isSubset(of: [.hard, .soft]))
        XCTAssertTrue(zones.contains(.hard))
        XCTAssertTrue(zones.contains(.soft))
    }

    @MainActor
    func test_classification_pairedSoundsOppositeZones() {
        // Методическая точность: в каждой паре звонкий и глухой в разных зонах.
        let items = VoicingSoftnessCorpus.sortItems(for: .voicing, targetSounds: [])
        // Известные звонкие/глухие.
        let voiced = Set(items.filter { $0.correctZone == .voiced }.map(\.token))
        let voiceless = Set(items.filter { $0.correctZone == .voiceless }.map(\.token))
        // Б — звонкий, П — глухой (из пака).
        XCTAssertTrue(voiced.contains("Б"))
        XCTAssertTrue(voiceless.contains("П"))
        XCTAssertTrue(voiced.isDisjoint(with: voiceless))
    }

    @MainActor
    func test_trapRounds_targetWordIsTargetOption() {
        let rounds = VoicingSoftnessCorpus.trapRounds(targetSounds: [])
        XCTAssertFalse(rounds.isEmpty)
        for round in rounds {
            let targets = round.options.filter { $0.isTarget }
            XCTAssertEqual(targets.count, 1, "Ровно одна целевая картинка в раунде \(round.id)")
            XCTAssertEqual(round.options.count, 2, "Минимальная пара = 2 варианта")
            XCTAssertEqual(targets.first?.word, round.targetWord)
        }
    }

    @MainActor
    func test_trapRounds_optionsHaveDistinctAssets() {
        let rounds = VoicingSoftnessCorpus.trapRounds(targetSounds: [])
        for round in rounds {
            let assets = Set(round.options.map(\.imageAsset))
            XCTAssertEqual(assets.count, round.options.count, "Картинки пары различны: \(round.id)")
            for opt in round.options {
                XCTAssertFalse(opt.imageAsset.isEmpty)
                XCTAssertTrue(opt.imageAsset.hasPrefix("word_"))
            }
        }
    }

    @MainActor
    func test_sortItems_prioritisesTargetSound() {
        let items = VoicingSoftnessCorpus.sortItems(for: .voicing, targetSounds: ["Ж"])
        XCTAssertEqual(items.first?.baseSound.uppercased(), "Ж")
    }

    func test_letter_extractsByIndex_safely() {
        XCTAssertEqual(VoicingSoftnessPackLoader.letter(in: "коза", at: 2), "з")
        XCTAssertEqual(VoicingSoftnessPackLoader.letter(in: "коза", at: 99), "")
        XCTAssertEqual(VoicingSoftnessPackLoader.letter(in: "коза", at: -1), "")
    }
}
