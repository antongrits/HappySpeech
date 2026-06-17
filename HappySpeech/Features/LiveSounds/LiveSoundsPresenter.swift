import Foundation
import OSLog

// MARK: - LiveSoundsPresentationLogic

@MainActor
protocol LiveSoundsPresentationLogic: AnyObject {
    func presentStart(_ response: LiveSoundsModels.Start.Response)
    func presentLoadRound(_ response: LiveSoundsModels.LoadRound.Response)
    func presentPlaying(_ isPlaying: Bool)
    /// Подсветка звука, который Ляля произносит «сейчас» (nil — пауза).
    func presentNowSound(_ index: Int?)
    func presentPace(_ pace: LiveSoundsPace)
    func presentChoosePicture(_ response: LiveSoundsModels.ChoosePicture.Response)
    func presentPlaceCharacter(
        _ response: LiveSoundsModels.PlaceCharacter.Response,
        placedLetters: [String],
        usedBenchIndices: Set<Int>
    )
    func presentComplete(_ response: LiveSoundsModels.Complete.Response)
}

// MARK: - LiveSoundsPresenter
//
// Конвертирует Response → ViewModel. Бизнес-логика (каталог раундов, проверка
// ответов, синтез, счёт) — в Interactor. Здесь — форматирование и локализация.

@MainActor
final class LiveSoundsPresenter: LiveSoundsPresentationLogic {

    weak var display: (any LiveSoundsDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "LiveSoundsPresenter")

    // MARK: - Start

    func presentStart(_ response: LiveSoundsModels.Start.Response) {
        let firstVM = response.rounds.first.map(Self.makeRoundVM)
        let vm = LiveSoundsModels.Start.ViewModel(
            firstRound: firstVM,
            totalRounds: response.rounds.count
        )
        logger.info("presentStart rounds=\(response.rounds.count, privacy: .public)")
        display?.displayStart(vm)
    }

    // MARK: - LoadRound

    func presentLoadRound(_ response: LiveSoundsModels.LoadRound.Response) {
        display?.displayLoadRound(response)
    }

    // MARK: - Playing / NowSound / Pace

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    func presentNowSound(_ index: Int?) {
        display?.displayNowSound(index)
    }

    func presentPace(_ pace: LiveSoundsPace) {
        display?.displayPace(pace)
    }

    // MARK: - ChoosePicture

    func presentChoosePicture(_ response: LiveSoundsModels.ChoosePicture.Response) {
        let feedback: String
        if response.isCorrect {
            feedback = String(
                format: String(localized: "liveSounds.feedback.correct %@",
                               defaultValue: "Точно — %@! Ты слепил звуки в слово."),
                response.word.uppercased()
            )
        } else {
            feedback = String(localized: "liveSounds.feedback.retry",
                              defaultValue: "Послушай ещё разок — слей звуки вместе и выбери картинку.")
        }
        let vm = LiveSoundsModels.ChoosePicture.ViewModel(
            selectedIndex: response.optionIndex,
            correctIndex: response.isCorrect ? response.correctIndex : nil,
            isCorrect: response.isCorrect,
            feedbackText: feedback,
            solved: response.isCorrect
        )
        logger.info("presentChoosePicture correct=\(response.isCorrect, privacy: .public)")
        display?.displayChoosePicture(vm)
    }

    // MARK: - PlaceCharacter

    func presentPlaceCharacter(
        _ response: LiveSoundsModels.PlaceCharacter.Response,
        placedLetters: [String],
        usedBenchIndices: Set<Int>
    ) {
        let activeSlot: Int? = response.rowComplete
            ? nil
            : (response.isCorrect ? response.slotIndex + 1 : response.slotIndex)

        let feedback: String
        if response.isCorrect {
            feedback = response.rowComplete
                ? String(localized: "liveSounds.bench.rowDone", defaultValue: "Все человечки на месте — ряд собран!")
                : ""
        } else {
            feedback = String(localized: "liveSounds.bench.retry",
                              defaultValue: "Послушай слово до конца — кто стоит здесь? Попробуй другого человечка.")
        }

        let vm = LiveSoundsModels.PlaceCharacter.ViewModel(
            placedLetters: placedLetters,
            usedBenchIndices: usedBenchIndices,
            activeSlotIndex: activeSlot,
            feedbackCorrect: response.isCorrect,
            feedbackText: feedback,
            rowComplete: response.rowComplete
        )
        logger.info("presentPlaceCharacter correct=\(response.isCorrect, privacy: .public) done=\(response.rowComplete, privacy: .public)")
        display?.displayPlaceCharacter(vm)
    }

    // MARK: - Complete

    func presentComplete(_ response: LiveSoundsModels.Complete.Response) {
        let stars = LiveSoundsScoring.stars(for: response.score)
        let pct = Int((response.score * 100).rounded())
        let scoreLabel = String(
            format: String(localized: "liveSounds.score %lld", defaultValue: "Результат: %lld%%"),
            pct
        )
        let message: String
        switch stars {
        case 3: message = String(localized: "liveSounds.done.3",
                                 defaultValue: "Ты настоящий мастер синтеза! Слепил все слова из звуков.")
        case 2: message = String(localized: "liveSounds.done.2",
                                 defaultValue: "Отлично сливаешь звуки в слова!")
        case 1: message = String(localized: "liveSounds.done.1",
                                 defaultValue: "Хорошо! В следующий раз получится ещё лучше.")
        default: message = String(localized: "liveSounds.done.0",
                                  defaultValue: "Давай послушаем звуки и попробуем ещё раз?")
        }
        logger.info("presentComplete stars=\(stars, privacy: .public) score=\(response.score, privacy: .public)")
        let vm = LiveSoundsModels.Complete.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            completionMessage: message,
            finalScore: response.score
        )
        display?.displayComplete(vm)
    }

    // MARK: - Helpers

    private static func makeRoundVM(_ round: LiveSoundsRound) -> LiveSoundsModels.RoundViewModel {
        LiveSoundsModels.RoundViewModel(
            word: round.word.uppercased(),
            imageAsset: round.imageAsset,
            sounds: round.sounds,
            options: round.options,
            benchLetters: round.benchLetters,
            mode: round.mode
        )
    }
}
