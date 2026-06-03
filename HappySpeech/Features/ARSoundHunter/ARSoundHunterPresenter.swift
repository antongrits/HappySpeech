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

    /// Маппинг звук → имена имейджсетов берётся через `KidWordContentProvider`
    /// (общий источник правды по контенту). Если для слова нет ассета — карточка
    /// рендерит SF Symbol-плейсхолдер.
    private static func assetName(for word: String) -> String? {
        let normalized = word.lowercased()
        return KidWordContentProvider.allFamilies
            .lazy
            .flatMap { KidWordContentProvider.words(soundFamily: $0) }
            .first { $0.text.lowercased() == normalized }?
            .asset
    }

    func presentStartGame(_ response: ARSoundHunterModels.StartGame.Response) {
        let prompt = String(
            format: String(localized: "arSoundHunter.prompt.findAndName"),
            response.targetSound
        )
        let cards: [ARSoundHunterModels.Card]
        switch response.mode {
        case .photoCards:
            cards = response.huntableWords
                .prefix(6)
                .map { match in
                    ARSoundHunterModels.Card(
                        id: match.word,
                        word: match.word.capitalizedFirstLetter,
                        assetName: Self.assetName(for: match.word)
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
        let prompt = String(
            format: String(localized: "arSoundHunter.prompt.nameIt"),
            response.word
        )
        display?.displaySelectCard(.init(
            word: response.word.capitalizedFirstLetter,
            prompt: prompt
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
