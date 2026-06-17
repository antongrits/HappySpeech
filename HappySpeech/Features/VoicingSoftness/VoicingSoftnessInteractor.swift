import Foundation
import OSLog

// MARK: - VoicingSoftnessBusinessLogic

@MainActor
protocol VoicingSoftnessBusinessLogic: AnyObject {
    func start(request: VoicingSoftnessModels.Start.Request) async
    func answer(request: VoicingSoftnessModels.Answer.Request) async
}

// MARK: - VoicingSoftnessDataStore

@MainActor
protocol VoicingSoftnessDataStore: AnyObject {
    var childId: String { get set }
    var mode: VoicingSoftnessMode { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    var attemptsInRound: Int { get set }
}

// MARK: - VoicingSoftnessInteractor (Clean Swift: Interactor)
//
// «Карта звонкости и мягкости» — дифференциация оппозиционных фонем.
//
// Бизнес-логика:
//   • ведёт прогресс по раундам (sort-режимы или слова-ловушки);
//   • проверяет верность по акустическому признаку (звонкость / твёрдость-
//     мягкость) — «светофор» hit / almost / retry, без «неправильно»;
//   • звонкий звук попал верно → реальная виброотдача (метафора голоса,
//     ключевая тактильная опора методики Каше);
//   • после 2 промахов подряд — подсказка «потрогай горлышко» (errorless
//     fading) и мягкое продвижение раунда;
//   • по завершении — recordSessionResult для spaced-repetition + пословный
//     recordItemOutcome.
// Без таймеров-соревнований (антифатиговое правило).

@MainActor
final class VoicingSoftnessInteractor: VoicingSoftnessBusinessLogic, VoicingSoftnessDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2

    // MARK: - DataStore

    var childId: String
    var mode: VoicingSoftnessMode = .voicing
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// Раунды сортировки (voicing / softness).
    private(set) var sortRounds: [VoicingSoftnessItem] = []
    /// Раунды слов-ловушек (trapWords).
    private(set) var trapRounds: [VoicingSoftnessTrapRound] = []
    /// Целевой звук сессии (для записи прогресса).
    private(set) var sessionTargetSound: String = "Б"

    // MARK: - VIP

    var presenter: (any VoicingSoftnessPresentationLogic)?

    // MARK: - Deps

    private let worker: any VoicingSoftnessWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "VoicingSoftness.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any VoicingSoftnessWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Derived

    /// Общее число раундов текущей сессии (по активному режиму).
    var totalRounds: Int {
        mode == .trapWords ? trapRounds.count : sortRounds.count
    }

    /// Доля правильных ответов сессии.
    var accuracyFraction: Double {
        totalRounds == 0 ? 0 : Double(correctCount) / Double(totalRounds)
    }

    // MARK: - Start

    func start(request: VoicingSoftnessModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(
            childId: request.childId,
            preferredMode: request.preferredMode
        )
        mode = response.mode
        sortRounds = response.sortRounds
        trapRounds = response.trapRounds
        sessionTargetSound = response.targetSound
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        Self.logger.debug(
            "Started voicing-softness: mode \(response.mode.rawValue, privacy: .public), \(self.totalRounds) rounds"
        )
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: VoicingSoftnessModels.Answer.Request) async {
        guard currentIndex < totalRounds else {
            Self.logger.warning("Answer called after session finished")
            return
        }

        switch mode {
        case .voicing, .softness:
            await answerSort(request: request)
        case .trapWords:
            await answerTrap(request: request)
        }
    }

    // MARK: - Sort answer (voicing / softness)

