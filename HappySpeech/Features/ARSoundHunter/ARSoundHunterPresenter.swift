import Foundation

// MARK: - ARSoundHunterPresentationLogic

@MainActor
protocol ARSoundHunterPresentationLogic: AnyObject {
    func presentStartGame(_ response: ARSoundHunterModels.StartGame.Response)
    func presentFrameClassified(_ response: ARSoundHunterModels.FrameClassified.Response)
    func presentSelectCard(_ response: ARSoundHunterModels.SelectCard.Response)
    func presentScoreNaming(_ response: ARSoundHunterModels.ScoreNaming.Response)
    func presentNextRound(_ response: ARSoundHunterModels.NextRound.Response)
    /// Мягкий повтор без звёзд (молчание / шум).
    func presentRetry(foundWord: String)
}

// MARK: - ARSoundHunterDisplayLogic

@MainActor
protocol ARSoundHunterDisplayLogic: AnyObject {
    func displayStartGame(_ viewModel: ARSoundHunterModels.StartGame.ViewModel)
    func displayFrameClassified(_ viewModel: ARSoundHunterModels.FrameClassified.ViewModel)
    func displaySelectCard(_ viewModel: ARSoundHunterModels.SelectCard.ViewModel)
    func displayScoreNaming(_ viewModel: ARSoundHunterModels.ScoreNaming.ViewModel)
    func displayNextRound(_ viewModel: ARSoundHunterModels.NextRound.ViewModel)
    func displayRetry(foundWord: String)
}

// MARK: - ARSoundHunterPresenter

@MainActor
final class ARSoundHunterPresenter: ARSoundHunterPresentationLogic {

    weak var display: (any ARSoundHunterDisplayLogic)?

    /// Резолв слова в имя имейджсета (`word_*`) через `LessonContentMap` —
    /// тот же путь, что используют рабочие экраны уроков (Listen-and-Choose и др.).
    ///
    /// Источник правды — полный `word_manifest.json`, поэтому слова без тега
    /// группы звуков (арбуз, вертолёт) и слова из «несвистящих» групп (барабан=Б,
    /// ведро=В) тоже резолвятся — в отличие от прежнего пути через
    /// `KidWordContentProvider`, который перебирал лишь канонические группы
    /// и оставлял такие карточки пустыми. Если ассета реально нет — `nil`, и
    /// View рендерит graceful SF Symbol-плейсхолдер.
    private static func assetName(for word: String) -> String? {
        LessonContentMap.asset(for: word)
    }

    func presentStartGame(_ response: ARSoundHunterModels.StartGame.Response) {
        let prompt = String(
            format: String(localized: "arSoundHunter.prompt.findAndName"),
            response.targetSound
        )
        let cards: [ARSoundHunterModels.Card]
        switch response.mode {
        case .photoCards:
            // Сетка = целевые (со звуком) + дистракторы (без звука). Признак
            // `isTarget` НЕ отражается в визуале карточки (иначе задание
            // тривиально) — он нужен Interactor'у при выборе.
            cards = response.gridCards.map { card in
                ARSoundHunterModels.Card(
                    id: card.match.word,
                    word: card.match.word.capitalizedFirstLetter,
                    assetName: Self.assetName(for: card.match.word),
                    isTarget: card.isTarget
                )
            }
        case .camera:
            cards = []
        }
        display?.displayStartGame(.init(
            targetSound: response.targetSound,
            prompt: prompt,
            mode: response.mode,
            cards: cards,
            mascotState: .pointing
        ))
    }

    func presentFrameClassified(_ response: ARSoundHunterModels.FrameClassified.Response) {
        display?.displayFrameClassified(.init(
            foundWord: response.foundObject?.word.capitalizedFirstLetter,
            lockProgress: min(max(response.lockProgress, 0), 1),
            shouldPrompt: response.foundObject != nil
        ))
    }

    func presentSelectCard(_ response: ARSoundHunterModels.SelectCard.Response) {
        let word = response.word.capitalizedFirstLetter
        guard response.isTarget else {
            // Дистрактор: мягкий фидбэк «В этом слове нет звука Х», подсветка
            // карточки. Без звезды и без штрафа — положительное подкрепление.
            let feedback = String(
                format: String(localized: "arSoundHunter.feedback.noSound"),
                response.targetSound
            )
            display?.displaySelectCard(.init(
                word: nil,
                prompt: nil,
                distractorFeedback: feedback,
                distractorCardId: response.word
            ))
            return
        }
        let prompt = String(
            format: String(localized: "arSoundHunter.prompt.nameIt"),
            word
        )
        display?.displaySelectCard(.init(
            word: word,
            prompt: prompt,
            distractorFeedback: nil,
            distractorCardId: nil
        ))
    }

    func presentScoreNaming(_ response: ARSoundHunterModels.ScoreNaming.Response) {
        let feedback: String
        switch response.stars {
        case 3:  feedback = String(localized: "arSoundHunter.feedback.excellent")
        case 2:  feedback = String(localized: "arSoundHunter.feedback.good")
        default: feedback = String(localized: "arSoundHunter.feedback.tryAgain")
        }
        display?.displayScoreNaming(.init(
            stars: response.stars,
            feedback: feedback,
            foundWord: response.foundWord.capitalizedFirstLetter,
            isSuccess: response.stars >= 2
        ))
    }

    func presentNextRound(_ response: ARSoundHunterModels.NextRound.Response) {
        let text = String(
            format: String(localized: "arSoundHunter.totalFound"),
            response.totalFound
        )
        display?.displayNextRound(.init(totalFoundText: text))
    }

    func presentRetry(foundWord: String) {
        display?.displayRetry(foundWord: foundWord.capitalizedFirstLetter)
    }
}
