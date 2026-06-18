import Foundation
import OSLog

// MARK: - SoundCompositionPresentationLogic

@MainActor
protocol SoundCompositionPresentationLogic: AnyObject {
    func presentStart(_ response: SoundCompositionModels.Start.Response)
    func presentLoadWord(_ response: SoundCompositionModels.LoadWord.Response)
    func presentPlaying(_ isPlaying: Bool)
    func presentPlaceChip(_ response: SoundCompositionModels.PlaceChip.Response, allSounds: [SoundUnit])
    func presentSynthesis(_ response: SoundCompositionModels.Synthesis.Response)
    func presentBonus(_ response: SoundCompositionModels.Bonus.Response)
    func presentComplete(_ response: SoundCompositionModels.Complete.Response)
}

// MARK: - SoundCompositionPresenter
//
// Конвертирует Response → ViewModel. Бизнес-логика (каталог слов, проверка
// фишек, синтез, счёт) — в Interactor. Здесь — форматирование и локализация.

@MainActor
final class SoundCompositionPresenter: SoundCompositionPresentationLogic {

    weak var display: (any SoundCompositionDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundCompositionPresenter")

    // MARK: - Start

    func presentStart(_ response: SoundCompositionModels.Start.Response) {
        let firstVM = response.words.first.map { word in
            SoundCompositionModels.WordViewModel(
                text: word.text.uppercased(),
                imageAsset: word.imageAsset,
                soundCount: word.soundCount,
                stretchedHint: SoundCompositionDisplay.stretchedHint(for: word)
            )
        }
        let vm = SoundCompositionModels.Start.ViewModel(
            firstWord: firstVM,
            totalWords: response.words.count
        )
        logger.info("presentStart words=\(response.words.count, privacy: .public)")
        display?.displayStart(vm)
    }

    // MARK: - LoadWord

    func presentLoadWord(_ response: SoundCompositionModels.LoadWord.Response) {
        display?.displayLoadWord(response)
    }

    // MARK: - Playing

    func presentPlaying(_ isPlaying: Bool) {
        display?.displayPlaying(isPlaying)
    }

    // MARK: - PlaceChip

    func presentPlaceChip(_ response: SoundCompositionModels.PlaceChip.Response, allSounds: [SoundUnit]) {
        // Собираем фишки: все звуки до текущего «активного» включительно, если
        // попадание было верным.
        let placedUpTo = response.isCorrect ? response.soundIndex : response.soundIndex - 1
        let placed: [PlacedChip] = allSounds.enumerated()
            .prefix(placedUpTo + 1)
            .map { _, s in PlacedChip(letter: s.letter, type: s.type) }

        let nextIndex: Int? = response.isWordComplete
            ? nil
            : (response.isCorrect ? response.soundIndex + 1 : response.soundIndex)

        let nextSound: SoundUnit? = nextIndex.flatMap { allSounds.indices.contains($0) ? allSounds[$0] : nil }

        let feedback: String
        if response.isCorrect {
            feedback = response.isWordComplete
                ? String(localized: "soundComposition.feedback.wordDone", defaultValue: "Все звуки на местах!")
                : ""
        } else {
            // Мягкая подсказка вместо «неправильно».
            feedback = Self.softHint(for: response.correctType, letter: response.letter)
        }

        let vm = SoundCompositionModels.PlaceChip.ViewModel(
            placedChips: placed,
            activeSoundIndex: nextIndex,
            activeSoundLetter: nextSound?.letter ?? response.letter,
            activeSoundType: nextSound?.type ?? response.correctType,
            feedbackCorrect: response.isCorrect,
            feedbackText: feedback,
            isWordComplete: response.isWordComplete
        )
        let placeInfo = "correct=\(response.isCorrect) done=\(response.isWordComplete)"
        logger.info(
            "presentPlaceChip idx=\(response.soundIndex, privacy: .public) \(placeInfo, privacy: .public)"
        )
        display?.displayPlaceChip(vm)
    }

    /// Мягкая подсказка по признаку звука — БЕЗ слова «неправильно».
    private static func softHint(for type: SoundType, letter: String) -> String {
        let upper = letter.uppercased()
        switch type {
        case .vowel:
            return String(
                format: String(localized: "soundComposition.hint.vowel %@",
                               defaultValue: "Послушай: «%@» можно петь и тянуть — это гласный."),
                upper
            )
        case .hard:
            return String(
                format: String(localized: "soundComposition.hint.hard %@",
                               defaultValue: "Послушай: «%@» — звук-силач, он твёрдый. Попробуй ещё разок!"),
                upper
            )
        case .soft:
            return String(
                format: String(localized: "soundComposition.hint.soft %@",
                               defaultValue: "Послушай: «%@» — звук-братик, он мягкий. Попробуй ещё разок!"),
                upper
            )
        }
    }

    // MARK: - Synthesis

    func presentSynthesis(_ response: SoundCompositionModels.Synthesis.Response) {
        let word = response.word
        let title = String(
            format: String(localized: "soundComposition.synth.title %@",
                           defaultValue: "Получилось — %@!"),
            word.text.uppercased()
        )
        let summary = Self.summaryLine(for: word)

        var bonusVM: SoundCompositionModels.BonusViewModel?
        if let chain = word.chain, !chain.variants.isEmpty {
            // Целевой вариант — первый (Ляля просит именно его, остальные —
            // отвлекающие, но тоже реальные слова цепочки).
            let target = chain.variants[0]
            let variants = chain.variants.enumerated().map { idx, v in
                SoundCompositionModels.BonusViewModel.BonusVariant(
                    id: idx,
                    text: v.text.uppercased(),
                    asset: v.asset,
                    firstLetter: v.swapTo
                )
            }
            let baseFirst = word.sounds.first?.letter ?? ""
            bonusVM = SoundCompositionModels.BonusViewModel(
                prompt: String(
                    format: String(localized: "soundComposition.bonus.prompt %@ %@",
                                   defaultValue: "Замени «%@» на «%@» — какое слово вышло?"),
                    baseFirst, target.swapTo
                ),
                baseText: chain.baseText.uppercased(),
                baseAsset: chain.baseAsset,
                firstLetter: baseFirst,
                variants: variants,
                targetIndex: 0
            )
        }

        let vm = SoundCompositionModels.Synthesis.ViewModel(
            title: title,
            summaryLine: summary,
            chips: response.chips,
            imageAsset: word.imageAsset,
            bonus: bonusVM
        )
        logger.info("presentSynthesis word=\(word.id, privacy: .public) bonus=\(bonusVM != nil, privacy: .public)")
        display?.displaySynthesis(vm)
    }

    /// «5 звуков · 2 слога · ударение на «И»».
    private static func summaryLine(for word: SoundCompositionWord) -> String {
        let soundsPart = "\(word.soundCount) \(pluralRu(word.soundCount, "звук", "звука", "звуков"))"
        let syllableCount = max(word.syllables.count, 1)
        let syllablesPart = "\(syllableCount) \(pluralRu(syllableCount, "слог", "слога", "слогов"))"
        let stressed = word.sounds.indices.contains(word.stressIndex - 1)
            ? word.sounds[word.stressIndex - 1].letter
            : ""
        let stressPart = String(
            format: String(localized: "soundComposition.summary.stress %@",
                           defaultValue: "ударение на «%@»"),
            stressed
        )
        return [soundsPart, syllablesPart, stressPart].joined(separator: " · ")
    }

    /// Русские формы множественного числа: 1 звук, 2 звука, 5 звуков.
    private static func pluralRu(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let mod100 = n % 100
        if (11...14).contains(mod100) { return many }
        switch n % 10 {
        case 1:      return one
        case 2, 3, 4: return few
        default:     return many
        }
    }

    // MARK: - Bonus

    func presentBonus(_ response: SoundCompositionModels.Bonus.Response) {
        let feedback: String
        if response.isCorrect {
            feedback = String(
                format: String(localized: "soundComposition.bonus.correct %@",
                               defaultValue: "Один звук поменяли — вышло «%@»!"),
                response.resultWord.uppercased()
            )
        } else {
            feedback = String(localized: "soundComposition.bonus.retry",
                              defaultValue: "Послушай ещё разок и попробуй другой звук.")
        }
        let vm = SoundCompositionModels.Bonus.ViewModel(
            selectedIndex: response.isCorrect ? response.variantIndex : nil,
            feedbackText: feedback
        )
        display?.displayBonus(vm)
    }

    // MARK: - Complete

    func presentComplete(_ response: SoundCompositionModels.Complete.Response) {
        let stars = SoundCompositionScoring.stars(for: response.score)
        let pct = Int((response.score * 100).rounded())
        let scoreLabel = String(
            format: String(localized: "soundComposition.score %lld", defaultValue: "Результат: %lld%%"),
            pct
        )
        let message: String
        switch stars {
        case 3: message = String(localized: "soundComposition.done.3",
                                 defaultValue: "Ты настоящий мастер звуков! Разобрал все слова.")
        case 2: message = String(localized: "soundComposition.done.2",
                                 defaultValue: "Отличная работа со звуками!")
        case 1: message = String(localized: "soundComposition.done.1",
                                 defaultValue: "Хорошо! В следующий раз получится ещё лучше.")
        default: message = String(localized: "soundComposition.done.0",
                                  defaultValue: "Давай разберём звуки ещё раз?")
        }
        logger.info("presentComplete stars=\(stars, privacy: .public) score=\(response.score, privacy: .public)")
        let vm = SoundCompositionModels.Complete.ViewModel(
            starsEarned: stars,
            scoreLabel: scoreLabel,
            completionMessage: message,
            finalScore: response.score
        )
        display?.displayComplete(vm)
    }
}
