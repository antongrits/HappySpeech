import Foundation
import OSLog

// MARK: - ListenYourselfBusinessLogic

@MainActor
protocol ListenYourselfBusinessLogic: AnyObject {
    func loadWord(_ request: ListenYourselfModels.LoadWord.Request) async
    func recordTake(_ request: ListenYourselfModels.RecordTake.Request) async
    func chooseTake(_ request: ListenYourselfModels.ChooseTake.Request)
    func playTake(number: Int) async
    func playReference() async
    func goToCompare()
    func judge(_ request: ListenYourselfModels.Judge.Request) async
    func revealSecretTip(_ request: ListenYourselfModels.SecretTip.Request) async
    func resetTakes()
    func cancel()
}

// MARK: - ListenYourselfInteractor
//
// «Послушай себя» — слуховой самоконтроль.
//
//   loadWord → intro → record(1) → record(2) → choosing(выбор лучшего дубля)
//            → comparing → judge(самооценка) → [secret tip] → готово
//
// Принципы:
//   • НИКАКОЙ числовой оценки приложения ребёнку — он выбирает лучший дубль и
//     оценивает похожесть сам (формирование суждения, Левина/Волкова).
//   • Запись реальная (`AudioService`), 2 дубля, выбор сохраняется.
//   • Факт рефлексии/самооценки фиксируется в планировщике повторов (FSRS) —
//     слово возвращается на повтор по реальному исходу, без наказания.
//   • «Секретный совет» (ASR) — опционален, ПОСЛЕ выбора ребёнка, как подсказка.

@MainActor
final class ListenYourselfInteractor: ListenYourselfBusinessLogic {

    // MARK: - Dependencies

    private let presenter: any ListenYourselfPresentationLogic
    private let worker: SelfCompareSessionWorker
    /// Планировщик интервальных повторов (FSRS). Опционален: при nil рефлексия
    /// не фиксируется (Preview), но игра работает.
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Репозиторий профиля — источник РЕАЛЬНОГО возраста ребёнка (влияет на
    /// возрастной тюнинг «секретного совета»). Опционален: при nil/сбое — fallback.
    private let childRepository: (any ChildRepository)?
    private let childId: String
    /// Реальный возраст ребёнка (резолвится в `loadWord`). До резолва — дефолт
    /// целевой полосы фичи (6–8 лет).
    private var childAge: Int = 7

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ListenYourself.Interactor"
    )

    // MARK: - Tunables

    /// Сколько дублей записывает ребёнок (методика: два дубля «по-разному»).
    private let takesPerSession = 2

    /// Самооценка `.like`/`.close` → слово закреплено (correct), `.almost` → на
    /// повтор. Это исход РЕФЛЕКСИИ ребёнка, не машинная оценка произношения.
    private static func isMastered(_ j: ListenYourselfModels.SelfJudgement) -> Bool {
        switch j {
        case .like, .close: return true
        case .almost:       return false
        }
    }

    // MARK: - Session state

    private(set) var phase: ListenYourselfModels.Phase = .loading
    private(set) var word: String = ""
    private(set) var targetSound: String = ""
    private(set) var takes: [ListenYourselfModels.Take] = []
    private(set) var chosenTakeNumber: Int?
    private(set) var judgement: ListenYourselfModels.SelfJudgement?

    private var recordingTask: Task<Void, Never>?

    // MARK: - Init

    init(
        presenter: any ListenYourselfPresentationLogic,
        worker: SelfCompareSessionWorker,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        childRepository: (any ChildRepository)? = nil,
        childId: String,
        childAge: Int = 7
    ) {
        self.presenter = presenter
        self.worker = worker
        self.adaptivePlanner = adaptivePlanner
        self.childRepository = childRepository
        self.childId = childId
        self.childAge = childAge
    }

    // MARK: - loadWord

    func loadWord(_ request: ListenYourselfModels.LoadWord.Request) async {
        // Резолвим реальный возраст ребёнка (для возрастного тюнинга совета).
        if let childRepository, !request.childId.isEmpty {
            if let profile = try? await childRepository.fetch(id: request.childId) {
                childAge = profile.age
            }
        }
        let card = ListenYourselfWordProvider.wordForToday()
        word = card.word
        targetSound = card.targetSound
        phase = .intro

        let response = ListenYourselfModels.LoadWord.Response(
            word: card.word,
            targetSound: card.targetSound,
            illustrationSymbol: card.displaySymbol,
            highlightLetter: card.targetSound.uppercased()
        )
        Self.logger.info("ListenYourself: загрузка слова '\(card.word, privacy: .public)' звук=\(card.targetSound, privacy: .public)")
        await presenter.presentLoadWord(response: response)
    }

    // MARK: - recordTake

