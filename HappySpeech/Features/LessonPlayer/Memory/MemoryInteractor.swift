import Foundation
import OSLog

// MARK: - MemoryBusinessLogic

@MainActor
protocol MemoryBusinessLogic: AnyObject {
    func loadSession(_ request: MemoryModels.LoadSession.Request) async
    func flipCard(_ request: MemoryModels.FlipCard.Request) async
    func cancel()
}

// MARK: - MemoryInteractor
//
// «Найди пару» 4×4. Держит:
//   • колоду из 16 карточек;
//   • две «открытых» карты пока проверяем пару;
//   • счётчик найденных пар;
//   • таймер-обратный отсчёт (60 с).
//
// Поведение:
//   flipCard → если карта не matched и не faceUp — переворачиваем.
//     Если теперь 2 открытых:
//       • pairId равны      → mark matched, обе остаются, match counter ++.
//       • pairId не равны   → isFlipDisabled = true, ждём 1 с через Task.sleep,
//                              потом закрываем обе.
//     После match проверяем «все пары найдены» → completeSession(.allMatched).
//
//   Таймер: отдельный Task, каждую секунду считает elapsed. При elapsed >= limit
//   → completeSession(.timeExpired).
//
//   cancel(): снимает таймер (при onDisappear View).

@MainActor
final class MemoryInteractor: MemoryBusinessLogic {

    // MARK: Dependencies

    var presenter: (any MemoryPresentationLogic)?
    private let hapticService: any HapticService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "Memory")

    // MARK: Config

    private let timeLimit: Int = 60

    // MARK: State

    private var cards: [MemoryCard] = []
    private var openIndices: [Int] = []          // индексы в `cards`, открытых сейчас
    private var matchedPairs: Int = 0
    private var totalPairs: Int = 8
    private var isFlipDisabled: Bool = false
    private var isGameOver: Bool = false
    private var elapsed: Int = 0
    private var timerTask: Task<Void, Never>?

    // MARK: Init

    init(hapticService: any HapticService) {
        self.hapticService = hapticService
    }

    deinit {
        timerTask?.cancel()
    }

    // MARK: - loadSession

    func loadSession(_ request: MemoryModels.LoadSession.Request) async {
        self.cards = MemoryCard.deck(for: request.soundGroup)
        self.totalPairs = cards.count / 2
        self.matchedPairs = 0
        self.openIndices = []
        self.isFlipDisabled = false
        self.isGameOver = false
        self.elapsed = 0
        logger.info("Memory loaded cards=\(self.cards.count, privacy: .public) pairs=\(self.totalPairs, privacy: .public) limit=\(self.timeLimit, privacy: .public)s")

        let response = MemoryModels.LoadSession.Response(
            cards: cards,
            childName: request.childName,
            timeLimit: timeLimit
        )
        presenter?.presentLoadSession(response)

        // Немедленный tick-снимок, чтобы метка таймера отрисовалась.
        presenter?.presentTimerTick(MemoryModels.TimerTick.Response(
            remaining: timeLimit,
            expired: false
        ))

        startTimer()
    }

    // MARK: - flipCard

    func flipCard(_ request: MemoryModels.FlipCard.Request) async {
        guard !isGameOver, !isFlipDisabled else { return }
        guard let idx = cards.firstIndex(where: { $0.id == request.cardId }) else {
            logger.error("flipCard: unknown cardId \(request.cardId, privacy: .public)")
            return
        }
        // Нельзя переворачивать уже matched или уже открытую.
        guard !cards[idx].isMatched, !cards[idx].isFaceUp else { return }

        cards[idx].isFaceUp = true
        openIndices.append(idx)
        hapticService.selection()

        // Одна открытая карта — просто обновляем UI.
        if openIndices.count == 1 {
            presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
                cards: cards,
                matchFound: false,
                matchedPairId: nil,
                gameOver: false
            ))
            return
        }

        // Две открытых — проверяем пару.
        let firstIdx = openIndices[0]
        let secondIdx = openIndices[1]
        let firstCard = cards[firstIdx]
        let secondCard = cards[secondIdx]

        if firstCard.pairId == secondCard.pairId {
            cards[firstIdx].isMatched = true
            cards[secondIdx].isMatched = true
            matchedPairs += 1
            hapticService.notification(.success)
            let allMatched = (matchedPairs >= totalPairs)
            logger.info("Match pair=\(firstCard.pairId, privacy: .public) matched=\(self.matchedPairs, privacy: .public)/\(self.totalPairs, privacy: .public)")

            presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
                cards: cards,
                matchFound: true,
                matchedPairId: firstCard.pairId,
                gameOver: allMatched
            ))
            openIndices.removeAll()

            if allMatched {
                await completeSession(
                    matchedPairs: matchedPairs,
                    elapsedSeconds: elapsed,
                    reason: .allMatched
                )
            }
            return
        }

        // Пара не совпала — коротко подсвечиваем и закрываем через 1с.
        hapticService.notification(.warning)
        isFlipDisabled = true
        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: false
        ))

        try? await Task.sleep(for: .seconds(1))
        guard !isGameOver else { return }
        // Закрываем обе карты (если они всё ещё face-up и не matched).
        for openIdx in [firstIdx, secondIdx] where !cards[openIdx].isMatched {
            cards[openIdx].isFaceUp = false
        }
        openIndices.removeAll()
        isFlipDisabled = false
        presenter?.presentFlipCard(MemoryModels.FlipCard.Response(
            cards: cards,
            matchFound: false,
            matchedPairId: nil,
            gameOver: false
        ))
    }

    // MARK: - cancel

    func cancel() {
        isGameOver = true
        timerTask?.cancel()
        timerTask = nil
        logger.info("Memory cancelled")
    }

    // MARK: - Private: timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard !self.isGameOver else { return }
                self.elapsed += 1
                let remaining = max(0, self.timeLimit - self.elapsed)
                let expired = (remaining == 0)
                self.presenter?.presentTimerTick(MemoryModels.TimerTick.Response(
                    remaining: remaining,
                    expired: expired
                ))
                if expired {
                    self.isGameOver = true
                    await self.completeSession(
                        matchedPairs: self.matchedPairs,
                        elapsedSeconds: self.elapsed,
                        reason: .timeExpired
                    )
                    return
                }
            }
        }
    }

    // MARK: - Private: completeSession

    private func completeSession(
        matchedPairs: Int,
        elapsedSeconds: Int,
        reason: MemoryGameOverReason
    ) async {
        timerTask?.cancel()
        timerTask = nil
        logger.info("Memory complete matched=\(matchedPairs, privacy: .public)/\(self.totalPairs, privacy: .public) elapsed=\(elapsedSeconds, privacy: .public)s reason=\(String(describing: reason), privacy: .public)")

        let response = MemoryModels.CompleteSession.Request(
            matchedPairs: matchedPairs,
            elapsedSeconds: elapsedSeconds,
            reason: reason
        )
        // Request фактически является parameters-носителем; пересылаем в Presenter.
        presenter?.presentCompleteSession(response)
    }
}
