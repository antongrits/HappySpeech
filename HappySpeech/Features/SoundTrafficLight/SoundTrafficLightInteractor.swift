import Foundation
import OSLog

// MARK: - SoundTrafficLightBusinessLogic

@MainActor
protocol SoundTrafficLightBusinessLogic: AnyObject {
    func start(request: SoundTrafficLightModels.Start.Request) async
    /// Уровни слог / слово: сортировка материала в гараж.
    func sort(request: SoundTrafficLightModels.Sort.Request) async
    /// Уровень фраза: выбор доминирующего звука фразы.
    func choosePhrase(request: SoundTrafficLightModels.ChoosePhrase.Request) async
    /// Уровень текст: подсчёт слов со звуком A и со звуком B.
    func countText(request: SoundTrafficLightModels.CountText.Request) async
}

// MARK: - SoundTrafficLightDataStore

@MainActor
protocol SoundTrafficLightDataStore: AnyObject {
    var childId: String { get set }
    var pair: DifferentiationPair? { get set }
    var level: DifferentiationLevel { get set }
    var rounds: [TrafficLightRound] { get set }
    var phrases: [TrafficLightPhrase] { get set }
    var texts: [TrafficLightText] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - SoundTrafficLightInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Бизнес-логика лестницы дифференциации: ведёт прогресс по раундам/фразам/
// текстам текущего уровня, проверяет ответ, считает точность и по окончании
// сессии применяет методический критерий перехода на следующий уровень
// (`SoundTrafficLightCriteria`), сохраняя прогресс. Без таймеров-соревнований
// (антифатиговое правило).

@MainActor
final class SoundTrafficLightInteractor: SoundTrafficLightBusinessLogic, SoundTrafficLightDataStore {

    // MARK: - DataStore

    var childId: String
    var pair: DifferentiationPair?
    var level: DifferentiationLevel = .word
    var rounds: [TrafficLightRound] = []
    var phrases: [TrafficLightPhrase] = []
    var texts: [TrafficLightText] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any SoundTrafficLightPresentationLogic)?

    // MARK: - Deps

    private let worker: any SoundTrafficLightWorkerProtocol
    private let hapticService: any HapticService
    private let progressStore: any DifferentiationProgressStoring

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SoundTrafficLightWorkerProtocol,
        hapticService: any HapticService,
        progressStore: any DifferentiationProgressStoring = UserDefaultsDifferentiationProgressStore()
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.progressStore = progressStore
    }

    // MARK: - Start

    func start(request: SoundTrafficLightModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(childId: request.childId)
        pair = response.pair
        level = response.level
        rounds = response.rounds
        phrases = response.phrases
        texts = response.texts
        currentIndex = 0
        correctCount = 0
        Self.logger.debug(
            "Started traffic-light level=\(response.level.rawValue, privacy: .public)"
        )
        await presenter?.presentStart(response: response)
    }

    // MARK: - Sort (слог / слово)

    func sort(request: SoundTrafficLightModels.Sort.Request) async {
        guard level == .syllable || level == .word else {
            Self.logger.warning("sort called on non-round level \(self.level.rawValue, privacy: .public)")
            return
        }
        guard currentIndex < rounds.count else {
            Self.logger.warning("Sort called after level finished")
            return
        }
        let round = rounds[currentIndex]
        let wasCorrect = (round.belongsToA == request.pickedGarageA)
        registerAnswer(wasCorrect: wasCorrect)

        currentIndex += 1
        let isFinished = currentIndex >= rounds.count
        let nextRound = isFinished ? nil : rounds[currentIndex]
        let nextLevel = isFinished ? commitSessionResult(total: rounds.count) : nil

        let response = SoundTrafficLightModels.Sort.Response(
            wasCorrect: wasCorrect,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: isFinished ? nil : currentIndex,
            correctCount: correctCount,
            totalRounds: rounds.count,
            level: level,
            nextLevel: nextLevel
        )
        await presenter?.presentSort(response: response)
    }

    // MARK: - ChoosePhrase (фраза)

    func choosePhrase(request: SoundTrafficLightModels.ChoosePhrase.Request) async {
        guard level == .phrase else {
            Self.logger.warning("choosePhrase called on level \(self.level.rawValue, privacy: .public)")
            return
        }
        guard currentIndex < phrases.count else {
            Self.logger.warning("choosePhrase called after level finished")
            return
        }
        let phrase = phrases[currentIndex]
        let wasCorrect = (phrase.dominant == request.pickedSide)
        registerAnswer(wasCorrect: wasCorrect)

        currentIndex += 1
        let isFinished = currentIndex >= phrases.count
        let nextPhrase = isFinished ? nil : phrases[currentIndex]
        let nextLevel = isFinished ? commitSessionResult(total: phrases.count) : nil

        let response = SoundTrafficLightModels.ChoosePhrase.Response(
            wasCorrect: wasCorrect,
            isFinished: isFinished,
            nextPhrase: nextPhrase,
            nextPhraseIndex: isFinished ? nil : currentIndex,
            correctCount: correctCount,
            totalPhrases: phrases.count,
            nextLevel: nextLevel
        )
        await presenter?.presentChoosePhrase(response: response)
    }

    // MARK: - CountText (текст)

    func countText(request: SoundTrafficLightModels.CountText.Request) async {
        guard level == .text else {
            Self.logger.warning("countText called on level \(self.level.rawValue, privacy: .public)")
            return
        }
        guard currentIndex < texts.count else {
            Self.logger.warning("countText called after level finished")
            return
        }
        let text = texts[currentIndex]
        let tolerance = SoundTrafficLightCriteria.textCountTolerance
        let correctA = abs(request.answerA - text.countA) <= tolerance
        let correctB = abs(request.answerB - text.countB) <= tolerance
        let textPassed = correctA && correctB
        registerAnswer(wasCorrect: textPassed)

        currentIndex += 1
        let isFinished = currentIndex >= texts.count
        let nextText = isFinished ? nil : texts[currentIndex]

        var pairCompleted = false
        if isFinished {
            // .text — финальный уровень дифференциации: следующего уровня нет,
            // commitSessionResult вызывается ради фиксации результата сессии.
            _ = commitSessionResult(total: texts.count)
            if let pair, level == .text {
                pairCompleted = progressStore
                    .progress(childId: childId, pairId: pair.id).isPairCompleted
            }
        }

        let response = SoundTrafficLightModels.CountText.Response(
            correctA: correctA,
            correctB: correctB,
            textPassed: textPassed,
            isFinished: isFinished,
            nextText: nextText,
            nextTextIndex: isFinished ? nil : currentIndex,
            passedCount: correctCount,
            totalTexts: texts.count,
            pairCompleted: pairCompleted
        )
        await presenter?.presentCountText(response: response)
    }

    // MARK: - Helpers

    private func registerAnswer(wasCorrect: Bool) {
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }
    }

    /// Применяет результат завершённой сессии к прогрессу пары, сохраняет его
    /// и возвращает рекомендованный следующий уровень (если критерий выполнен).
    private func commitSessionResult(total: Int) -> DifferentiationLevel? {
        guard let pair, total > 0 else { return nil }
        let accuracy = Double(correctCount) / Double(total)
        let current = progressStore.progress(childId: childId, pairId: pair.id)
        let updated = SoundTrafficLightCriteria.advance(
            current,
            accuracy: accuracy,
            availableLevels: pair.availableLevels
        )
        progressStore.save(updated, childId: childId, pairId: pair.id)
        return updated.level != current.level ? updated.level : nil
    }
}