    private func answerSort(request: VoicingSoftnessModels.Answer.Request) async {
        let round = sortRounds[currentIndex]
        let isCorrect = (request.chosenZone == round.correctZone)

        let outcome = evaluate(isCorrect: isCorrect)
        // Звонкий токен попал верно → виброотдача (метафора голоса).
        let triggerVoicedHaptic = isCorrect && round.isVoiced

        if isCorrect {
            if triggerVoicedHaptic {
                // Сильная «гудящая» виброотдача — почувствовать работу голоса.
                hapticService.notification(.success)
            } else {
                hapticService.selection()
            }
        } else {
            hapticService.notification(.warning)
        }

        if outcome.advance {
            await adaptivePlanner?.recordItemOutcome(
                childId: childId, itemId: round.id,
                sound: round.baseSound, correct: isCorrect
            )
            currentIndex += 1
        }

        let isFinished = currentIndex >= totalRounds
        let advancedToNext = outcome.advance && !isFinished
        let nextSort = advancedToNext ? sortRounds[currentIndex] : nil

        let response = VoicingSoftnessModels.Answer.Response(
            feedback: outcome.feedback,
            correctZone: round.correctZone,
            correctOptionId: nil,
            showThroatHint: outcome.showHint,
            triggerVoicedHaptic: triggerVoicedHaptic,
            replayWithEmphasis: outcome.replay,
            advancedToNextRound: outcome.advance,
            isFinished: isFinished,
            nextSort: nextSort,
            nextTrap: nil,
            nextRoundIndex: advancedToNext ? currentIndex : nil,
            mode: mode,
            trapDiffLetter: nil,
            trapTargetIsVoicedOrSoft: false,
            correctCount: correctCount,
            totalRounds: totalRounds
        )
        await presenter?.presentAnswer(response: response)

        if isFinished { await recordResult() }
    }

    // MARK: - Trap answer (слова-ловушки)

    private func answerTrap(request: VoicingSoftnessModels.Answer.Request) async {
        let round = trapRounds[currentIndex]
        let target = round.options.first { $0.isTarget }
        let isCorrect = (request.chosenOptionId == target?.id)

        let outcome = evaluate(isCorrect: isCorrect)
        if isCorrect {
            hapticService.notification(.success)
        } else {
            // Ошибка не наказывается — мягкая виброподсказка + «потрогай горлышко».
            hapticService.notification(.warning)
        }

        if outcome.advance {
            await adaptivePlanner?.recordItemOutcome(
                childId: childId, itemId: round.id,
                sound: round.baseSound, correct: isCorrect
            )
            currentIndex += 1
        }

        let isFinished = currentIndex >= totalRounds
        let advancedToNext = outcome.advance && !isFinished
        let nextTrap = advancedToNext ? trapRounds[currentIndex] : nil

        let response = VoicingSoftnessModels.Answer.Response(
            feedback: outcome.feedback,
            correctZone: nil,
            correctOptionId: target?.id,
            // В словах-ловушках при ЛЮБОЙ ошибке сразу показываем «потрогай
            // горлышко» с подсветкой различия (без штрафа, методика).
            showThroatHint: !isCorrect,
            triggerVoicedHaptic: false,
            replayWithEmphasis: outcome.replay,
            advancedToNextRound: outcome.advance,
            isFinished: isFinished,
            nextSort: nil,
            nextTrap: nextTrap,
            nextRoundIndex: advancedToNext ? currentIndex : nil,
            mode: mode,
            trapDiffLetter: round.diffLetter,
            trapTargetIsVoicedOrSoft: round.targetIsVoicedOrSoft,
            correctCount: correctCount,
            totalRounds: totalRounds
        )
        await presenter?.presentAnswer(response: response)

        if isFinished { await recordResult() }
    }

    // MARK: - Shared evaluation («светофор» + errorless fading)

    private struct Outcome {
        let feedback: FeedbackTier
        let advance: Bool
        let showHint: Bool
        let replay: Bool
    }

    /// Единая логика оценки для обоих типов раундов.
    private func evaluate(isCorrect: Bool) -> Outcome {
        if isCorrect {
            correctCount += 1
            attemptsInRound = 0
            return Outcome(feedback: .hit, advance: true, showHint: false, replay: false)
        }
        attemptsInRound += 1
        // 1-й промах — «почти»; со 2-го — «попробуем ещё» + подсказка и продвижение.
        let exhausted = attemptsInRound >= Self.maxAttempts
        let feedback: FeedbackTier = exhausted ? .retry : .almost
        if exhausted { attemptsInRound = 0 }
        return Outcome(feedback: feedback, advance: exhausted, showHint: exhausted, replay: true)
    }

    // MARK: - Adaptive

    /// По завершении сессии — SM-2 обратная связь для spaced-repetition.
    private func recordResult() async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(accuracyFraction)
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: sessionTargetSound,
                qualityScore: quality
            )
        } catch {
            Self.logger.error(
                "recordSessionResult failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