    func recordTake(_ request: ListenYourselfModels.RecordTake.Request) async {
        guard takes.count < takesPerSession else { return }
        let takeNumber = takes.count + 1
        phase = .recording(takeNumber: takeNumber)
        await presenter.presentRecordingStarted(takeNumber: takeNumber)

        do {
            let recorded = try await worker.recordTake()
            let take = ListenYourselfModels.Take(
                id: takeNumber,
                url: recorded.url,
                durationSec: recorded.durationSec
            )
            takes.append(take)
            let bothReady = takes.count >= takesPerSession
            phase = bothReady ? .choosing : .intro
            // Авто-выбор второго дубля как предложенного (как в эталоне), но
            // решение остаётся за ребёнком — он может переключить.
            if bothReady, chosenTakeNumber == nil {
                chosenTakeNumber = takeNumber
            }

            let response = ListenYourselfModels.RecordTake.Response(
                take: take,
                takeNumber: takeNumber,
                bothTakesReady: bothReady
            )
            await presenter.presentRecordTake(response: response, suggestedChoice: chosenTakeNumber)
        } catch is CancellationError {
            // Тихо: уход с экрана.
            phase = takes.count >= takesPerSession ? .choosing : .intro
        } catch {
            // Мягкая ошибка без фабрикации дубля: возвращаем к предыдущей фазе.
            phase = takes.count >= takesPerSession ? .choosing : .intro
            Self.logger.info("ListenYourself: дубль не записан (\(error.localizedDescription, privacy: .public))")
            await presenter.presentRecordingFailed(
                message: (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "listenYourself.error.recordingFailed")
            )
        }
    }

    // MARK: - chooseTake (РЕШЕНИЕ ребёнка)

    func chooseTake(_ request: ListenYourselfModels.ChooseTake.Request) {
        guard takes.contains(where: { $0.id == request.takeNumber }) else { return }
        chosenTakeNumber = request.takeNumber
        Self.logger.info("ListenYourself: ребёнок выбрал дубль \(request.takeNumber)")
        presenter.presentChoice(
            response: .init(chosenTakeNumber: request.takeNumber)
        )
    }

    // MARK: - playback

    func playTake(number: Int) async {
        guard let take = takes.first(where: { $0.id == number }) else { return }
        await worker.playTake(url: take.url)
    }

    func playReference() async {
        await worker.playReference(word: word)
    }

    // MARK: - goToCompare

    func goToCompare() {
        guard takes.count >= takesPerSession else { return }
        // Если ребёнок не переключал — фиксируем предложенный выбор.
        if chosenTakeNumber == nil { chosenTakeNumber = takes.last?.id }
        phase = .comparing
        presenter.presentCompare(
            word: word,
            chosenTakeNumber: chosenTakeNumber ?? takes.last?.id ?? 1
        )
    }

    // MARK: - judge (САМООЦЕНКА ребёнка, без цифр)

    func judge(_ request: ListenYourselfModels.Judge.Request) async {
        judgement = request.judgement
        let message = Self.mascotMessage(for: request.judgement)
        Self.logger.info("ListenYourself: самооценка \(request.judgement.rawValue, privacy: .public)")

        // Фиксируем РЕФЛЕКСИЮ как исход в FSRS: ребёнок отрефлексировал слово.
        // correct = его собственное суждение «похоже/как Ляля», не машинная оценка.
        await adaptivePlanner?.recordItemOutcome(
            childId: childId,
            itemId: word,
            sound: targetSound,
            correct: Self.isMastered(request.judgement)
        )

        await presenter.presentJudge(
            response: .init(judgement: request.judgement, mascotMessage: message)
        )
    }

    // MARK: - revealSecretTip (опц. ASR-совет, ПОСЛЕ выбора)

    func revealSecretTip(_ request: ListenYourselfModels.SecretTip.Request) async {
        // Совет считается по ВЫБРАННОМУ ребёнком дублю.
        guard let chosen = chosenTakeNumber,
              let take = takes.first(where: { $0.id == chosen }) else {
            await presenter.presentSecretTip(response: .init(tip: nil))
            return
        }
        let tip = await worker.makeSecretTip(
            takeURL: take.url,
            word: word,
            targetSound: targetSound,
            age: childAge
        )
        await presenter.presentSecretTip(response: .init(tip: tip))
    }

    // MARK: - resetTakes (перезапись)

    func resetTakes() {
        worker.stopPlayback()
        recordingTask?.cancel()
        recordingTask = nil
        takes.removeAll()
        chosenTakeNumber = nil
        judgement = nil
        phase = .intro
        presenter.presentReset()
    }

    // MARK: - cancel

    func cancel() {
        recordingTask?.cancel()
        recordingTask = nil
        worker.stopPlayback()
    }

    // MARK: - Mascot copy

    /// Тёплое сообщение Ляли — хвалит за сам факт рефлексии, не за «балл».
    private static func mascotMessage(for j: ListenYourselfModels.SelfJudgement) -> String {
        switch j {
        case .almost: return String(localized: "listenYourself.mascot.almost")
        case .close:  return String(localized: "listenYourself.mascot.close")
        case .like:   return String(localized: "listenYourself.mascot.like")
        }
    }
}
