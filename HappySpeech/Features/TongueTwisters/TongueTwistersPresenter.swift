import Foundation
import OSLog

// MARK: - TongueTwistersPresentationLogic

@MainActor
protocol TongueTwistersPresentationLogic: AnyObject {
    func presentStart(_ response: TongueTwistersModels.Start.Response)
    func presentLoadPhrase(_ response: TongueTwistersModels.LoadPhrase.Response)
    func presentPlaying(_ isPlaying: Bool)
    func presentRecording(_ isRecording: Bool)
    func presentBeat(_ beat: Int)
    func presentMetronome(on: Bool, bpm: Int)
    func presentChooseRhyme(_ response: TongueTwistersModels.ChooseRhyme.Response)
    func presentCheckRecording(_ response: TongueTwistersModels.CheckRecording.Response)
    func presentEnterTrain(states: [WagonState], currentIndex: Int?)
    func presentSpeakWagon(_ response: TongueTwistersModels.SpeakWagon.Response, total: Int)
    func presentComplete(_ response: TongueTwistersModels.Complete.Response)
}

// MARK: - TongueTwistersPresenter
//
// Конвертирует Response → ViewModel. Бизнес-логика (каталог, проверка рифмы,
// ASR-проверка, наращивание, счёт) — в Interactor. Здесь — форматирование и
// локализация (errorless-формулировки: поддержка, без слова «неправильно»).

@MainActor
final class TongueTwistersPresenter: TongueTwistersPresentationLogic {

    weak var display: (any TongueTwistersDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "TongueTwistersPresenter")

    // MARK: - Start

    func presentStart(_ response: TongueTwistersModels.Start.Response) {
        let firstVM = response.phrases.first.map {
            TongueTwistersModels.PhraseViewModel(
                targetSound: $0.targetSound,
                warmupSyllable: $0.warmupSyllable,
                warmupBeats: $0.warmupBeats
            )
        }
        display?.displayStart(.init(totalPhrases: response.phrases.count, first: firstVM))
        logger.info("presentStart phrases=\(response.phrases.count, privacy: .public)")
    }

    // MARK: - LoadPhrase

    func presentLoadPhrase(_ response: TongueTwistersModels.LoadPhrase.Response) {
        display?.displayLoadPhrase(response)
    }

    // MARK: - Playing / Recording / Beat

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    func presentRecording(_ isRecording: Bool) {
        display?.displayRecording(isRecording)
    }

    func presentBeat(_ beat: Int) {
        display?.displayBeat(beat)
    }

    func presentMetronome(on: Bool, bpm: Int) {
        display?.displayMetronome(on: on, bpm: bpm)
    }

    // MARK: - ChooseRhyme

    func presentChooseRhyme(_ response: TongueTwistersModels.ChooseRhyme.Response) {
        let vm: TongueTwistersModels.ChooseRhyme.ViewModel
        if response.isCorrect {
            vm = .init(
                isCorrect: true,
                selectedAnswerId: nil,
                filledWord: response.correctWord,
                feedbackText: String(
                    format: String(localized: "tongueTwisters.rhyme.correct %@",
                                   defaultValue: "Точно — «%@»! Звучит в рифму."),
                    response.correctWord
                ),
                advanceToSay: true
            )
            display?.displayChooseRhyme(vm)
            display?.displayEnterSay()
        } else {
            // Errorless: мягкая подсказка, без «неправильно».
            vm = .init(
                isCorrect: false,
                selectedAnswerId: nil,
                filledWord: nil,
                feedbackText: String(localized: "tongueTwisters.rhyme.retry",
                                     defaultValue: "Послушай конец строчки ещё разок — какое слово звучит в рифму?"),
                advanceToSay: false
            )
            display?.displayChooseRhyme(vm)
        }
        logger.info("presentChooseRhyme correct=\(response.isCorrect, privacy: .public)")
    }

    // MARK: - CheckRecording (мягкий статус-пилл)

    func presentCheckRecording(_ response: TongueTwistersModels.CheckRecording.Response) {
        let sound = response.targetSound.uppercased()
        let vm: TongueTwistersModels.CheckRecording.ViewModel
        if response.inconclusive {
            // ASR молчит/недоступен — пилл скрываем (первично — старание ребёнка).
            vm = .init(statusText: "", soundHeard: false, showStatus: false)
        } else if response.soundHeard {
            vm = .init(
                statusText: String(
                    format: String(localized: "tongueTwisters.status.heard %@",
                                   defaultValue: "Слышу звук %@ — отлично!"),
                    sound
                ),
                soundHeard: true,
                showStatus: true
            )
        } else {
            // Поддержка, не штраф: предлагаем сказать ещё разок погромче.
            vm = .init(
                statusText: String(
                    format: String(localized: "tongueTwisters.status.again %@",
                                   defaultValue: "Скажи ещё разок, выдели звук %@ погромче."),
                    sound
                ),
                soundHeard: false,
                showStatus: true
            )
        }
        display?.displayCheckRecording(vm)
        logger.info("presentCheckRecording heard=\(response.soundHeard, privacy: .public) incon=\(response.inconclusive, privacy: .public)")
    }

    // MARK: - Train

    func presentEnterTrain(states: [WagonState], currentIndex: Int?) {
        display?.displayEnterTrain(states: states, currentIndex: currentIndex)
    }

    func presentSpeakWagon(_ response: TongueTwistersModels.SpeakWagon.Response, total: Int) {
        let vm = TongueTwistersModels.SpeakWagon.ViewModel(
            wagonStates: states(from: response, total: total),
            currentIndex: response.nextIndex,
            allDone: response.allDone
        )
        display?.displaySpeakWagon(vm)
    }

    private func states(from response: TongueTwistersModels.SpeakWagon.Response, total: Int) -> [WagonState] {
        var states = Array(repeating: WagonState.locked, count: total)
        for i in 0...response.completedIndex where i < total { states[i] = .done }
        if let next = response.nextIndex, next < total { states[next] = .now }
        return states
    }

    // MARK: - Complete

    func presentComplete(_ response: TongueTwistersModels.Complete.Response) {
        let stars = TongueTwistersScoring.stars(for: response.cleanFraction)
        let pct = Int((response.cleanFraction * 100).rounded())
        let scoreLabel = String(
            format: String(localized: "tongueTwisters.score %lld", defaultValue: "Результат: %lld%%"),
            pct
        )
        let message: String
        switch stars {
        case 3: message = String(localized: "tongueTwisters.done.3",
                                 defaultValue: "Чистоговорки звучат чисто — ты молодец!")
        case 2: message = String(localized: "tongueTwisters.done.2",
                                 defaultValue: "Отлично проговорил чистоговорки!")
        case 1: message = String(localized: "tongueTwisters.done.1",
                                 defaultValue: "Хорошо! В следующий раз получится ещё чище.")
        default: message = String(localized: "tongueTwisters.done.0",
                                  defaultValue: "Давай повторим чистоговорки ещё разок?")
        }
        display?.displayComplete(.init(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            completionMessage: message,
            finalScore: response.cleanFraction
        ))
        logger.info("presentComplete stars=\(stars, privacy: .public) score=\(response.cleanFraction, privacy: .public)")
    }
}
