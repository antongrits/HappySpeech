import Foundation

// MARK: - ListenAndChoosePresentationLogic

@MainActor
protocol ListenAndChoosePresentationLogic: AnyObject {
    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response)
    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response)
}

// MARK: - ListenAndChoosePresenter

@MainActor
final class ListenAndChoosePresenter: ListenAndChoosePresentationLogic {

    weak var display: (any ListenAndChooseDisplayLogic)?

    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response) {
        let options = response.options.map { item in
            ListenAndChooseModels.LoadRound.OptionViewModel(
                id: item.id,
                word: item.word,
                imageSystemName: Self.imageSymbol(for: item.word)
            )
        }
        let instruction: String = response.isRetry
            ? String(localized: "Давай попробуем ещё раз!")
            : String(localized: "Слушай внимательно и выбери картинку")

        let progressText: String?
        if response.totalQuestions > 1 {
            progressText = String(
                localized: "Вопрос \(response.questionNumber) из \(response.totalQuestions)"
            )
        } else {
            progressText = nil
        }

        // Q3.6 — локализованный заголовок бейджа сложности.
        let difficultyTitle = String(
            localized: String.LocalizationValue(response.difficulty.titleKey)
        )

        let vm = ListenAndChooseModels.LoadRound.ViewModel(
            targetWord: response.targetWord,
            options: options,
            correctIndex: response.correctIndex,
            instructionText: instruction,
            hintText: response.hint,
            progressText: progressText,
            isRetry: response.isRetry,
            difficulty: response.difficulty,
            difficultyTitle: difficultyTitle
        )
        display?.displayLoadRound(vm)
    }

    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response) {
        let feedback: String = {
            if response.isCorrect {
                if response.currentStreak >= 3 {
                    return String(localized: "Отлично! \(response.currentStreak) подряд!")
                }
                return String(localized: "Правильно!")
            }
            if response.shouldRevealAnswer {
                return String(localized: "Вот правильный ответ")
            }
            return String(localized: "Попробуй ещё раз")
        }()

        let streakText: String? = response.isCorrect && response.currentStreak >= 3
            ? String(localized: "Серия: \(response.currentStreak)")
            : nil

        let vm = ListenAndChooseModels.SubmitAttempt.ViewModel(
            isCorrect: response.isCorrect,
            feedbackText: feedback,
            shouldRevealAnswer: response.shouldRevealAnswer,
            correctIndex: response.correctIndex,
            finalScore: (response.isCorrect || response.shouldRevealAnswer) ? response.score : nil,
            streakText: streakText,
            hintText: response.hint
        )
        display?.displaySubmitAttempt(vm)
    }

    // MARK: Private

    /// Legacy mapping таблица русское слово → имя ассета.
    ///
    /// **DEPRECATED:** новый код должен пользоваться `LessonContentMap.asset(for:)`,
    /// который читает `HappySpeech/Content/word_manifest.json`. Эта таблица
    /// сохранена как safety-net fallback на случай, если manifest отсутствует
    /// в bundle (например, в Preview-сборках). При расхождении приоритет —
    /// у манифеста.
    private static let wordAssetMap: [String: String] = [
        // Existing assets (43)
        "яблоко": "word_apple", "сумка": "word_bag", "мяч": "word_ball",
        "медведь": "word_bear", "мишка": "word_bear", "кровать": "word_bed",
        "птица": "word_bird", "лодка": "word_boat", "книга": "word_book",
        "бабочка": "word_butterfly_insect", "торт": "word_cake", "машина": "word_car",
        "кот": "word_cat", "кошка": "word_cat", "стул": "word_chair",
        "корова": "word_cow", "чашка": "word_cup", "собака": "word_dog",
        "кукла": "word_doll", "дверь": "word_door", "слон": "word_elephant",
        "рыба": "word_fish", "цветок": "word_flower", "лес": "word_forest",
        "вилка": "word_fork", "лиса": "word_fox", "лягушка": "word_frog",
        "сад": "word_garden", "заяц": "word_hare", "курица": "word_hen",
        "дом": "word_house", "змей": "word_kite", "лампа": "word_lamp",
        "молоко": "word_milk", "луна": "word_moon", "парк": "word_park",
        "ручка": "word_pen", "карандаш": "word_pencil", "петух": "word_rooster",
        "ложка": "word_spoon", "солнце": "word_sun", "стол": "word_table",
        "поезд": "word_train", "дерево": "word_tree", "окно": "word_window",
        // FLUX-generated additions (Block — fig3.8 + Bingo screenshots)
        "лошадка": "word_horse", "лошадь": "word_horse",
        "облако": "word_cloud", "сок": "word_juice", "лист": "word_leaf",
        "лук": "word_onion", "ключ": "word_key", "рука": "word_hand",
        "снег": "word_snow", "мама": "word_mom", "огонь": "word_fire",
        "звезда": "word_star", "нос": "word_nose", "радуга": "word_rainbow",
        "роза": "word_rose", "сыр": "word_cheese", "жук": "word_beetle",
        "вода": "word_water", "гора": "word_mountain", "снежинка": "word_snowflake",
        "барабан": "word_drum", "лопатка": "word_shovel", "часы": "word_clock",
        "часики": "word_clock", "коза": "word_goat", "рысь": "word_lynx",
        "гусь": "word_goose", "горох": "word_peas", "шапка": "word_hat",
        "оса": "word_wasp", "рак": "word_crab", "ведро": "word_bucket",
        "пила": "word_saw", "ракета": "word_rocket", "клоун": "word_clown",
        "топор": "word_axe", "журавль": "word_crane", "забор": "word_fence",
        "лимон": "word_lemon", "орёл": "word_eagle", "орел": "word_eagle",
        "перо": "word_feather", "руль": "word_wheel", "мел": "word_chalk",
        "мухомор": "word_mushroom", "гриб": "word_mushroom",
        // Quick-fix additions for fig3.8 lesson distractors
        "зонт": "word_umbrella", "зонтик": "word_umbrella",
        "жираф": "word_giraffe"
    ]

    /// Picks an Asset name (Illustration) for the given Russian word if available,
    /// otherwise falls back to a generic SF Symbol. HSContentSymbol auto-routes
    /// between Asset / SF Symbol rendering based on the name.
    static func imageSymbol(for word: String) -> String {
        let normalized = word.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:"))
        // Primary: shared LessonContentMap (manifest-backed, 90+ words).
        if let asset = LessonContentMap.asset(for: normalized) { return asset }
        // Try first token (in case word is "одна машина") against the manifest.
        if let firstToken = normalized.components(separatedBy: .whitespaces).first,
           let asset = LessonContentMap.asset(for: firstToken) {
            return asset
        }
        // Legacy fallback: local hardcoded dict (kept for Preview / safety).
        if let asset = wordAssetMap[normalized] { return asset }
        if let firstToken = normalized.components(separatedBy: .whitespaces).first,
           let asset = wordAssetMap[firstToken] {
            return asset
        }
        // SF Symbol fallback by first letter (acoustic group)
        let first = normalized.first
        switch first {
        case "р", "r": return "circle.grid.2x2"
        case "с", "s": return "sun.max"
        case "ш", "w": return "leaf"
        case "л", "l": return "moon"
        case "к", "k": return "key"
        case "з", "z": return "umbrella"
        case "ц", "c": return "flower"
        case "ж", "j": return "bolt"
        case "ч":      return "clock"
        case "щ":      return "bubbles.and.sparkles"
        case "г", "g": return "mountain.2"
        case "х", "h": return "house"
        default:       return "star"
        }
    }
}
