import Foundation
import Observation

// MARK: - MinimalPairs VIP Models
//
// "Минимальные пары" — один из самых важных логопедических шаблонов для
// дифференциации фонетически близких звуков (С/Ш, Р/Л, К/Г, З/Ж …).
// Ребёнок слышит слово (TTS через AVSpeechSynthesizer) и выбирает правильную
// картинку из двух вариантов (target vs foil).
//
// Формат сессии: 10 раундов, на каждом 2 карточки, после выбора — фидбек,
// автопереход через 1.5с. Расчёт звёзд:
//   - 90%+ правильных → 3 звезды
//   - 70%+           → 2
//   - 50%+           → 1
//   - иначе           → 0
//
// Файл содержит только типы: Request/Response/ViewModel + Display store.

// MARK: - Domain: MinimalPairRound

/// Одна минимальная пара: целевое слово + фоил-дистрактор.
/// `targetIsLeft` — сгенерированный при создании раунда флаг, какая карточка —
/// правильная. Создаётся при `MinimalPairRound.rounds(count:)`.
struct MinimalPairRound: Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let targetWord: String
    let foilWord: String
    let targetEmoji: String
    let foilEmoji: String
    let soundContrast: String
    let targetIsLeft: Bool
}

extension MinimalPairRound {

    /// Канонический каталог минимальных пар. Источник: Коноваленко
    /// "Дифференциация звуков", адаптирован под возраст 5–8.
    /// `targetIsLeft` в каталоге — только seed, финальные раунды
    /// рандомизируют сторону в `rounds(count:)`.
    static let catalog: [MinimalPairRound] = [
        MinimalPairRound(
            id: "rak_lak",
            targetWord: "рак", foilWord: "лак",
            targetEmoji: "🦞",  foilEmoji: "💅",
            soundContrast: "Р-Л", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "rama_lama",
            targetWord: "рама", foilWord: "лама",
            targetEmoji: "🪟",   foilEmoji: "🦙",
            soundContrast: "Р-Л", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "roza_koza",
            targetWord: "роза", foilWord: "коза",
            targetEmoji: "🌹",   foilEmoji: "🐐",
            soundContrast: "Р-К", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "sova_shuba",
            targetWord: "сова", foilWord: "шуба",
            targetEmoji: "🦉",   foilEmoji: "🧥",
            soundContrast: "С-Ш", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "sumy_shumy",
            targetWord: "сумы", foilWord: "шумы",
            targetEmoji: "👜",   foilEmoji: "🔊",
            soundContrast: "С-Ш", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "suk_zhuk",
            targetWord: "сук", foilWord: "жук",
            targetEmoji: "🌿",  foilEmoji: "🐛",
            soundContrast: "С-Ж", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "zima_zhima",
            targetWord: "зима", foilWord: "жима",
            targetEmoji: "❄️",   foilEmoji: "💪",
            soundContrast: "З-Ж", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "lisa_lysa",
            targetWord: "лиса", foilWord: "лыса",
            targetEmoji: "🦊",   foilEmoji: "👤",
            soundContrast: "Л-Л'", targetIsLeft: true
        ),
        MinimalPairRound(
            id: "kot_god",
            targetWord: "кот", foilWord: "год",
            targetEmoji: "🐱",  foilEmoji: "📅",
            soundContrast: "К-Г", targetIsLeft: false
        ),
        MinimalPairRound(
            id: "gora_hora",
            targetWord: "гора", foilWord: "хора",
            targetEmoji: "⛰️",   foilEmoji: "💃",
            soundContrast: "Г-Х", targetIsLeft: true
        ),
    ]

    /// Готовит список раундов на сессию. Рандомизирует порядок и сторону
    /// целевой карточки. Если `contrast` пустой — берём все, иначе фильтруем.
    static func rounds(count: Int = 10, contrast: String = "") -> [MinimalPairRound] {
        let pool: [MinimalPairRound] = contrast.isEmpty
            ? catalog
            : catalog.filter { $0.soundContrast == contrast }
        let source = pool.isEmpty ? catalog : pool
        let shuffled = source.shuffled()
        // Гарантируем хотя бы count элементов — повторим если меньше в пуле.
        var result: [MinimalPairRound] = []
        result.reserveCapacity(count)
        var i = 0
        while result.count < count, !shuffled.isEmpty {
            let base = shuffled[i % shuffled.count]
            let randomizedSide = Bool.random()
            result.append(
                MinimalPairRound(
                    id: "\(base.id)-\(result.count)",
                    targetWord: base.targetWord,
                    foilWord: base.foilWord,
                    targetEmoji: base.targetEmoji,
                    foilEmoji: base.foilEmoji,
                    soundContrast: base.soundContrast,
                    targetIsLeft: randomizedSide
                )
            )
            i += 1
        }
        return result
    }
}

// MARK: - VIP Envelopes

enum MinimalPairsModels {

    // MARK: LoadSession
    enum LoadSession {
        struct Request: Sendable {
            let soundContrast: String
            let childName: String
        }
        struct Response: Sendable {
            let rounds: [MinimalPairRound]
            let childName: String
        }
        struct ViewModel: Sendable {
            let totalRounds: Int
            let greeting: String
        }
    }

    // MARK: StartRound
    enum StartRound {
        struct Request: Sendable {
            let roundIndex: Int
        }
        struct Response: Sendable {
            let pair: MinimalPairRound
            let roundNumber: Int
            let total: Int
        }
        struct ViewModel: Sendable {
            let pair: MinimalPairRound
            let progressLabel: String
            let promptText: String
            let targetWord: String
        }
    }

    // MARK: SelectOption
    enum SelectOption {
        struct Request: Sendable {
            let selectedIsTarget: Bool
        }
        struct Response: Sendable {
            let correct: Bool
            let correctAnswer: String
        }
        struct ViewModel: Sendable {
            let correct: Bool
            let feedbackText: String
            let correctAnswer: String
        }
    }

    // MARK: CompleteSession
    enum CompleteSession {
        struct Request: Sendable {}
        struct Response: Sendable {
            let correctCount: Int
            let totalRounds: Int
        }
        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
        }
    }
}

// MARK: - Display Store

/// Наблюдаемое состояние экрана. View пишет в него через
/// `MinimalPairsDisplayLogic`. Хранит фазу игры + все viewmodel-поля.
@Observable
@MainActor
final class MinimalPairsDisplay {
    var totalRounds: Int = 10
    var greeting: String = ""
    var currentPair: MinimalPairRound?
    var progressLabel: String = ""
    var promptText: String = ""
    var correct: Bool = false
    var feedbackText: String = ""
    var correctAnswer: String = ""
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var phase: MinimalPairsPhase = .loading
    var isAnswered: Bool = false
    var selectedIsTarget: Bool?
    var pendingFinalScore: Float?

    // Локальные счётчики корректных ответов для финального скора. Обновляются
    // в `displaySelectOption`, используются в `finalize()` view.
    var answeredCount: Int = 0
    var correctCount: Int = 0
}

enum MinimalPairsPhase: Sendable, Equatable {
    case loading
    case round
    case feedback
    case completed
}
