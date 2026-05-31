import Foundation
import OSLog

// MARK: - FourthExtraBusinessLogic

@MainActor
protocol FourthExtraBusinessLogic: AnyObject {
    func start(request: FourthExtraModels.Start.Request) async
    func answer(request: FourthExtraModels.Answer.Request) async
}

// MARK: - FourthExtraDataStore

@MainActor
protocol FourthExtraDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [FourthExtraRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - FourthExtraInteractor (Clean Swift: Interactor)
//
// F2-005 «Четвёртый лишний» (Wave 2).
//
// Бизнес-логика классификации/обобщения:
//   • ведёт прогресс по раундам (сетка 2×2);
//   • определяет «лишнюю» карточку (isExtra) и сверяет с выбором ребёнка;
//   • оценивает по «светофору» (hit / almost / retry) — без слова «неправильно»;
//   • после 2 промахов подряд показывает подсказку (подсветка трёх «своих»,
//     errorless fading) и мягко продвигает раунд (limit = `maxAttempts`);
//   • на попадание отдаёт обобщение «своих» + причину (для озвучки и обруча);
//   • для 7–8 лет в semantic-варианте — мягкий вопрос «почему лишний»;
//   • по завершении — `recordSessionResult` для spaced-repetition.
// Без таймеров-соревнований (антифатиговое правило).

@MainActor
final class FourthExtraInteractor: FourthExtraBusinessLogic, FourthExtraDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2
    /// С какого возраста просим вербализацию «почему лишний» (semantic).
    static let verbalizeMinAge = 7

    // MARK: - DataStore

    var childId: String
    var rounds: [FourthExtraRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// «Звук» сессии для record (lexика/звук).
    private(set) var sessionSoundTarget: String = "лексика"
    /// Возраст ребёнка (для гейта вербализации).
    private(set) var childAge: Int = 6

    // MARK: - VIP

    var presenter: (any FourthExtraPresentationLogic)?

    // MARK: - Deps

    private let worker: any FourthExtraWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FourthExtra.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any FourthExtraWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: FourthExtraModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(
            childId: request.childId,
            preferredVariant: request.preferredVariant
        )
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        sessionSoundTarget = response.soundTarget
        childAge = response.childAge
        Self.logger.debug("Started fourth-extra: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: FourthExtraModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let extraId = round.extraCardId ?? round.cards.first?.id ?? ""
        let isCorrect = (request.chosenCardId == extraId)

        let feedback: FeedbackTier
        var advance = false
        var showHint = false
        var askWhy = false

        if isCorrect {
            feedback = .hit
            correctCount += 1
            attemptsInRound = 0
            advance = true
            askWhy = (childAge >= Self.verbalizeMinAge && round.variant == .semantic)
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // 1-й промах — «почти»; со 2-го — «попробуем ещё» + подсказка.
            feedback = (attemptsInRound >= Self.maxAttempts) ? .retry : .almost
            showHint = attemptsInRound >= Self.maxAttempts
            hapticService.notification(.warning)
            // После исчерпания лимита попыток — мягко продвигаемся дальше
            // (errorless: не зацикливаем ребёнка на одном наборе).
            if attemptsInRound >= Self.maxAttempts {
                advance = true
                attemptsInRound = 0
            }
        }

        if advance {
            currentIndex += 1
        }

        let isFinished = currentIndex >= rounds.count
        let nextRound = (advance && !isFinished) ? rounds[currentIndex] : nil
        // Подсказка: три «не-лишних» карточки (сужаем выбор).
        let hintIds = showHint ? round.cards.filter { !$0.isExtra }.map(\.id) : []
        // Обобщение и причина — на попадании (методическое ядро).
        let groupingLabel = isCorrect ? Self.groupingLabel(for: round) : nil
        let extraReason = isCorrect
            ? round.cards.first { $0.id == extraId }?.extraReason
            : nil

        let response = FourthExtraModels.Answer.Response(
            feedback: feedback,
            extraCardId: extraId,
            groupingLabel: groupingLabel,
            extraReason: extraReason,
            hintCardIds: hintIds,
            showHint: showHint,
            askWhy: askWhy,
            advancedToNextRound: advance,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: (advance && !isFinished) ? currentIndex : nil,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentAnswer(response: response)

        if isFinished {
            await recordResult()
        }
    }

    // MARK: - Grouping

    /// Обобщение «своих»: semantic → категория, phonetic → «со звуком X».
    static func groupingLabel(for round: FourthExtraRound) -> String? {
        switch round.variant {
        case .semantic:
            return round.categoryLabel
        case .phonetic:
            guard let sound = round.targetSound else { return nil }
            return String(format: String(localized: "fourthExtra.grouping.sound"), sound)
        }
    }

    // MARK: - Adaptive

    /// По завершении сессии — SM-2 обратная связь для spaced-repetition.
    private func recordResult() async {
        guard let planner = adaptivePlanner else { return }
        let total = rounds.count
        let rate = total > 0 ? Double(correctCount) / Double(total) : 0
        let quality = SM2Quality.fromSuccessRate(rate)
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: sessionSoundTarget,
                qualityScore: quality
            )
        } catch {
            Self.logger.error(
                "recordSessionResult failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Helpers (testable, pure)

    /// Доля правильных ответов сессии.
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }
}
